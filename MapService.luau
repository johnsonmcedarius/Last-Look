local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local ServerScriptService = game:GetService("ServerScriptService")

local ServiceRegistry = require(ServerScriptService:WaitForChild("ServiceRegistry"))
local MapsFolder = ReplicatedStorage:WaitForChild("Maps")

local MapService = {}
local currentMap = nil

function MapService.Cleanup()
	if currentMap then
		currentMap:Destroy()
		currentMap = nil
	end
end

function MapService.SelectAndLoadMap()
	MapService.Cleanup()

	local maps = MapsFolder:GetChildren()
	if #maps == 0 then return nil end

	local mapTemplate = maps[math.random(#maps)]
	currentMap = mapTemplate:Clone()
	currentMap.Parent = Workspace
	return currentMap
end

function MapService.GetSpawns(map, tag)
	local spawnCFrames = {}
	for _, part in ipairs(CollectionService:GetTagged(tag)) do
		if part:IsDescendantOf(map) and part:IsA("BasePart") then
			table.insert(spawnCFrames, part.CFrame)
		end
	end
	return spawnCFrames
end

function MapService.TeleportPlayers(players, spawns)
	if #spawns == 0 then return end
	local GRID_SPACING = 4

	for i, player in ipairs(players) do
		local spawnIdx = ((i - 1) % #spawns) + 1
		local cf = spawns[spawnIdx]

		-- Simple grid offset
		local col = (i - 1) % 3
		local row = math.floor((i - 1) / 3)
		local offset = Vector3.new(col * GRID_SPACING, 3, row * GRID_SPACING)

		if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
			player.Character:PivotTo(cf + offset)
		end
	end
end

-- ── Zone System: Get zones by type (Neutral, DesignerProtected, CriticProtected) ──
function MapService.GetZones(map, zoneType)
	local zones = {}
	for _, zone in ipairs(CollectionService:GetTagged(zoneType)) do
		if zone:IsDescendantOf(map) and zone:IsA("BasePart") then
			table.insert(zones, zone)
		end
	end
	return zones
end

-- ── Zone System: Check if position is within a zone type ──
function MapService.IsInZone(position, zoneType)
	for _, zone in ipairs(CollectionService:GetTagged(zoneType)) do
		if zone:IsA("BasePart") then
			local dist = (position - zone.Position).Magnitude
			local radius = math.max(zone.Size.X, zone.Size.Z) / 2
			if dist <= radius then
				return true
			end
		end
	end
	return false
end

-- ── Zone System: Get all zone types for a map ──
function MapService.GetAllZones(map)
	return {
		Neutral = MapService.GetZones(map, "NeutralZone"),
		DesignerProtected = MapService.GetZones(map, "DesignerProtectedZone"),
		CriticProtected = MapService.GetZones(map, "CriticProtectedZone"),
	}
end

ServiceRegistry.Register("MapService", MapService)
return MapService