-- ─────────────────────────────────────────────────────────────────────────────
-- UnboxingController: Cinematic unboxing sequence
-- The Hype -> The Reveal -> The Pop -> The Reward
-- REFACTORED: References physical UI in StarterGui.UnboxingGui
-- ─────────────────────────────────────────────────────────────────────────────

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local PlayerGui = player:WaitForChild("PlayerGui")

local SoundService = require(ReplicatedStorage:WaitForChild("SoundService"))
local UIConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("UIConfig"))

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local TriggerUnboxing = Remotes:WaitForChild("TriggerUnboxing")
local CrateResult = Remotes:WaitForChild("CrateResult")

-- ── Reference Physical UI from StarterGui ──
local screenGui = PlayerGui:WaitForChild("UnboxingCinematic", 5)
if not screenGui then
	warn("[UNBOXING] UnboxingCinematic not found! Falling back to UnboxingGui")
	screenGui = PlayerGui:WaitForChild("UnboxingGui", 5)
end

local mainContainer = screenGui:FindFirstChild("MainContainer") or screenGui
local viewport = mainContainer:FindFirstChild("CrateViewport") or screenGui:FindFirstChild("CrateViewport")
local camera = viewport and viewport:FindFirstChild("ViewportCamera")
local worldModel = viewport and viewport:FindFirstChild("WorldModel")
local crateContainer = worldModel and worldModel:FindFirstChild("CrateContainer")
local rewardFrame = mainContainer:FindFirstChild("RewardContainer") or mainContainer:FindFirstChild("RewardFrame")
local rewardName = rewardFrame and rewardFrame:FindFirstChild("RewardName")
local rewardRarity = rewardFrame and rewardFrame:FindFirstChild("RewardRarity")
local skipButton = mainContainer:FindFirstChild("SkipButton")
local flashFrame = mainContainer:FindFirstChild("FlashOverlay") or mainContainer:FindFirstChild("FlashFrame")
local overlay = mainContainer:FindFirstChild("Overlay")
local starLatch = screenGui:FindFirstChild("StarLatch")
local spinningBackground = rewardFrame and rewardFrame:FindFirstChild("SpinningBackground")

-- ── Rarity Colors — read from RevealBillboard template attributes ────────────
-- Designers can tweak these in Studio without touching script.
-- Falls back to white if attribute missing.
local _rarityTemplate = nil
local function getRarityColor(rarityName)
	if not _rarityTemplate then
		local assets = ReplicatedStorage:FindFirstChild("Assets")
		_rarityTemplate = assets and assets:FindFirstChild("RevealBillboard")
	end
	if _rarityTemplate then
		local col = _rarityTemplate:GetAttribute("Color_" .. (rarityName or "Common"))
		if col then return col end
	end
	-- Fallback table if template not loaded
	local fallback = {
		Common=Color3.fromRGB(180,180,180), Rare=Color3.fromRGB(100,200,255),
		Legendary=Color3.fromRGB(255,200,50),
		Mythic=Color3.fromRGB(255,50,150),
	}
	return fallback[rarityName] or Color3.new(1,1,1)
end

-- ── Crate Models (from Workspace) ──
local function getCrateModel(crateType)
	local crate = workspace:FindFirstChild(crateType == "RobuxCrate" and "RobuxCrate" or "GachaCratePodium")
	if crate then
		return crate:Clone()
	end
	-- Fallback: create a simple box
	local fallback = Instance.new("Part")
	fallback.Size = Vector3.new(2, 2, 2)
	fallback.Color = crateType == "RobuxCrate" and Color3.fromRGB(255, 200, 50) or Color3.fromRGB(100, 200, 255)
	return fallback
end

-- ── Animation State ──
local isPlaying = false
local skipRequested = false

-- ── THE HYPE: Shake animation (1.5s) ──
local function playHypeAnimation(crate)
	local startTime = os.clock()
	local duration = skipRequested and 0 or 1.5
	
	while os.clock() - startTime < duration do
		if skipRequested then break end
		
		local elapsed = os.clock() - startTime
		local intensity = math.min(1, elapsed / duration) * 0.15  -- Ramps up
		
		-- Shake effect
		crate.CFrame = crate.CFrame * CFrame.Angles(
			math.sin(elapsed * 30) * intensity,
			math.sin(elapsed * 25) * intensity,
			math.sin(elapsed * 20) * intensity
		)
		
		task.wait(0.03)
	end
end

-- ── THE REVEAL: Star latch spin and glow (0.8s) ──
local function playRevealAnimation(crate)
	local startTime = os.clock()
	local duration = skipRequested and 0 or 0.8
	
	if starLatch then
		starLatch.Visible = true
		starLatch.Rotation = 0
	end
	
	while os.clock() - startTime < duration do
		if skipRequested then break end
		
		local elapsed = os.clock() - startTime
		local spinProgress = elapsed / duration
		
		-- 360 degree spin for crate
		crate.CFrame = crate.CFrame * CFrame.Angles(0, math.rad(spinProgress * 360), 0)
		
		-- 360 degree spin for UI star latch
		if starLatch then
			starLatch.Rotation = spinProgress * 360
		end
		
		-- Glow effect (increase light intensity)
		local light = camera:FindFirstChild("CrateLight")
		if light then
			light.Brightness = 2 + spinProgress * 3
		end
		
		task.wait(0.03)
	end
	
	if starLatch then starLatch.Visible = false end
