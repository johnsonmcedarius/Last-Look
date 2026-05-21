local Players           = game:GetService("Players")
local ReplicatedStorage   = game:GetService("ReplicatedStorage")
local Teams               = game:GetService("Teams")
local ServerScriptService = game:GetService("ServerScriptService")

local ServiceRegistry = require(ServerScriptService:WaitForChild("ServiceRegistry"))
local RoundEvents     = require(ServerScriptService:WaitForChild("RoundEvents"))
local Config          = require(ReplicatedStorage:WaitForChild("SharedConfig"))

-- Await dependencies
local DataManager = ServiceRegistry.Await("DataManager")

-- DailyLookbook is optional
local function getDailyLookbook()
	return ServiceRegistry.Get("DailyLookbook")
end

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local ShowMVP         = Remotes:WaitForChild("ShowMVP")
local ShowEndStats    = Remotes:WaitForChild("ShowEndStats")
local PostMatchXP     = Remotes:WaitForChild("PostMatchXP")

local roundScores    = {}
local roundActive    = false
local pressureTimers = {}

-- ── Internal Helpers ─────────────────────────────────────────────────────────
local function initScore(player)
	roundScores[player.UserId] = {
		Player = player,
		fabricCount = 0,
		dunks = 0,
		unfreezes = 0,
		freezes = 0,
		neverFrozen = true,
		sabotages = 0,
		xpEarned = 0,
		coinsEarned = 0,
		totalPoints = 0
	}
end

local function getScore(player)
	return roundScores[player.UserId]
end

local function giveReward(player, rewardKey)
	local r = Config.REWARDS[rewardKey]
	if not r then return end

	if DataManager and DataManager.AddReward then
		DataManager.AddReward(player, r.XP, r.Coins, true)
	end

	local score = getScore(player)
	if score then
		score.xpEarned    += r.XP
		score.coinsEarned += r.Coins
	end
end

-- ── Public API ───────────────────────────────────────────────────────────────
local RewardTracker = {}

function RewardTracker.OnFabricCollect(player)
	local s = getScore(player)
	if s then 
		s.fabricCount += 1 
		s.totalPoints += Config.POINTS.FABRIC_COLLECT
	end
	giveReward(player, "FabricCollect")
end

function RewardTracker.OnFabricDunk(player)
	local s = getScore(player)
	if s then 
		s.dunks += 1 
		s.totalPoints += Config.POINTS.FABRIC_DUNK
	end
	giveReward(player, "FabricDunk")

	print("[REWARDS] " .. player.Name .. " dunked fabric! Total Dunks: " .. (s and s.dunks or 0))
end

function RewardTracker.OnFabricShred(player)
	local s = getScore(player)
	if s then 
		s.dunks += 1 
		s.totalPoints += Config.POINTS.SHRED_FABRIC or 50
	end
	giveReward(player, "FabricShred")

	print("[REWARDS] " .. player.Name .. " shredded fabric! Total Shreds: " .. (s and s.dunks or 0))
end

function RewardTracker.OnUnfreezeAlly(player)
	giveReward(player, "UnfreezeAlly")
	local s = getScore(player)
	if s then s.unfreezes += 1 end
	local lb = getDailyLookbook()
	if lb then lb.AddProgress(player, "Rescues", 1) end
end

function RewardTracker.OnFreezeDesigner(critic)
	giveReward(critic, "FreezeDesigner")
	local s = getScore(critic)
	if s then s.freezes += 1 end
	local lb = getDailyLookbook()
	if lb then lb.AddProgress(critic, "Freezes", 1) end
end

function RewardTracker.OnFreezeCritic(designer)
	giveReward(designer, "FreezeCritic")
	local s = getScore(designer)
	if s then s.freezes += 1 end
	local lb = getDailyLookbook()
	if lb then lb.AddProgress(designer, "Freezes", 1) end
end

-- Universal freeze reward (works for both teams)
function RewardTracker.OnFreezePlayer(attacker)
	local attackerTeam = attacker.Team and attacker.Team.Name
	if attackerTeam == "Designers" then
		RewardTracker.OnFreezeCritic(attacker)
	elseif attackerTeam == "Critics" then
		RewardTracker.OnFreezeDesigner(attacker)
	end
end

function RewardTracker.OnSabotage(critic)
	local s = getScore(critic)
	if s then 
		s.sabotages += 1 
		s.totalPoints += Config.POINTS.SABOTAGE
	end
	giveReward(critic, "SabotageStation")

	local lb = getDailyLookbook()
	if lb then lb.AddProgress(critic, "Sabotages", 1) end
end

function RewardTracker.OnPlayerFrozen(designer)
	local s = getScore(designer)
	if s then s.neverFrozen = false end
end

