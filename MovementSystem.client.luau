local Players             = game:GetService("Players")
local UIS                 = game:GetService("UserInputService")
local RunService           = game:GetService("RunService")
local TweenService         = game:GetService("TweenService")
local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage    = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

-- Modules
local SoundService = require(ReplicatedStorage:WaitForChild("SoundService"))
local Config       = require(ReplicatedStorage:WaitForChild("SharedConfig"))
local VFXModule    = require(ReplicatedStorage:WaitForChild("VFXModule"))

-- Remotes
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local MovementEffect = Remotes:WaitForChild("MovementEffect")
local DashCooldownUpdate = Remotes:FindFirstChild("DashCooldownUpdate")

-- ── Settings ─────────────────────────────────────────────────────────────────
local DASH_DURATION = 0.22
local NORMAL_FOV    = 70
local SPRINT_FOV    = 80
local DASH_FOV      = 95

local SPRINT_ANIM_ID = "rbxassetid://130150958024919"
local JUMP_ANIM_ID   = "rbxassetid://123456789" 
local DASH_ANIMS = {
	Forward  = "rbxassetid://117382622603922",
	Backward = "rbxassetid://126640575736027",
	Left     = "rbxassetid://139408657874679",
	Right    = "rbxassetid://129377801326400",
}

-- ── State ────────────────────────────────────────────────────────────────────
local sprinting         = false
local dashing           = false
local dashCooldownUntil = 0
local character, humanoid, root
local sprintTrack, jumpTrack
local dashTracks = {}

-- ── Character Setup (Fixed Logic) ──────────────────────────────────────────
local function setupCharacter(char)
	character = char
	humanoid  = char:WaitForChild("Humanoid")
	root      = char:WaitForChild("HumanoidRootPart")

	local animator = humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator")
	if not animator.Parent then animator.Parent = humanoid end

	-- Helper to create and load animations correctly
	local function loadAnim(id)
		local anim = Instance.new("Animation")
		anim.AnimationId = id
		return animator:LoadAnimation(anim)
	end

	-- Load Animations
	sprintTrack = loadAnim(SPRINT_ANIM_ID)
	jumpTrack   = loadAnim(JUMP_ANIM_ID)

	for name, id in pairs(DASH_ANIMS) do
		dashTracks[name] = loadAnim(id)
	end

	-- Apply Stats
	humanoid.JumpPower = Config.JUMP_POWER or 50
	humanoid.WalkSpeed = Config.WALK_SPEED or 16

	-- Jump Signal
	local lastJump = 0
	humanoid.Jumping:Connect(function()
		local now = os.clock()
		if now - lastJump < 0.5 then return end -- Rate limit
		lastJump = now
		
		SoundService.PlayLocal("FashionJump")
		VFXModule.Play("JumpBurst", root.Position)
		MovementEffect:FireServer("Jump")
		if jumpTrack then jumpTrack:Play() end
	end)
end

player.CharacterAdded:Connect(setupCharacter)
if player.Character then setupCharacter(player.Character) end


local function getDashDirection()
	local move = humanoid.MoveDirection
	if move.Magnitude == 0 then return "Forward", root.CFrame.LookVector end

	local localMove = root.CFrame:VectorToObjectSpace(move)

	if math.abs(localMove.Z) > math.abs(localMove.X) then
		if localMove.Z < 0 then return "Forward", move end
		return "Backward", move
	else
		if localMove.X < 0 then return "Left", move end
		return "Right", move
	end
end

