local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService      = game:GetService("TweenService")

local player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local UpdateDualScore = Remotes:WaitForChild("UpdateDualScore")

-- Wait for GameplayHUD ScreenGui
local screenGui = player.PlayerGui:WaitForChild("GameplayHUD", 5)

-- ── State ──
local lastDesignerScore = 0
local lastCriticScore = 0
local isClutchFlashActive = false

-- ── Helper to find UI elements ──
local function getFrame(name)
	return screenGui:FindFirstChild(name, true)
end

-- ── Clutch Flash Effect (when score reaches target-1) ──
-- Uses physical UI in StarterGui.GameplayHUD.ClutchFlash
local function playClutchFlash(teamName)
	if isClutchFlashActive then return end
	isClutchFlashActive = true

	local flashFrame = getFrame("ClutchFlash")
	if not flashFrame then
		warn("[SCOREUI] ClutchFlash not found in GameplayHUD!")
		isClutchFlashActive = false
		return
	end

	-- Set color based on team
	flashFrame.BackgroundColor3 = teamName == "Designers" and Color3.fromRGB(100, 200, 255) or Color3.fromRGB(255, 100, 150)

	-- Flash animation
	flashFrame.Visible = true
	TweenService:Create(flashFrame, TweenInfo.new(0.15), {BackgroundTransparency = 0.7}):Play()
	task.wait(0.15)
	TweenService:Create(flashFrame, TweenInfo.new(0.3), {BackgroundTransparency = 1}):Play()
	task.wait(0.3)
	flashFrame.Visible = false

	isClutchFlashActive = false
end

-- ── Score Update Handler ──
UpdateDualScore.OnClientEvent:Connect(function(designerScore, criticScore, target)
	-- Update numerical displays
	local designerLabel = getFrame("DesignerScore")
	local criticLabel = getFrame("CriticScore")
	local targetLabel = getFrame("TargetScoreLabel")
	local vsLabel = getFrame("VSSeparator")

	-- Update Designer score
	if designerLabel then
		designerLabel.Text = tostring(designerScore)
		-- Flash on score increase
		if designerScore > lastDesignerScore then
			TweenService:Create(designerLabel, TweenInfo.new(0.1), {TextColor3 = Color3.fromRGB(100, 200, 255)}):Play()
			task.delay(0.2, function()
				TweenService:Create(designerLabel, TweenInfo.new(0.2), {TextColor3 = Color3.fromRGB(255, 255, 255)}):Play()
			end)
		end
	end

	-- Update Critic score
	if criticLabel then
		criticLabel.Text = tostring(criticScore)
		-- Flash on score increase
		if criticScore > lastCriticScore then
			TweenService:Create(criticLabel, TweenInfo.new(0.1), {TextColor3 = Color3.fromRGB(255, 100, 150)}):Play()
			task.delay(0.2, function()
				TweenService:Create(criticLabel, TweenInfo.new(0.2), {TextColor3 = Color3.fromRGB(255, 255, 255)}):Play()
			end)
		end
	end

	-- Update target display
	if targetLabel then
		targetLabel.Text = "/ " .. tostring(target)
	end

	-- Clutch indicator when close to winning
	if designerScore >= target - 1 or criticScore >= target - 1 then
		if designerScore >= target - 1 then
			playClutchFlash("Designers")
		else
			playClutchFlash("Critics")
		end
	end

	-- Store last scores
	lastDesignerScore = designerScore
	lastCriticScore = criticScore
end)

print("[SCOREUI] ScoreUIController initialized - numerical display ready")