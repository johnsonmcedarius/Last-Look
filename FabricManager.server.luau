local CollectionService   = game:GetService("CollectionService")
local ReplicatedStorage   = game:GetService("ReplicatedStorage")
local Players             = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")

-- Service & Module Imports
local ServiceRegistry = require(ServerScriptService:WaitForChild("ServiceRegistry"))
local RoundEvents     = require(ServerScriptService:WaitForChild("RoundEvents"))
local Config          = require(ReplicatedStorage:WaitForChild("SharedConfig"))
local VFX             = require(ReplicatedStorage:WaitForChild("VFXModule"))

-- Defer service lookups to avoid race conditions
local function getShowstopperService()
	return ServiceRegistry.Get("ShowstopperService")
end
local function getRewardTracker()
	return ServiceRegistry.Get("RewardTracker")
end
local function getFabricCarrierService()
	return ServiceRegistry.Get("FabricCarrierService")
end

local SoundService = require(ReplicatedStorage:WaitForChild("SoundService"))
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

-- ── Remotes Helper ───────────────────────────────────────────────────────────
local function getRemote(name, className)
	local r = Remotes:FindFirstChild(name)
	if not r then 
		r = Instance.new(className or "RemoteEvent") 
		r.Name = name 
		r.Parent = Remotes 
	end
	return r
end

local UpdateDualScore = getRemote("UpdateDualScore")
local SabotagePing = getRemote("SabotagePing")
local ObjectiveWarning = getRemote("ObjectiveWarning")
local RackStateChanged = getRemote("RackStateChanged")
local ShowRewardPopup = getRemote("ShowRewardPopup")

-- ── Constants & Balancing ──
local SABOTAGE_DURATION      = 20
local SABOTAGE_HOLD_DURATION = 3.5
local REBOOT_HOLD_DURATION   = 3
local NORMAL_PICKUP_HOLD     = 2.5
local SABOTAGED_PICKUP_HOLD  = 5.0
local RACK_COOLDOWN          = 5
local BIN_HITBOX_SIZE        = Vector3.new(10, 8, 10)
local SHREDDER_HITBOX_SIZE   = Vector3.new(10, 8, 10)

local GameSettings = {
	TotalFabricNeeded = 5,
	CriticTeamName    = "Critics",
	DesignerTeamName  = "Designers",
}

-- ── State Management ──
local designerScore = 0
local criticScore = 0
local activeSabotages = 0
local tangleTimers = {}

local function UpdateDualScoreUI()
	local MatchRegistry = ServiceRegistry.Get("MatchRegistry")
	local target = MatchRegistry and MatchRegistry.GetTargetScore() or 5
	UpdateDualScore:FireAllClients(designerScore, criticScore, target)
end

local FabricManager = {}

-- ── Helpers ──────────────────────────────────────────────────────────────────

local function isWithinRange(player, target)
	if not player.Character or not player.Character:FindFirstChild("HumanoidRootPart") then return false end
	local dist = (player.Character.HumanoidRootPart.Position - target.Position).Magnitude
	return dist <= (Config.MAX_INTERACTION_DISTANCE or 30)
end

-- ── PHASE 8: Back-Anchor Logic for FBRoll ──
-- Ensures fabric roll attaches to HumanoidRootPart, not limbs
local function attachFabricToBack(player, tool)
	local char = player.Character
	if not char then return end
	
	local hrp = char:FindFirstChild("HumanoidRootPart")
	if not hrp then return end
	
	local handle = tool:FindFirstChild("Handle") or tool:FindFirstChild("BackHandle")
	if not handle then return end
	
	-- Remove any existing welds
	for _, child in ipairs(handle:GetChildren()) do
		if child:IsA("WeldConstraint") or child:IsA("ManualWeld") then
			child:Destroy()
		end
	end
	
	-- PHASE 4 FIX: Position first, then weld to prevent teleportation
	handle.CFrame = hrp.CFrame * CFrame.new(0, 0, 1.5) * CFrame.Angles(0, math.rad(180), 0)

	-- Create weld to HumanoidRootPart (centered on back)
	local weld = Instance.new("WeldConstraint")
	weld.Name = "BackWeld"
	weld.Part0 = hrp
	weld.Part1 = handle
	weld.Enabled = true
	weld.Parent = handle
	
	print("[FABRIC] " .. player.Name .. " fabric roll anchored to HumanoidRootPart")
