local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local CollectionService = game:GetService("CollectionService")

local Showstopper = {
	Config = {
		Name = "The Main Event",
		Duration = 10,
		Radius = 20, -- Trend-Killer Aura radius
		EffectType = "GlobalBuff",
		TeamHypePercent = 0.10, -- +10% charge boost for teammates
	},
}

-- ─────────────────────────────────────────────────────────────────────────────
-- THE MAIN EVENT: Full Implementation
-- Transforms the user into a high-fashion juggernaut for 10 seconds
-- ─────────────────────────────────────────────────────────────────────────────

function Showstopper.Execute(player)
	local StatusHandler = require(ServerScriptService:WaitForChild("StatusHandler"))
	local ServiceRegistry = require(ServerScriptService:WaitForChild("ServiceRegistry"))
	local ShowstopperService = ServiceRegistry.Await("ShowstopperService")
	local FabricManager = ServiceRegistry.Await("FabricManager")
	local Config = require(ReplicatedStorage:WaitForChild("SharedConfig"))
	local SoundService = require(ReplicatedStorage:WaitForChild("SoundService"))
	local VFX = require(ReplicatedStorage:WaitForChild("VFXModule"))

	local char = player.Character
	if not char then return end

	-- ── 1. APPLY MAIN EVENT ACTIVE STATE ──
	-- This triggers: WalkSpeed 45, freeze immunity, and client VFX
	StatusHandler.ApplyGlobalBuff(player.Team, "MainEvent", Showstopper.Config.Duration)

	-- ── 2. FREEZE IMMUNITY ──
	-- Player is immune to all "Freeze" attempts while active
	char:SetAttribute("FreezeImmune", true)
	task.delay(Showstopper.Config.Duration, function()
		if char and char.Parent then
			char:SetAttribute("FreezeImmune", nil)
		end
	end)

	-- ── 3. TREND-KILLER AURA ──
	-- Any opposing team within 20-stud radius has WalkSpeed cut by 50%
	local function applyTrendKillerAura()
		local root = char:FindFirstChild("HumanoidRootPart")
		if not root then return end

		local playerTeam = player.Team
		if not playerTeam then return end

		local opposingTeamName = playerTeam.Name == "Designers" and "Critics" or "Designers"
		local opposingTeam = game.Teams:FindFirstChild(opposingTeamName)
		if not opposingTeam then return end

		for _, opponent in ipairs(opposingTeam:GetPlayers()) do
			local oppChar = opponent.Character
			local oppRoot = oppChar and oppChar:FindFirstChild("HumanoidRootPart")
			if oppRoot and oppChar then
				local dist = (root.Position - oppRoot.Position).Magnitude
				if dist <= Showstopper.Config.Radius then
					-- Apply 50% speed reduction (8 speed instead of 16)
					StatusHandler.ApplySpeedDebuff(player, oppChar, 8, 1.0) -- Reapply every second
				end
			end
		end
	end

	-- Run aura check every 0.5 seconds for the duration
	local auraRunning = true
	task.spawn(function()
		while auraRunning and char and char:GetAttribute("MainEventActive") do
			applyTrendKillerAura()
			task.wait(0.5)
		end
	end)

	-- ── 4. TEAM HYPE HOOK ──
	-- Every successful dunk during Showstopper grants teammates +10% charge
	local originalOnFabricDunk = ShowstopperService.OnFabricDunk
	ShowstopperService.OnFabricDunk = function(dunkPlayer)
		if dunkPlayer == player and char and char:GetAttribute("MainEventActive") then
			-- Grant +10% charge to all teammates
			local team = player.Team
			if team then
				for _, teammate in ipairs(team:GetPlayers()) do
					if teammate ~= player then
						ShowstopperService.AddCharge(teammate, Config.MAX_CHARGE * Showstopper.Config.TeamHypePercent)
					end
				end
			end
		end
		-- Call original if it exists
		if originalOnFabricDunk then
			originalOnFabricDunk(dunkPlayer)
		end
	end

	-- ── 5. INSTANT SABOTAGE REBOOT ──
	-- Standing near sabotaged bin/shredder instantly reboots it
	local function checkSabotageReboot()
		local root = char:FindFirstChild("HumanoidRootPart")
		if not root then return end

		-- Check bins
		for _, bin in ipairs(CollectionService:GetTagged("FabricBins")) do
			if bin:GetAttribute("IsSabotaged") then
				local dist = (bin:GetPivot().Position - root.Position).Magnitude
				if dist <= 10 then
					bin:SetAttribute("IsSabotaged", false)
					VFX.Play("SabotageClear", bin:GetPivot().Position)
					SoundService.FireToAll("Unsabotage", bin:GetPivot().Position)
					local ObjectiveWarning = ReplicatedStorage:FindFirstChild("Remotes") and ReplicatedStorage.Remotes:FindFirstChild("ObjectiveWarning")
					if ObjectiveWarning then
						ObjectiveWarning:FireAllClients("Designers", false)
					end
					-- Clean up reboot prompt
					local reboot = bin:FindFirstChild("BinReboot")
					if reboot then reboot:Destroy() end
					print("[MAIN EVENT] " .. player.Name .. " instantly rebooted sabotaged bin!")
				end
			end
		end

		-- Check shredders
		for _, shredder in ipairs(CollectionService:GetTagged("FabricShredders")) do
			if shredder:GetAttribute("IsSabotaged") then
				local dist = (shredder:GetPivot().Position - root.Position).Magnitude
				if dist <= 10 then
					shredder:SetAttribute("IsSabotaged", false)
					VFX.Play("SabotageClear", shredder:GetPivot().Position)
					SoundService.FireToAll("Unsabotage", shredder:GetPivot().Position)
					local ObjectiveWarning = ReplicatedStorage:FindFirstChild("Remotes") and ReplicatedStorage.Remotes:FindFirstChild("ObjectiveWarning")
					if ObjectiveWarning then
						ObjectiveWarning:FireAllClients("Critics", false)
					end
					-- Clean up reboot prompt
					local reboot = shredder:FindFirstChild("ShredderReboot")
					if reboot then reboot:Destroy() end
					print("[MAIN EVENT] " .. player.Name .. " instantly rebooted sabotaged shredder!")
				end
			end
		end
	end

	-- Run sabotage reboot check periodically
	task.spawn(function()
		while auraRunning and char and char:GetAttribute("MainEventActive") do
			checkSabotageReboot()
			task.wait(0.3)
		end
	end)

	-- ── 6. CLEANUP ON DURATION END ──
	task.delay(Showstopper.Config.Duration, function()
		auraRunning = false
		-- Restore original OnFabricDunk
		if originalOnFabricDunk then
			ShowstopperService.OnFabricDunk = originalOnFabricDunk
		end
	end)

	print("[MAIN EVENT] " .. player.Name .. " is taking the stage for " .. Showstopper.Config.Duration .. " seconds!")
end

return Showstopper
