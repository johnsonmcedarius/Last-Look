local Showstopper = {
	Config = {
		Name = "The Velvet Rope",
		Duration = 7,
		Radius = 40,
		EffectType = "Zone",
		AdrenalineBoostPercent = 0.20, -- +20% charge gain
		AdrenalineDuration = 10, -- Lasts 10 seconds after zone ends
	},
}

-- ─────────────────────────────────────────────────────────────────────────────
-- THE VELVET ROPE: Full Implementation
-- Instant Guest List: Unfreeze + reset strikes for teammates in radius
-- VIP Protection: Freeze immunity + ability immunity for duration
-- Adrenaline Boost: +20% Showstopper charge gain for 10 seconds
-- Physical Barrier: Collision wall for opposing team
-- ─────────────────────────────────────────────────────────────────────────────

function Showstopper.Execute(player)
	local Players = game:GetService("Players")
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local ServerScriptService = game:GetService("ServerScriptService")
	
	local ZoneHandler = require(ServerScriptService:WaitForChild("ZoneHandler"))
	local ServiceRegistry = require(ServerScriptService:WaitForChild("ServiceRegistry"))
	local SoundService = require(ReplicatedStorage:WaitForChild("SoundService"))
	local VFX = require(ReplicatedStorage:WaitForChild("VFXModule"))
	
	local char = player.Character
	if not char then return end
	local root = char:FindFirstChild("HumanoidRootPart")
	if not root then return end
	
	local pos = root.Position
	local playerTeam = player.Team
	if not playerTeam then return end
	
	-- ── 1. INSTANT GUEST LIST: Unfreeze + Reset Strikes ──
	-- Find all teammates within radius and rescue them
	local initialParts = workspace:GetPartBoundsInRadius(pos, Showstopper.Config.Radius)
	local rescuedPlayers = {}
	
	for _, part in ipairs(initialParts) do
		local teammateChar = part.Parent
		local teammate = Players:GetPlayerFromCharacter(teammateChar)
		if teammate and teammate.Team == playerTeam then
			rescuedPlayers[teammate] = true
			
			-- Unfreeze if frozen
			local TagManager = ServiceRegistry.Get("TagManager")
			if TagManager and TagManager.Unfreeze then
				TagManager.Unfreeze(teammate)
			end
			
			-- Reset strikes
			local Relevance = ServiceRegistry.Get("RelevanceSystem")
			if Relevance and Relevance.ResetStrikes then
				Relevance.ResetStrikes(teammate)
			end
			
			-- Apply VIP Protection (freeze immunity)
			teammateChar:SetAttribute("VIPProtection", true)
			teammateChar:SetAttribute("FreezeImmune", true)
			
			print("[VELVET ROPE] " .. teammate.Name .. " added to VIP list - unfrozen & strikes reset")
		end
	end
	
	-- ── 2. CREATE COLLISION BARRIER ZONE ──
	-- ZoneHandler creates the physical barrier and applies VIPProtection
	ZoneHandler.CreateCollisionFilterZone(player, Showstopper.Config.Duration, Showstopper.Config.Radius, pos)
	
	-- ── 3. ADRENALINE BOOST: +20% Charge Gain ──
	-- Applied to all teammates who were in the zone
	for teammate, _ in pairs(rescuedPlayers) do
		teammate:SetAttribute("AdrenalineBoost", true)
		
		-- Clear adrenaline boost after duration
		task.delay(Showstopper.Config.AdrenalineDuration, function()
			if teammate and teammate.Parent then
				teammate:SetAttribute("AdrenalineBoost", nil)
				print("[VELVET ROPE] " .. teammate.Name .. " adrenaline boost expired")
			end
		end)
	end
	
	-- ── 4. CLEANUP VIP PROTECTION AFTER DURATION ──
	task.delay(Showstopper.Config.Duration, function()
		for teammate, _ in pairs(rescuedPlayers) do
			if teammate and teammate.Character and teammate.Character.Parent then
				teammate.Character:SetAttribute("VIPProtection", nil)
				teammate.Character:SetAttribute("FreezeImmune", nil)
			end
		end
		print("[VELVET ROPE] VIP Protection expired for all guests")
	end)
	
	-- ── 5. TRIGGER CLIENT VFX ──
	local Remotes = ReplicatedStorage:FindFirstChild("Remotes")
	local ShowstopperLocalTrigger = Remotes and Remotes:FindFirstChild("ShowstopperLocalTrigger")
	if ShowstopperLocalTrigger then
		ShowstopperLocalTrigger:FireClient(player, {
			ShowstopperName = "The Velvet Rope",
			Position = pos,
			Radius = Showstopper.Config.Radius,
			Duration = Showstopper.Config.Duration,
		})
	end
	
	-- ── 6. PLAY ACTIVATION SOUND ──
	SoundService.FireToAll("VelvetRopeActivate", pos)
	
	print("[VELVET ROPE] " .. player.Name .. " opened the VIP Lounge at " .. tostring(pos))
end

return Showstopper
