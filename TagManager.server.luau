local Players         = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Teams           = game:GetService("Teams")
local ServerScriptService = game:GetService("ServerScriptService")
local CollectionService = game:GetService("CollectionService")

local ServiceRegistry = require(ServerScriptService:WaitForChild("ServiceRegistry"))
local RoundEvents     = require(ServerScriptService:WaitForChild("RoundEvents"))
local Config          = require(ReplicatedStorage:WaitForChild("SharedConfig"))

-- Await hard deps
local Relevance       = ServiceRegistry.Await("RelevanceSystem")
local RewardTracker   = ServiceRegistry.Await("RewardTracker")
local ShowstopperService = ServiceRegistry.Await("ShowstopperService")
local DataManager     = ServiceRegistry.Await("DataManager")
local SkinEffects     = require(ServerScriptService:WaitForChild("SkinEffectService"))

local SoundService = require(ReplicatedStorage:WaitForChild("SoundService"))
local Assets        = ReplicatedStorage:WaitForChild("Assets")
local Podiums       = Assets:WaitForChild("Podiums")

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local SpawnPodiumVFX    = Remotes:WaitForChild("SpawnPodiumVFX")
local DespawnPodiumVFX  = Remotes:WaitForChild("DespawnPodiumVFX")
local FreezeEvent       = Remotes:WaitForChild("FreezeEvent")

local frozenPlayers = {}
local frozenCritics = {}

-- ── Clash Mechanic: Track pending freezes for simultaneous detection ──
local pendingFreezes = {}  -- [playerUserId] = {targetUserId, timestamp}
local CLASH_WINDOW = 0.1   -- 100ms window for "simultaneous" freeze
local CLASH_PUSH_FORCE = 50

-- ── Clash Mechanic: Pushback on simultaneous freeze ──
local function applyClashPushback(p1, p2)
	local p1Root = p1.Character and p1.Character:FindFirstChild("HumanoidRootPart")
	local p2Root = p2.Character and p2.Character:FindFirstChild("HumanoidRootPart")
	if not p1Root or not p2Root then return end

	-- Calculate pushback direction (away from each other)
	local dir = (p1Root.Position - p2Root.Position).Unit
	if dir.Magnitude == 0 then
		dir = Vector3.new(1, 0, 0)  -- Default direction if on same position
	end

	-- Apply velocity to both players
	p1Root.AssemblyLinearVelocity = dir * CLASH_PUSH_FORCE
	p2Root.AssemblyLinearVelocity = -dir * CLASH_PUSH_FORCE

	-- VFX and sound
	local midPoint = (p1Root.Position + p2Root.Position) / 2
	VFX.Play("ClashSpark", midPoint)
	SoundService.FireToAll("ClashSound", midPoint)

	-- UI notification
	local ClashNotification = Remotes:FindFirstChild("ClashNotification")
	if ClashNotification then
		ClashNotification:FireAllClients(p1.Name, p2.Name)
	end

	print("[TAG] CLASH! " .. p1.Name .. " and " .. p2.Name .. " froze simultaneously - both pushed back!")
end
local function createCountdownBillboard(root)
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "CancelCountdown"
	billboard.Size = UDim2.fromOffset(120, 40)
	billboard.StudsOffset = Vector3.new(0, 4, 0)
	billboard.AlwaysOnTop = false
	billboard.Parent = root

	local label = Instance.new("TextLabel")
	label.Name = "TimerLabel"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.TextColor3 = Color3.fromRGB(255, 80, 80)
	label.TextStrokeTransparency = 0.5
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.Text = Config.CANCELLATION_TIME .. "s"
	label.Parent = billboard

	return billboard, label
end

local function checkTotalFreeze()
	local designersTeam = Teams:FindFirstChild("Designers")
	if not designersTeam then return end

	local designers = designersTeam:GetPlayers()
	local totalFrozen = 0
	for _ in pairs(frozenPlayers) do totalFrozen += 1 end

	if totalFrozen >= #designers and #designers > 0 then
		ReplicatedStorage:SetAttribute("AllDesignersFrozen", true)
	end
end

local function checkTotalCriticFreeze()
	local criticsTeam = Teams:FindFirstChild("Critics")
	if not criticsTeam then return end

	local critics = criticsTeam:GetPlayers()
	local totalFrozen = 0
	for _ in pairs(frozenCritics) do totalFrozen += 1 end

	if totalFrozen >= #critics and #critics > 0 then
		ReplicatedStorage:SetAttribute("AllCriticsFrozen", true)
	end
end