end

-- Watch for FBRoll equipment to apply back-anchor
local function watchFabricEquipment(player)
	local function onToolEquipped(tool)
		if tool.Name == "FBRoll" then
			attachFabricToBack(player, tool)
		end
	end
	
	local function onChildAdded(child)
		if child:IsA("Tool") and child.Name == "FBRoll" then
			-- Small delay to ensure tool is fully equipped
			task.defer(function()
				attachFabricToBack(player, child)
			end)
		end
	end
	
	player.Character.ChildAdded:Connect(onChildAdded)
end

local function setRackState(rack, sabotaged)
	local regular  = rack:FindFirstChild("RegularState")
	local sabState = rack:FindFirstChild("SabotagedState")

	if regular then
		for _, p in ipairs(regular:GetDescendants()) do
			if p:IsA("BasePart") then
				p.Transparency = sabotaged and 1 or 0
				p.CanCollide   = not sabotaged
			end
		end
	end

	if sabState then
		for _, p in ipairs(sabState:GetDescendants()) do
			if p:IsA("BasePart") then
				p.Transparency = sabotaged and 0 or 1
				p.CanCollide   = sabotaged
			end
		end
	end

	rack:SetAttribute("IsSabotaged", sabotaged)
	RackStateChanged:FireAllClients(rack, sabotaged)
end

-- ── Score Getters ──
function FabricManager.GetDesignerScore()
	return designerScore
end

function FabricManager.GetCriticScore()
	return criticScore
end

function FabricManager.ResetScores()
	designerScore = 0
	criticScore = 0
end

function FabricManager.IsSabotageAvailable()
	return true -- Sabotage is now only on scoring zones, not racks
end

function FabricManager.CleanseNearbySabotage(player, radius)
	local pos = player.Character and player.Character.PrimaryPart and player.Character.PrimaryPart.Position
	if not pos then return end
	
	local teamName = player.Team and player.Team.Name
	
	-- Check Bins
	for _, bin in ipairs(CollectionService:GetTagged("FabricBins")) do
		if (bin:GetPivot().Position - pos).Magnitude <= radius then
			if bin:GetAttribute("IsSabotaged") then
				bin:SetAttribute("IsSabotaged", false)
				VFX.Play("SabotageClear", bin:GetPivot().Position)
				SoundService.FireToAll("Unsabotage", bin:GetPivot().Position)
				-- Clear warning for team
				ObjectiveWarning:FireAllClients("Designers", false)
				
				-- Clean up any reboot prompts that might be there
				local reboot = bin:FindFirstChild("BinReboot")
				if reboot then reboot:Destroy() end
				
				print("[FABRIC] Glitch Gala rebooted Bin for " .. player.Name)
			end
		end
	end
	
	-- Check Shredders
	for _, shredder in ipairs(CollectionService:GetTagged("FabricShredders")) do
		if (shredder:GetPivot().Position - pos).Magnitude <= radius then
			if shredder:GetAttribute("IsSabotaged") then
				shredder:SetAttribute("IsSabotaged", false)
				VFX.Play("SabotageClear", shredder:GetPivot().Position)
				SoundService.FireToAll("Unsabotage", shredder:GetPivot().Position)
				ObjectiveWarning:FireAllClients("Critics", false)
				
				local reboot = shredder:FindFirstChild("ShredderReboot")
				if reboot then reboot:Destroy() end
				
				print("[FABRIC] Glitch Gala rebooted Shredder for " .. player.Name)
			end
		end
	end
end

local function unsabotageRack(rack)
	if not rack or not rack.Parent then return end
	if not rack:GetAttribute("IsSabotaged") then return end

	setRackState(rack, false)
	activeSabotages = math.max(0, activeSabotages - 1)

	-- Reset both prompts to normal state
	local dp = rack:FindFirstChild("DesignerPickup")
	local cp = rack:FindFirstChild("CriticPickup")
	if dp then 
		dp.HoldDuration = NORMAL_PICKUP_HOLD
		dp.ActionText = "Collect Fabric"
	end
	if cp then
		cp.HoldDuration = NORMAL_PICKUP_HOLD
		cp.ActionText = "Collect Fabric"
	end
end

-- ── Interaction Logic ──

