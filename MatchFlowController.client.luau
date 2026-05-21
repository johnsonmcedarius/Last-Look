-- ─────────────────────────────────────────────────────────────────────────────
-- MatchFlowController: Handles PregameIntro and PostGameSummary
-- References physical UI in StarterGui.MatchFlow
-- ─────────────────────────────────────────────────────────────────────────────

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService      = game:GetService("TweenService")
local RunService        = game:GetService("RunService")

local player = Players.LocalPlayer
local PlayerGui = player:WaitForChild("PlayerGui")

-- ── Reference Physical UI ──
local screenGui = PlayerGui:WaitForChild("MatchFlow", 5)
if not screenGui then
	warn("[MATCHFLOW] MatchFlow ScreenGui not found!")
	return
end

local pregameIntro = screenGui:FindFirstChild("PregameIntro")
local postGameSummary = screenGui:FindFirstChild("PostGameSummary")

-- PregameIntro elements
local versusScreen = pregameIntro and pregameIntro:FindFirstChild("VersusScreen")
local teamSplitLabel = versusScreen and versusScreen:FindFirstChild("TeamSplitLabel")
local mapNameLabel = versusScreen and versusScreen:FindFirstChild("MapNameLabel")
local playerViewport = versusScreen and versusScreen:FindFirstChild("PlayerViewport")
local viewportCamera = playerViewport and playerViewport:FindFirstChild("ViewportCamera")
local worldModel = playerViewport and playerViewport:FindFirstChild("WorldModel")

-- PostGameSummary elements
local criticVictoryHeader = postGameSummary and postGameSummary:FindFirstChild("CriticVictoryWinHeader")
local designerVictoryHeader = postGameSummary and postGameSummary:FindFirstChild("DesignerVictoryWinHeader")
local earningsRollup = postGameSummary and postGameSummary:FindFirstChild("EarningsRollup")
local coinReward = earningsRollup and earningsRollup:FindFirstChild("CoinReward")
local coinAmount = coinReward and coinReward:FindFirstChild("CoinAmount")
local xpReward = earningsRollup and earningsRollup:FindFirstChild("XPReward")
local xpBarFill = xpReward and xpReward:FindFirstChild("XPBarBg") and xpReward.XPBarBg:FindFirstChild("XPBarFill")
local xpLabel = xpReward and xpReward:FindFirstChild("XPLabel")
local xpGained = xpReward and xpReward:FindFirstChild("XPGained")
local levelUpBanner = earningsRollup and earningsRollup:FindFirstChild("LevelUpBanner")

-- ── Remotes ──
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local MatchStart = Remotes:WaitForChild("MatchStart")
local MatchEnd = Remotes:WaitForChild("MatchEnd")
local PostMatchXP = Remotes:WaitForChild("PostMatchXP")

-- ── Config ──
local Config = require(ReplicatedStorage:WaitForChild("SharedConfig"))

-- ── State ──
local isShowingPregame = false
local isShowingPostgame = false

-- ── Helper: Get Required XP ──
local function getRequiredXP(level)
	return math.floor(Config.BASE_XP * (level ^ Config.XP_MULTIPLIER))
end

-- ── PregameIntro Animation ──
local function showPregameIntro(teamCounts, mapName)
	if isShowingPregame or not pregameIntro then return end
	isShowingPregame = true
	
	screenGui.Enabled = true
	pregameIntro.Visible = true
	
	-- Set team split (e.g., "5 VS 5")
	if teamSplitLabel then
		teamSplitLabel.Text = string.format("%d VS %d", teamCounts.Designers or 0, teamCounts.Critics or 0)
		teamSplitLabel.TextTransparency = 1
		
		-- Fade in
		TweenService:Create(teamSplitLabel, TweenInfo.new(0.5), {TextTransparency = 0}):Play()
	end
	
	-- Roll map name
	if mapNameLabel then
		mapNameLabel.Text = mapName or "UNKNOWN"
		mapNameLabel.TextTransparency = 1
		
		task.delay(0.3, function()
			TweenService:Create(mapNameLabel, TweenInfo.new(0.5), {TextTransparency = 0}):Play()
		end)
	end
	
	-- Animate player viewport (if available)
	if viewportCamera and worldModel then
		-- Setup camera position
		viewportCamera.CFrame = CFrame.new(Vector3.new(0, 0, 10), Vector3.new(0, 0, 0))
		
		-- TODO: Add player character models to WorldModel for animation
	end
	
	-- Auto-hide after duration
	task.delay(3, function()
		hidePregameIntro()
	end)
end

local function hidePregameIntro()
	if not isShowingPregame then return end
	
	-- Fade out
	if pregameIntro then
		local bg = pregameIntro:FindFirstChild("Background")
		if bg then
			TweenService:Create(bg, TweenInfo.new(0.5), {ImageTransparency = 1}):Play()
		end
		
		if teamSplitLabel then
			TweenService:Create(teamSplitLabel, TweenInfo.new(0.3), {TextTransparency = 1}):Play()
		end
		
		if mapNameLabel then
			TweenService:Create(mapNameLabel, TweenInfo.new(0.3), {TextTransparency = 1}):Play()
		end
	end
	
	task.delay(0.5, function()
		if pregameIntro then pregameIntro.Visible = false end
		screenGui.Enabled = false
		isShowingPregame = false
	end)