-- ── Unfreeze (Rescue) ──
local function unfreezePlayer(targetPlayer, rescuer)
	local data = frozenPlayers[targetPlayer.UserId] or frozenCritics[targetPlayer.UserId]
	if not data then return end

	local isDesigner = frozenPlayers[targetPlayer.UserId] ~= nil
	local frozenTable = isDesigner and frozenPlayers or frozenCritics

	if targetPlayer.Character then
		SkinEffects.ClearManual(targetPlayer.Character)
		local standEffect = targetPlayer:GetAttribute("EquippedSkinEffect") or "None"
		SkinEffects.ApplyManual(targetPlayer, targetPlayer.Character, standEffect)
	end

	if data.Podium then
		DespawnPodiumVFX:FireAllClients(data.Podium:GetPivot().Position)
		SoundService.FireToAll("PodiumDespawn", data.Podium:GetPivot().Position)
		data.Podium:Destroy()
	end

	if data.PoseAnim then data.PoseAnim:Stop() end
	if data.Countdown then data.Countdown:Destroy() end

	local root = targetPlayer.Character and targetPlayer.Character:FindFirstChild("HumanoidRootPart")
	local humanoid = targetPlayer.Character and targetPlayer.Character:FindFirstChild("Humanoid")

	if root then root.Anchored = false end

	-- GHOSTING BUFF: 2-second invincibility + transparency
	if targetPlayer.Character and humanoid then
		targetPlayer:SetAttribute("IsGhosting", true)
		humanoid.WalkSpeed = 0 -- Brief stun during ghosting

		-- Transparency effect
		for _, part in ipairs(targetPlayer.Character:GetDescendants()) do
			if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
				part.Transparency = 0.6
			end
		end

		task.delay(2, function()
			if not targetPlayer.Character then return end
			targetPlayer:SetAttribute("IsGhosting", false)
			humanoid.WalkSpeed = Config.WALK_SPEED or 16
			for _, part in ipairs(targetPlayer.Character:GetDescendants()) do
				if part:IsA("BasePart") then
					part.Transparency = 0
				end
			end
		end)
	end

	SoundService.FireToAll("PlayerUnfrozen", root and root.Position or Vector3.zero)

	if rescuer then
		ShowstopperService.OnTeamRescue(rescuer)
		RewardTracker.OnUnfreezeAlly(rescuer)
	end

	frozenTable[targetPlayer.UserId] = nil

	-- Update appropriate freeze attribute
	if isDesigner then
		ReplicatedStorage:SetAttribute("AllDesignersFrozen", false)
	else
		ReplicatedStorage:SetAttribute("AllCriticsFrozen", false)
	end
end

-- ── Freeze (Podium Setup) ──
local function freezePlayer(targetPlayer, attacker)
	-- Determine which tracking table to use
	local isDesigner = targetPlayer.Team and targetPlayer.Team.Name == "Designers"
	local isCritic = targetPlayer.Team and targetPlayer.Team.Name == "Critics"
	if not isDesigner and not isCritic then return end

	local frozenTable = isDesigner and frozenPlayers or frozenCritics
	if frozenTable[targetPlayer.UserId] then return end

	-- Strike System Integration (universal)
	local isEliminated = Relevance.AddStrike(targetPlayer)
	if isEliminated then
		if isDesigner then
			task.defer(checkTotalFreeze)
		else
			task.defer(checkTotalCriticFreeze)
		end
		return
	end

	local char = targetPlayer.Character
	local root = char:FindFirstChild("HumanoidRootPart")
	local hum = char:FindFirstChild("Humanoid")
	if not root or not hum then return end

	-- Strip tools and clear fabric carrier status
	local tool = char:FindFirstChild("FBRoll") or targetPlayer.Backpack:FindFirstChild("FBRoll")
	if tool then tool:Destroy() end

	-- Clear fabric carrier status so team can pick up new fabric
	local FabricCarrierService = ServiceRegistry.Get("FabricCarrierService")
	if FabricCarrierService then
		FabricCarrierService.OnPlayerFrozen(targetPlayer)
	end

	root.Anchored = true
	RewardTracker.OnPlayerFrozen(targetPlayer)

	local equippedEffect = targetPlayer:GetAttribute("EquippedSkinEffect") or "None"
	if not DataManager.HasItem(targetPlayer, Config.CATEGORIES.SKIN_EFFECTS, equippedEffect) then
		equippedEffect = "None"
	end
	SkinEffects.ApplyManual(targetPlayer, char, equippedEffect)

	local podiumName = targetPlayer:GetAttribute("EquippedPodium") or "BasicPodium"
	local podiumTemplate = Podiums:FindFirstChild(podiumName) or Podiums:FindFirstChild("BasicPodium")
	local podium = podiumTemplate:Clone()

	local rayParams = RaycastParams.new()
	rayParams.FilterDescendantsInstances = {char}
	local rayResult = workspace:Raycast(root.Position, Vector3.new(0, -10, 0), rayParams)
	local groundPos = rayResult and rayResult.Position or (root.Position - Vector3.new(0, 3, 0))

	podium:PivotTo(CFrame.new(groundPos) * CFrame.Angles(0, math.rad(root.Orientation.Y), 0))
	podium.Parent = workspace

	local standPoint = podium:FindFirstChild("StandPoint", true)
	if standPoint then
		root.CFrame = standPoint.WorldCFrame
	else
		root.CFrame = CFrame.new(groundPos + Vector3.new(0, 3, 0)) * CFrame.Angles(0, math.rad(root.Orientation.Y), 0)
	end

	local poseID = targetPlayer:GetAttribute("EquippedPose") or "rbxassetid://74997474532222"
	local animObj = Instance.new("Animation")
	animObj.AnimationId = poseID
	local poseTrack = hum:LoadAnimation(animObj)
	poseTrack:Play()

	local promptPart = podium:FindFirstChild("Base") or podium:FindFirstChildWhichIsA("BasePart") or podium.PrimaryPart
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Unfreeze Teammate"
	prompt.ObjectText = targetPlayer.Name
	prompt.HoldDuration = 0
	prompt.RequiresLineOfSight = false
	prompt.Parent = promptPart

	-- Tag prompt for appropriate team
	local promptTag = isDesigner and "DesignerPrompt" or "CriticPrompt"
	CollectionService:AddTag(prompt, promptTag)

	prompt.Triggered:Connect(function(rescuer)
		local rescuerTeam = rescuer.Team and rescuer.Team.Name
		if rescuerTeam == (isDesigner and "Designers" or "Critics") then
			unfreezePlayer(targetPlayer, rescuer)
		end
	end)

	local billboard, timerLabel = createCountdownBillboard(root)
	local podiumPos = podium:GetPivot().Position
	SpawnPodiumVFX:FireAllClients(podiumPos)
	SoundService.FireToAll("PodiumSpawn", podiumPos)

	frozenTable[targetPlayer.UserId] = {
		TimeLeft = Config.CANCELLATION_TIME,
		Podium = podium,
		PoseAnim = poseTrack,
		Player = targetPlayer,
		Countdown = billboard,
		TimerLabel = timerLabel,
	}

	if attacker then
		RewardTracker.OnFreezePlayer(attacker)
		if ShowstopperService.OnFreezePlayer then
			ShowstopperService.OnFreezePlayer(attacker)
		end
	end

	if isDesigner then
		checkTotalFreeze()
	else
		checkTotalCriticFreeze()
	end
