local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService      = game:GetService("TweenService")
local RunService        = game:GetService("RunService")
local UIS               = game:GetService("UserInputService")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

local SoundService = require(ReplicatedStorage:WaitForChild("SoundService"))
local Remotes      = ReplicatedStorage:WaitForChild("Remotes")



local VFXModule
local ok, result = pcall(function()
	return require(ReplicatedStorage:WaitForChild("VFXModule", 3))
end)
if ok then VFXModule = result end

local function emitVFX(effectName, position)
	if VFXModule and VFXModule.Play then
		VFXModule.Play(effectName, position)
	else
		-- Fallback: plain sound only until VFXModule is wired up
		warn("[HUD] VFXModule not found — skipping visual for: " .. effectName)
	end
end

-- Wait for GameplayHUD ScreenGui (physical UI in StarterGui)
local screenGui = player.PlayerGui:WaitForChild("GameplayHUD", 5)
if not screenGui then
	warn("[HUD] GameplayHUD not found in PlayerGui! Ensure StarterGui.GameplayHUD exists.")
	return
end

-- Load HUD modules
local HUDModules = ReplicatedStorage:WaitForChild("HUDModules", 5)

local function requireModule(name)
	if not HUDModules then return nil end
	local m = HUDModules:FindFirstChild(name)
	if not m then warn("[HUD] Module not found: " .. name) return nil end
	local ok2, res = pcall(require, m)
	if ok2 then return res else warn("[HUD] Failed to load " .. name .. ": " .. res) return nil end
end

local AbilitiesModule = requireModule("HUDModule_Abilities")
local CooldownsModule = requireModule("HUDModule_Cooldowns")
local RewardsModule   = requireModule("HUDModule_Rewards")
local BannersModule   = requireModule("HUDModule_Banners")
local WeaponStateModule = requireModule("HUDModule_WeaponState")
local FabricSlotModule  = requireModule("HUDModule_FabricSlot")
local ProximityWarningsModule = requireModule("HUDModule_ProximityWarnings")
local ShowstopperModule = requireModule("HUDModule_Showstopper")
-- MatchFlow + MetaMenus modules need THEIR OWN ScreenGuis, not GameplayHUD
local MatchFlowModule   = requireModule("HUDModule_MatchFlow")
local MetaMenusModule   = requireModule("HUDModule_MetaMenus")

if AbilitiesModule then AbilitiesModule.Init(screenGui, Remotes, SoundService) end
if CooldownsModule then CooldownsModule.Init(screenGui, Remotes) end
if RewardsModule   then RewardsModule.Init(screenGui, Remotes, SoundService) end
if BannersModule   then BannersModule.Init(screenGui, Remotes, SoundService, player) end
if WeaponStateModule then WeaponStateModule.Init(screenGui, Remotes) end
if FabricSlotModule  then FabricSlotModule.Init(screenGui, Remotes) end
if ProximityWarningsModule then ProximityWarningsModule.Init(screenGui, Remotes) end
if ShowstopperModule then ShowstopperModule.Init(screenGui, Remotes, SoundService) end

-- MatchFlow module gets the MatchFlow ScreenGui (not GameplayHUD)
if MatchFlowModule then
	local matchFlowGui = player.PlayerGui:WaitForChild("MatchFlow", 8)
	if matchFlowGui then
		MatchFlowModule.Init(matchFlowGui, Remotes, SoundService)
	else
		warn("[HUD] MatchFlow ScreenGui not found — HUDModule_MatchFlow not initialized")
	end
end

-- MetaMenus module gets the MetaMenus ScreenGui
if MetaMenusModule then
	local metaMenusGui = player.PlayerGui:WaitForChild("MetaMenus", 8)
	if metaMenusGui then
		MetaMenusModule.Init(metaMenusGui, Remotes, SoundService)
	else
		warn("[HUD] MetaMenus ScreenGui not found — HUDModule_MetaMenus not initialized")
	end
end

local function getFrame(name)
	return screenGui:FindFirstChild(name, true)
end


-- Device detection & keybind hints

local function getDevice()
	if UIS.TouchEnabled and not UIS.KeyboardEnabled then return "Mobile"
	elseif UIS.GamepadEnabled then return "Xbox"
	else return "PC" end
end

