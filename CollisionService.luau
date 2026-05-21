local PhysicsService = game:GetService("PhysicsService")
local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")

local ServiceRegistry = require(ServerScriptService:WaitForChild("ServiceRegistry"))

local PLAYERS_GROUP = "Players"
local DEFAULT_GROUP = "Default"

local CollisionService = {}

-- ── Setup Collision Groups ─────────────────────────────────────────────────────
function CollisionService.Setup()
	-- Create collision groups (wrapped in pcall in case they already exist)
	pcall(function()
		PhysicsService:RegisterCollisionGroup(PLAYERS_GROUP)
	end)
	pcall(function()
		PhysicsService:RegisterCollisionGroup(DEFAULT_GROUP)
	end)
	
	-- Players don't collide with each other (permanent for teammates)
	pcall(function()
		PhysicsService:CollisionGroupSetCollidable(PLAYERS_GROUP, PLAYERS_GROUP, false)
	end)
	
	-- Players DO collide with world objects
	pcall(function()
		PhysicsService:CollisionGroupSetCollidable(PLAYERS_GROUP, DEFAULT_GROUP, true)
	end)
	
	print("[COLLISION] Groups initialized. Player-to-player collision disabled.")
end

-- ── Set Collision Group for a Player's Character ───────────────────────────────
function CollisionService.SetPlayerCollisionGroup(player, groupName)
	local char = player.Character
	if not char then return end
	
	for _, part in ipairs(char:GetDescendants()) do
		if part:IsA("BasePart") then
			part.CollisionGroup = groupName
		end
	end
end

-- ── Enable/Disable Player-to-Player Collision ─────────────────────────────────
function CollisionService.SetPlayerCollisionEnabled(player, enabled)
	local group = enabled and DEFAULT_GROUP or PLAYERS_GROUP
	CollisionService.SetPlayerCollisionGroup(player, group)
end

-- ── Apply to all players (for round start) ─────────────────────────────────────
function CollisionService.ApplyToAllPlayers(enabled)
	for _, player in ipairs(Players:GetPlayers()) do
		CollisionService.SetPlayerCollisionEnabled(player, enabled)
	end
end

-- ── Character Spawn Handler ─────────────────────────────────────────────────────
local function onCharacterAdded(player, character)
	-- Default: Players don't collide with each other
	task.defer(function()
		CollisionService.SetPlayerCollisionEnabled(player, false)
	end)
end

local function onPlayerAdded(player)
	if player.Character then
		onCharacterAdded(player, player.Character)
	end
	player.CharacterAdded:Connect(function(char)
		onCharacterAdded(player, char)
	end)
end

-- ── Initialize ────────────────────────────────────────────────────────────────
CollisionService.Setup()

for _, player in ipairs(Players:GetPlayers()) do
	onPlayerAdded(player)
end
Players.PlayerAdded:Connect(onPlayerAdded)

ServiceRegistry.Register("CollisionService", CollisionService)
return CollisionService