local function setupFabricRack(rack)
	rack:SetAttribute("IsOnCooldown", false)
	rack:SetAttribute("IsSabotaged", false)
	setRackState(rack, false)

	-- DESIGNER COLLECTION PROMPT
	local dp = rack:FindFirstChild("DesignerPickup") or Instance.new("ProximityPrompt")
	dp.Name = "DesignerPickup"
	dp.ActionText = "Collect Fabric"
	dp.ObjectText = "Fabric Rack"
	dp.HoldDuration = NORMAL_PICKUP_HOLD
	dp.MaxActivationDistance = 8
	dp.Parent = rack
	CollectionService:AddTag(dp, "DesignerPrompt")

	-- CRITIC COLLECTION PROMPT (NEW - Both teams collect)
	local cp = rack:FindFirstChild("CriticPickup") or Instance.new("ProximityPrompt")
	cp.Name = "CriticPickup"
	cp.ActionText = "Collect Fabric"
	cp.ObjectText = "Fabric Rack"
	cp.HoldDuration = NORMAL_PICKUP_HOLD
	cp.MaxActivationDistance = 8
	cp.Parent = rack
	CollectionService:AddTag(cp, "CriticPrompt")

	-- DESIGNER COLLECTION LOGIC
	dp.Triggered:Connect(function(player)
		if not (player.Team and player.Team.Name == GameSettings.DesignerTeamName) then return end
		if rack:GetAttribute("IsOnCooldown") then return end

		local rackBase = rack:FindFirstChildWhichIsA("BasePart") or rack.PrimaryPart
		if not isWithinRange(player, rackBase) then return end

		-- Check if team can carry fabric (1 per team limit)
		local FabricCarrierService = getFabricCarrierService()
		if FabricCarrierService and not FabricCarrierService.CanCarry(player) then
			print("[FABRIC] " .. player.Name .. " cannot carry - teammate already has fabric")
			return
		end

		local hasFabric = player.Backpack:FindFirstChild("FBRoll") or (player.Character and player.Character:FindFirstChild("FBRoll"))
		if hasFabric then return end

		local wasSabotaged = rack:GetAttribute("IsSabotaged")

		-- Give FBRoll tool
		local assets = ReplicatedStorage:FindFirstChild("Assets")
		local fbAsset = assets and assets:FindFirstChild("FBRoll")
		if fbAsset then fbAsset:Clone().Parent = player.Backpack end

		-- Mark as carrier
		if FabricCarrierService then
			FabricCarrierService.SetCarrier(player)
		end

		-- Feedback
		VFX.Play("FabricRackPickup", rackBase.Position)
		SoundService.FireToAll("FabricPickup", rackBase.Position)

		if wasSabotaged then
			unsabotageRack(rack)
			if tangleTimers[rack] then task.cancel(tangleTimers[rack]) end
		end

		local RewardTracker = getRewardTracker()
		if RewardTracker then RewardTracker.OnFabricCollect(player) end
		rack:SetAttribute("IsOnCooldown", true)
		dp.Enabled = false
		cp.Enabled = false

		task.delay(RACK_COOLDOWN, function()
			if not rack or not rack.Parent then return end
			rack:SetAttribute("IsOnCooldown", false)
			dp.Enabled = true
			cp.Enabled = true
		end)
	end)

	-- CRITIC COLLECTION LOGIC (NEW)
	cp.Triggered:Connect(function(player)
		if not (player.Team and player.Team.Name == GameSettings.CriticTeamName) then return end
		if rack:GetAttribute("IsOnCooldown") then return end

		local rackBase = rack:FindFirstChildWhichIsA("BasePart") or rack.PrimaryPart
		if not isWithinRange(player, rackBase) then return end

		-- Check if team can carry fabric (1 per team limit)
		local FabricCarrierService = getFabricCarrierService()
		if FabricCarrierService and not FabricCarrierService.CanCarry(player) then
			print("[FABRIC] " .. player.Name .. " cannot carry - teammate already has fabric")
			return
		end

		local hasFabric = player.Backpack:FindFirstChild("FBRoll") or (player.Character and player.Character:FindFirstChild("FBRoll"))
		if hasFabric then return end

		local wasSabotaged = rack:GetAttribute("IsSabotaged")

		-- Give FBRoll tool
		local assets = ReplicatedStorage:FindFirstChild("Assets")
		local fbAsset = assets and assets:FindFirstChild("FBRoll")
		if fbAsset then fbAsset:Clone().Parent = player.Backpack end

		-- Mark as carrier
		if FabricCarrierService then
			FabricCarrierService.SetCarrier(player)
		end

		-- Feedback
		VFX.Play("FabricRackPickup", rackBase.Position)
		SoundService.FireToAll("FabricPickup", rackBase.Position)

		if wasSabotaged then
			unsabotageRack(rack)
			if tangleTimers[rack] then task.cancel(tangleTimers[rack]) end
		end

		local RewardTracker = getRewardTracker()
		if RewardTracker then RewardTracker.OnFabricCollect(player) end
		rack:SetAttribute("IsOnCooldown", true)
		dp.Enabled = false
		cp.Enabled = false

		task.delay(RACK_COOLDOWN, function()
			if not rack or not rack.Parent then return end
			rack:SetAttribute("IsOnCooldown", false)
			dp.Enabled = true
			cp.Enabled = true
		end)
	end)
