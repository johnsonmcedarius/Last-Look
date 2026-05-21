local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService      = game:GetService("TweenService")

local player = Players.LocalPlayer
local Config = require(ReplicatedStorage:WaitForChild("SharedConfig"))

local Remotes      = ReplicatedStorage:WaitForChild("Remotes")
local PostMatchXP  = Remotes:WaitForChild("PostMatchXP")

local screenGui = player.PlayerGui:WaitForChild("MatchFlow", 5)
if not screenGui then
	-- Fallback to GameHUD for backwards compatibility
	screenGui = player.PlayerGui:WaitForChild("GameHUD", 5)
end

local function getFrame(name)
    return screenGui and screenGui:FindFirstChild(name, true)
end

-- XP math (matches DataManager)
local function GetRequiredXP(level)
    return math.floor(Config.BASE_XP * (level ^ Config.XP_MULTIPLIER))
end

-------------------------------------------------
-- XP Progress Bar Animation
-- Expected in GameHUD:
--   EndStatsFrame > XPBarBg (Frame) > XPBarFill (Frame, scales X)
--   EndStatsFrame > XPLabel (TextLabel, shows "Level X")
--   EndStatsFrame > LevelUpBanner (Frame, hidden normally)
-------------------------------------------------
local function animateXPBar(currentLevel, currentXP, xpEarned)
    local xpFill     = getFrame("XPBarFill")
    local xpLabel    = getFrame("XPLabel")
    local levelUpBanner = getFrame("LevelUpBanner")

    if not xpFill then return end

    local required   = GetRequiredXP(currentLevel)
    local startPct   = math.clamp(currentXP / required, 0, 1)
    local endXP      = currentXP + xpEarned
    local newLevel   = currentLevel
    local didLevelUp = false

    -- Simulate level-up(s)
    while endXP >= GetRequiredXP(newLevel) do
        endXP    -= GetRequiredXP(newLevel)
        newLevel += 1
        didLevelUp = true
    end

    local endPct = math.clamp(endXP / GetRequiredXP(newLevel), 0, 1)

    if xpLabel then xpLabel.Text = "Level " .. currentLevel end

    -- Start bar at current XP
    xpFill.Size = UDim2.new(startPct, 0, 1, 0)

    task.wait(0.5)

    if didLevelUp then
        -- Fill to 100%, flash, then reset and fill to new position
        TweenService:Create(xpFill, TweenInfo.new(0.8, Enum.EasingStyle.Quad), {
            Size = UDim2.new(1, 0, 1, 0)
        }):Play()
        task.wait(0.9)

        -- Flash gold on level up
        TweenService:Create(xpFill, TweenInfo.new(0.15), {
            BackgroundColor3 = Color3.fromRGB(255, 220, 0)
        }):Play()

        if levelUpBanner then
            levelUpBanner.Visible = true
            local lvlLabel = levelUpBanner:FindFirstChildOfClass("TextLabel")
            if lvlLabel then lvlLabel.Text = "LEVEL UP! " .. newLevel end
            task.delay(2, function() levelUpBanner.Visible = false end)
        end

        task.wait(0.3)

        -- Reset bar and fill to new position
        xpFill.Size = UDim2.new(0, 0, 1, 0)
        if xpLabel then xpLabel.Text = "Level " .. newLevel end
    end

    -- Animate to final position
    TweenService:Create(xpFill, TweenInfo.new(1.2, Enum.EasingStyle.Quad), {
        Size = UDim2.new(endPct, 0, 1, 0)
    }):Play()
end

-------------------------------------------------
-- PostMatchXP: server sends current level/xp + xp earned this round
-------------------------------------------------
-- XP BAR ANIMATION is owned by MatchFlowController (PostGameSummary sequence).
-- XPBarController only updates the in-match level label if it exists.
-- Both scripts listen to PostMatchXP but only MatchFlowController tweens the bar.
PostMatchXP.OnClientEvent:Connect(function(currentLevel, currentXP, xpEarned)
	-- Update any persistent level label (e.g. lobby XP display if added later)
	local xpLabel = getFrame("XPLabel")
	if xpLabel then
		xpLabel.Text = "Level " .. currentLevel
	end
	-- NOTE: Full bar animation is handled by MatchFlowController.showPostGameSummary()
	-- Do NOT call animateXPBar() here — it would double-fire on the same XPBarFill.
end)

print("[CLIENT] XPBarController ready." .. Config.XP_MULTIPLIER)
