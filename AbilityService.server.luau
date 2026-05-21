-- ─────────────────────────────────────────────────────────────────────────────
-- AbilityService: Server-side tactical ability execution and management
-- ─────────────────────────────────────────────────────────────────────────────

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local ServiceRegistry = require(ServerScriptService:WaitForChild("ServiceRegistry"))
local DataManager = ServiceRegistry.Await("DataManager")
local SoundService = require(ReplicatedStorage:WaitForChild("SoundService"))
local CombatRegistry = require(ReplicatedStorage:WaitForChild("CombatRegistry"))

local PhysicsHandler = require(ServerScriptService:WaitForChild("PhysicsHandler"))
local ZoneHandler = require(ServerScriptService:WaitForChild("ZoneHandler"))
local IllusionHandler = require(ServerScriptService:WaitForChild("IllusionHandler"))
local StatusHandler = require(ServerScriptService:WaitForChild("StatusHandler"))
local WeaponVisibilityService = require(ServerScriptService:WaitForChild("WeaponVisibilityService"))

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local ActivateAbility = Remotes:WaitForChild("ActivateAbility")
local AbilityCooldownUpdate = Remotes:WaitForChild("AbilityCooldownUpdate")
local PlayVFX = Remotes:FindFirstChild("PlayVFX") or Instance.new("RemoteEvent", Remotes)
PlayVFX.Name = "PlayVFX"

local Debris = game:GetService("Debris")

-- ── State Management ─────────────────────────────────────────────────────────
local cooldowns = {}
local activeCasts = {} -- Strict debounce for activation animations

-- ── Helpers ──────────────────────────────────────────────────────────────────
local function routeAbility(player, abilityName)
	-- DYNAMIC LOADING: Find module in Universal folder
	local folder = ReplicatedStorage:WaitForChild("Abilities"):WaitForChild("Universal")
	
	local fileName = abilityName:gsub("%s+", "")
	local mod = folder:FindFirstChild(fileName)
	
	if mod and mod:IsA("ModuleScript") then
		local success, result = pcall(require, mod)
		if success and result.Execute then
			result.Execute(player)
		else
			warn("[ABILITY] Failed to execute module for " .. abilityName .. ": " .. tostring(result))
		end
	else
		warn("[ABILITY] No execution module found for " .. abilityName .. " at " .. folder:GetFullName() .. "." .. fileName)
	end
end

-- ── Activation Handler ───────────────────────────────────────────────────────
ActivateAbility.OnServerEvent:Connect(function(player, abilityName)
	-- Death & Stun Bypass Check
	local char = player.Character
	if not char or not char:FindFirstChild("Humanoid") or char.Humanoid.Health <= 0 then return end
	if char:GetAttribute("Stunned") or char:GetAttribute("Frozen") then return end

	-- Strict Debounce
	if activeCasts[player.UserId] then return end

	local abilityData = CombatRegistry.Abilities[abilityName]
	if not abilityData then return end

	-- 1. Ownership & Loadout Check
	local data = DataManager.GetData(player)
	if not data or not data.Equipped then return end
	
	local isEquipped = false
	for k, v in pairs(data.Equipped) do
		if v == abilityName then
			isEquipped = true
			break
		end
	end
	
	if not isEquipped then
		warn("[ABILITY] " .. player.Name .. " does not have " .. tostring(abilityName) .. " equipped")
		return
	end

	-- 2. Cooldown Check
	local now = os.clock()
	if now < (cooldowns[player.UserId .. "_" .. abilityName] or 0) then 
		return 
	end

	-- 3. Execution Lock
	activeCasts[player.UserId] = true

	-- 4. Play VFX & SFX (Client-Side Pipeline)
	if abilityData.VFXAssetName ~= "" then
		PlayVFX:FireAllClients(abilityData.VFXAssetName, player.Character)
	end
	if abilityData.SFXId ~= "rbxassetid://0" then
		SoundService.FireToClient(player, abilityData.SFXId)
	end
	
	-- Hide weapon during cast (assume 0.5s cast animation for tactical abilities)
	WeaponVisibilityService.HideWeapon(player, 0.5)

	-- 5. Route Mechanical Execution
	print("[ABILITY] " .. player.Name .. " activated " .. abilityName)
	
	-- PHASE 4 FIX: Wrap in pcall to prevent permanent lockout on error
	local success, err = pcall(function()
		routeAbility(player, abilityName)
	end)
	
	if not success then
		warn("[ABILITY] CRITICAL ERROR executing " .. abilityName .. ": " .. tostring(err))
	end
	
	-- 6. Set Cooldown & Clean Lock
	local duration = abilityData.Cooldown
	cooldowns[player.UserId .. "_" .. abilityName] = now + duration
	activeCasts[player.UserId] = nil
	
	-- Sync cooldown to client for UI
	AbilityCooldownUpdate:FireClient(player, abilityName, duration)
end)

-- ── Failsafes ────────────────────────────────────────────────────────────────
local function cleanupPlayer(player)
	PhysicsHandler.Cleanup(player)
	ZoneHandler.Cleanup(player)
	IllusionHandler.Cleanup(player)
	StatusHandler.Cleanup(player)
end

Players.PlayerRemoving:Connect(function(player)
	cleanupPlayer(player)
	activeCasts[player.UserId] = nil
end)

local PlayerEliminated = Remotes:FindFirstChild("PlayerEliminated")
if PlayerEliminated then
	PlayerEliminated.OnServerEvent:Connect(function(player)
		cleanupPlayer(player)
	end)
end

local RoundEvents = ServerScriptService:FindFirstChild("RoundEvents")
if RoundEvents then
	local RE = require(RoundEvents)
	RE.Intermission.Event:Connect(function()
		PhysicsHandler.CleanupAll()
		ZoneHandler.CleanupAll()
		IllusionHandler.CleanupAll()
		StatusHandler.CleanupAll()
		cooldowns = {}
	end)
end

local AbilityService = {}
ServiceRegistry.Register("AbilityService", AbilityService)

return AbilityService
