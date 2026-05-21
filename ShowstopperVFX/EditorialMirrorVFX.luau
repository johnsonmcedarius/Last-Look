-- ─────────────────────────────────────────────────────────────────────────────
-- EditorialMirrorVFX: Client-side visual effects for 'The Editorial Mirror' Showstopper
-- Implements: Diamond/crystal texture, kaleidoscope filter, crystalline footstep sounds
-- ─────────────────────────────────────────────────────────────────────────────

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local Lighting = game:GetService("Lighting")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

-- ── Settings ─────────────────────────────────────────────────────────────────
local KALEIDOSCOPE_INTENSITY = 0.6
local CRYSTAL_COLOR = Color3.fromRGB(200, 255, 255)
local CHIME_INTERVAL = 0.3

-- ── State ────────────────────────────────────────────────────────────────────
local isActive = false
local colorCorrection = nil
local blurEffect = nil
local crystalHighlight = nil
local crystalTexture = nil
local chimeTime = 0
local originalMaterials = {}
local originalColors = {}

-- ── Helper Functions ─────────────────────────────────────────────────────────

local function applyKaleidoscopeFilter()
	-- Create color correction for kaleidoscope effect
	if not colorCorrection then
		colorCorrection = Instance.new("ColorCorrectionEffect")
		colorCorrection.Name = "KaleidoscopeFilter"
		colorCorrection.Parent = Lighting
	end
	
	-- Apply kaleidoscope-like color shift
	colorCorrection.Saturation = 0.5
	colorCorrection.Contrast = 0.3
	colorCorrection.Brightness = 0.1
	colorCorrection.TintColor = Color3.fromRGB(200, 255, 255) -- Cyan tint
	
	-- Add slight blur for dreamy effect
	if not blurEffect then
		blurEffect = Instance.new("BlurEffect")
		blurEffect.Name = "KaleidoscopeBlur"
		blurEffect.Parent = Lighting
	end
	
	TweenService:Create(blurEffect, TweenInfo.new(0.5), {Size = 2}):Play()
	
	print("[EditorialMirror] Kaleidoscope filter applied")
end

local function removeKaleidoscopeFilter()
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
	
	if blurEffect then
		TweenService:Create(blurEffect, TweenInfo.new(0.5), {Size = 0}):Play()
		task.delay(0.5, function()
			if blurEffect then
				blurEffect:Destroy()
				blurEffect = nil
			end
		end)
	end
end

local function applyCrystalTexture(character)
	-- Store original materials and colors
	originalMaterials = {}
	originalColors = {}
	
	for _, part in ipairs(character:GetDescendants()) do
		if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
			originalMaterials[part] = part.Material
			originalColors[part] = part.Color
			
			-- Apply crystal/diamond appearance
			part.Material = Enum.Material.DiamondPlate
			part.Color = CRYSTAL_COLOR
			part.Reflectance = 0.8
		end
	end
	
	-- Add highlight for extra sparkle
	crystalHighlight = Instance.new("Highlight")
	crystalHighlight.Name = "CrystalHighlight"
	crystalHighlight.FillColor = CRYSTAL_COLOR
	crystalHighlight.FillTransparency = 0.5
	crystalHighlight.OutlineColor = Color3.fromRGB(255, 255, 255)
	crystalHighlight.OutlineTransparency = 0
	crystalHighlight.Parent = character
	
	print("[EditorialMirror] Crystal texture applied")
end

local function removeCrystalTexture(character)
	-- Restore original materials and colors
	for part, material in pairs(originalMaterials) do
		if part and part.Parent then
			part.Material = material
			part.Color = originalColors[part]
			part.Reflectance = 0
		end
	end
	
	originalMaterials = {}
	originalColors = {}
	
	if crystalHighlight then
		crystalHighlight:Destroy()
		crystalHighlight = nil
	end
	
	print("[EditorialMirror] Crystal texture removed")
end

local function playCrystallineChime()
	-- High-pitched crystalline chime sound
	local chime = Instance.new("Sound")
	chime.SoundId = "rbxassetid://0" -- Replace with crystal chime sound
	chime.Volume = 0.3
	chime.Pitch = 1.5 + math.random() * 0.5 -- Random pitch variation
	chime.Parent = camera
	chime:Play()
	Debris:AddItem(chime, 2)
end

-- ── Module Export ─────────────────────────────────────────────────────────────

local EditorialMirrorVFX = {}

function EditorialMirrorVFX.Activate(playerArg, data)
	local targetPlayer = playerArg or player
	local char = targetPlayer.Character
	if not char then return end
	
	isActive = true
	
	-- ── 1. APPLY CRYSTAL TEXTURE TO USER ──
	applyCrystalTexture(char)
	
	-- ── 2. APPLY KALEIDOSCOPE FILTER (for enemies, but we apply locally for user too) ──
	-- Note: The kaleidoscope filter should only apply to enemies, but since
	-- we're on the client, we check if this is the local player
	if targetPlayer == player then
		-- User gets crystal texture, enemies get kaleidoscope
		-- This would be handled by server firing to enemies only
	else
		-- This client is an enemy - apply kaleidoscope
		applyKaleidoscopeFilter()
	end
	
	-- ── 3. PLAY ACTIVATION SOUND ──
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local success, SoundService = pcall(function()
		return require(ReplicatedStorage:WaitForChild("SoundService"))
	end)
	if success and SoundService and SoundService.PlayLocal then
		SoundService.PlayLocal("EditorialMirrorActivate")
	end
	
	-- Initial chime
	playCrystallineChime()
	
	chimeTime = 0
	
	print("[EditorialMirror] Activated - Reflecting the vibe!")
end

function EditorialMirrorVFX.Deactivate()
	isActive = false
	
	local char = player.Character
	if char then
		removeCrystalTexture(char)
	end
	
	removeKaleidoscopeFilter()
	
	print("[EditorialMirror] Deactivated")
end

function EditorialMirrorVFX.OnRenderStepped(deltaTime)
	if not isActive then return end
	
	-- Play crystalline chimes periodically
	chimeTime = chimeTime + deltaTime
	if chimeTime >= CHIME_INTERVAL then
		chimeTime = 0
		playCrystallineChime()
	end
end

function EditorialMirrorVFX.IsActive()
	return isActive
end

return EditorialMirrorVFX