local function updateKeybindHints()
	local device = getDevice()
	local hints  = {
		DashHint        = {PC = "[Q] Dash",       Xbox = "[R1] Dash",    Mobile = "DASH"},
		AbilityHint     = {PC = "[E] Ability",     Xbox = "[RB] Ability", Mobile = "ABILITY"},
		ShowstopperHint = {PC = "[F] Showstopper", Xbox = "[Y] Stopper",  Mobile = "SHOW"},
		PassHint        = {PC = "[E] Pass Fabric", Xbox = "[X] Pass",     Mobile = "PASS"},
	}
	for frameName, deviceTexts in pairs(hints) do
		local label = getFrame(frameName)
		if label then label.Text = deviceTexts[device] or deviceTexts["PC"] end
	end
end

player.CharacterAdded:Connect(updateKeybindHints)
task.delay(1, updateKeybindHints)

-------------------------------------------------
-- Blind overlay
-------------------------------------------------
local BlindClient = Remotes:WaitForChild("BlindClient")
BlindClient.OnClientEvent:Connect(function(duration)
	local overlay = getFrame("BlindOverlay")
	if not overlay then return end
	overlay.BackgroundTransparency = 0
	overlay.Visible = true
	task.delay(duration * 0.6, function()
		TweenService:Create(overlay, TweenInfo.new(duration * 0.4), {BackgroundTransparency = 1}):Play()
		task.delay(duration * 0.4 + 0.1, function() overlay.Visible = false end)
	end)
end)

-------------------------------------------------
-- Dazed animation
-------------------------------------------------
local PlayDazedAnim = Remotes:WaitForChild("PlayDazedAnim")
local DAZED_ANIM_ID = "rbxassetid://0"  -- TODO: Replace with real ID

PlayDazedAnim.OnClientEvent:Connect(function(duration)
	local char = player.Character
	if not char then return end
	local hum  = char:FindFirstChildOfClass("Humanoid")
	if not hum then return end
	local animator = hum:FindFirstChildOfClass("Animator")
	if not animator or DAZED_ANIM_ID == "rbxassetid://0" then return end
	local anim = Instance.new("Animation")
	anim.AnimationId = DAZED_ANIM_ID
	local track = animator:LoadAnimation(anim)
	track.Priority = Enum.AnimationPriority.Action2
	track:Play()
	task.delay(duration, function() if track then track:Stop() end end)
end)

-------------------------------------------------
-- Camera shake
-------------------------------------------------
local CameraShake = Remotes:WaitForChild("CameraShake")
CameraShake.OnClientEvent:Connect(function()
	local started   = os.clock()
	local duration  = 0.5
	local intensity = 0.4
	local conn
	conn = RunService.RenderStepped:Connect(function()
		local elapsed = os.clock() - started
		if elapsed >= duration then conn:Disconnect() return end
		local decay = 1 - (elapsed / duration)
		camera.CFrame = camera.CFrame * CFrame.new(
			(math.random() - 0.5) * intensity * decay,
			(math.random() - 0.5) * intensity * decay * 0.5,
			0
		)
	end)
end)

-------------------------------------------------
-- VFX events — all replaced with VFXModule.Emit
-- No more Instance.new("Part") + TweenService expanding balls
-------------------------------------------------

local ShowExplosionVFX = Remotes:WaitForChild("ShowExplosionVFX")
ShowExplosionVFX.OnClientEvent:Connect(function(position)
	emitVFX("Explosion", position)
end)

local PlayPoofVFX = Remotes:WaitForChild("PlayPoofVFX")
PlayPoofVFX.OnClientEvent:Connect(function(position)
	emitVFX("Poof", position)
end)

local SpawnPodiumVFX   = Remotes:WaitForChild("SpawnPodiumVFX")
local DespawnPodiumVFX = Remotes:WaitForChild("DespawnPodiumVFX")

SpawnPodiumVFX.OnClientEvent:Connect(function(position)
	emitVFX("PodiumSpawn", position)
end)

DespawnPodiumVFX.OnClientEvent:Connect(function(position)
	emitVFX("PodiumDespawn", position)
end)

local RackPickupVFX = Remotes:WaitForChild("RackPickupVFX")
RackPickupVFX.OnClientEvent:Connect(function(position)
	emitVFX("RackPickup", position)
end)

local RackStateChanged = Remotes:WaitForChild("RackStateChanged")
RackStateChanged.OnClientEvent:Connect(function(rack, sabotaged)
	if not rack or not rack.Parent then return end
	local rackBase = rack:IsA("BasePart") and rack or rack:FindFirstChildWhichIsA("BasePart")
	local pos = rackBase and rackBase.Position or Vector3.zero
	emitVFX(sabotaged and "RackSabotage" or "RackRestore", pos)
	SoundService.PlayLocal(sabotaged and "HairsprayHiss" or "FabricPickup")
end)