local function performDash()
	if not humanoid or dashing then return end

	-- System Shock Check: Glitch Gala disables dash
	if player:GetAttribute("DashDisabled") then
		-- Visual feedback for denied dash
		local PlayerGui = player:FindFirstChild("PlayerGui")
		if PlayerGui then
			local deniedGui = Instance.new("ScreenGui")
			deniedGui.Name = "DashDenied"
			deniedGui.IgnoreGuiInset = true
			deniedGui.DisplayOrder = 10000
			deniedGui.Parent = PlayerGui
			
			local deniedFrame = Instance.new("Frame")
			deniedFrame.Size = UDim2.new(1, 0, 1, 0)
			deniedFrame.BackgroundColor3 = Color3.fromRGB(255, 0, 100)
			deniedFrame.BackgroundTransparency = 0.7
			deniedFrame.BorderSizePixel = 0
			deniedFrame.Parent = deniedGui
			
			-- Quick flash
			TweenService:Create(deniedFrame, TweenInfo.new(0.15), {
				BackgroundTransparency = 1
			}):Play()
			
			game:GetService("Debris"):AddItem(deniedGui, 0.2)
		end
		
		SoundService.PlayLocal("DashDenied")
		print("[MOVEMENT] Dash denied - System Shock active")
		return
	end

	-- Main Event: Zero cooldown on Fashion Dash
	local char = player.Character
	local mainEventActive = char and char:GetAttribute("MainEventActive")
	if not mainEventActive and os.clock() < dashCooldownUntil then return end

	-- Universal dash - both teams can use
	if not player.Team then return end
	if player.Team.Name ~= "Designers" and player.Team.Name ~= "Critics" then return end

	dashing = true
	-- Only apply cooldown if Main Event is NOT active
	if not mainEventActive then
		dashCooldownUntil = os.clock() + (Config.DASH_COOLDOWN or 0.5)
	end

	local dirName, dashVector = getDashDirection()
	local track = dashTracks[dirName]

	-- PHASE 4 FIX: Flatten the vector to prevent accidental flying
	local flatVector = Vector3.new(dashVector.X, 0, dashVector.Z).Unit

	-- Play Feedback
	if track then track:Play(0.1) end
	SoundService.PlayLocal("FashionDash") 
	VFXModule.PlayLocal("DashRainbow", root.Position) -- Local-only for performance
	MovementEffect:FireServer("Dash") 

	-- Physics
	local att = Instance.new("Attachment", root)
	local dashVel = Instance.new("LinearVelocity")
	dashVel.MaxForce = 100000
	dashVel.VectorVelocity = flatVector * (Config.DASH_SPEED or 90)
	dashVel.Attachment0 = att
	dashVel.Parent = root

	TweenService:Create(camera, TweenInfo.new(0.2), {FieldOfView = DASH_FOV}):Play()

	task.wait(DASH_DURATION)

	-- Cleanup
	if track then track:Stop(0.2) end
	dashVel:Destroy()
	att:Destroy()

	local targetFOV = sprinting and SPRINT_FOV or NORMAL_FOV
	TweenService:Create(camera, TweenInfo.new(0.3), {FieldOfView = targetFOV}):Play()
	dashing = false
end

-- ── Inputs & Render Loop ─────────────────────────────────────────────────────
UIS.InputBegan:Connect(function(input, gp)
	if gp then return end
	if input.KeyCode == Enum.KeyCode.Q then performDash() end
	if input.KeyCode == Enum.KeyCode.LeftShift then sprinting = true end
end)

UIS.InputEnded:Connect(function(input)
	if input.KeyCode == Enum.KeyCode.LeftShift then sprinting = false end
end)

ContextActionService:BindAction("FashionDash", function(_, state)
	if state == Enum.UserInputState.Begin then performDash() end
end, true, Enum.KeyCode.ButtonR1)

-- ── FLASH MOB: MOMENTUM RESET ──
-- Listen for dash cooldown reset from server
if DashCooldownUpdate then
	DashCooldownUpdate.OnClientEvent:Connect(function(newCooldown)
		if newCooldown == 0 then
			dashCooldownUntil = 0
			print("[MOVEMENT] Dash cooldown reset - Momentum Reset active!")
		else
			dashCooldownUntil = newCooldown
		end
	end)
end

RunService.RenderStepped:Connect(function()
	if not humanoid or dashing then return end

	if sprinting and humanoid.MoveDirection.Magnitude > 0 then
		humanoid.WalkSpeed = Config.SPRINT_SPEED or 24
		if sprintTrack and not sprintTrack.IsPlaying then 
			sprintTrack:Play() 
			TweenService:Create(camera, TweenInfo.new(0.3), {FieldOfView = SPRINT_FOV}):Play()
		end
	else
		humanoid.WalkSpeed = Config.WALK_SPEED or 16
		if sprintTrack and sprintTrack.IsPlaying then 
			sprintTrack:Stop() 
			TweenService:Create(camera, TweenInfo.new(0.3), {FieldOfView = NORMAL_FOV}):Play()
		end
	end
end)