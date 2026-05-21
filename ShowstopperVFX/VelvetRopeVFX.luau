-- ─────────────────────────────────────────────────────────────────────────────
-- VelvetRopeVFX: Client-side visual effects for 'The Velvet Rope' Showstopper
-- Implements: Gold stanchions, red velvet ropes, red carpet, paparazzi flashes,
--             jazzy lounge music, and VIP atmosphere
-- ─────────────────────────────────────────────────────────────────────────────

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local Lighting = game:GetService("Lighting")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

-- ── Settings ─────────────────────────────────────────────────────────────────
local STANCHION_HEIGHT = 6
local STANCHION_RADIUS = 0.3
local ROPE_SEGMENTS = 12
local CARPET_ALPHA = 0.6
local FLASH_INTERVAL_MIN = 0.3
local FLASH_INTERVAL_MAX = 1.0

-- ── State ────────────────────────────────────────────────────────────────────
local isActive = false
local stanchions = {}
local ropeParts = {}
local carpetPart = nil
local flashParts = {}
local musicTrack = nil
local zoneCenter = nil
local zoneRadius = 40
local flickerTime = 0
local nextFlashIn = 0

-- ── Helper Functions ─────────────────────────────────────────────────────────

local function createStanchion(position, rotation)
	-- Create gold stanchion (pole)
	local stanchion = Instance.new("Part")
	stanchion.Name = "VIPStanchion"
	stanchion.Size = Vector3.new(STANCHION_RADIUS * 2, STANCHION_HEIGHT, STANCHION_RADIUS * 2)
	stanchion.CFrame = CFrame.new(position) * CFrame.Angles(0, math.rad(rotation), 0)
	stanchion.Anchored = true
	stanchion.CanCollide = false
	stanchion.Material = Enum.Material.Metal
	stanchion.Color = Color3.fromRGB(255, 215, 0) -- Gold
	stanchion.Parent = workspace
	
	-- Add decorative ball on top
	local ball = Instance.new("Part")
	ball.Name = "StanchionTop"
	ball.Shape = Enum.PartType.Ball
	ball.Size = Vector3.new(0.8, 0.8, 0.8)
	ball.CFrame = stanchion.CFrame * CFrame.new(0, STANCHION_HEIGHT / 2 + 0.4, 0)
	ball.Anchored = true
	ball.CanCollide = false
	ball.Material = Enum.Material.Metal
	ball.Color = Color3.fromRGB(255, 215, 0)
	ball.Parent = workspace
	
	return stanchion, ball
end

local function createRopeSegment(startPos, endPos, segmentIndex)
	-- Create velvet rope segment
	local rope = Instance.new("Part")
	rope.Name = "VelvetRope_" .. segmentIndex
	
	local direction = (endPos - startPos)
	local length = direction.Magnitude
	local midpoint = (startPos + endPos) / 2
	
	rope.Size = Vector3.new(0.15, length, 0.15)
	rope.CFrame = CFrame.new(midpoint, endPos) * CFrame.Angles(math.rad(90), 0, 0)
	rope.Anchored = true
	rope.CanCollide = false
	rope.Material = Enum.Material.Fabric
	rope.Color = Color3.fromRGB(139, 0, 0) -- Deep red velvet
	rope.Parent = workspace
	
	return rope
end

local function createCarpet(center, radius)
	-- Create red carpet floor
	local carpet = Instance.new("Part")
	carpet.Name = "VIPCarpet"
	carpet.Shape = Enum.PartType.Cylinder
	carpet.Size = Vector3.new(0.2, radius * 2, radius * 2)
	carpet.CFrame = CFrame.new(center) * CFrame.Angles(0, 0, math.rad(90))
	carpet.Anchored = true
	carpet.CanCollide = false
	carpet.Material = Enum.Material.Fabric
	carpet.Color = Color3.fromRGB(139, 0, 0) -- Deep red
	carpet.Transparency = CARPET_ALPHA
	carpet.Parent = workspace
	
	-- Add subtle glow underneath
	local glow = Instance.new("PointLight")
	glow.Color = Color3.fromRGB(255, 215, 0)
	glow.Brightness = 1
	glow.Range = 20
	glow.Parent = carpet
	
	return carpet
end

local function createFlashPosition(position)
	-- Create paparazzi flash point light
	local flash = Instance.new("PointLight")
	flash.Name = "PaparazziFlash"
	flash.Color = Color3.fromRGB(255, 255, 255)
	flash.Brightness = 0
	flash.Range = 15
	flash.Position = position + Vector3.new(0, 5, 0)
	flash.Parent = workspace
	
	return flash
end

local function playLoungeMusic()
	-- Sophisticated jazzy lounge remix
	local musicId = "rbxassetid://0" -- Replace with actual lounge track
	if musicTrack then musicTrack:Destroy() end

	musicTrack = Instance.new("Sound")
	musicTrack.SoundId = musicId
	musicTrack.Volume = 0.6
	musicTrack.Parent = camera
	
	-- Add reverb for upscale feel
	local reverb = Instance.new("ReverbSoundEffect")
	reverb.DecayTime = 1.5
	reverb.Density = 0.6
	reverb.Parent = musicTrack
	
	musicTrack:Play()
	Debris:AddItem(musicTrack, 10)
