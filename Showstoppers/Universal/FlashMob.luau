local Showstopper = {
	Config = {
		Name = "The Flash Mob",
		Duration = 12,
		Radius = 0,
		EffectType = "GlobalBuff",
		BaseSpeedBoost = 15,
		ChainBonusPerTeammate = 5,
		ChainRadius = 20,
		TelePassMultiplier = 3,
		DunkSpeedBoostPercent = 0.10,
		SabotageCooldownReduction = 0.50,
		BonusDuration = 20,
	},
}

-- ─────────────────────────────────────────────────────────────────────────────
-- THE FLASH MOB: Full Implementation
-- Synchronized Strut: +15 WalkSpeed, +5 per teammate in chain
-- Tele-Pass: Triple FabricPass range
-- Momentum Reset: Dash cooldown reset on fabric pass
-- Dunk/Shred Bonus: +10% speed + 50% sabotage cooldown reduction
-- ─────────────────────────────────────────────────────────────────────────────

function Showstopper.Execute(player)
	local Players = game:GetService("Players")
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local ServerScriptService = game:GetService("ServerScriptService")
	
	local StatusHandler = require(ServerScriptService:WaitForChild("StatusHandler"))
	local ServiceRegistry = require(ServerScriptService:WaitForChild("ServiceRegistry"))
	local SoundService = require(ReplicatedStorage:WaitForChild("SoundService"))
	local VFX = require(ReplicatedStorage:WaitForChild("VFXModule"))
	
	local playerTeam = player.Team
	if not playerTeam then return end
	
	-- ── 1. APPLY BASE SPEED BUFF TO ALL TEAMMATES ──
	StatusHandler.ApplyGlobalBuff(playerTeam, "FlashMob", Showstopper.Config.Duration)
	
	-- ── 2. TELE-PASS: TRIPLE FABRIC PASS RANGE ──
	-- Set attribute on all teammates that FabricPassSystem will check
	for _, teammate in ipairs(playerTeam:GetPlayers()) do
		teammate:SetAttribute("TelePassActive", true)
		teammate:SetAttribute("FlashMobActive", true)
		
		-- Clear after duration
		task.delay(Showstopper.Config.Duration, function()
			if teammate and teammate.Parent then
				teammate:SetAttribute("TelePassActive", nil)
				teammate:SetAttribute("FlashMobActive", nil)
			end
		end)
	end
	
	-- ── 3. CHAIN BONUS: +5 SPEED PER TEAMMATE IN 20-STUD RADIUS ──
	-- Run periodic check for chain bonus
	local chainTask = task.spawn(function()
		local endTime = os.clock() + Showstopper.Config.Duration
		while os.clock() < endTime do
			for _, teammate in ipairs(playerTeam:GetPlayers()) do
				local char = teammate.Character
				local root = char and char:FindFirstChild("HumanoidRootPart")
				if root then
					-- Count nearby teammates
					local chainCount = 0
					for _, other in ipairs(playerTeam:GetPlayers()) do
						if other ~= teammate then
							local otherChar = other.Character
							local otherRoot = otherChar and otherChar:FindFirstChild("HumanoidRootPart")
							if otherRoot then
								local dist = (root.Position - otherRoot.Position).Magnitude
								if dist <= Showstopper.Config.ChainRadius then
									chainCount = chainCount + 1
								end
							end
						end
					end
					
					-- Apply chain bonus
					local chainBonus = chainCount * Showstopper.Config.ChainBonusPerTeammate
					teammate:SetAttribute("ChainSpeedBonus", chainBonus)
					
					-- Update speed
					local humanoid = char:FindFirstChild("Humanoid")
					if humanoid then
						local baseSpeed = 16
						local flashMobBonus = Showstopper.Config.BaseSpeedBoost
						humanoid.WalkSpeed = baseSpeed + flashMobBonus + chainBonus
					end
				end
			end
			task.wait(0.5)
		end
		
		-- Clear chain bonuses
		for _, teammate in ipairs(playerTeam:GetPlayers()) do
			teammate:SetAttribute("ChainSpeedBonus", nil)
		end
	end)
	
	-- ── 4. TRIGGER CLIENT VFX ──
	local Remotes = ReplicatedStorage:FindFirstChild("Remotes")
	local ShowstopperLocalTrigger = Remotes and Remotes:FindFirstChild("ShowstopperLocalTrigger")
	if ShowstopperLocalTrigger then
		for _, teammate in ipairs(playerTeam:GetPlayers()) do
			ShowstopperLocalTrigger:FireClient(teammate, {
				ShowstopperName = "The Flash Mob",
				Duration = Showstopper.Config.Duration,
			})
		end
	end
	
	-- ── 5. PLAY ACTIVATION SOUND ──
	SoundService.FireToAll("FlashMobActivate")
	
	print("[FLASH MOB] " .. player.Name .. " started the Flash Mob - SQUAD GOALS!")
end

-- ── BONUS: DUNK/SHRED HOOK ──
-- Called by FabricManager when a dunk/shred happens during Flash Mob
function Showstopper.OnDunkOrShred(team)
	local Players = game:GetService("Players")
	local ServerScriptService = game:GetService("ServerScriptService")
	local ServiceRegistry = require(ServerScriptService:WaitForChild("ServiceRegistry"))
	
	-- Apply bonus to entire team
	for _, teammate in ipairs(team:GetPlayers()) do
		-- +10% speed boost
		teammate:SetAttribute("DunkSpeedBonus", Showstopper.Config.DunkSpeedBoostPercent)
		
		-- 50% sabotage cooldown reduction
		teammate:SetAttribute("SabotageCooldownReduction", Showstopper.Config.SabotageCooldownReduction)
		
		-- Clear after bonus duration
		task.delay(Showstopper.Config.BonusDuration, function()
			if teammate and teammate.Parent then
				teammate:SetAttribute("DunkSpeedBonus", nil)
				teammate:SetAttribute("SabotageCooldownReduction", nil)
			end
		end)
	end
	
	print("[FLASH MOB] Dunk/Shred bonus applied to " .. team.Name)
end

return Showstopper