end

-- ── THE POP: Lid opens (0.5s) ──
local function playPopAnimation(crate)
	local startTime = os.clock()
	local duration = skipRequested and 0 or 0.5
	
	-- Find lid part
	local lid = crate:FindFirstChild("Lid") or crate:FindFirstChildWhichIsA("BasePart")
	if lid then
		local startCFrame = lid.CFrame
		
		while os.clock() - startTime < duration do
			if skipRequested then break end
			
			local elapsed = os.clock() - startTime
			local openProgress = elapsed / duration
			
			-- Pivot lid open (rotate on X axis)
			lid.CFrame = startCFrame * CFrame.Angles(math.rad(-90 * openProgress), 0, 0)
			
			task.wait(0.03)
		end
	end
	
	-- Play pop sound
	SoundService.PlayLocal("FabricDunk")
end

-- ── THE REWARD: Show item with flash (2s) ──
local function playRewardAnimation(itemName, rarity)
	-- White flash using existing FlashFrame with UIGradient wipe
	if flashFrame then
		local gradient = flashFrame:FindFirstChild("UIGradient")
		if gradient then
			-- Reset gradient for wipe
			gradient.Offset = Vector2.new(-1, 0)
			flashFrame.BackgroundTransparency = 0
			flashFrame.Visible = true
			
			TweenService:Create(gradient, TweenInfo.new(0.5), {Offset = Vector2.new(1, 0)}):Play()
			task.delay(0.5, function()
				TweenService:Create(flashFrame, TweenInfo.new(0.3), {BackgroundTransparency = 1}):Play()
				task.delay(0.3, function() flashFrame.Visible = false end)
			end)
		else
			flashFrame.Visible = true
			flashFrame.BackgroundTransparency = 0
			TweenService:Create(flashFrame, TweenInfo.new(0.3), {BackgroundTransparency = 1}):Play()
			task.delay(0.3, function() flashFrame.Visible = false end)
		end
	end
	
	-- Show reward frame
	rewardName.Text = itemName
	rewardRarity.Text = rarity:upper()
	rewardRarity.TextColor3 = getRarityColor(rarity)
	
	rewardFrame.Visible = true
	rewardFrame.Size = UDim2.new(0, 0, 0, 0)
	rewardFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
	
	TweenService:Create(rewardFrame, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Size = UDim2.new(0.5, 0, 0.3, 0),
		Position = UDim2.new(0.25, 0, 0.35, 0)
	}):Play()
	
	-- Start spinning background rotation
	local spinning = true
	task.spawn(function()
		while spinning and rewardFrame.Visible do
			if spinningBackground then
				spinningBackground.Rotation = spinningBackground.Rotation + 2
			end
			task.wait()
		end
	end)
	
	-- Wait for display
	task.wait(2)
	spinning = false
end

-- ── Main Unboxing Sequence ──
local function playUnboxingSequence(crateType, result)
	if isPlaying then return end
	isPlaying = true
	skipRequested = false
	
	-- Show GUI
	screenGui.Enabled = true
	
	-- Setup camera
	camera.CFrame = CFrame.new(Vector3.new(0, 0, 10), Vector3.new(0, 0, 0))
	
	-- Get crate model
	local crate = getCrateModel(crateType)
	crate.Parent = crateContainer
	crate:PivotTo(CFrame.new(Vector3.new(0, 0, 0)))
	
	-- Show skip button after 0.5s
	task.delay(0.5, function()
		if isPlaying then
			skipButton.Visible = true
		end
	end)
	
	-- Play animations
	playHypeAnimation(crate)
	playRevealAnimation(crate)
	playPopAnimation(crate)
	playRewardAnimation(result.Name, result.Rarity)
	
	-- Cleanup
	crate:Destroy()
	screenGui.Enabled = false
	skipButton.Visible = false
	rewardFrame.Visible = false
	isPlaying = false
end

-- ── Skip Button Handler ──
skipButton.MouseButton1Click:Connect(function()
	skipRequested = true
	skipButton.Visible = false
end)

-- ── Listen for unboxing trigger + result ────────────────────────────────────
-- FIXED: RemoteEvent:Wait() hangs forever. Instead we queue the crateType
-- from TriggerUnboxing and consume it when CrateResult fires.
local pendingCrateType = nil

TriggerUnboxing.OnClientEvent:Connect(function(crateType)
	pendingCrateType = crateType
end)

CrateResult.OnClientEvent:Connect(function(result)
	if not pendingCrateType then
		warn("[UNBOXING] CrateResult fired but no pending crateType — ignoring")
		return
	end
	local crateType = pendingCrateType
	pendingCrateType = nil
	if result then
		playUnboxingSequence(crateType, result)
	end
end)

print("[UNBOXING] UnboxingController initialized")