end

local function setupFabricBin(bin)
	local hitbox = bin:FindFirstChild("DepositHitbox") or Instance.new("Part")
	if not hitbox.Parent then
		hitbox.Name = "DepositHitbox"
		hitbox.Size = BIN_HITBOX_SIZE
		hitbox.Transparency = 1
		hitbox.CanCollide = false
		hitbox.Anchored = true
		local binBase = bin:IsA("BasePart") and bin or bin:FindFirstChildWhichIsA("BasePart")
		if binBase then hitbox.CFrame = binBase.CFrame end
		hitbox.Parent = bin
	end

	local depositing = {}

	hitbox.Touched:Connect(function(hit)
		-- PHASE 4 FIX: Lock bins when round is not active
		local RoundService = ServiceRegistry.Get("RoundService")
		if not RoundService or RoundService.Phase ~= "Active" then return end

		local player = Players:GetPlayerFromCharacter(hit.Parent)
		if not player or not (player.Team and player.Team.Name == GameSettings.DesignerTeamName) then return end
		if depositing[player.UserId] then return end

		local fabricTool = hit.Parent:FindFirstChild("FBRoll") or player.Backpack:FindFirstChild("FBRoll")
		if not fabricTool then return end

		depositing[player.UserId] = true
		fabricTool:Destroy()  -- ALWAYS destroy the fabric

		-- Clear carrier status
		local FabricCarrierService = getFabricCarrierService()
		if FabricCarrierService then
			FabricCarrierService.OnFabricDeposited(player)
		end

		if bin:GetAttribute("IsSabotaged") then
			-- Sabotaged: Take but don't count
			VFX.Play("SabotagedDeposit", hitbox.Position)
			ShowRewardPopup:FireClient(player, "SABOTAGED!", "Fabric lost!")
			print("[FABRIC] " .. player.Name .. " deposited to sabotaged bin - no score!")
		else
			-- Normal: Score it
			designerScore += 1
			UpdateDualScoreUI()

			VFX.Play("FabricDeposit", hitbox.Position)
			local ShowstopperService = getShowstopperService()
			if ShowstopperService then ShowstopperService.OnFabricDunk(player) end
			ShowRewardPopup:FireClient(player, "+25 XP", "+10 Coins")
		end

		task.delay(0.5, function() depositing[player.UserId] = nil end)
	end)
end

-- ── Fabric Shredder (Critic Scoring Zone) ──