function RewardTracker.OnApplyPressure(critic)
	giveReward(critic, "ApplyPressure")
end

-- PHASE 7: Universal objective completion reward
function RewardTracker.OnObjectiveComplete(player)
	giveReward(player, "ObjectiveComplete")
end

function RewardTracker.GetScore(player)
	return getScore(player)
end

-- // THE "TOP 3" ENGINE // --
function RewardTracker.GetTopPerformers(count)
	local list = {}
	for _, data in pairs(roundScores) do
		if data.Player and data.Player.Parent then
			table.insert(list, data)
		end
	end

	table.sort(list, function(a, b)
		if a.dunks ~= b.dunks then
			return a.dunks > b.dunks
		end
		return a.totalPoints > b.totalPoints
	end)

	local results = {}
	for i = 1, math.min(count, #list) do
		table.insert(results, {
			Player = list[i].Player,
			Score = list[i].dunks,
			Points = list[i].totalPoints
		})
	end

	return results
end

-- ── Passive Survival Rewards ──────────────────────────────────────────────────
task.spawn(function()
	while true do
		task.wait(60)
		if not roundActive then continue end
		for _, p in ipairs(Players:GetPlayers()) do
			if p.Team and (p.Team.Name == Config.TEAMS.DESIGNER or p.Team.Name == Config.TEAMS.CRITIC) then
				giveReward(p, "SurvivalPerMinute")
				local lb = getDailyLookbook()
				if lb then lb.AddProgress(p, "SurvivalMins", 1) end
			end
		end
	end
end)

-- ── Pressure Detection ──
-- PHASE 5: Symmetric pressure detection for BOTH teams
local designerPressureTimers = {}
local criticPressureTimers = {}

task.spawn(function()
	while true do
		task.wait(1)
		if not roundActive then 
			pressureTimers = {} 
			designerPressureTimers = {}
			criticPressureTimers = {}
			continue 
		end

		-- ── CRITICS PRESSURING DESIGNERS (Original Logic) ──
		for _, critic in ipairs(Players:GetPlayers()) do
			if not (critic.Team and critic.Team.Name == Config.TEAMS.CRITIC) then continue end
			local cr = critic.Character and critic.Character:FindFirstChild("HumanoidRootPart")
			if not cr then continue end

			local closeDesigner, closestDist = nil, math.huge
			for _, designer in ipairs(Players:GetPlayers()) do
				if not (designer.Team and designer.Team.Name == Config.TEAMS.DESIGNER) then continue end
				local dr = designer.Character and designer.Character:FindFirstChild("HumanoidRootPart")
				if not dr then continue end
				local dist = (cr.Position - dr.Position).Magnitude
				if dist < Config.PRESSURE.DETECTION_RANGE and dist < closestDist then
					closestDist   = dist
					closeDesigner = designer
				end
			end

			if closeDesigner then
				local entry = pressureTimers[critic.UserId]
				if entry and entry.targetUserId == closeDesigner.UserId then
					if os.clock() - entry.startTime >= Config.PRESSURE.TIME_THRESHOLD then
						RewardTracker.OnApplyPressure(critic)
						pressureTimers[critic.UserId] = nil
					end
				else
					pressureTimers[critic.UserId] = {startTime = os.clock(), targetUserId = closeDesigner.UserId}
				end
			else
				pressureTimers[critic.UserId] = nil
			end
		end

		-- ── DESIGNERS PRESSURING CRITICS (NEW: Symmetric Logic) ──
		for _, designer in ipairs(Players:GetPlayers()) do
			if not (designer.Team and designer.Team.Name == Config.TEAMS.DESIGNER) then continue end
			local dr = designer.Character and designer.Character:FindFirstChild("HumanoidRootPart")
			if not dr then continue end

			local closeCritic, closestDist = nil, math.huge
			for _, critic in ipairs(Players:GetPlayers()) do
				if not (critic.Team and critic.Team.Name == Config.TEAMS.CRITIC) then continue end
				local cr = critic.Character and critic.Character:FindFirstChild("HumanoidRootPart")
				if not cr then continue end
				local dist = (dr.Position - cr.Position).Magnitude
				if dist < Config.PRESSURE.DETECTION_RANGE and dist < closestDist then
					closestDist = dist
					closeCritic = critic
				end
			end

			if closeCritic then
				local entry = designerPressureTimers[designer.UserId]
				if entry and entry.targetUserId == closeCritic.UserId then
					if os.clock() - entry.startTime >= Config.PRESSURE.TIME_THRESHOLD then
						-- Designers also get pressure rewards for pressuring Critics
						RewardTracker.OnApplyPressure(designer)
						designerPressureTimers[designer.UserId] = nil
					end
				else
					designerPressureTimers[designer.UserId] = {startTime = os.clock(), targetUserId = closeCritic.UserId}
				end
			else
				designerPressureTimers[designer.UserId] = nil
			end
		end
	end
end)

-- ── MVP calculation ──
local function calculateMVP()
	local designerMVP, criticMVP
	local bestDesignerScore, bestCriticScore = -1, -1

	for _, p in ipairs(Players:GetPlayers()) do
		local s = getScore(p)
		if not s then continue end

		if p.Team and p.Team.Name == Config.TEAMS.DESIGNER then
			-- Designers: Dunks + Fabric Collected + Unfreezes + Never Frozen Bonus
			local score = (s.dunks * Config.MVP_WEIGHTS.DUNK_MULTIPLIER) 
				+ (s.fabricCount * Config.MVP_WEIGHTS.FABRIC_MULTIPLIER) 
				+ (s.unfreezes * Config.MVP_WEIGHTS.UNFREEZE_MULTIPLIER) 
				+ (s.neverFrozen and Config.MVP_WEIGHTS.NEVER_FROZEN_BONUS or 0)
			if score > bestDesignerScore then bestDesignerScore = score designerMVP = p end
		elseif p.Team and p.Team.Name == Config.TEAMS.CRITIC then
			-- Critics: Shreds (dunks) + Freezes + Sabotages
			local score = (s.dunks * Config.MVP_WEIGHTS.DUNK_MULTIPLIER) 
				+ (s.freezes * Config.MVP_WEIGHTS.FREEZE_MULTIPLIER) 
				+ (s.sabotages * Config.MVP_WEIGHTS.SABOTAGE_MULTIPLIER)
			if score > bestCriticScore then bestCriticScore = score criticMVP = p end
		end
	end

	return designerMVP, criticMVP
end

-- ── Round Lifecycle ──────────────────────────────────────────────────────────
RoundEvents.RoundStarted.Event:Connect(function()
	roundActive    = true
	pressureTimers = {}
	for _, p in ipairs(Players:GetPlayers()) do initScore(p) end
	print("[REWARDS] Round started. Stats initialized.")
end)

RoundEvents.RoundEnded.Event:Connect(function(winningTeamName)
	if not roundActive then return end
	roundActive = false

	for _, p in ipairs(Players:GetPlayers()) do
		if p.Team then
			local score = getScore(p)
			if p.Team.Name == winningTeamName then
				if score then score.totalPoints += Config.POINTS.CLEAN_RUNWAY end

				if winningTeamName == Config.TEAMS.DESIGNER then
					giveReward(p, "DesignerWin")
				else
					giveReward(p, "CriticWin")
				end
			end
		end
	end

	task.wait(0.5)

	local designerMVP, criticMVP = calculateMVP()
	local mvpPlayer = (winningTeamName == Config.TEAMS.DESIGNER) and designerMVP or criticMVP
	local mvpTitle  = (winningTeamName == Config.TEAMS.DESIGNER) and "The Lead Designer" or "The Lead Editor"
	local mvpKey    = (winningTeamName == Config.TEAMS.DESIGNER) and "DesignerMVP" or "CriticMVP"

	if mvpPlayer then
		giveReward(mvpPlayer, mvpKey)

		local allStats = {}
		for _, p in ipairs(Players:GetPlayers()) do
			local s = getScore(p)
			if s then
				table.insert(allStats, {
					Name   = p.Name,
					UserId = p.UserId,
					XP     = s.xpEarned,
					Coins  = s.coinsEarned,
				})
			end
		end

		ShowMVP:FireAllClients(mvpPlayer.Name, mvpPlayer.UserId, mvpTitle)

		task.delay(10, function()
			for _, p in ipairs(Players:GetPlayers()) do
				local myScore = getScore(p)
				local data    = DataManager.GetData(p)

				ShowEndStats:FireClient(p, allStats,
					myScore and myScore.xpEarned   or 0,
					myScore and myScore.coinsEarned or 0)

				if data and PostMatchXP then
					PostMatchXP:FireClient(p, data.Level, data.XP, myScore and myScore.xpEarned or 0)
				end
			end
		end)
	end
end)

RoundEvents.Intermission.Event:Connect(function()
	roundScores    = {}
	pressureTimers = {}
	designerPressureTimers = {}
	criticPressureTimers = {}
	print("[REWARDS] Stats cleared for Intermission.")
end)

Players.PlayerAdded:Connect(function(p)
	if roundActive then initScore(p) end
end)

Players.PlayerRemoving:Connect(function(p)
	roundScores[p.UserId]    = nil
	pressureTimers[p.UserId] = nil
	designerPressureTimers[p.UserId] = nil
	criticPressureTimers[p.UserId] = nil
end)

ServiceRegistry.Register("RewardTracker", RewardTracker)
return RewardTracker