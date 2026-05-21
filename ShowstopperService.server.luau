-- ─────────────────────────────────────────────────────────────────────────────
-- ShowstopperService: Server-side ultimate execution and management
-- ─────────────────────────────────────────────────────────────────────────────

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local ServiceRegistry = require(ServerScriptService:WaitForChild("ServiceRegistry"))
local DataManager = ServiceRegistry.Await("DataManager")
local RoundEvents = require(ServerScriptService:WaitForChild("RoundEvents"))
local Config = require(ReplicatedStorage:WaitForChild("SharedConfig"))
local SoundService = require(ReplicatedStorage:WaitForChild("SoundService"))
local CombatRegistry = require(ReplicatedStorage:WaitForChild("CombatRegistry"))

local PhysicsHandler = require(ServerScriptService:WaitForChild("PhysicsHandler"))
local ZoneHandler = require(ServerScriptService:WaitForChild("ZoneHandler"))
local IllusionHandler = require(ServerScriptService:WaitForChild("IllusionHandler"))
local StatusHandler = require(ServerScriptService:WaitForChild("StatusHandler"))
local WeaponVisibilityService = require(ServerScriptService:WaitForChild("WeaponVisibilityService"))

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local ActivateShowstopper = Remotes:WaitForChild("ActivateShowstopper")
local UpdateShowstopperCharge = Remotes:WaitForChild("UpdateShowstopperCharge")
local ShowstopperFullAlert = Remotes:WaitForChild("ShowstopperFullAlert")
local PlayVFX = Remotes:FindFirstChild("PlayVFX") or Instance.new("RemoteEvent", Remotes)
PlayVFX.Name = "PlayVFX"

-- ── State Management ─────────────────────────────────────────────────────────
local playerCharge = {}
local cooldowns = {} -- Cooldowns to prevent gaining charge immediately after use
local activeCasts = {}
local chargeWasFull = {}
local POST_ULT_COOLDOWN = 15 -- Seconds before a player can start gaining charge again

-- ── Helpers ──────────────────────────────────────────────────────────────────
local function getCharge(player)
	return playerCharge[player.UserId] or 0
end

local function syncCharge(player)
	UpdateShowstopperCharge:FireClient(player, getCharge(player), Config.MAX_CHARGE)
end

local function resetCharge(player)
	playerCharge[player.UserId] = 0
	chargeWasFull[player.UserId] = nil
	syncCharge(player)
end

-- ── Service Logic ────────────────────────────────────────────────────────────
local ShowstopperService = {
	GetCharge = getCharge,
	ResetCharge = resetCharge,
}

function ShowstopperService.AddCharge(player, amount)
	if not player or not player.Parent then return end
	
	-- Post-ult cooldown check
	if os.clock() < (cooldowns[player.UserId] or 0) then return end

	local prev = getCharge(player)
	
	-- ── ABILITY HOOK: The Velvet Rope (Adrenaline Boost) ──
	-- VIPProtection gives +20% charge gain
	-- AdrenalineBoost attribute also gives +20% (stacks)
	local multiplier = 1.0
	if player:GetAttribute("VIPProtection") then
		multiplier = multiplier + 0.2
	end
	if player:GetAttribute("AdrenalineBoost") then
		multiplier = multiplier + 0.2
	end
	
	local new = math.clamp(prev + (amount * multiplier), 0, Config.MAX_CHARGE)
	playerCharge[player.UserId] = new
	syncCharge(player)

	if new >= Config.MAX_CHARGE and not chargeWasFull[player.UserId] then
		chargeWasFull[player.UserId] = true
		ShowstopperFullAlert:FireClient(player)
		SoundService.FireToClient(player, "ShowstopperReady")
	end
end

-- ── Event Hooks for Game Logic ──
ShowstopperService.OnFabricDunk     = function(p) ShowstopperService.AddCharge(p, Config.CHARGES.FabricDunk) end
ShowstopperService.OnFabricShred    = function(p) ShowstopperService.AddCharge(p, Config.CHARGES.FabricShred or 20) end
ShowstopperService.OnTeamRescue     = function(p) ShowstopperService.AddCharge(p, Config.CHARGES.TeamRescue) end
ShowstopperService.OnAbilityHit     = function(p) ShowstopperService.AddCharge(p, Config.CHARGES.AbilityHit) end
ShowstopperService.OnFreezeDesigner = function(p) ShowstopperService.AddCharge(p, Config.CHARGES.FreezeDesigner) end
ShowstopperService.OnFreezeCritic   = function(p) ShowstopperService.AddCharge(p, Config.CHARGES.FreezeCritic or 30) end

ShowstopperService.OnFreezePlayer = function(p)
	local teamName = p.Team and p.Team.Name
	if teamName == "Designers" then
		ShowstopperService.OnFreezeCritic(p)
	elseif teamName == "Critics" then
		ShowstopperService.OnFreezeDesigner(p)
	end