local function setupFabricShredder(shredder)
	local hitbox = shredder:FindFirstChild("ShredHitbox") or Instance.new("Part")
	if not hitbox.Parent then
		hitbox.Name = "ShredHitbox"
		hitbox.Size = SHREDDER_HITBOX_SIZE
		hitbox.Transparency = 1
		hitbox.CanCollide = false
		hitbox.Anchored = true
		local shredderBase = shredder:IsA("BasePart") and shredder or shredder:FindFirstChildWhichIsA("BasePart")
		if shredderBase then hitbox.CFrame = shredderBase.CFrame end
		hitbox.Parent = shredder
	end

	local depositing = {}

	hitbox.Touched:Connect(function(hit)
		-- PHASE 4 FIX: Lock shredders when round is not active
		local RoundService = ServiceRegistry.Get("RoundService")
		if not RoundService or RoundService.Phase ~= "Active" then return end

		local player = Players:GetPlayerFromCharacter(hit.Parent)
		if not player or not (player.Team and player.Team.Name == GameSettings.CriticTeamName) then return end
		if depositing[player.UserId] then return end

		local fabricTool = hit.Parent:FindFirstChild("FBRoll") or player.Backpack:FindFirstChild("FBRoll")
		if not fabricTool then return end

		depositing[player.UserId] = true
		fabricTool:Destroy()  -- ALWAYS destroy the fabric

		-- Clear carrier status
		local FabricCarrierService = getFabricCarrierService()
		if FabricCarrierService then
			FabricCarrierService.OnFabricDeposited(player)
		end

		if shredder:GetAttribute("IsSabotaged") then
			-- Sabotaged: Take but don't count
			VFX.Play("SabotagedShred", hitbox.Position)
			ShowRewardPopup:FireClient(player, "SABOTAGED!", "Fabric lost!")
			print("[FABRIC] " .. player.Name .. " shredded at sabotaged shredder - no score!")
		else
			-- Normal: Score it
			criticScore += 1
			UpdateDualScoreUI()

			VFX.Play("FabricShred", hitbox.Position)
			local ShowstopperService = getShowstopperService()
			if ShowstopperService and ShowstopperService.OnFabricShred then
				ShowstopperService.OnFabricShred(player)
			end
			ShowRewardPopup:FireClient(player, "+25 XP", "+10 Coins")
		end

		task.delay(0.5, function() depositing[player.UserId] = nil end)
	end)
end

-- ── Cross-Team Sabotage ──

local function setupBinSabotage(bin)
	local sabotagePrompt = Instance.new("ProximityPrompt")
	sabotagePrompt.Name = "BinSabotage"
	sabotagePrompt.ActionText = "Sabotage Bin"
	sabotagePrompt.ObjectText = "Designer Scoring Zone"
	sabotagePrompt.HoldDuration = SABOTAGE_HOLD_DURATION
	sabotagePrompt.MaxActivationDistance = 8
	sabotagePrompt.Parent = bin
	CollectionService:AddTag(sabotagePrompt, "CriticPrompt")

	sabotagePrompt.Triggered:Connect(function(critic)
		if not (critic.Team and critic.Team.Name == GameSettings.CriticTeamName) then return end
		if bin:GetAttribute("IsSabotaged") then return end

		bin:SetAttribute("IsSabotaged", true)
		VFX.PlaySabotageVFX(bin)
		SoundService.FireToAll("HairsprayHiss", bin:GetPivot().Position)
		-- Notify affected team (Designers) their bin is sabotaged
		SabotagePing:FireAllClients(bin, "Designers", "Collection Bin")
		ObjectiveWarning:FireAllClients("Designers", true)
		-- Global announcement
		local Announcer = ServiceRegistry.Get("ShowstopperAnnouncer")
		if Announcer and Announcer.AnnounceSabotage then
			Announcer.AnnounceSabotage("Designers", "Collection Bin")
		end

		-- Add Reboot prompt for Designers
		local rebootPrompt = Instance.new("ProximityPrompt")
		rebootPrompt.Name = "BinReboot"
		rebootPrompt.ActionText = "Reboot Bin"
		rebootPrompt.HoldDuration = REBOOT_HOLD_DURATION
		rebootPrompt.MaxActivationDistance = 8
		rebootPrompt.Parent = bin
		CollectionService:AddTag(rebootPrompt, "DesignerPrompt")

		rebootPrompt.Triggered:Connect(function(designer)
			if not (designer.Team and designer.Team.Name == GameSettings.DesignerTeamName) then return end
			bin:SetAttribute("IsSabotaged", false)
			rebootPrompt:Destroy()
			VFX.Play("SabotageClear", bin:GetPivot().Position)
			SoundService.FireToAll("Unsabotage", bin:GetPivot().Position)
			-- Clear warning for Designers
			ObjectiveWarning:FireAllClients("Designers", false)
		end)
	end)
end

