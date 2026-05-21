local Players             = game:GetService("Players")
local ReplicatedStorage   = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local CollectionService   = game:GetService("CollectionService")
local Debris              = game:GetService("Debris")

local Showstopper = {
	Config = {
		Name = "The Paparazzi Swarm",
		Duration = 9,
		Radius = 0,
		EffectType = "ScreenModify",
		BlindDuration = 2.5,   -- How long the blind overlay lingers per flash
		DroneCount = 12,       -- Number of server-side drone parts spawned
		DronePushRadius = 10,  -- Radius around a sabotaged obj where drones push enemies
		DronePushForce = 80,   -- BodyVelocity magnitude for the push
		RevealDuration = 9,    -- Enemy outline reveal matches full duration
	},
}

-- ─────────────────────────────────────────────────────────────────────────────
-- THE PAPARAZZI SWARM: Full Implementation
-- Universal Blind: BlindClient overlay fired at all enemies.
-- Tracking Leak: Enemy positions revealed through walls via "Revealed" attribute.
-- Score Window: Drones physically push enemies away from sabotaged objectives.
-- VFX: Light burst particles across map + sound of shutter clicks.
-- ─────────────────────────────────────────────────────────────────────────────

function Showstopper.Execute(player)
	local ServiceRegistry = require(ServerScriptService:WaitForChild("ServiceRegistry"))
	local SoundService    = require(ReplicatedStorage:WaitForChild("SoundService"))
	local VFX             = require(ReplicatedStorage:WaitForChild("VFXModule"))

	local char = player.Character
	if not char then return end
	local root = char:FindFirstChild("HumanoidRootPart")
	if not root then return end

	local playerTeam = player.Team
	if not playerTeam then return end
	local opposingTeamName = playerTeam.Name == "Designers" and "Critics" or "Designers"
	local opposingTeam = game.Teams:FindFirstChild(opposingTeamName)

	local Remotes = ReplicatedStorage:FindFirstChild("Remotes")
	local BlindClient             = Remotes and Remotes:FindFirstChild("BlindClient")
	local ShowstopperLocalTrigger = Remotes and Remotes:FindFirstChild("ShowstopperLocalTrigger")
	local ShowstopperAnnounce     = Remotes and Remotes:FindFirstChild("ShowstopperAnnounce")

	-- ── 1. UNIVERSAL BLIND: fire to all enemies ──
	-- BlindClient fires an overlay that tweens back out over ~2.5 seconds.
	if opposingTeam and BlindClient then
		for _, enemy in ipairs(opposingTeam:GetPlayers()) do
			BlindClient:FireClient(enemy, Showstopper.Config.BlindDuration)
		end
	end

	-- ── 2. TRACKING LEAK: reveal all enemies through walls ──
	-- "Revealed" attribute is already read by the nameplate/outline system.
	-- We also set a timed cleanup so it clears exactly when the swarm ends.
	if opposingTeam then
		for _, enemy in ipairs(opposingTeam:GetPlayers()) do
			local enemyChar = enemy.Character
			if enemyChar then
				enemyChar:SetAttribute("Revealed", true)
				print("[PAPARAZZI] " .. enemy.Name .. " position leaked to " .. playerTeam.Name)
			end

			-- Clear after duration
			task.delay(Showstopper.Config.RevealDuration, function()
				local ec = enemy.Character
				if ec then ec:SetAttribute("Revealed", nil) end
			end)
		end
	end

	-- ── 3. SPAWN DRONE PARTS (server-side) ──
	-- Invisible sensor parts float near sabotaged objectives and push enemies away.
	-- They also double as the "physical" presence of the swarm.
	local activeDrones = {}

	local function spawnDroneAt(targetPos)
		local drone = Instance.new("Part")
		drone.Name = "PaparazziDrone"
		drone.Size = Vector3.new(1.5, 1.5, 1.5)
		drone.Shape = Enum.PartType.Ball
		drone.Transparency = 1       -- invisible server part; client VFX handles visuals
		drone.CanCollide = false
		drone.Anchored = false
		drone.Massless = true
		drone.Position = targetPos + Vector3.new(math.random(-6,6), math.random(3,8), math.random(-6,6))
		drone.Parent = workspace:FindFirstChild("DebrisFolder") or workspace
		Debris:AddItem(drone, Showstopper.Config.Duration)
		table.insert(activeDrones, drone)
		return drone
	end

	-- Spawn drones around every sabotaged objective belonging to the enemy
	local function refreshDronesAroundObjectives()
		local sabotageTargetTags = playerTeam.Name == "Designers"
			and {"FabricShredders"} -- critics own shredders
			or {"FabricBins"}        -- designers own bins

		for _, tag in ipairs(sabotageTargetTags) do
			for _, obj in ipairs(CollectionService:GetTagged(tag)) do
				if obj:GetAttribute("IsSabotaged") then
					local objPos = obj:GetPivot().Position
					for i = 1, 3 do  -- 3 drones per sabotaged objective
						spawnDroneAt(objPos)
					end
				end
			end
		end
	end

	-- Also spawn some ambient drones near map center for harass effect
	local mapCenter = Vector3.new(0, 5, 0)
	for i = 1, Showstopper.Config.DroneCount do
		spawnDroneAt(mapCenter + Vector3.new(math.random(-30,30), 0, math.random(-30,30)))
	end
	refreshDronesAroundObjectives()

	-- ── 4. DRONE PUSH LOOP ──
	-- Every 0.3s: check if any enemy is within DronePushRadius of a drone.
	-- If so, apply a BodyVelocity kick away from the drone.
	local running = true
	task.spawn(function()
		local endTime = os.clock() + Showstopper.Config.Duration
		while running and os.clock() < endTime do
			if opposingTeam then
				for _, drone in ipairs(activeDrones) do
					if not drone or not drone.Parent then continue end
					for _, enemy in ipairs(opposingTeam:GetPlayers()) do
						local enemyChar = enemy.Character
						local enemyRoot = enemyChar and enemyChar:FindFirstChild("HumanoidRootPart")
						if enemyRoot then
							local dist = (drone.Position - enemyRoot.Position).Magnitude
							if dist <= Showstopper.Config.DronePushRadius then
								-- Push enemy away from drone position
								local pushDir = (enemyRoot.Position - drone.Position).Unit
								local bv = Instance.new("BodyVelocity")
								bv.MaxForce = Vector3.new(1,1,1) * 100000
								bv.Velocity = pushDir * Showstopper.Config.DronePushForce
								bv.Parent = enemyRoot
								Debris:AddItem(bv, 0.15)
							end
						end
					end
				end
			end
			task.wait(0.3)
		end
		running = false
	end)

	-- ── 5. GLOBAL VFX: light bursts across map ──
	VFX.Play("PaparazziSwarmVFX", mapCenter)      -- PLACEHOLDER — replace with flash burst particles
	SoundService.FireToAll("PaparazziShutterLoop") -- PLACEHOLDER — replace with shutter click loop

	-- ── 6. ANNOUNCEMENT ──
	if ShowstopperAnnounce then
		ShowstopperAnnounce:FireAllClients(
			player.Name,
			"The Paparazzi Swarm",
			"SMILE! THE PAPARAZZI HAVE ARRIVED!"
		)
	end

	-- ── 7. FIRE CLIENT-SIDE TRIGGER (for local camera shake etc.) ──
	if ShowstopperLocalTrigger then
		ShowstopperLocalTrigger:FireClient(player, {
			ShowstopperName = "The Paparazzi Swarm",
			Position = root.Position,
			Duration = Showstopper.Config.Duration,
		})
	end

	-- ── 8. CLEANUP ──
	task.delay(Showstopper.Config.Duration, function()
		running = false
		print("[PAPARAZZI] Swarm dispersed for " .. player.Name)
	end)

	print("[PAPARAZZI] " .. player.Name .. " unleashed the Paparazzi Swarm for " .. Showstopper.Config.Duration .. "s")
end

return Showstopper
