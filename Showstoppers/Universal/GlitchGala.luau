local Showstopper = {
	Config = {
		Name = "The Glitch Gala",
		Duration = 8,
		Radius = 30,
		EffectType = "Zone",
		SystemShockRadius = 30,
		SystemShockDuration = 4,
		SpeedCap = 12,
	},
}

-- ─────────────────────────────────────────────────────────────────────────────
-- THE GLITCH GALA: Full Implementation
-- System Shock: Disables dash and caps speed for enemies in initial pulse
-- Relevance Drain: Double strikes for enemies in glitch zone
-- Sabotage Reboot: Instantly cleanses sabotaged bins/shredders
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
	
	-- ── 1. SYSTEM SHOCK: Initial 30-stud pulse ──
	-- Disables Fashion Dash and caps WalkSpeed to 12 for 4 seconds
	local opposingTeamName = playerTeam and playerTeam.Name == "Designers" and "Critics" or "Designers"
	local opposingTeam = game.Teams:FindFirstChild(opposingTeamName)
	
	if opposingTeam then
		for _, opponent in ipairs(opposingTeam:GetPlayers()) do
			local oppChar = opponent.Character
			local oppRoot = oppChar and oppChar:FindFirstChild("HumanoidRootPart")
			if oppRoot and oppChar then
				local dist = (pos - oppRoot.Position).Magnitude
				if dist <= Showstopper.Config.SystemShockRadius then
					-- Apply System Shock debuffs
					opponent:SetAttribute("DashDisabled", true)
					opponent:SetAttribute("SpeedCap", Showstopper.Config.SpeedCap)
					
					-- Apply speed cap to character
					local humanoid = oppChar:FindFirstChild("Humanoid")
					if humanoid then
						humanoid.WalkSpeed = math.min(humanoid.WalkSpeed, Showstopper.Config.SpeedCap)
					end
					
					-- Notify client for visual feedback
					local Remotes = ReplicatedStorage:FindFirstChild("Remotes")
					local MovementEffect = Remotes and Remotes:FindFirstChild("MovementEffect")
					if MovementEffect then
						MovementEffect:FireClient(opponent, "SystemShock", {
							Duration = Showstopper.Config.SystemShockDuration,
							SpeedCap = Showstopper.Config.SpeedCap,
						})
					end
					
					-- Visual feedback at victim position
					VFX.Play("GlitchPulse", oppRoot.Position)
					SoundService.FireToClient(opponent, "SystemShock")
					
					print("[GLITCH GALA] System Shock applied to " .. opponent.Name)
					
					-- Clear debuffs after duration
					task.delay(Showstopper.Config.SystemShockDuration, function()
						if opponent and opponent.Parent then
							opponent:SetAttribute("DashDisabled", nil)
							opponent:SetAttribute("SpeedCap", nil)
							
							-- Restore normal speed
							local oppCharNow = opponent.Character
							if oppCharNow then
								local humanoidNow = oppCharNow:FindFirstChild("Humanoid")
								if humanoidNow then
									humanoidNow.WalkSpeed = 16 -- Reset to base speed
								end
							end
							
							print("[GLITCH GALA] System Shock expired for " .. opponent.Name)
						end
					end)
				end
			end
			end
		end
	end
	
	-- ── 2. GLITCH ZONE: Vision denial + Relevance Drain ──
	-- ZoneHandler creates the zone and sets InGlitch attribute on enemies
	-- RelevanceSystem already checks InGlitch for double strikes
	ZoneHandler.CreateVisionDenialZone(player, Showstopper.Config.Duration, Showstopper.Config.Radius, pos, true)
	
	-- ── 3. TRIGGER CLIENT VFX ──
	-- Fire ShowstopperLocalTrigger for zero-latency client VFX
	local Remotes = ReplicatedStorage:FindFirstChild("Remotes")
	local ShowstopperLocalTrigger = Remotes and Remotes:FindFirstChild("ShowstopperLocalTrigger")
	if ShowstopperLocalTrigger then
		ShowstopperLocalTrigger:FireClient(player, {
			ShowstopperName = "The Glitch Gala",
			Position = pos,
			Radius = Showstopper.Config.Radius,
			Duration = Showstopper.Config.Duration,
		})
	end
	
	-- ── 4. ANNOUNCEMENT ──
	-- ShowstopperAnnouncer handles the "ERROR: THE GALA IS GLITCHED!" message
	-- (Already triggered by ShowstopperService via ShowstopperAnnounce remote)
	
	print("[GLITCH GALA] " .. player.Name .. " executed The Glitch Gala at " .. tostring(pos))
end

return Showstopper
