-- ─────────────────────────────────────────────────────────────────────────────
-- AbilityController: Client-side ability activation
-- Handles E key input for ability usage with weapon hiding
-- ─────────────────────────────────────────────────────────────────────────────

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local ActivateAbility = Remotes:WaitForChild("ActivateAbility")
local AbilityCooldownUpdate = Remotes:WaitForChild("AbilityCooldownUpdate")

-- ── State ──
local cooldowns = {}
local isActivating = false

-- ── Helper: Check if ability is ready ──
local function isAbilityReady()
	local now = os.clock()
	for abilityName, cooldownEnd in pairs(cooldowns) do
		if now < cooldownEnd then
			return false, abilityName, cooldownEnd - now
		end
	end
	return true
end

-- ── Helper: Get equipped ability ──
local function getEquippedAbility()
	local DataManager = require(ReplicatedStorage:WaitForChild("SharedConfig"))
	-- We need to get this from the player's data
	-- For now, check player attributes
	local abilityName = player:GetAttribute("EquippedAbility1")
	return abilityName
end

-- ── Activate Ability ──
local function activateAbility()
	if isActivating then return end
	
	local ready, abilityName, remainingCooldown = isAbilityReady()
	if not ready then
		print("[ABILITY] " .. abilityName .. " on cooldown: " .. math.floor(remainingCooldown * 10) / 10 .. "s")
		return
	end
	
	local equippedAbility = getEquippedAbility()
	if not equippedAbility or equippedAbility == "" then
		print("[ABILITY] No ability equipped")
		return
	end
	
	isActivating = true
	
	-- Fire to server for execution
	ActivateAbility:FireServer(equippedAbility)
	
	-- Brief lock to prevent spam
	task.wait(0.5)
	isActivating = false
end

-- ── Input Handler ──
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	
	-- E key for ability activation
	if input.KeyCode == Enum.KeyCode.E then
		activateAbility()
	end
end)

-- ── Cooldown Updates from Server ──
AbilityCooldownUpdate.OnClientEvent:Connect(function(abilityName, duration)
	cooldowns[abilityName] = os.clock() + duration
	print("[ABILITY] " .. abilityName .. " cooldown: " .. duration .. "s")
end)

print("[ABILITY] AbilityController initialized")