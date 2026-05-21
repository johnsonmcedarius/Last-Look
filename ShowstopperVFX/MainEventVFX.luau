-- ─────────────────────────────────────────────────────────────────────────────
-- MainEventVFX: Client-side visual effects for 'The Main Event' Showstopper
-- Migrated from CombatVFXController for modular architecture
-- ─────────────────────────────────────────────────────────────────────────────

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

-- ── Settings ─────────────────────────────────────────────────────────────────
local MAIN_EVENT_FOV = 105
local NORMAL_FOV = 70
local SPOTLIGHT_HEIGHT = 50
local RUNWAY_LENGTH = 15
local RUNWAY_WIDTH = 6

-- ── State ────────────────────────────────────────────────────────────────────
local isActive = false
local currentSpotlight = nil
local currentRunway = nil
local goldenGlowHighlight = nil
local musicTrack = nil
local character = nil
local rootPart = nil

-- ── Helper Functions ─────────────────────────────────────────────────────────

local function setFOV(targetFOV, duration)
	TweenService:Create(camera, TweenInfo.new(duration or 0.5), {FieldOfView = targetFOV}):Play()
end

local function playMainEventMusic()
	local musicId = "rbxassetid://0" -- Swap with your high-energy track ID
	if musicTrack then musicTrack:Destroy() end

	musicTrack = Instance.new("Sound")
	musicTrack.SoundId = musicId
	musicTrack.Volume = 0.8
	musicTrack.Parent = camera
	musicTrack:Play()
	Debris:AddItem(musicTrack, 12)
end

local function stopMainEventMusic()
	if musicTrack then
		TweenService:Create(musicTrack, TweenInfo.new(1), {Volume = 0}):Play()
		task.delay(1, function()
			if musicTrack then musicTrack:Destroy(); musicTrack = nil end
		end)
	end
end

-- ── Module Export ─────────────────────────────────────────────────────────────

local MainEventVFX = {}

function MainEventVFX.Activate(playerArg, data)
	-- Use passed player or default to local player
	local targetPlayer = playerArg or player
	character = targetPlayer.Character
	if not character or not character.PrimaryPart then return end
	rootPart = character.PrimaryPart
	
	isActive = true

	-- Spotlight setup
	currentSpotlight = Instance.new("Part")
	currentSpotlight.Name = "MainEventSpotlight"
	currentSpotlight.Transparency = 1
	currentSpotlight.CanCollide = false
	currentSpotlight.Anchored = true
	currentSpotlight.Parent = workspace
	
	local light = Instance.new("PointLight", currentSpotlight)
	light.Color = Color3.fromRGB(255, 230, 150)
	light.Brightness = 3
	light.Range = 30

	-- Runway setup
	currentRunway = Instance.new("Part")
	currentRunway.Name = "MainEventRunway"
	currentRunway.Size = Vector3.new(RUNWAY_WIDTH, 0.1, RUNWAY_LENGTH)
	currentRunway.Transparency = 0.5
	currentRunway.Material = Enum.Material.Neon
	currentRunway.Color = Color3.fromRGB(255, 215, 0)
	currentRunway.Anchored = true
	currentRunway.CanCollide = false
	currentRunway.Parent = workspace

	-- Glow setup
	goldenGlowHighlight = Instance.new("Highlight", character)
	goldenGlowHighlight.FillColor = Color3.fromRGB(255, 215, 0)
	goldenGlowHighlight.FillTransparency = 0.8

	-- Local player only effects (Camera/Music)
	if targetPlayer == player then
		setFOV(MAIN_EVENT_FOV, 0.5)
		playMainEventMusic()
	end
	
	-- Play activation VFX if VFXModule available
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local success, VFXModule = pcall(function()
		return require(ReplicatedStorage:FindFirstChild("VFXModule") or ReplicatedStorage:WaitForChild("VFX", 1))
	end)
	if success and VFXModule and VFXModule.Play then
		VFXModule.Play("MainEventBurst", rootPart.Position)
	end
	
	-- Play activation sound
	local soundSuccess, SoundService = pcall(function()
		return require(ReplicatedStorage:WaitForChild("SoundService"))
	end)
	if soundSuccess and SoundService and SoundService.PlayLocal then
		SoundService.PlayLocal("ShowstopperActivate")
	end
	
	print("[MainEventVFX] Activated for " .. targetPlayer.Name)
end

function MainEventVFX.Deactivate()
	isActive = false
	
	if currentSpotlight then 
		currentSpotlight:Destroy() 
		currentSpotlight = nil 
	end
	if currentRunway then 
		currentRunway:Destroy() 
		currentRunway = nil 
	end
	if goldenGlowHighlight then 
		goldenGlowHighlight:Destroy() 
		goldenGlowHighlight = nil 
	end
	
	-- Local player only cleanup
	setFOV(NORMAL_FOV, 0.5)
	stopMainEventMusic()
	
	character = nil
	rootPart = nil
	
	print("[MainEventVFX] Deactivated")
end

function MainEventVFX.OnRenderStepped(deltaTime)
	if not isActive or not rootPart then return end

	-- Update spotlight position
	if currentSpotlight then
		currentSpotlight.CFrame = CFrame.new(rootPart.Position)
	end
	
	-- Update runway position and rotation
	if currentRunway then
		currentRunway.CFrame = CFrame.new(rootPart.Position - rootPart.CFrame.LookVector * RUNWAY_LENGTH / 2) 
			* CFrame.Angles(0, math.atan2(rootPart.CFrame.LookVector.X, rootPart.CFrame.LookVector.Z), 0)
	end
end

function MainEventVFX.IsActive()
	return isActive
end

return MainEventVFX