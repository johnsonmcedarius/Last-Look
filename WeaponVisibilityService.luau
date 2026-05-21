-- ─────────────────────────────────────────────────────────────────────────────
-- WeaponVisibilityService: Server-side weapon visibility management
-- Handles hiding weapons during animations and abilities
-- ─────────────────────────────────────────────────────────────────────────────

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local ServiceRegistry = require(ServerScriptService:WaitForChild("ServiceRegistry"))

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local WeaponBusyState = Remotes:WaitForChild("WeaponBusyState")

-- ── State: Track which players have hidden weapons ──
local hiddenWeapons = {}  -- [playerUserId] = {endTime, originalTransparency}

local WeaponVisibilityService = {}

-- ── Helper: Get player's equipped weapon ──
local function getEquippedWeapon(player)
	local character = player.Character
	if not character then return nil end
	
	-- Check for any tool in character (equipped)
	for _, child in ipairs(character:GetChildren()) do
		if child:IsA("Tool") then
			return child
		end
	end
	
	return nil
end

-- ── Helper: Set weapon transparency ──
local function setWeaponTransparency(weapon, transparency)
	if not weapon then return end
	
	-- Set transparency on all parts in the tool
	for _, part in ipairs(weapon:GetDescendants()) do
		if part:IsA("BasePart") then
			part.Transparency = transparency
		end
	end
	
	-- Also set on the tool's Handle if it exists
	local handle = weapon:FindFirstChild("Handle")
	if handle then
		handle.Transparency = transparency
	end
end

-- ── API: Hide weapon for duration (called from server scripts) ──
function WeaponVisibilityService.HideWeapon(player, duration)
	if not player then return false end
	
	local weapon = getEquippedWeapon(player)
	if not weapon then return false end
	
	-- Store original transparency
	local handle = weapon:FindFirstChild("Handle")
	local originalTransparency = handle and handle.Transparency or 0
	
	-- Hide weapon
	setWeaponTransparency(weapon, 1)
	
	-- Track state
	hiddenWeapons[player.UserId] = {
		endTime = os.clock() + duration,
		originalTransparency = originalTransparency,
		weapon = weapon
	}
	
	-- Fire to client for HUD busy state
	WeaponBusyState:FireClient(player, player.Name, true, duration)
	
	-- Schedule restore
	task.delay(duration, function()
		WeaponVisibilityService.RestoreWeapon(player)
	end)
	
	print("[WEAPON_VIS] " .. player.Name .. " weapon hidden for " .. duration .. "s")
	return true
end

-- ── API: Restore weapon visibility ──
function WeaponVisibilityService.RestoreWeapon(player)
	if not player then return false end
	
	local data = hiddenWeapons[player.UserId]
	if not data then return false end
	
	-- Check if weapon still exists and is still equipped
	local weapon = data.weapon
	if weapon and weapon.Parent and weapon.Parent == player.Character then
		setWeaponTransparency(weapon, data.originalTransparency)
		print("[WEAPON_VIS] " .. player.Name .. " weapon restored")
	end
	
	-- Clear state
	hiddenWeapons[player.UserId] = nil
	
	-- Fire to client for HUD restore
	WeaponBusyState:FireClient(player, player.Name, false, 0)
	
	return true
end

-- ── API: Check if player's weapon is hidden ──
function WeaponVisibilityService.IsWeaponHidden(player)
	return hiddenWeapons[player.UserId] ~= nil
end

-- ── Lifecycle: Handle player leaving ──
Players.PlayerRemoving:Connect(function(player)
	hiddenWeapons[player.UserId] = nil
end)

-- ── Register Service ──
ServiceRegistry.Register("WeaponVisibilityService", WeaponVisibilityService)
return WeaponVisibilityService
