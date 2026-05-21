-- ─────────────────────────────────────────────────────────────────────────────
-- FlashMobVFX: Client-side visual effects for 'The Flash Mob' Showstopper
-- Implements: Ghost silhouette trails, camera flash bursts, rhythm tile floor,
--             drum-line track with finger snaps and camera clicks
-- ─────────────────────────────────────────────────────────────────────────────

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local Lighting = game:GetService("Lighting")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

-- ── Settings ─────────────────────────────────────────────────────────────────
local GHOST_TRAIL_TRANSPARENCY = 0.7
local GHOST_SPAWN_INTERVAL = 0.15
local RHYTHM_TILE_SIZE = 8
local RHYTHM_PULSE_SPEED = 0.5
local FLASH_DURATION = 0.2

-- ── State ────────────────────────────────────────────────────────────────────
local isActive = false
local ghostTrails = {} -- [player] = {trailParts, lastSpawnTime}
local rhythmTiles = {}
local musicTrack = nil
local snapTrack = nil
local pulseTime = 0
local lastGhostSpawn = 0

-- ── Helper Functions ─────────────────────────────────────────────────────────

local function createGhostSilhouette(targetPlayer)
	local char = targetPlayer.Character
	if not char then return nil end
	
	local root = char:FindFirstChild("HumanoidRootPart")
	if not root then return nil end
	
	-- Create ghost part at current position
	local ghost = Instance.new("Part")
	ghost.Name = "GhostTrail_" .. targetPlayer.UserId
	ghost.Size = Vector3.new(2, 3, 1)
	ghost.CFrame = root.CFrame
	ghost.Anchored = true
	ghost.CanCollide = false
	ghost.Transparency = GHOST_TRAIL_TRANSPARENCY
	ghost.Material = Enum.Material.Neon
	ghost.Color = Color3.fromRGB(255, 200, 100) -- Golden glow
	ghost.Parent = workspace
	
	-- Fade out and destroy
	TweenService:Create(ghost, TweenInfo.new(1), {
		Transparency = 1,
		Size = ghost.Size * 0.5
	}):Play()
	Debris:AddItem(ghost, 1.5)
	
	return ghost
end

local function createRhythmTile(center, index)
	-- Create glowing rhythm tile on floor
	local tile = Instance.new("Part")
	tile.Name = "RhythmTile_" .. index
	tile.Size = Vector3.new(RHYTHM_TILE_SIZE, 0.1, RHYTHM_TILE_SIZE)
	tile.CFrame = CFrame.new(center)
	tile.Anchored = true
	tile.CanCollide = false
	tile.Transparency = 0.8
	tile.Material = Enum.Material.Neon
	tile.Color = Color3.fromRGB(255, 100, 200) -- Pink/purple
	tile.Parent = workspace
	
	return tile
end