end

-- ── PostGameSummary Animation ──
local function showPostGameSummary(winningTeam, coinsEarned, currentLevel, currentXP, xpEarned)
	if isShowingPostgame or not postGameSummary then return end
	isShowingPostgame = true
	
	screenGui.Enabled = true
	postGameSummary.Visible = true
	
	-- Show appropriate victory header
	if winningTeam == "Critics" and criticVictoryHeader then
		criticVictoryHeader.Visible = true
		designerVictoryHeader.Visible = false
	elseif winningTeam == "Designers" and designerVictoryHeader then
		designerVictoryHeader.Visible = true
		criticVictoryHeader.Visible = false
	end
	
	-- Animate coin reward
	if coinAmount then
		coinAmount.Text = "+0"
		
		-- Count up animation
		local startCoins = 0
		local endCoins = coinsEarned or 0
		local duration = 1.5
		local startTime = os.clock()
		
		task.spawn(function()
			while os.clock() - startTime < duration do
				local progress = (os.clock() - startTime) / duration
				local currentCoins = math.floor(startCoins + (endCoins - startCoins) * progress)
				coinAmount.Text = string.format("+%d", currentCoins)
				task.wait(0.05)
			end
			coinAmount.Text = string.format("+%d", endCoins)
		end)
	end
	
	-- Animate XP bar
	if xpBarFill and xpLabel and xpGained then
		local required = getRequiredXP(currentLevel)
		local startPct = math.clamp(currentXP / required, 0, 1)
		local endXP = currentXP + xpEarned
		local newLevel = currentLevel
		local didLevelUp = false
		
		-- Simulate level-up(s)
		while endXP >= getRequiredXP(newLevel) do
			endXP = endXP - getRequiredXP(newLevel)
			newLevel = newLevel + 1
			didLevelUp = true
		end
		
		local endPct = math.clamp(endXP / getRequiredXP(newLevel), 0, 1)
		
		xpLabel.Text = "Level " .. currentLevel
		xpGained.Text = string.format("+%d XP", xpEarned)
		xpBarFill.Size = UDim2.new(startPct, 0, 1, 0)
		
		task.delay(0.5, function()
			if didLevelUp then
				-- Fill to 100%, flash, then reset
				TweenService:Create(xpBarFill, TweenInfo.new(0.8, Enum.EasingStyle.Quad), {
					Size = UDim2.new(1, 0, 1, 0)
				}):Play()
				task.wait(0.9)
				
				-- Show level up banner
				if levelUpBanner then
					levelUpBanner.Visible = true
					local lvlLabel = levelUpBanner:FindFirstChild("LevelLabel")
					if lvlLabel then lvlLabel.Text = "LEVEL UP! " .. newLevel end
					task.delay(2, function() levelUpBanner.Visible = false end)
				end
				
				-- Reset bar
				xpBarFill.Size = UDim2.new(0, 0, 1, 0)
				xpLabel.Text = "Level " .. newLevel
			end
			
			-- Animate to final position
			TweenService:Create(xpBarFill, TweenInfo.new(1.2, Enum.EasingStyle.Quad), {
				Size = UDim2.new(endPct, 0, 1, 0)
			}):Play()
		end)
	end
	
	-- Auto-hide after duration
	task.delay(5, function()
		hidePostGameSummary()
	end)
end

local function hidePostGameSummary()
	if not isShowingPostgame then return end
	
	if postGameSummary then
		local bg = postGameSummary:FindFirstChild("Background")
		if bg then
			TweenService:Create(bg, TweenInfo.new(0.5), {ImageTransparency = 1}):Play()
		end
	end
	
	task.delay(0.5, function()
		if postGameSummary then postGameSummary.Visible = false end
		if criticVictoryHeader then criticVictoryHeader.Visible = false end
		if designerVictoryHeader then designerVictoryHeader.Visible = false end
		screenGui.Enabled = false
		isShowingPostgame = false
	end)
end

-- ── Remote Listeners ──
if MatchStart then
	MatchStart.OnClientEvent:Connect(function(pregameData)
		-- Server sends a single table, need to destructure properly
		local teamCounts = pregameData and pregameData.TeamCounts or { Designers = 0, Critics = 0 }
		local mapName = pregameData and pregameData.MapName or "UNKNOWN"
		showPregameIntro(teamCounts, mapName)
	end)
end

if MatchEnd then
	MatchEnd.OnClientEvent:Connect(function(winningTeam, coinsEarned)
		-- XP data comes separately via PostMatchXP
		showPostGameSummary(winningTeam, coinsEarned, 1, 0, 0)
	end)
end

if PostMatchXP then
	PostMatchXP.OnClientEvent:Connect(function(currentLevel, currentXP, xpEarned)
		-- Update XP display if postgame is showing
		if isShowingPostgame and xpLabel and xpGained then
			xpLabel.Text = "Level " .. currentLevel
			xpGained.Text = string.format("+%d XP", xpEarned)
		end
	end)
end

print("[MATCHFLOW] MatchFlowController initialized")