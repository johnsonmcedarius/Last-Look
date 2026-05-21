-- ─────────────────────────────────────────────────────────────────────────────
-- FabricCarrierService: Team-based fabric limit (1 carrier per team)
-- Ensures only one player per team can carry fabric roll at a time
-- ─────────────────────────────────────────────────────────────────────────────

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local ServiceRegistry = require(ServerScriptService:WaitForChild("ServiceRegistry"))
local Config = require(ReplicatedStorage:WaitForChild("SharedConfig"))

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local FabricCarrierUpdate = Remotes:WaitForChild("FabricCarrierUpdate")

-- ── State: Track who's carrying fabric per team ──
local teamCarriers = {
	Designers = nil,  -- Player reference or nil
	Critics = nil,    -- Player reference or nil
}

-- ── Helper: Get team name from player ──
local function getTeamName(player)
	if player.Team then
		return player.Team.Name
	end
	return nil
end

-- ── Helper: Check if player is carrying fabric ──
local function isCarryingFabric(player)
	local char = player.Character
	if not char then return false end
	
	local inHand = char:FindFirstChild("FBRoll")
	local inBackpack = player.Backpack:FindFirstChild("FBRoll")
	
	return inHand ~= nil or inBackpack ~= nil
end

-- ── Helper: Remove fabric from player (used when frozen) ──
local function removeFabricFromPlayer(player)
	local char = player.Character
	if not char then return end
	
	local inHand = char:FindFirstChild("FBRoll")
	local inBackpack = player.Backpack:FindFirstChild("FBRoll")
	
	if inHand then inHand:Destroy() end
	if inBackpack then inBackpack:Destroy() end
end

local FabricCarrierService = {}

-- ── API: Check if team can carry fabric ──
function FabricCarrierService.CanCarry(player)
	local teamName = getTeamName(player)
	if not teamName then return false end
	
	-- Check if team exists in our tracking
	if not teamCarriers[teamName] then return false end
	
	-- If nobody is carrying, player can carry
	if teamCarriers[teamName] == nil then
		return true
	end
	
	-- If the same player is already the carrier, they can continue
	if teamCarriers[teamName] == player then
		return true
	end
	
	-- Someone else on the team is carrying
	return false
end

-- ── API: Get current carrier for a team ──
function FabricCarrierService.GetCarrier(teamName)
	return teamCarriers[teamName]
end

-- ── API: Set player as carrier ──
function FabricCarrierService.SetCarrier(player)
	local teamName = getTeamName(player)
	if not teamName then return false end
	
	-- Check if someone else is already carrying
	if teamCarriers[teamName] and teamCarriers[teamName] ~= player then
		return false
	end
	
	teamCarriers[teamName] = player
	
	-- Broadcast to all clients
	FabricCarrierUpdate:FireAllClients(teamName, player.UserId, player.Name)
	
	print("[FABRIC_CARRIER] " .. player.Name .. " is now carrying fabric for " .. teamName)
	return true
end

-- ── API: Clear carrier (when frozen or deposited) ──
function FabricCarrierService.ClearCarrier(player)
	local teamName = getTeamName(player)
	if not teamName then return end
	
	-- Only clear if this player was the carrier
	if teamCarriers[teamName] == player then
		teamCarriers[teamName] = nil
		
		-- Broadcast to all clients
		FabricCarrierUpdate:FireAllClients(teamName, nil, nil)
		
		print("[FABRIC_CARRIER] " .. player.Name .. " is no longer carrying fabric for " .. teamName)
	end
end

-- ── API: Handle player getting frozen - remove fabric ──
function FabricCarrierService.OnPlayerFrozen(player)
	local teamName = getTeamName(player)
	if not teamName then return end
	
	-- Check if this player was carrying fabric
	if teamCarriers[teamName] == player then
		-- Remove fabric from player
		removeFabricFromPlayer(player)
		
		-- Clear carrier status
		teamCarriers[teamName] = nil
		
		-- Broadcast to all clients
		FabricCarrierUpdate:FireAllClients(teamName, nil, nil)
		
		print("[FABRIC_CARRIER] " .. player.Name .. " was frozen - fabric removed from " .. teamName)
	end
end

-- ── API: Handle fabric deposit - clear carrier ──
function FabricCarrierService.OnFabricDeposited(player)
	FabricCarrierService.ClearCarrier(player)
end

-- ── API: Get all carriers (for debugging) ──
function FabricCarrierService.GetAllCarriers()
	local carriers = {}
	for teamName, player in pairs(teamCarriers) do
		carriers[teamName] = player and player.Name or nil
	end
	return carriers
end

-- ── API: Reset all carriers (on round end) ──
function FabricCarrierService.Reset()
	teamCarriers.Designers = nil
	teamCarriers.Critics = nil
	
	-- Broadcast reset to all clients
	FabricCarrierUpdate:FireAllClients("Designers", nil, nil)
	FabricCarrierUpdate:FireAllClients("Critics", nil, nil)
	
	print("[FABRIC_CARRIER] All carriers reset")
end

-- ── Lifecycle: Handle player leaving ──
Players.PlayerRemoving:Connect(function(player)
	local teamName = getTeamName(player)
	if teamName and teamCarriers[teamName] == player then
		teamCarriers[teamName] = nil
		FabricCarrierUpdate:FireAllClients(teamName, nil, nil)
		print("[FABRIC_CARRIER] " .. player.Name .. " left - fabric carrier slot freed for " .. teamName)
	end
end)

ServiceRegistry.Register("FabricCarrierService", FabricCarrierService)
return FabricCarrierService