end

-- ── Systems Loop ──
task.spawn(function()
	while true do
		task.wait(1)

		-- Process frozen Designers
		for userId, data in pairs(frozenPlayers) do
			local isCamped = false
			local targetChar = data.Player.Character

			local criticsTeam = Teams:FindFirstChild("Critics")
			if criticsTeam then
				for _, critic in ipairs(criticsTeam:GetPlayers()) do
					local cc = critic.Character
					if cc and targetChar and cc:FindFirstChild("HumanoidRootPart") and targetChar:FindFirstChild("HumanoidRootPart") then
						if (cc.HumanoidRootPart.Position - targetChar.HumanoidRootPart.Position).Magnitude < Config.ANTI_CAMP_DISTANCE then
							isCamped = true
							break
						end
					end
				end
			end

			if not isCamped then
				data.TimeLeft -= 1
				if data.TimerLabel and data.TimerLabel.Parent then
					data.TimerLabel.Text = data.TimeLeft .. "s"
				end

				if data.TimeLeft <= 0 then
					print("[TAG] " .. data.Player.Name .. " (Designer) was not rescued. CANCELLED.")
					local playerToEliminate = data.Player
					frozenPlayers[userId] = nil
					Relevance.Eliminate(playerToEliminate)
					if data.Podium then data.Podium:Destroy() end
					if data.Countdown then data.Countdown:Destroy() end
				end
			end
		end

		-- Process frozen Critics
		for userId, data in pairs(frozenCritics) do
			local isCamped = false
			local targetChar = data.Player.Character

			local designersTeam = Teams:FindFirstChild("Designers")
			if designersTeam then
				for _, designer in ipairs(designersTeam:GetPlayers()) do
					local dc = designer.Character
					if dc and targetChar and dc:FindFirstChild("HumanoidRootPart") and targetChar:FindFirstChild("HumanoidRootPart") then
						if (dc.HumanoidRootPart.Position - targetChar.HumanoidRootPart.Position).Magnitude < Config.ANTI_CAMP_DISTANCE then
							isCamped = true
							break
						end
					end
				end
			end

			if not isCamped then
				data.TimeLeft -= 1
				if data.TimerLabel and data.TimerLabel.Parent then
					data.TimerLabel.Text = data.TimeLeft .. "s"
				end

				if data.TimeLeft <= 0 then
					print("[TAG] " .. data.Player.Name .. " (Critic) was not rescued. CANCELLED.")
					local playerToEliminate = data.Player
					frozenCritics[userId] = nil
					Relevance.Eliminate(playerToEliminate)
					if data.Podium then data.Podium:Destroy() end
					if data.Countdown then data.Countdown:Destroy() end
				end
			end
		end
	end
end)

