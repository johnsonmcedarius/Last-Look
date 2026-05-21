-- ─────────────────────────────────────────────────────────────────────────────
-- PhysicsHandler: Handles physics-based ability logic
-- ─────────────────────────────────────────────────────────────────────────────
local PhysicsHandler = {}

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

function PhysicsHandler.ApplyFrictionRemoval(player, duration, radius, position)
	-- Create the visual/trigger part
	local zone = Instance.new("Part")
	zone.Name = "SlipperyGlossZone"
	zone.Shape = Enum.PartType.Cylinder
	zone.Size = Vector3.new(1, radius * 2, radius * 2)
	zone.Position = position - Vector3.new(0, 2.5, 0) -- Near floor
	zone.Rotation = Vector3.new(0, 0, 90)
	zone.Transparency = 0.5 -- Debug/Visual
	zone.Color = Color3.fromRGB(200, 240, 255)
	zone.CanCollide = false
	zone.Anchored = true
	zone.Parent = workspace
	
	tagForCleanup(zone, player)
	Debris:AddItem(zone, duration)
	
	-- Actual Logic: Check for players in zone
	task.spawn(function()
		local endTime = os.clock() + duration
		while os.clock() < endTime do
			local parts = workspace:GetPartBoundsInRadius(position, radius)
			local affectedCharacters = {}
			
			for _, part in ipairs(parts) do
				local char = part.Parent
				if char and char:FindFirstChild("Humanoid") and not affectedCharacters[char] then
					-- Don't affect caster (optional, based on design)
					if char == player.Character then continue end
					
					affectedCharacters[char] = true
					local humanoid = char.Humanoid
					local root = char.PrimaryPart
					
					if root and not root:FindFirstChild("SlipperyVelocity") then
						humanoid.PlatformStand = true
						
						local lv = Instance.new("LinearVelocity")
						lv.Name = "SlipperyVelocity"
						lv.MaxForce = 100000
						lv.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
						lv.VectorVelocity = root.AssemblyLinearVelocity -- Keep current momentum
						
						local attachment = Instance.new("Attachment")
						attachment.Parent = root
						lv.Attachment0 = attachment
						lv.Parent = root
						
						task.delay(1.5, function()
							if lv then lv:Destroy() end
							if attachment then attachment:Destroy() end
							if char and char:FindFirstChild("Humanoid") then
								char.Humanoid.PlatformStand = false
							end
						end)
					end
				end
			end
			task.wait(0.2)
		end
	end)
end

function PhysicsHandler.ApplyDirectionalPushback(player, direction, duration, radius, position)
	-- Wind Machine
	local cone = Instance.new("Part")
	cone.Name = "WindCone"
	cone.Size = Vector3.new(radius, radius, radius * 2)
	cone.CFrame = CFrame.lookAt(position, position + direction) * CFrame.new(0, 0, -radius)
	cone.Transparency = 0.7
	cone.CanCollide = false
	cone.Anchored = true
	cone.Parent = workspace
	
	tagForCleanup(cone, player)
	Debris:AddItem(cone, duration)
	
	task.spawn(function()
		local endTime = os.clock() + duration
		while os.clock() < endTime do
			local overlapParams = OverlapParams.new()
			overlapParams.FilterDescendantsInstances = {player.Character}
			overlapParams.FilterType = Enum.RaycastFilterType.Exclude
			
			local hitParts = workspace:GetPartBoundsInBox(cone.CFrame, cone.Size, overlapParams)
			local affected = {}
			
			for _, part in ipairs(hitParts) do
				local char = part.Parent
				if char and char:FindFirstChild("HumanoidRootPart") and not affected[char] then
					affected[char] = true
					local root = char.HumanoidRootPart
					
					-- Apply impulse/force
					root:ApplyImpulse(direction * 5000) -- Adjust strength
				end
			end
			task.wait(0.1)
		end
	end)
end

function PhysicsHandler.ApplyGrapple(player, targetPosition)
	local char = player.Character
	if not char or not char.PrimaryPart then return end
	
	local root = char.PrimaryPart
	
	local attachment1 = Instance.new("Attachment")
	attachment1.Position = targetPosition
	attachment1.Parent = workspace.Terrain -- Anchor to world
	
	local attachment0 = Instance.new("Attachment")
	attachment0.Parent = root
	
	local ap = Instance.new("AlignPosition")
	ap.Name = "GrappleConstraint"
	ap.Attachment0 = attachment0
	ap.Attachment1 = attachment1
	ap.MaxForce = 200000
	ap.Responsiveness = 15
	ap.Parent = root
	
	tagForCleanup(ap, player)
	
	-- Visual line (Tape)
	local beam = Instance.new("Beam")
	beam.Attachment0 = attachment0
	beam.Attachment1 = attachment1
	beam.Width0 = 0.2
	beam.Width1 = 0.2
	beam.Color = ColorSequence.new(Color3.fromRGB(255, 255, 200))
	beam.Parent = root
	
	task.delay(1, function()
		ap:Destroy()
		attachment0:Destroy()
		attachment1:Destroy()
		beam:Destroy()
	end)
end

function PhysicsHandler.Cleanup(player)
	for _, obj in ipairs(CollectionService:GetTagged(ENTITY_TAG)) do
		if obj:GetAttribute("OwnerId") == player.UserId then
			obj:Destroy()
		end
	end
end

function PhysicsHandler.CleanupAll()
	for _, obj in ipairs(CollectionService:GetTagged(ENTITY_TAG)) do
		obj:Destroy()
	end
end

return PhysicsHandler