end

local function stopLoungeMusic()
	if musicTrack then
		TweenService:Create(musicTrack, TweenInfo.new(1), {Volume = 0}):Play()
		task.delay(1, function()
			if musicTrack then musicTrack:Destroy(); musicTrack = nil end
		end)
	end
end

local function triggerPaparazziFlash(flash)
	if not flash or not flash.Parent then return end
	
	-- Quick bright flash
	flash.Brightness = 5
	TweenService:Create(flash, TweenInfo.new(0.1), {Brightness = 0}):Play()
end

-- ── Module Export ─────────────────────────────────────────────────────────────

local VelvetRopeVFX = {}

function VelvetRopeVFX.Activate(playerArg, data)
	local targetPlayer = playerArg or player
	local char = targetPlayer.Character
	if not char or not char.PrimaryPart then return end
	
	zoneCenter = data and data.Position or char.PrimaryPart.Position
	zoneRadius = data and data.Radius or 40
	local duration = data and data.Duration or 7
	
	isActive = true
	
	-- ── 1. CREATE FOUR GOLD STANCHIONS ──
	local corners = {}
	for i = 1, 4 do
		local angle = (i - 1) * 90
		local radAngle = math.rad(angle)
		local offset = Vector3.new(math.cos(radAngle) * zoneRadius, 0, math.sin(radAngle) * zoneRadius)
		local cornerPos = zoneCenter + offset + Vector3.new(0, STANCHION_HEIGHT / 2, 0)
		
		local stanchion, ball = createStanchion(cornerPos, angle)
		table.insert(stanchions, stanchion)
		table.insert(stanchions, ball)
		corners[i] = cornerPos
	end
	
	-- ── 2. CREATE VELVET ROPES BETWEEN STANCHIONS ──
	for i = 1, 4 do
		local nextI = i % 4 + 1
		local startPos = corners[i] - Vector3.new(0, STANCHION_HEIGHT / 2 - 1, 0)
		local endPos = corners[nextI] - Vector3.new(0, STANCHION_HEIGHT / 2 - 1, 0)
		
		-- Create rope segments for curved effect
		local rope = createRopeSegment(startPos, endPos, i)
		table.insert(ropeParts, rope)
	end
	
	-- ── 3. CREATE RED CARPET ──
	carpetPart = createCarpet(zoneCenter, zoneRadius)
	
	-- ── 4. CREATE PAPARAZZI FLASH POSITIONS ──
	for i = 1, 8 do
		local angle = (i - 1) * 45
		local radAngle = math.rad(angle)
		local offset = Vector3.new(math.cos(radAngle) * zoneRadius, 0, math.sin(radAngle) * zoneRadius)
		local flashPos = zoneCenter + offset
		local flash = createFlashPosition(flashPos)
		table.insert(flashParts, flash)
	end
	
	-- ── 5. PLAY LOUNGE MUSIC ──
	playLoungeMusic()
	
	-- ── 6. PLAY ACTIVATION SOUND ──
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local success, SoundService = pcall(function()
		return require(ReplicatedStorage:WaitForChild("SoundService"))
	end)
	if success and SoundService and SoundService.PlayLocal then
		SoundService.PlayLocal("VelvetRopeActivate")
	end
	
	-- Reset flash timer
	flickerTime = 0
	nextFlashIn = math.random() * 0.5
	
	print("[VelvetRopeVFX] VIP Lounge activated at: " .. tostring(zoneCenter))
end

function VelvetRopeVFX.Deactivate()
	isActive = false
	
	-- Cleanup stanchions
	for _, part in ipairs(stanchions) do
		if part and part.Parent then part:Destroy() end
	end
	stanchions = {}
	
	-- Cleanup ropes
	for _, rope in ipairs(ropeParts) do
		if rope and rope.Parent then rope:Destroy() end
	end
	ropeParts = {}
	
	-- Cleanup carpet
	if carpetPart then
		carpetPart:Destroy()
		carpetPart = nil
	end
	
	-- Cleanup flashes
	for _, flash in ipairs(flashParts) do
		if flash and flash.Parent then flash:Destroy() end
	end
	flashParts = {}
	
	stopLoungeMusic()
	
	zoneCenter = nil
	
	print("[VelvetRopeVFX] VIP Lounge deactivated")
end

function VelvetRopeVFX.OnRenderStepped(deltaTime)
	if not isActive then return end
	
	-- Handle random paparazzi flashes
	flickerTime = flickerTime + deltaTime
	if flickerTime >= nextFlashIn then
		-- Pick random flash position
		if #flashParts > 0 then
			local randomFlash = flashParts[math.random(1, #flashParts)]
			triggerPaparazziFlash(randomFlash)
		end
		
		flickerTime = 0
		nextFlashIn = FLASH_INTERVAL_MIN + math.random() * (FLASH_INTERVAL_MAX - FLASH_INTERVAL_MIN)
	end
end

function VelvetRopeVFX.IsActive()
	return isActive
end

return VelvetRopeVFX