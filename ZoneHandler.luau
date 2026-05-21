-- ─────────────────────────────────────────────────────────────────────────────
-- ZoneHandler: Handles Area-of-Effect abilities and zones
-- ─────────────────────────────────────────────────────────────────────────────
local ZoneHandler = {}

local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")

local ENTITY_TAG = "CombatEntity"

-- ── Helpers ──
local function tagForCleanup(obj, owner)
	CollectionService:AddTag(obj, ENTITY_TAG)
	if owner then
		obj:SetAttribute("OwnerId", owner.UserId)
	end
end

-- ── Core Logic ──

function ZoneHandler.CreateVisionDenialZone(player, duration, radius, position, isGlitch)
	-- The Smoke Machine / Glitch Gala
	local zoneName = isGlitch and "GlitchGalaZone" or "VisionDenialZone"
	local attributeName = isGlitch and "InGlitch" or "InSmoke"
	
	local zone = Instance.new("Part")
	zone.Name = zoneName
	zone.Shape = Enum.PartType.Ball
	zone.Size = Vector3.new(radius * 2, radius * 2, radius * 2)
	zone.Position = position
	zone.Transparency = 0.6
	zone.Color = isGlitch and Color3.fromRGB(50, 50, 50) or Color3.fromRGB(150, 100, 200)
	zone.CanCollide = false
	zone.Anchored = true
	zone.Parent = workspace
	
	tagForCleanup(zone, player)
	Debris:AddItem(zone, duration)
	
	-- Apply Attribute Loop
	task.spawn(function()
		local endTime = os.clock() + duration
		local ServerScriptService = game:GetService("ServerScriptService")
		local FabricManager = require(ServerScriptService:WaitForChild("ServiceRegistry")).Get("FabricManager")
		
		while os.clock() < endTime do
			local parts = workspace:GetPartBoundsInRadius(position, radius)
			local presentPlayers = {}
			
			for _, part in ipairs(parts) do
				local char = part.Parent
				local p = game.Players:GetPlayerFromCharacter(char)
				if p and not presentPlayers[p] then
					-- For Glitch, only affect enemies
					if isGlitch and p.Team == player.Team then continue end
					
					presentPlayers[p] = true
					p:SetAttribute(attributeName, true)
				end
			end
			
			-- Cleanup attribute for players who left
			for _, p in ipairs(game.Players:GetPlayers()) do
				if not presentPlayers[p] and p:GetAttribute(attributeName) then
					p:SetAttribute(attributeName, nil)
				end
			end
			
			-- Special: Glitch Gala cleanses sabotage
			if isGlitch and FabricManager then
				FabricManager.CleanseNearbySabotage(player, radius)
			end
			
			task.wait(0.5)
		end
		
		-- Final cleanup
		for _, p in ipairs(game.Players:GetPlayers()) do
			p:SetAttribute(attributeName, nil)
		end
	end)
end

function ZoneHandler.CreateCollisionFilterZone(player, duration, radius, position)
	-- The Velvet Rope
	local teamName = player.Team and player.Team.Name
	if not teamName then return end
	
	local zone = Instance.new("Part")
	zone.Name = "VelvetRopeBarrier"
	zone.Shape = Enum.PartType.Cylinder
	zone.Size = Vector3.new(15, radius * 2, radius * 2)
	zone.Position = position
	zone.Rotation = Vector3.new(0, 0, 90)
	zone.Transparency = 0.5
	zone.Color = Color3.fromRGB(200, 0, 0)
	zone.Anchored = true
	
	-- Assign Collision Group
	zone.CollisionGroup = teamName == "Designers" and "DesignerBarrier" or "CriticBarrier"
	
	zone.Parent = workspace
	tagForCleanup(zone, player)
	Debris:AddItem(zone, duration)
	
	-- Apply VIP Protection and Reset Strikes
	task.spawn(function()
		local endTime = os.clock() + duration
		local ServerScriptService = game:GetService("ServerScriptService")
		local Relevance = require(ServerScriptService:WaitForChild("ServiceRegistry")).Get("RelevanceSystem")
		
		-- One-time rescue upon popping
		local initialParts = workspace:GetPartBoundsInRadius(position, radius)
		for _, part in ipairs(initialParts) do
			local char = part.Parent
			local p = game.Players:GetPlayerFromCharacter(char)
			if p and p.Team == player.Team then
				if Relevance then Relevance.ResetStrikes(p) end
				-- Trigger unfreeze in TagManager if frozen
				local TagManager = require(ServerScriptService:WaitForChild("ServiceRegistry")).Get("TagManager")
				if TagManager then TagManager.Unfreeze(p) end
			end
		end

		while os.clock() < endTime do
			local parts = workspace:GetPartBoundsInRadius(position, radius)
			local presentTeammates = {}
			
			for _, part in ipairs(parts) do
				local char = part.Parent
				local p = game.Players:GetPlayerFromCharacter(char)
				if p and p.Team == player.Team then
					presentTeammates[p] = true
					p:SetAttribute("VIPProtection", true)
					-- Adrenaline Boost: +20% Showstopper Charge gain (handled in ShowstopperService)
				end
			end
			
			-- Cleanup attribute
			for _, p in ipairs(game.Players:GetPlayers()) do
				if not presentTeammates[p] and p:GetAttribute("VIPProtection") then
					p:SetAttribute("VIPProtection", nil)
				end
			end
			
			task.wait(0.5)
		end
		
		for _, p in ipairs(game.Players:GetPlayers()) do
			p:SetAttribute("VIPProtection", nil)
		end
	end)
end

function ZoneHandler.CreateProjectileBarrier(player, duration, radius, position)
	-- The Fabric Shield
	local zone = Instance.new("Part")
	zone.Name = "FabricShield"
	zone.Size = Vector3.new(radius, 10, 1)
	zone.CFrame = player.Character.PrimaryPart.CFrame * CFrame.new(0, 0, -3)
	zone.Transparency = 0.8
	zone.Anchored = false -- Attach to player
	zone.CanCollide = true
	zone.Parent = player.Character
	
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = player.Character.PrimaryPart
	weld.Part1 = zone
	weld.Parent = zone
	
	tagForCleanup(zone, player)
	Debris:AddItem(zone, duration)
end

function ZoneHandler.Cleanup(player)
	for _, obj in ipairs(CollectionService:GetTagged(ENTITY_TAG)) do
		if obj:GetAttribute("OwnerId") == player.UserId then
			obj:Destroy()
		end
	end
end

function ZoneHandler.CleanupAll()
	for _, obj in ipairs(CollectionService:GetTagged(ENTITY_TAG)) do
		obj:Destroy()
	end
end

return ZoneHandler