local DepositVFX = Remotes:WaitForChild("DepositVFX")
DepositVFX.OnClientEvent:Connect(function(position)
	emitVFX("Deposit", position)
end)

-- ─────────────────────────────────────────────────────────────────────────────
-- Showstopper charge bar - NOW HANDLED BY HUDModule_Showstopper
-- The module handles: charge updates, neon pulse at 100%, full alert flash
-- ─────────────────────────────────────────────────────────────────────────────

-------------------------------------------------
-- Exit waypoint
-------------------------------------------------
local ShowExitWaypoint = Remotes:WaitForChild("ShowExitWaypoint")
ShowExitWaypoint.OnClientEvent:Connect(function(exitPos)
	local waypoint = getFrame("ExitWaypoint")
	if not waypoint then return end
	waypoint.Visible = true
	if waypoint:IsA("BillboardGui") then
		local marker = Instance.new("Part")
		marker.Size        = Vector3.new(1,1,1)
		marker.Position    = exitPos + Vector3.new(0,5,0)
		marker.Anchored    = true
		marker.Transparency = 1
		marker.CanCollide  = false
		marker.Parent      = workspace
		waypoint.Adornee   = marker
	end
end)

-------------------------------------------------
-- Sound relay
-------------------------------------------------
local PlaySoundRemote = Remotes:WaitForChild("PlaySound")
PlaySoundRemote.OnClientEvent:Connect(function(soundName, position)
	if not position then
		SoundService.PlayLocal(soundName)
	else
		-- Use a temporary invisible part for 3D audio positioning
		local part = Instance.new("Part")
		part.Size        = Vector3.new(0.1, 0.1, 0.1)
		part.Position    = position
		part.Anchored    = true
		part.Transparency = 1
		part.CanCollide  = false
		part.Parent      = workspace
		SoundService.PlayAt(soundName, part)
		game:GetService("Debris"):AddItem(part, 5)
	end
end)

-------------------------------------------------
-- Objective Warning Icon (when team bin/shredder sabotaged)
-------------------------------------------------
-- Objective Warning Icon (physical UI in StarterGui.GameplayHUD)
local ObjectiveWarning = Remotes:WaitForChild("ObjectiveWarning")
local warningIcon = getFrame("ObjectiveWarningIcon")

-- Pulse animation for warning icon
local warningPulseConn = nil
local function startWarningPulse()
	if warningPulseConn then return end
	warningPulseConn = task.spawn(function()
		while warningIcon and warningIcon.Visible do
			TweenService:Create(warningIcon, TweenInfo.new(0.5), {BackgroundTransparency = 0.5}):Play()
			task.wait(0.5)
			TweenService:Create(warningIcon, TweenInfo.new(0.5), {BackgroundTransparency = 0.2}):Play()
			task.wait(0.5)
		end
		warningPulseConn = nil
	end)
end

ObjectiveWarning.OnClientEvent:Connect(function(teamName, isWarning)
	-- Only show warning to the affected team
	if not (player.Team and player.Team.Name == teamName) then return end

	if isWarning then
		-- Show warning icon (physical UI already exists)
		if warningIcon then
			warningIcon.Visible = true
			startWarningPulse()
			SoundService.PlayLocal("PaparazziStorm")
		end
	else
		-- Hide warning icon
		if warningIcon then
			warningIcon.Visible = false
		end
	end
end)

-------------------------------------------------
-- Strikes — only the LOCAL player's own count arrives here now
-- (RelevanceSystem was fixed to only FireClient to the struck player)
-------------------------------------------------
local UpdateStrikes = Remotes:WaitForChild("UpdateStrikes")
UpdateStrikes.OnClientEvent:Connect(function(strikes, maxStrikes)
	for i = 1, maxStrikes do
		local icon = getFrame("Strike" .. i)
		if icon then
			if i <= strikes then
				icon.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
			else
				icon.BackgroundColor3 = Color3.fromRGB(255, 80, 80)
			end
		end
	end
end)

-------------------------------------------------
-- REMOVED: AbilityCooldownUpdate.OnServerEvent
-- Ability cooldown bars are now updated instantly in the LocalScript that
-- fires the ability (no server round-trip needed). See HUDModule_Abilities.
-------------------------------------------------
