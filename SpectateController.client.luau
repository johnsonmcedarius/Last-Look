-- SpectateController (LocalScript in StarterPlayerScripts)
-- Handles client-side spectator camera following and betting UI interaction.
-- UI elements expected in GameHUD ScreenGui:
--   SpectateFrame         - shown while spectating
--   SpectateLabel         - "Watching: PlayerName"
--   BetFrame              - betting panel
--   BetTargetList         - scrolling list of bet targets (you build the layout)
--   BetStatusLabel        - feedback text
--   CycleButton           - TextButton to switch spectate target

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local StartSpectate    = Remotes:WaitForChild("StartSpectate")
local StopSpectate     = Remotes:WaitForChild("StopSpectate")
local CycleSpectate    = Remotes:WaitForChild("CycleSpectate")
local PlaceBet         = Remotes:WaitForChild("PlaceBet")
local BetResult        = Remotes:WaitForChild("BetResult")
local UpdateBetTargets = Remotes:WaitForChild("UpdateBetTargets")

-- GUI refs
-- Resolved lazily so the ScreenGui is guaranteed to exist
local function getHUD()
	return player.PlayerGui:WaitForChild("GameplayHUD", 10)
end

local function getFrame(name)
	local hud = player.PlayerGui:FindFirstChild("GameplayHUD")
	return hud and hud:FindFirstChild(name, true)
end

local spectateFrame  = nil  -- set in StartSpectate handler
local spectateLabel  = nil
local betFrame       = nil
local betStatusLabel = nil
local cycleButton    = nil

-- Resolve after PlayerGui populates
task.defer(function()
	local hud = player.PlayerGui:WaitForChild("GameplayHUD", 10)
	if not hud then return end
	spectateFrame  = hud:FindFirstChild("SpectateFrame",  true)
	spectateLabel  = hud:FindFirstChild("SpectateLabel",  true)
	betFrame       = hud:FindFirstChild("BetFrame",       true)
	betStatusLabel = hud:FindFirstChild("BetStatusLabel", true)
	cycleButton    = hud:FindFirstChild("CycleButton",    true)
	-- Wire cycle button now that ref is resolved
	if cycleButton then
		cycleButton.Activated:Connect(function()
			if spectating then CycleSpectate:FireServer() end
		end)
	end
end)

-- State
local currentTarget = nil
local spectating = false
local camConnection

-------------------------------------------------
-- Spectate camera
-------------------------------------------------
local function startFollowCam(target)
	if camConnection then camConnection:Disconnect() end
	camera.CameraType = Enum.CameraType.Scriptable

	camConnection = RunService.RenderStepped:Connect(function()
		if not target or not target.Character then return end
		local root = target.Character:FindFirstChild("HumanoidRootPart")
		if not root then return end

		-- Smooth third-person follow
		local offset = Vector3.new(0, 6, 14)
		local targetCFrame = CFrame.new(root.Position + Vector3.new(0, 1, 0))
			* CFrame.Angles(math.rad(-10), 0, 0)
		camera.CFrame = camera.CFrame:Lerp(
			CFrame.new(root.Position + offset, root.Position + Vector3.new(0, 1, 0)),
			0.1
		)
	end)
end

local function stopFollowCam()
	if camConnection then
		camConnection:Disconnect()
		camConnection = nil
	end
	camera.CameraType = Enum.CameraType.Custom
end

-------------------------------------------------
-- Remote handlers
-------------------------------------------------
StartSpectate.OnClientEvent:Connect(function(target)
	currentTarget = target
	spectating = true

	if spectateFrame then spectateFrame.Visible = true end
	if spectateLabel then
		spectateLabel.Text = "Watching: " .. (target and target.Name or "?")
	end

	startFollowCam(target)
	print("[SPECTATE] Now watching: " .. (target and target.Name or "?"))
end)

StopSpectate.OnClientEvent:Connect(function()
	spectating = false
	currentTarget = nil
	stopFollowCam()

	if spectateFrame then spectateFrame.Visible = false end
	if betFrame then betFrame.Visible = false end
end)

-- Bet target list update
UpdateBetTargets.OnClientEvent:Connect(function(targets, bettingOpen, betCost)
	if not betFrame then return end
	betFrame.Visible = spectating and bettingOpen

	-- Clear and repopulate the target list
	local list = getFrame("BetTargetList")
	if not list then return end

	for _, child in ipairs(list:GetChildren()) do
		if child:IsA("TextButton") then child:Destroy() end
	end

	-- Clone physical template from GameplayHUD instead of Instance.new
	local template = list:FindFirstChild("BetTargetButton")

	for _, targetData in ipairs(targets) do
		local btn
		if template then
			btn = template:Clone()
			btn.Text        = targetData.Name
			local costLabel = btn:FindFirstChild("CostLabel")
			if costLabel then costLabel.Text = tostring(betCost) .. " 🪙" end
		else
			-- Template missing — log and skip this entry
			warn("[SpectateController] BetTargetButton template missing from BetTargetList!")
			continue
		end
		btn.Visible = true
		btn.LayoutOrder = _
		btn.Parent = list

		btn.Activated:Connect(function()
			PlaceBet:FireServer(targetData.UserId, betCost)
		end)
	end
end)

-- Bet feedback
BetResult.OnClientEvent:Connect(function(success, message)
	if betStatusLabel then
		betStatusLabel.Text = message
		betStatusLabel.TextColor3 = success
			and Color3.fromRGB(100, 255, 100)
			or Color3.fromRGB(255, 100, 100)
		betStatusLabel.Visible = true

		task.delay(3, function()
			betStatusLabel.Visible = false
		end)
	end
end)

-- CycleButton is wired in the task.defer resolver above
-- (Kept here as a safety wire in case defer hasn't run yet)
task.delay(1, function()
	if cycleButton then
		cycleButton.Activated:Connect(function()
			if spectating then CycleSpectate:FireServer() end
		end)
	end
end)
