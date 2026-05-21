-- ─────────────────────────────────────────────────────────────────────────────
-- HUDModule_MatchFlow
-- Manages PregameIntro and PostGameSummary inside MatchFlow ScreenGui.
-- Called by HUDController:  MatchFlowModule.Init(matchFlowGui, remotes, ss)
-- ─────────────────────────────────────────────────────────────────────────────

local HUDModule_MatchFlow = {}

local TweenService = game:GetService("TweenService")
local Players      = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PreGameModule = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("PreGameModule"))

local SHOW_INFO = TweenInfo.new(0.35, Enum.EasingStyle.Back,  Enum.EasingDirection.Out)
local HIDE_INFO = TweenInfo.new(0.22, Enum.EasingStyle.Quad,  Enum.EasingDirection.In)

-- R15 Idle Animation ID
local IDLE_ANIM_ID = "rbxassetid://507766388"

function HUDModule_MatchFlow.Init(screenGui, remotes, soundService)

	-- ── UI refs ───────────────────────────────────────────────────────────────
	local pregameIntro    = screenGui:FindFirstChild("PregameIntro")
	local postGameSummary = screenGui:FindFirstChild("PostGameSummary")

	-- ── State ─────────────────────────────────────────────────────────────────
	local isPregameActive  = false
	local isPostgameActive = false
	local coinCountThread  = nil

	-- Viewports
	local designerViewport = pregameIntro and pregameIntro:FindFirstChild("VersusScreen") and pregameIntro.VersusScreen:FindFirstChild("DesignerViewport")
	local criticViewport = pregameIntro and pregameIntro:FindFirstChild("VersusScreen") and pregameIntro.VersusScreen:FindFirstChild("CriticViewport")

	-- ── Internal helpers ──────────────────────────────────────────────────────
	local function getRequiredXP(level)
		local Config = require(ReplicatedStorage:WaitForChild("SharedConfig"))
		return math.floor(Config.BASE_XP * (level ^ Config.XP_MULTIPLIER))
	end

	local function playSound(key)
		if soundService and soundService.PlayLocal then
			soundService.PlayLocal(key, 0.85)
		end
	end

	-- ── Character Appearance Loading ────────────────────────────────────────────
	local function createCharacterModelFromUserId(userId)
		-- Create a new character model
		local character = Instance.new("Model")
		character.Name = "Player_" .. userId
		
		-- Create HumanoidRootPart
		local hrp = Instance.new("Part")
		hrp.Name = "HumanoidRootPart"
		hrp.Size = Vector3.new(2, 2, 1)
		hrp.Transparency = 1
		hrp.CanCollide = false
		hrp.Anchored = true
		hrp.Parent = character
		character.PrimaryPart = hrp
		
		-- Create Humanoid
		local humanoid = Instance.new("Humanoid")
		humanoid.Parent = character
		
		-- Create Head
		local head = Instance.new("Part")
		head.Name = "Head"
		head.Size = Vector3.new(2, 1, 1)
		head.CanCollide = false
		head.Anchored = true
		head.Parent = character
		
		-- Create Torso
		local torso = Instance.new("Part")
		torso.Name = "Torso"
		torso.Size = Vector3.new(2, 2, 1)
		torso.CanCollide = false
		torso.Anchored = true
		torso.Parent = character
		
		-- Create basic body parts
		local leftArm = Instance.new("Part")
		leftArm.Name = "Left Arm"
		leftArm.Size = Vector3.new(1, 2, 1)
		leftArm.CanCollide = false
		leftArm.Anchored = true
		leftArm.Parent = character
		
		local rightArm = Instance.new("Part")
		rightArm.Name = "Right Arm"
		rightArm.Size = Vector3.new(1, 2, 1)
		rightArm.CanCollide = false
		rightArm.Anchored = true
		rightArm.Parent = character
		
		local leftLeg = Instance.new("Part")
		leftLeg.Name = "Left Leg"
		leftLeg.Size = Vector3.new(1, 2, 1)
		leftLeg.CanCollide = false
		leftLeg.Anchored = true
		leftLeg.Parent = character
		
		local rightLeg = Instance.new("Part")
		rightLeg.Name = "Right Leg"
		rightLeg.Size = Vector3.new(1, 2, 1)
		rightLeg.CanCollide = false
		rightLeg.Anchored = true
		rightLeg.Parent = character
		
		-- Try to get player appearance (async, wrapped in pcall)
		local success, appearance = pcall(function()
			return Players:GetCharacterAppearanceInfoAsync(userId)
		end)
		
		if success and appearance then
			-- Apply skin color
			if appearance.bodyColors then
				local bc = appearance.bodyColors
				if bc.headColor3 then head.Color = bc.headColor3 end
				if bc.torsoColor3 then torso.Color = bc.torsoColor3 end
				if bc.leftArmColor3 then leftArm.Color = bc.leftArmColor3 end
				if bc.rightArmColor3 then rightArm.Color = bc.rightArmColor3 end
				if bc.leftLegColor3 then leftLeg.Color = bc.leftLegColor3 end
				if bc.rightLegColor3 then rightLeg.Color = bc.rightLegColor3 end
			end
			
			-- Apply face
			if appearance.face then
				local face = Instance.new("Decal")
				face.Name = "Face"
				face.Texture = appearance.face
				face.Face = Enum.NormalId.Front
				face.Parent = head
			end
			
			-- Apply t-shirt
			if appearance.tShirt then
				local tshirt = Instance.new("Decal")
				tshirt.Name = "tShirt"
				tshirt.Texture = appearance.tShirt
				tshirt.Face = Enum.NormalId.Front
				tshirt.Parent = torso
			end
			
			-- Apply shirt
			if appearance.shirt then
				local shirt = Instance.new("Shirt")
				shirt.ShirtTemplate = appearance.shirt
				shirt.Parent = character
			end
			
			-- Apply pants
			if appearance.pants then
				local pants = Instance.new("Pants")
				pants.PantsTemplate = appearance.pants
				pants.Parent = character
			end
		end
		
		return character
	end

	local function setupViewport(viewport, teamName, userIds)
		if not viewport then return end
		local worldModel = viewport:FindFirstChildOfClass("WorldModel")
		if not worldModel then return end
		
		worldModel:ClearAllChildren()
		
		-- Number of characters to show (based on player count, max 3)
		local numToShow = math.min(userIds and #userIds or 1, 3)
		if numToShow == 0 then numToShow = 1 end
		
		-- Spacing between characters
		local spacing = 3
		local startX = -((numToShow - 1) * spacing) / 2
		
		-- Create character models for each player
		for i = 1, numToShow do
			local userId = userIds and userIds[i]
			local character
			
			if userId then
				character = createCharacterModelFromUserId(userId)
			else
				-- Fallback: Create a basic dummy
				character = Instance.new("Model")
				local hrp = Instance.new("Part")
				hrp.Name = "HumanoidRootPart"
				hrp.Size = Vector3.new(2, 2, 1)
				hrp.Transparency = 1
				hrp.Anchored = true
				hrp.Parent = character
				character.PrimaryPart = hrp
				Instance.new("Humanoid", character)
				
				local head = Instance.new("Part")
				head.Name = "Head"
				head.Size = Vector3.new(2, 1, 1)
				head.Anchored = true
				head.Parent = character
			end
			
			character.Name = teamName .. "Player" .. i
			
			-- Position character in a row
			local xPos = startX + (i - 1) * spacing
			character:PivotTo(CFrame.new(xPos, 0, 0) * CFrame.Angles(0, math.pi, 0))
			character.Parent = worldModel
			
			-- Play idle animation
			local hum = character:FindFirstChildOfClass("Humanoid")
			if hum then
				local animator = hum:FindFirstChildOfClass("Animator") or Instance.new("Animator", hum)
				local anim = Instance.new("Animation")
				anim.AnimationId = IDLE_ANIM_ID
				
				local track = animator:LoadAnimation(anim)
				track.Looped = true
				track:Play()
			end
		end
		
		-- Camera setup
		local cam = viewport.CurrentCamera or Instance.new("Camera")
		cam.FieldOfView = 30
		-- Adjust camera distance based on number of characters
		local camDist = 8 + (numToShow - 1) * 1.5
		cam.CFrame = CFrame.new(Vector3.new(0, 2, camDist), Vector3.new(0, 1.5, 0))
		cam.Parent = viewport
		viewport.CurrentCamera = cam
	end

	-- tweenIn: scale from 0.96 → 1. Position NEVER changes.
	-- restSize / restPos passed in so caller controls the target — no drift possible.
	local function tweenIn(frame, restSize, restPos)
		-- Hard-reset position first — guarantees clean start even after a bad previous state
		frame.Position               = restPos
		frame.Size                   = UDim2.new(restSize.X.Scale * 0.96, restSize.X.Offset,
		                                          restSize.Y.Scale * 0.96, restSize.Y.Offset)
		frame.BackgroundTransparency = 0.6
		frame.Visible                = true
		TweenService:Create(frame, SHOW_INFO, {
			Size                   = restSize,
			BackgroundTransparency = 0,
		}):Play()
	end

	-- tweenOut: fade out only — NO position movement. Hard-reset in callback.
	local function tweenOut(frame, restSize, restPos, callback)
		TweenService:Create(frame, HIDE_INFO, {
			BackgroundTransparency = 1,
		}):Play()
		task.delay(HIDE_INFO.Time + 0.05, function()
			frame.Visible                = false
			-- Always hard-reset so next tweenIn starts from a clean state
			frame.Size                   = restSize
			frame.Position               = restPos
			frame.BackgroundTransparency = 0
			if callback then callback() end
		end)
	end

	-- ── Public API ────────────────────────────────────────────────────────────

	function HUDModule_MatchFlow.ShowPregameIntro(teamCounts, mapName, duration, designerUserIds, criticUserIds)
		if isPregameActive or not pregameIntro then return end
		isPregameActive = true
		screenGui.Enabled = true

		local vs  = pregameIntro:FindFirstChild("VersusScreen")
		local bg  = pregameIntro:FindFirstChild("Background")

		if vs then
			local split = vs:FindFirstChild("TeamSplitLabel")
			local map   = vs:FindFirstChild("MapNameLabel")
			if split then split.Text = string.format("%d VS %d",
				teamCounts and teamCounts.Designers or 0,
				teamCounts and teamCounts.Critics    or 0) end
			if map then map.Text = mapName or "UNKNOWN MAP" end
			
			-- Setup Viewports with actual player appearances
			setupViewport(designerViewport, "Designer", designerUserIds)
			setupViewport(criticViewport, "Critic", criticUserIds)
		end

		-- Tween in
		tweenIn(pregameIntro,
			UDim2.new(1, 0, 1, 0),   -- restSize: full screen
			UDim2.new(0, 0, 0, 0)    -- restPos: top-left
		)
		playSound("UI_OpenPanel")

		task.delay(duration or PreGameModule.GetDuration(), function()
			HUDModule_MatchFlow.HidePregameIntro()
		end)
	end

	function HUDModule_MatchFlow.HidePregameIntro()
		if not isPregameActive or not pregameIntro then return end
		tweenOut(pregameIntro, UDim2.new(1, 0, 1, 0), UDim2.new(0, 0, 0, 0), function()
			isPregameActive = false
			-- Disable ScreenGui only if postgame is also not showing
			if not isPostgameActive then
				screenGui.Enabled = false
			end
		end)
	end

	function HUDModule_MatchFlow.ShowPostGameSummary(winningTeam, coins, xpData)
		if isPostgameActive or not postGameSummary then return end
		isPostgameActive = true
		screenGui.Enabled = true

		-- Victory headers
		local criticH   = postGameSummary:FindFirstChild("CriticVictoryWinHeader")
		local designerH = postGameSummary:FindFirstChild("DesignerVictoryWinHeader")
		if criticH   then criticH.Visible   = (winningTeam == "Critics")   end
		if designerH then designerH.Visible = (winningTeam == "Designers") end

		-- Static labels
		local earnings = postGameSummary:FindFirstChild("EarningsRollup")
		if earnings and xpData then
			local xpReward = earnings:FindFirstChild("XPReward")
			local xpBarFill = xpReward and xpReward:FindFirstChild("XPBarBg") and xpReward.XPBarBg:FindFirstChild("XPBarFill")
			local xpLabel = xpReward and xpReward:FindFirstChild("XPLabel")
			local xpGained = xpReward and xpReward:FindFirstChild("XPGained")
			local levelUpBanner = earnings:FindFirstChild("LevelUpBanner")

			if xpBarFill and xpLabel and xpGained then
				local currentLevel = xpData.level or 1
				local currentXP = xpData.currentXP or 0
				local xpEarned = xpData.xpEarned or 0

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
		end

		tweenIn(postGameSummary,
			UDim2.new(1, 0, 1, 0),
			UDim2.new(0, 0, 0, 0)
		)
		playSound("UI_OpenPanel")

		-- Kick off coin counter after 0.4s (let the tween settle first)
		task.delay(0.4, function()
			HUDModule_MatchFlow.AnimateCoinCount(coins or 0, 1.8)
		end)
		
		-- Auto-hide after duration
		task.delay(8, function()
			HUDModule_MatchFlow.HidePostGameSummary()
		end)
	end

	function HUDModule_MatchFlow.HidePostGameSummary()
		if not isPostgameActive or not postGameSummary then return end
		tweenOut(postGameSummary, UDim2.new(1, 0, 1, 0), UDim2.new(0, 0, 0, 0), function()
			isPostgameActive = false
			if not isPregameActive then screenGui.Enabled = false end
			-- Reset headers
			local criticH   = postGameSummary:FindFirstChild("CriticVictoryWinHeader")
			local designerH = postGameSummary:FindFirstChild("DesignerVictoryWinHeader")
			if criticH   then criticH.Visible   = false end
			if designerH then designerH.Visible = false end
		end)
	end

	function HUDModule_MatchFlow.AnimateCoinCount(targetAmount, duration)
		-- Cancel any running counter
		if coinCountThread then
			task.cancel(coinCountThread)
			coinCountThread = nil
		end

		local earnings = postGameSummary and postGameSummary:FindFirstChild("EarningsRollup")
		local coinAmount = earnings
			and earnings:FindFirstChild("CoinReward")
			and earnings.CoinReward:FindFirstChild("CoinAmount")
		if not coinAmount then return end

		duration = duration or 1.5
		local startTime = os.clock()
		coinCountThread = task.spawn(function()
			while os.clock() - startTime < duration do
				local t = (os.clock() - startTime) / duration
				-- Ease-out cubic so it decelerates near the end
				local eased = 1 - (1 - t) ^ 3
				coinAmount.Text = string.format("+%d", math.floor(targetAmount * eased))
				task.wait(0.04)
			end
			coinAmount.Text = string.format("+%d", targetAmount)
			coinCountThread = nil
		end)
	end

	-- ── Remote Listeners ──────────────────────────────────────────────────────
	if remotes then
		local MatchStart = remotes:WaitForChild("MatchStart", 5)
		local MatchEnd = remotes:WaitForChild("MatchEnd", 5)
		local PostMatchXP = remotes:WaitForChild("PostMatchXP", 5)

		if MatchStart then
			MatchStart.OnClientEvent:Connect(function(pregameData)
				-- Server sends a single table, need to destructure properly
				local teamCounts = pregameData and pregameData.TeamCounts or { Designers = 0, Critics = 0 }
				local mapName = pregameData and pregameData.MapName or "UNKNOWN"
				local duration = pregameData and pregameData.Duration
				local designerUserIds = pregameData and pregameData.DesignerUserIds
				local criticUserIds = pregameData and pregameData.CriticUserIds
				HUDModule_MatchFlow.ShowPregameIntro(teamCounts, mapName, duration, designerUserIds, criticUserIds)
			end)
		end

		if MatchEnd then
			MatchEnd.OnClientEvent:Connect(function(winningTeam, coinsEarned)
				-- XP data will come via PostMatchXP
				HUDModule_MatchFlow.ShowPostGameSummary(winningTeam, coinsEarned, nil)
			end)
		end

		if PostMatchXP then
			PostMatchXP.OnClientEvent:Connect(function(currentLevel, currentXP, xpEarned)
				if isPostgameActive then
					-- If summary is already showing, we might want to re-trigger or update it
					-- For now, we just pass the data to ShowPostGameSummary if it wasn't showing,
					-- but since MatchEnd usually comes first, we handle it here:
					HUDModule_MatchFlow.ShowPostGameSummary(nil, nil, {
						level = currentLevel,
						currentXP = currentXP,
						xpEarned = xpEarned
					})
				end
			end)
		end
	end

	-- Exposed so MatchFlowController can call cleanup
	function HUDModule_MatchFlow.IsActive()
		return isPregameActive or isPostgameActive
	end

end

return HUDModule_MatchFlow