local function createRhythmGrid(center)
	-- Create grid of rhythm tiles around the map
	local tiles = {}
	local gridSize = 3
	local spacing = RHYTHM_TILE_SIZE * 1.5
	
	for x = -gridSize, gridSize do
		for z = -gridSize, gridSize do
			local offset = Vector3.new(x * spacing, 0, z * spacing)
			local tilePos = center + offset
			local tile = createRhythmTile(tilePos, #tiles + 1)
			table.insert(tiles, tile)
		end
	end
	
	return tiles
end

local function playDrumLineTrack()
	-- Heavy rhythmic drum-line track
	local musicId = "rbxassetid://0" -- Replace with actual drum track
	if musicTrack then musicTrack:Destroy() end

	musicTrack = Instance.new("Sound")
	musicTrack.SoundId = musicId
	musicTrack.Volume = 0.7
	musicTrack.Parent = camera
	musicTrack:Play()
	Debris:AddItem(musicTrack, 15)
end

local function stopDrumLineTrack()
	if musicTrack then
		TweenService:Create(musicTrack, TweenInfo.new(1), {Volume = 0}):Play()
		task.delay(1, function()
			if musicTrack then musicTrack:Destroy(); musicTrack = nil end
		end)
	end
end

local function playFingerSnap()
	-- Quick finger snap sound
	local snapId = "rbxassetid://0" -- Replace with snap sound
	if snapTrack then snapTrack:Destroy() end

	snapTrack = Instance.new("Sound")
	snapTrack.SoundId = snapId
	snapTrack.Volume = 0.5
	snapTrack.Parent = camera
	snapTrack:Play()
	Debris:AddItem(snapTrack, 1)
end

local function triggerCameraFlash(position)
	-- Massive camera flash burst at position
	local flash = Instance.new("PointLight")
	flash.Name = "CameraFlash"
	flash.Color = Color3.fromRGB(255, 255, 255)
	flash.Brightness = 10
	flash.Range = 30
	flash.Position = position
	flash.Parent = workspace
	
	-- Quick flash and fade
	TweenService:Create(flash, TweenInfo.new(FLASH_DURATION), {
		Brightness = 0
	}):Play()
	Debris:AddItem(flash, FLASH_DURATION + 0.1)
	
	-- Play camera click sound
	local click = Instance.new("Sound")
	click.SoundId = "rbxassetid://0" -- Camera shutter sound
	click.Volume = 0.8
	click.Parent = workspace
	click:Play()
	Debris:AddItem(click, 1)
end

-- ── Module Export ─────────────────────────────────────────────────────────────

local FlashMobVFX = {}

function FlashMobVFX.Activate(playerArg, data)
	local targetPlayer = playerArg or player
	local char = targetPlayer.Character
	if not char or not char.PrimaryPart then return end
	
	local center = data and data.Position or char.PrimaryPart.Position
	local duration = data and data.Duration or 12
	
	isActive = true
	
	-- ── 1. CREATE RHYTHM TILE GRID ──
	rhythmTiles = createRhythmGrid(center)
	
	-- ── 2. PLAY DRUM-LINE TRACK ──
	playDrumLineTrack()
	
	-- ── 3. PLAY ACTIVATION SOUND ──
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local success, SoundService = pcall(function()
		return require(ReplicatedStorage:WaitForChild("SoundService"))
	end)
	if success and SoundService and SoundService.PlayLocal then
		SoundService.PlayLocal("FlashMobActivate")
	end
	
	-- Initial flash
	triggerCameraFlash(char.PrimaryPart.Position)
	
	-- Reset timers
	pulseTime = 0
	lastGhostSpawn = 0
	
	print("[FlashMobVFX] Flash Mob activated - SQUAD GOALS!")
end

function FlashMobVFX.Deactivate()
	isActive = false
	
	-- Cleanup rhythm tiles
	for _, tile in ipairs(rhythmTiles) do
		if tile and tile.Parent then tile:Destroy() end
	end
	rhythmTiles = {}
	
	-- Cleanup ghost trails
	for playerUserId, ghostData in pairs(ghostTrails) do
		if ghostData.trail and ghostData.trail.Parent then
			ghostData.trail:Destroy()
		end
	end
	ghostTrails = {}
	
	stopDrumLineTrack()
	
	print("[FlashMobVFX] Flash Mob deactivated")
end

function FlashMobVFX.OnRenderStepped(deltaTime)
	if not isActive then return end
	
	pulseTime = pulseTime + deltaTime
	lastGhostSpawn = lastGhostSpawn + deltaTime
	
	-- ── RHYTHM TILE PULSE ──
	-- Pulse tiles to the beat
	for i, tile in ipairs(rhythmTiles) do
		if tile and tile.Parent then
			local phase = (pulseTime + i * 0.1) % (RHYTHM_PULSE_SPEED * 2)
			local brightness = phase < RHYTHM_PULSE_SPEED and phase / RHYTHM_PULSE_SPEED or (RHYTHM_PULSE_SPEED * 2 - phase) / RHYTHM_PULSE_SPEED
			tile.Transparency = 0.5 + brightness * 0.4
			tile.Color = Color3.fromHSV((pulseTime * 0.5 + i * 0.05) % 1, 0.8, 1)
		end
	end
	
	-- ── GHOST SILHOUETTE SPAWNING ──
	-- Spawn ghost trails for all teammates periodically
	if lastGhostSpawn >= GHOST_SPAWN_INTERVAL then
		lastGhostSpawn = 0
		
		-- Get local player's team
		local myTeam = player.Team
		if myTeam then
			for _, teammate in ipairs(myTeam:GetPlayers()) do
				if teammate.Character and teammate.Character:FindFirstChild("HumanoidRootPart") then
					createGhostSilhouette(teammate)
				end
			end
		end
		
		-- Play finger snap on beat
		playFingerSnap()
	end
end

function FlashMobVFX.TriggerPassFlash(position)
	-- Called when a fabric pass happens - trigger camera flash
	triggerCameraFlash(position)
end

function FlashMobVFX.IsActive()
	return isActive
end

return FlashMobVFX