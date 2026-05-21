local Players             = game:GetService("Players")
local ReplicatedStorage   = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local ServiceRegistry = require(ServerScriptService:WaitForChild("ServiceRegistry"))
local AbilityConfig   = require(ReplicatedStorage:WaitForChild("AbilityConfig"))
local DataManager     = ServiceRegistry.Await("DataManager")

local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local function getRemote(name)
	local r = Remotes:FindFirstChild(name)
	if not r then r = Instance.new("RemoteEvent") r.Name = name r.Parent = Remotes end
	return r
end

-- Remotes
local UpdateAbilitySlots = getRemote("UpdateAbilitySlots")
local PurchaseAbility    = getRemote("PurchaseAbility")
local EquipAbility       = getRemote("EquipAbility")

local function syncToClient(player)
	local data = DataManager.GetData(player)
	if not data then return end

	local equipped = {data.Equipped.Ability1 or "Empty"}
	UpdateAbilitySlots:FireClient(player, equipped, 1)
end

PurchaseAbility.OnServerEvent:Connect(function(player, abilityName)
	local ability = AbilityConfig:GetAbilityData(abilityName)

	if not ability or DataManager.HasItem(player, "Abilities", abilityName) then 
		return 
	end

	local cost = AbilityConfig:GetPrice(ability.Rarity)
	if DataManager.SubtractCoins(player, cost) then
		DataManager.GiveItem(player, "Abilities", abilityName)
		print("[SHOP] " .. player.Name .. " now owns " .. abilityName)
	else
		print("[SHOP] " .. player.Name .. " is too broke for " .. abilityName)
	end
end)

EquipAbility.OnServerEvent:Connect(function(player, abilityName)
	if not DataManager.HasItem(player, "Abilities", abilityName) then 
		return 
	end

	if DataManager.UpdateEquipped then
		DataManager.UpdateEquipped(player, "Ability1", abilityName)
		print("[EQUIP] " .. player.Name .. " equipped " .. abilityName)
		syncToClient(player)
	else
		warn("[DATA] DataManager.UpdateEquipped is missing! Ability didn't sync.")
	end
end)

local AbilitySlotService = {
	GetEquipped = function(player) 
		local data = DataManager.GetData(player)
		return data and data.Equipped.Ability1 or ""
	end,
}

Players.PlayerAdded:Connect(function(player)
	task.wait(3)
	syncToClient(player)
end)

for _, p in ipairs(Players:GetPlayers()) do
	task.spawn(function() task.wait(3) syncToClient(p) end)
end

ServiceRegistry.Register("AbilitySlotService", AbilitySlotService)
return AbilitySlotService