local Players             = game:GetService("Players")
local ReplicatedStorage   = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local ServiceRegistry = require(ServerScriptService:WaitForChild("ServiceRegistry"))
local DataManager     = ServiceRegistry.Await("DataManager")
local GachaService    = ServiceRegistry.Await("GachaService")

local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local function getRemote(name)
	local r = Remotes:FindFirstChild(name)
	if not r then r = Instance.new("RemoteEvent") r.Name = name r.Parent = Remotes end
	return r
end

local GetDailyChallenges   = getRemote("GetDailyChallenges")
local DailyChallengeUpdate = getRemote("DailyChallengeUpdate")

-- ── Constants ──
local DAY_SECONDS = 86400

local function getMidnight(timestamp)
	local date = os.date("!*t", timestamp)
	return os.time({year=date.year, month=date.month, day=date.day, hour=0, min=0, sec=0})
end

-- ── Simplified MVP challenge pool ────────────────────────────────────────────
-- All stats are generic and tracked by existing round/XP systems.
-- DO NOT add hyper-specific hooks (sabotages, stuns, etc.) until post-launch.
local ChallengeTemplates = {
	{Id = "play_3",       Desc = "Play 3 matches",        Goal = 3,   Stat = "MatchesPlayed"},
	{Id = "play_5",       Desc = "Play 5 matches",        Goal = 5,   Stat = "MatchesPlayed"},
	{Id = "earn_250xp",   Desc = "Earn 250 XP",           Goal = 250, Stat = "XPEarned"},
	{Id = "earn_500xp",   Desc = "Earn 500 XP",           Goal = 500, Stat = "XPEarned"},
	{Id = "earn_1000xp",  Desc = "Earn 1,000 XP",         Goal = 1000,Stat = "XPEarned"},
	{Id = "survive_5min", Desc = "Survive 5 minutes total",Goal = 5,  Stat = "SurvivalMins"},
	{Id = "survive_10min",Desc = "Survive 10 minutes total",Goal = 10, Stat = "SurvivalMins"},
	{Id = "pass_3",       Desc = "Pass the fabric 3 times",Goal = 3,  Stat = "Passes"},
	{Id = "pass_5",       Desc = "Pass the fabric 5 times",Goal = 5,  Stat = "Passes"},
}

local dailyData = {}  -- [userId] = runtime cache

local function getOrCreateDaily(player)
	if dailyData[player.UserId] then return dailyData[player.UserId] end

	local profileData = DataManager.GetData(player)
	local saved       = profileData and profileData.DailyLookbook
	local now         = os.time()
	
	local lastResetMidnight = saved and getMidnight(saved.lastReset or 0) or 0
	local todayMidnight = getMidnight(now)
	
	local needsReset  = not saved or todayMidnight > lastResetMidnight

	if needsReset then
		-- Shuffle and pick 3
		local shuffled = {}
		for _, t in ipairs(ChallengeTemplates) do table.insert(shuffled, t) end
		for i = #shuffled, 2, -1 do
			local j = math.random(i)
			shuffled[i], shuffled[j] = shuffled[j], shuffled[i]
		end

		local chosen = {}
		for i = 1, 3 do table.insert(chosen, shuffled[i]) end

		local fresh = {
			challenges = chosen,
			progress   = {0, 0, 0},
			lastReset  = now,
			completed  = false,
			rewarded   = false,
		}

		dailyData[player.UserId] = fresh

		if profileData then
			profileData.DailyLookbook = {
				challenges = chosen,
				progress   = {0, 0, 0},
				lastReset  = now,
				completed  = false,
				rewarded   = false,
			}
		end

		print("[DAILY] New challenges generated for " .. player.Name)
	else
		dailyData[player.UserId] = {
			challenges = saved.challenges,
			progress   = saved.progress or {0, 0, 0},
			lastReset  = saved.lastReset,
			completed  = saved.completed or false,
			rewarded   = saved.rewarded or false,
		}
	end

	return dailyData[player.UserId]
end

local function syncToClient(player)
	local data = dailyData[player.UserId]
	if not data then return end
	DailyChallengeUpdate:FireClient(player, data.challenges, data.progress, data.completed)
end

local function checkCompletion(player)
	local data = dailyData[player.UserId]
	if not data or data.rewarded then return end

	for i, challenge in ipairs(data.challenges) do
		if (data.progress[i] or 0) < challenge.Goal then return end
	end

	data.completed = true
	data.rewarded  = true

	local profileData = DataManager.GetData(player)

	if math.random(2) == 1 then
		DataManager.AddCoins(player, 100)
		print("[DAILY] " .. player.Name .. " completed Daily Lookbook! Rewarded 100 Coins.")
	else
		GachaService.AddCrate(player, "CoinDesignerCrate", 1)
		print("[DAILY] " .. player.Name .. " completed Daily Lookbook! Rewarded a CoinDesignerCrate.")
	end

	if profileData and profileData.DailyLookbook then
		profileData.DailyLookbook.completed = true
		profileData.DailyLookbook.rewarded  = true
	end

	syncToClient(player)
end

-- ── Public API ────────────────────────────────────────────────────────────────
local DailyLookbook = {
	AddProgress = function(player, stat, amount)
		local data = dailyData[player.UserId]
		if not data or data.completed then return end

		local changed = false
		for i, challenge in ipairs(data.challenges) do
			if challenge.Stat == stat then
				data.progress[i] = math.min(
					(data.progress[i] or 0) + (amount or 1),
					challenge.Goal
				)
				changed = true
			end
		end

		if changed then
			local profileData = DataManager.GetData(player)
			if profileData and profileData.DailyLookbook then
				profileData.DailyLookbook.progress = data.progress
			end
			syncToClient(player)
			checkCompletion(player)
		end
	end,
}

GetDailyChallenges.OnServerEvent:Connect(function(player)
	getOrCreateDaily(player)
	syncToClient(player)
end)

-- PHASE 2 FIX: Listen to DataManager instead of PlayerAdded to avoid race conditions
DataManager.OnDataLoaded(function(player)
	getOrCreateDaily(player)
	syncToClient(player)
end)

Players.PlayerRemoving:Connect(function(player)
	dailyData[player.UserId] = nil
end)

ServiceRegistry.Register("DailyLookbook", DailyLookbook)
return DailyLookbook