end

ShowstopperService.OnFabricPass = function(p1, p2) 
	ShowstopperService.AddCharge(p1, Config.CHARGES.FabricPass) 
	if p2 then ShowstopperService.AddCharge(p2, 5) end
end

-- ── Route Showstopper ──
local function routeShowstopper(player, moduleName)
	-- DYNAMIC LOADING: Find module in Universal folder
	local folder = ReplicatedStorage:WaitForChild("Showstoppers"):WaitForChild("Universal")
	
	-- Standard loading
	local fileName = moduleName:gsub("%s+", "")
	local mod = folder:FindFirstChild(fileName)
	
	if mod and mod:IsA("ModuleScript") then
		local success, result = pcall(require, mod)
		if success and result.Execute then
			result.Execute(player)
		else
			warn("[SHOWSTOPPER] Failed to execute module for " .. moduleName .. ": " .. tostring(result))
		end
	else
		warn("[SHOWSTOPPER] No execution module found for " .. moduleName .. " at " .. folder:GetFullName() .. "." .. fileName)
	end
end

-- ── Activation Handler ───────────────────────────────────────────────────────
ActivateShowstopper.OnServerEvent:Connect(function(player, moduleName)
	-- Death & Stun Bypass Check
	local char = player.Character
	if not char or not char:FindFirstChild("Humanoid") or char.Humanoid.Health <= 0 then return end
	if char:GetAttribute("Stunned") or char:GetAttribute("Frozen") then return end

	-- Strict Debounce
	if activeCasts[player.UserId] then return end

	local showstopperData = CombatRegistry.Showstoppers[moduleName]
	if not showstopperData then return end

	-- 1. Ownership & Loadout Check
	local data = DataManager.GetData(player)
	if not data or not data.Equipped then return end
	
	local isEquipped = false
	for k, v in pairs(data.Equipped) do
		if v == moduleName then
			isEquipped = true
			break
		end
	end
	
	if not isEquipped then
		warn("[SHOWSTOPPER] " .. player.Name .. " does not have " .. tostring(moduleName) .. " equipped")
		return
	end

	-- 2. Charge Check
	local charge = getCharge(player)
	if charge < Config.MAX_CHARGE then
		warn("[SHOWSTOPPER] " .. player.Name .. " charge insufficient: " .. charge)
		return
	end

	-- 3. Execution Lock
	activeCasts[player.UserId] = true

	-- 4. Global Feedback (Announcer & VFX)
	print("[SHOWSTOPPER] " .. player.Name .. " executed " .. moduleName)
	
	local ShowstopperAnnounce = Remotes:FindFirstChild("ShowstopperAnnounce")
	if ShowstopperAnnounce then
		ShowstopperAnnounce:FireAllClients(player.Name, moduleName)
	end
	
	if showstopperData.VFXAssetName ~= "" then
		PlayVFX:FireAllClients(showstopperData.VFXAssetName, player.Character)
	end
	
	if showstopperData.SFXId ~= "rbxassetid://0" then
		SoundService.FireToClient(player, showstopperData.SFXId)
	else
		SoundService.FireToClient(player, "ShowstopperActivate")
	end
	
	-- Hide weapon during cast (assume 1s cast animation for showstoppers)
	WeaponVisibilityService.HideWeapon(player, 1.0)

	-- 5. Route Mechanical Execution
	routeShowstopper(player, moduleName)
	
	-- 6. Reset & Cleanup
	resetCharge(player)
	cooldowns[player.UserId] = os.clock() + showstopperData.Duration + POST_ULT_COOLDOWN
	activeCasts[player.UserId] = nil
end)

-- ── Cleanup & Failsafes ──────────────────────────────────────────────────────
local function cleanupPlayer(player)
	-- Failsafe: Cleanup logic if player leaves/dies mid-cast
end

RoundEvents.Intermission.Event:Connect(function()
	for _, p in ipairs(Players:GetPlayers()) do
		resetCharge(p)
		cooldowns[p.UserId] = nil
		activeCasts[p.UserId] = nil
		chargeWasFull[p.UserId] = nil
	end
end)

Players.PlayerRemoving:Connect(function(player)
	playerCharge[player.UserId] = nil
	cooldowns[player.UserId] = nil
	chargeWasFull[player.UserId] = nil
	activeCasts[player.UserId] = nil
	cleanupPlayer(player)
end)

local PlayerEliminated = Remotes:FindFirstChild("PlayerEliminated")
if PlayerEliminated then
	PlayerEliminated.OnServerEvent:Connect(function(player)
		cleanupPlayer(player)
	end)
end

ServiceRegistry.Register("ShowstopperService", ShowstopperService)
return ShowstopperService