local function setupShredderSabotage(shredder)
	local sabotagePrompt = Instance.new("ProximityPrompt")
	sabotagePrompt.Name = "ShredderSabotage"
	sabotagePrompt.ActionText = "Sabotage Shredder"
	sabotagePrompt.ObjectText = "Critic Scoring Zone"
	sabotagePrompt.HoldDuration = SABOTAGE_HOLD_DURATION
	sabotagePrompt.MaxActivationDistance = 8
	sabotagePrompt.Parent = shredder
	CollectionService:AddTag(sabotagePrompt, "DesignerPrompt")

	sabotagePrompt.Triggered:Connect(function(designer)
		if not (designer.Team and designer.Team.Name == GameSettings.DesignerTeamName) then return end
		if shredder:GetAttribute("IsSabotaged") then return end

		shredder:SetAttribute("IsSabotaged", true)
		VFX.PlaySabotageVFX(shredder)
		SoundService.FireToAll("HairsprayHiss", shredder:GetPivot().Position)
		-- Notify affected team (Critics) their shredder is sabotaged
		SabotagePing:FireAllClients(shredder, "Critics", "Industrial Shredder")
		ObjectiveWarning:FireAllClients("Critics", true)
		-- Global announcement
		local Announcer = ServiceRegistry.Get("ShowstopperAnnouncer")
		if Announcer and Announcer.AnnounceSabotage then
			Announcer.AnnounceSabotage("Critics", "Industrial Shredder")
		end

		-- Add Reboot prompt for Critics
		local rebootPrompt = Instance.new("ProximityPrompt")
		rebootPrompt.Name = "ShredderReboot"
		rebootPrompt.ActionText = "Reboot Shredder"
		rebootPrompt.HoldDuration = REBOOT_HOLD_DURATION
		rebootPrompt.MaxActivationDistance = 8
		rebootPrompt.Parent = shredder
		CollectionService:AddTag(rebootPrompt, "CriticPrompt")

		rebootPrompt.Triggered:Connect(function(critic)
			if not (critic.Team and critic.Team.Name == GameSettings.CriticTeamName) then return end
			shredder:SetAttribute("IsSabotaged", false)
			rebootPrompt:Destroy()
			VFX.Play("SabotageClear", shredder:GetPivot().Position)
			SoundService.FireToAll("Unsabotage", shredder:GetPivot().Position)
			-- Clear warning for Critics
			ObjectiveWarning:FireAllClients("Critics", false)
		end)
	end)
end

-- ── Lifecycle ──

local function resetAll()
	designerScore = 0
	criticScore = 0
	activeSabotages = 0
	UpdateDualScoreUI()
	for _, timer in pairs(tangleTimers) do task.cancel(timer) end
	tangleTimers = {}

	for _, rack in ipairs(CollectionService:GetTagged("FabricRacks")) do
		setRackState(rack, false)
		rack:SetAttribute("IsOnCooldown", false)
	end

	for _, bin in ipairs(CollectionService:GetTagged("FabricBins")) do
		bin:SetAttribute("IsSabotaged", false)
	end

	for _, shredder in ipairs(CollectionService:GetTagged("FabricShredders")) do
		shredder:SetAttribute("IsSabotaged", false)
	end
end

RoundEvents.Intermission.Event:Connect(resetAll)

-- Initial Setup
for _, r in ipairs(CollectionService:GetTagged("FabricRacks")) do setupFabricRack(r) end
for _, b in ipairs(CollectionService:GetTagged("FabricBins")) do
	setupFabricBin(b)
	setupBinSabotage(b)
end
for _, s in ipairs(CollectionService:GetTagged("FabricShredders")) do
	setupFabricShredder(s)
	setupShredderSabotage(s)
end

CollectionService:GetInstanceAddedSignal("FabricRacks"):Connect(setupFabricRack)
CollectionService:GetInstanceAddedSignal("FabricBins"):Connect(function(b)
	setupFabricBin(b)
	setupBinSabotage(b)
end)
CollectionService:GetInstanceAddedSignal("FabricShredders"):Connect(function(s)
	setupFabricShredder(s)
	setupShredderSabotage(s)
end)

-- PHASE 8: Watch for fabric equipment to apply back-anchor
for _, player in ipairs(Players:GetPlayers()) do
	player.CharacterAdded:Connect(function()
		watchFabricEquipment(player)
	end)
	if player.Character then
		watchFabricEquipment(player)
	end
end
Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function()
		watchFabricEquipment(player)
	end)
end)

ServiceRegistry.Register("FabricManager", FabricManager)
return FabricManager