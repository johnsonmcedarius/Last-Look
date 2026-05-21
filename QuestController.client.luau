-- ─────────────────────────────────────────────────────────────────────────────
-- QuestController: Handles daily challenge display and progress
-- ─────────────────────────────────────────────────────────────────────────────

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local PlayerGui = player:WaitForChild("PlayerGui")
local QuestMenu = PlayerGui:WaitForChild("QuestMenu")
local MainFrame = QuestMenu:WaitForChild("MainFrame")
local Scroll = MainFrame:WaitForChild("QuestList")
local Template = Scroll:WaitForChild("QuestTemplate")

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local GetDailyChallenges = Remotes:WaitForChild("GetDailyChallenges")
local DailyChallengeUpdate = Remotes:WaitForChild("DailyChallengeUpdate")

-- ── Core Logic ──
local function updateQuestList(challenges, progress, completed)
	-- Clear old quests (keep template + layout)
	for _, child in ipairs(Scroll:GetChildren()) do
		if child:IsA("Frame") and child.Name ~= "QuestTemplate" then
			child:Destroy()
		end
	end
	
	if not challenges then return end
	
	for i, data in ipairs(challenges) do
		local row = Template:Clone()
		row.Name = data.Id or tostring(i)
		row.QuestTitle.Text = data.Desc or "Unknown Quest"
		
		-- Use 100 as placeholder reward if not specified in template
		row.RewardLabel.Text = "Reward: 100 Coins"
		
		local currentProgress = progress and progress[i] or 0
		local target = data.Goal or 1
		local alpha = math.clamp(currentProgress / target, 0, 1)
		
		row.ProgressBg.ProgressBar.Size = UDim2.new(alpha, 0, 1, 0)
		
		-- Polish: If completed, change color
		if currentProgress >= target then
			row.ProgressBg.ProgressBar.BackgroundColor3 = Color3.fromRGB(100, 255, 100)
		end
		
		row.Visible = true
		row.Parent = Scroll
	end
end

-- ── Listeners ──
DailyChallengeUpdate.OnClientEvent:Connect(function(challenges, progress, completed)
	updateQuestList(challenges, progress, completed)
end)

-- Request initial data
task.spawn(function()
	-- In the current server script, GetDailyChallenges triggers a sync via DailyChallengeUpdate
	GetDailyChallenges:FireServer()
end)

print("[QUESTS] QuestController initialized")