-- ── TagManager API ──
local TagManager = {
	Unfreeze = function(player) unfreezePlayer(player, nil) end,
	CheckTotalFreeze = checkTotalFreeze,
	CheckTotalCriticFreeze = checkTotalCriticFreeze,

	CheckDunkDenied = function(attacker, targetRoot)
		for _, bin in ipairs(CollectionService:GetTagged("FabricBins")) do
			local bp = bin:IsA("BasePart") and bin or bin:FindFirstChildWhichIsA("BasePart")
			if bp and targetRoot and (targetRoot.Position - bp.Position).Magnitude <= Config.DUNK_DENIED_RANGE then
				if ShowstopperService.OnDunkDenied then
					ShowstopperService.OnDunkDenied(attacker)
				end
				return true
			end
		end
		return false
	end,
}

-- ── Systems ──
RoundEvents.Intermission.Event:Connect(function()
	for _, data in pairs(frozenPlayers) do
		if data.Player then unfreezePlayer(data.Player, nil) end
	end
	for _, data in pairs(frozenCritics) do
		if data.Player then unfreezePlayer(data.Player, nil) end
	end
end)

-- UPDATED: Universal Freeze Trigger (Both Teams) with Clash Mechanic
FreezeEvent.OnServerEvent:Connect(function(player, targetChar)
	-- 1. TEAM CHECK: Must be on a valid team
	if not (player.Team and (player.Team.Name == "Designers" or player.Team.Name == "Critics")) then return end

	-- 2. NIL CHECK
	if not targetChar or not targetChar:FindFirstChild("HumanoidRootPart") then return end
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not root then return end

	-- 3. DISTANCE CHECK (Hardened Security)
	local dist = (root.Position - targetChar.HumanoidRootPart.Position).Magnitude
	if dist > (Config.MAX_INTERACTION_DISTANCE + 5) then
		warn("[SECURITY] " .. player.Name .. " attempted to freeze from " .. dist .. " studs!")
		return
	end

	-- 4. CROSS-TEAM LOGIC: Can only freeze opposite team
	local targetPlayer = Players:GetPlayerFromCharacter(targetChar)
	if not targetPlayer then return end

	local playerTeam = player.Team.Name
	local targetTeam = targetPlayer.Team and targetPlayer.Team.Name

	-- Designers freeze Critics, Critics freeze Designers
	if playerTeam == targetTeam then return end
	if playerTeam == "Designers" and targetTeam ~= "Critics" then return end
	if playerTeam == "Critics" and targetTeam ~= "Designers" then return end

	-- ── ABILITY HOOKS: Immunities and Reflections ──
	if targetPlayer:GetAttribute("MainEventActive") then
		print("[TAG] " .. targetPlayer.Name .. " is immune to freeze (The Main Event)!")
		return
	end
	if targetPlayer:GetAttribute("VIPProtection") then
		print("[TAG] " .. targetPlayer.Name .. " is immune to freeze (Velvet Rope)!")
		return
	end
	if targetPlayer:GetAttribute("ControlsInverted") then
		print("[TAG] " .. targetPlayer.Name .. " REFLECTED the freeze! (Editorial Mirror)")
		-- The Editorial Mirror: Freeze the attacker instead, give them a strike
		freezePlayer(player, targetPlayer)
		return
	end

	-- Check if already frozen
	if frozenPlayers[targetPlayer.UserId] or frozenCritics[targetPlayer.UserId] then return end

	-- ── CLASH MECHANIC: Check for simultaneous freeze ──
	local now = os.clock()
	local pending = pendingFreezes[targetPlayer.UserId]

	if pending and (now - pending.timestamp) < CLASH_WINDOW then
		-- CLASH DETECTED! Both players tried to freeze each other simultaneously
		applyClashPushback(player, targetPlayer)
		pendingFreezes[player.UserId] = nil
		pendingFreezes[targetPlayer.UserId] = nil
		return  -- Neither gets frozen
	end

	-- Track this pending freeze for clash detection
	pendingFreezes[player.UserId] = {
		targetUserId = targetPlayer.UserId,
		timestamp = now
	}

	-- Clear pending after window passes
	task.delay(CLASH_WINDOW, function()
		if pendingFreezes[player.UserId] and pendingFreezes[player.UserId].targetUserId == targetPlayer.UserId then
			pendingFreezes[player.UserId] = nil
		end
	end)

	TagManager.CheckDunkDenied(player, targetChar.HumanoidRootPart)
	freezePlayer(targetPlayer, player)
end)

ServiceRegistry.Register("TagManager", TagManager)
return TagManager