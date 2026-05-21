-- ─────────────────────────────────────────────────────────────────────────────
-- GlitchGalaVFX: Client-side visual effects for 'The Glitch Gala' Showstopper
-- Implements: Grayscale static storm, digital grid skybox, nameplate garble,
--             screen flicker, and distorted audio effects
-- ─────────────────────────────────────────────────────────────────────────────

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local Lighting = game:GetService("Lighting")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

-- ── Settings ─────────────────────────────────────────────────────────────────
local FLICKER_INTERVAL_MIN = 0.05
local FLICKER_INTERVAL_MAX = 0.3
local GARBLE_CHARS = {"@", "#", "$", "%", "&", "*", "!", "?", "0", "1"}
local GARBLE_WORDS = {"ERR0R", "GLITCH", "NULL", "VOID", "CORRUPT", "@@@@@@"}
local STATIC_INTENSITY = 0.4

-- ── State ────────────────────────────────────────────────────────────────────
local isActive = false
local colorCorrection = nil
local skybox = nil
local originalSkybox = nil
local glitchZone = nil
local musicTrack = nil
local flickerTime = 0
local nextFlickerIn = 0
local garbledPlayers = {}
local nameplateConnections = {}

-- ── Helper Functions ─────────────────────────────────────────────────────────

local function getRandomGarble()
	-- 50% chance for word, 50% for random chars
	if math.random() < 0.5 then
		local word = GARBLE_WORDS[math.random(1, #GARBLE_WORDS)]
		return word
	else
		local length = math.random(4, 8)
		local result = ""
		for i = 1, length do
			result = result .. GARBLE_CHARS[math.random(1, #GARBLE_CHARS)]
		end
		return result
	end
end

local function applyGrayscale()
	-- Create or update ColorCorrection effect
	if not colorCorrection then
		colorCorrection = Instance.new("ColorCorrectionEffect")
		colorCorrection.Name = "GlitchGalaGrayscale"
		colorCorrection.Parent = Lighting
	end
	
	-- Tween to grayscale
	colorCorrection.Saturation = -1 + STATIC_INTENSITY -- Desaturated with slight color
	colorCorrection.Contrast = 0.2
	colorCorrection.Brightness = -0.1
	
	-- Add slight color tint (digital purple/magenta)
	colorCorrection.TintColor = Color3.fromRGB(200, 150, 255)
	
	TweenService:Create(colorCorrection, TweenInfo.new(0.5), {
		Saturation = -1 + STATIC_INTENSITY,
		Contrast = 0.2,
		Brightness = -0.1
	}):Play()
end

local function removeGrayscale()
	if colorCorrection then
		TweenService:Create(colorCorrection, TweenInfo.new(0.5), {
			Saturation = 0,
			Contrast = 0,
			Brightness = 0,
		TintColor = Color3.fromRGB(255, 255, 255)
		}):Play()
		
		task.delay(0.5, function()
			if colorCorrection then
				colorCorrection:Destroy()
				colorCorrection = nil
			end
		end)
	end
end

local function applyDigitalSkybox()
	-- Store original skybox
	originalSkybox = Lighting:FindFirstChildOfClass("Sky")
	
	-- Create digital grid skybox
	skybox = Instance.new("Sky")
	skybox.Name = "GlitchGalaSkybox"
	
	-- Use neon-like colors for digital grid effect
	-- These would ideally be actual skybox textures, but we'll use solid colors
	skybox.SkyboxBk = "rbxassetid://0" -- Placeholder: should be digital grid texture
	skybox.SkyboxDn = "rbxassetid://0"
	skybox.SkyboxFt = "rbxassetid://0"
	skybox.SkyboxLf = "rbxassetid://0"
	skybox.SkyboxRt = "rbxassetid://0"
	skybox.SkyboxUp = "rbxassetid://0"
	
	-- Set starry properties for glitch effect
	skybox.StarCount = 500
	skybox.StarIntensity = 5
	
	skybox.Parent = Lighting
	
	-- If original skybox exists, hide it
	if originalSkybox then
		originalSkybox.Enabled = false
	end
end

local function removeDigitalSkybox()
	if skybox then
		skybox:Destroy()
		skybox = nil
	end
	
	-- Restore original skybox
	if originalSkybox then
		originalSkybox.Enabled = true
		originalSkybox = nil
	end
end

local function playGlitchMusic()
	-- Distorted bass-boosted theme (placeholder: use low-pass filter effect)
	local musicId = "rbxassetid://0" -- Replace with actual glitch track
	if musicTrack then musicTrack:Destroy() end

	musicTrack = Instance.new("Sound")
	musicTrack.SoundId = musicId
	musicTrack.Volume = 0.6
	musicTrack.PlaybackSpeed = 0.9 -- Slightly slower for "corrupted" feel
	musicTrack.Parent = camera
	
	-- Add distortion effect
	local distortion = Instance.new("DistortionSoundEffect")
	distortion.Level = 0.3
	distortion.Parent = musicTrack
	
	-- Add reverb for "corrupted vinyl" effect
	local reverb = Instance.new("ReverbSoundEffect")
	reverb.DecayTime = 2
	reverb.Density = 0.8
	reverb.Parent = musicTrack
	
	musicTrack:Play()
	Debris:AddItem(musicTrack, 10)
end

local function stopGlitchMusic()
	if musicTrack then
		TweenService:Create(musicTrack, TweenInfo.new(1), {Volume = 0}):Play()
		task.delay(1, function()
			if musicTrack then musicTrack:Destroy(); musicTrack = nil end
		end)
	end
end

local function createGlitchZone(position, radius)
	-- Create visible glitch zone sphere
	glitchZone = Instance.new("Part")
	glitchZone.Name = "GlitchGalaZone"
	glitchZone.Shape = Enum.PartType.Ball
	glitchZone.Size = Vector3.new(radius * 2, radius * 2, radius * 2)
	glitchZone.Position = position
	glitchZone.Transparency = 0.7
	glitchZone.Color = Color3.fromRGB(50, 50, 50)
	glitchZone.Material = Enum.Material.Neon
	glitchZone.Anchored = true
	glitchZone.CanCollide = false
	glitchZone.Parent = workspace
	
	-- Add pulsing effect
	task.spawn(function()
		while glitchZone and glitchZone.Parent do
			TweenService:Create(glitchZone, TweenInfo.new(0.5), {
				Transparency = 0.5,
				Size = Vector3.new(radius * 2.1, radius * 2.1, radius * 2.1)
			}):Play()
			task.wait(0.5)
			TweenService:Create(glitchZone, TweenInfo.new(0.5), {
				Transparency = 0.8,
				Size = Vector3.new(radius * 2, radius * 2, radius * 2)
			}):Play()
			task.wait(0.5)
		end
	end)
end

local function removeGlitchZone()
	if glitchZone then
		glitchZone:Destroy()
		glitchZone = nil
	end
end

local function garbleNameplates()
	-- Hook into all player nameplates and garble them
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local template = assets and assets:FindFirstChild("NameplateTemplate")
	
	for _, p in ipairs(Players:GetPlayers()) do
		if p ~= player then -- Don't garble own nameplate
			local char = p.Character
			if char then
				local head = char:FindFirstChild("Head")
				if head then
					local nameplate = head:FindFirstChild("CustomNameplate")
					if nameplate then
						local nameLabel = nameplate:FindFirstChild("NameLabel")	if nameLabel then
							-- Store original name
							garbledPlayers[p.UserId] = nameLabel.Text
							
							-- Apply garble
							nameLabel.Text = getRandomGarble()
							nameLabel.TextColor3 = Color3.fromRGB(255, 0, 100) -- Glitch pink/red
						end
					end
				end
			end
		end
	end
end

local function restoreNameplates()
	-- Restore all nameplates to original names
	for _, p in ipairs(Players:GetPlayers()) do
		local char = p.Character
		if char then
			local head = char:FindFirstChild("Head")
			if head then
				local nameplate = head:FindFirstChild("CustomNameplate")
				if nameplate then
					local nameLabel = nameplate:FindFirstChild("NameLabel")
					if nameLabel and garbledPlayers[p.UserId] then
						nameLabel.Text = garbledPlayers[p.UserId]
						-- Restore team color (handled by NameplateController)
					end
				end
			end
		end
	end
	garbledPlayers = {}
end

local function triggerScreenFlicker()
	-- Brief screen flash for glitch effect
	local flickerGui = Instance.new("ScreenGui")
	flickerGui.Name = "GlitchFlicker"
	flickerGui.IgnoreGuiInset = true
	flickerGui.DisplayOrder = 10000
	flickerGui.Parent = player:WaitForChild("PlayerGui")
	
	local flickerFrame = Instance.new("Frame")
	flickerFrame.Size = UDim2.new(1, 0, 1, 0)
	flickerFrame.BackgroundColor3 = Color3.fromRGB(255, 0, 100)
	flickerFrame.BackgroundTransparency = 0.8
	flickerFrame.BorderSizePixel = 0
	flickerFrame.Parent = flickerGui
	
	-- Quick flash
	TweenService:Create(flickerFrame, TweenInfo.new(0.05), {
		BackgroundTransparency = 1
	}):Play()
	
	Debris:AddItem(flickerGui, 0.1)
end

-- ── Module Export ─────────────────────────────────────────────────────────────

local GlitchGalaVFX = {}

function GlitchGalaVFX.Activate(playerArg, data)
	local targetPlayer = playerArg or player
	local char = targetPlayer.Character
	if not char or not char.PrimaryPart then return end
	
	local position = data and data.Position or char.PrimaryPart.Position
	local radius = data and data.Radius or 30
	local duration = data and data.Duration or 8
	
	isActive = true
	
	-- Apply all visual effects
	applyGrayscale()
	applyDigitalSkybox()
	createGlitchZone(position, radius)
	playGlitchMusic()
	garbleNameplates()
	
	-- Initial flicker
	triggerScreenFlicker()
	
	-- Reset flicker timer
	flickerTime = 0
	nextFlickerIn = math.random() * 0.5
	
	print("[GlitchGalaVFX] Activated at position: " .. tostring(position))
end

function GlitchGalaVFX.Deactivate()
	isActive = false
	
	removeGrayscale()
	removeDigitalSkybox()
	removeGlitchZone()
	stopGlitchMusic()
	restoreNameplates()
	
	print("[GlitchGalaVFX] Deactivated")
end

function GlitchGalaVFX.OnRenderStepped(deltaTime)
	if not isActive then return end
	
	-- Handle random screen flickers
	flickerTime = flickerTime + deltaTime
	if flickerTime >= nextFlickerIn then
		triggerScreenFlicker()
		flickerTime = 0
		nextFlickerIn = FLICKER_INTERVAL_MIN + math.random() * (FLICKER_INTERVAL_MAX - FLICKER_INTERVAL_MIN)
		
		-- Also garble nameplates again for dynamic effect
		garbleNameplates()
	end
end

function GlitchGalaVFX.IsActive()
	return isActive
end

return GlitchGalaVFX