local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local VFX = {}

-- ── VFX Culling Configuration ─────────────────────────────────────────────
local MAX_VFX_RANGE = 100 -- Studs: effects beyond this are culled
local LOCAL_ONLY_IMPORTANCE = true -- Enable local-only importance checks

-- Pool storage (optional, used if USE_POOLING = true)
local USE_POOLING = false
local pool = {} -- [effectName] = {available instances}

-------------------------------------------------
-- Internal: get the VFX folder
-------------------------------------------------
local function getVFXFolder()
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	if not assets then
		warn("[VFX] ReplicatedStorage.Assets folder missing!")
		return nil
	end
	local vfxFolder = assets:FindFirstChild("VFX")
	if not vfxFolder then
		warn("[VFX] ReplicatedStorage.Assets.VFX folder missing!")
		return nil
	end
	return vfxFolder
end

-------------------------------------------------
-- Get local player's position for culling
-------------------------------------------------
local function getLocalPlayerPosition()
	local player = Players.LocalPlayer
	if not player then return nil end
	local character = player.Character
	if not character then return nil end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then return nil end
	return root.Position
end

-------------------------------------------------
-- Check if effect should be rendered (culling)
-------------------------------------------------
local function shouldRenderEffect(position, localOnly)
	-- If this is a local-only effect, always render for the triggering player
	if localOnly then
		return true
	end
	
	-- Distance-based culling for non-local effects
	local localPos = getLocalPlayerPosition()
	if not localPos then return true end -- Default to render if we can't check
	
	local distance = (position - localPos).Magnitude
	return distance <= MAX_VFX_RANGE
end

-------------------------------------------------
-- Play: clone and position an effect
-- effectName: the name of the asset inside Assets/VFX
-- position: Vector3
-- parent: optional (defaults to workspace)
-- lifetime: optional override for how long before Debris cleans it up
-- localOnly: optional (if true, only renders for triggering player)
-------------------------------------------------
function VFX.Play(effectName, position, parent, lifetime, localOnly)
	-- VFX Culling: Skip rendering if too far from local player
	if not shouldRenderEffect(position, localOnly) then
		return nil
	end
	
	local vfxFolder = getVFXFolder()
	if not vfxFolder then return end

	local template = vfxFolder:FindFirstChild(effectName)
	if not template then
		warn("[VFX] Effect not found: " .. tostring(effectName))
		return
	end

	local clone = template:Clone()

	-- Position the effect
	if clone:IsA("BasePart") then
		clone.CFrame = CFrame.new(position)
	elseif clone:IsA("Model") then
		if clone.PrimaryPart then
			clone:PivotTo(CFrame.new(position))
		else
			clone:SetPrimaryPartCFrame(CFrame.new(position))
		end
	elseif clone:IsA("ParticleEmitter") then
		-- If it's a standalone emitter, wrap it
		local host = Instance.new("Part")
		host.Size = Vector3.new(0.1, 0.1, 0.1)
		host.CFrame = CFrame.new(position)
		host.Anchored = true
		host.CanCollide = false
		host.Transparency = 1
		clone.Parent = host
		clone = host
	end

	clone.Parent = parent or workspace

	-- Enable any particle emitters in descendants
	for _, child in ipairs(clone:GetDescendants()) do
		if child:IsA("ParticleEmitter") or child:IsA("Trail") then
			child.Enabled = true
		end
	end

	-- Cleanup via Debris service (never yields the calling script)
	local cleanupTime = lifetime or 3
	Debris:AddItem(clone, cleanupTime)

	return clone
end

-------------------------------------------------
-- PlayLocal: Effect that only renders for the local player
-- Use for dash rainbows, personal ability effects, etc.
-------------------------------------------------
function VFX.PlayLocal(effectName, position, parent, lifetime)
	return VFX.Play(effectName, position, parent, lifetime, true)
end

-------------------------------------------------
-- PlayWithRange: Effect with custom max range
-------------------------------------------------
function VFX.PlayWithRange(effectName, position, maxRange, parent, lifetime)
	local localPos = getLocalPlayerPosition()
	if localPos and (position - localPos).Magnitude > maxRange then
		return nil
	end
	return VFX.Play(effectName, position, parent, lifetime)
end

-------------------------------------------------
-- PlayAt: attach effect to a part (follows it)
-------------------------------------------------
function VFX.PlayAt(effectName, part, offset, lifetime)
	local vfxFolder = getVFXFolder()
	if not vfxFolder then return end

	local template = vfxFolder:FindFirstChild(effectName)
	if not template then
		warn("[VFX] Effect not found: " .. tostring(effectName))
		return
	end

	local clone = template:Clone()
	clone.Parent = part

	if clone:IsA("BasePart") then
		clone.CFrame = part.CFrame * CFrame.new(offset or Vector3.zero)
	end

	local cleanupTime = lifetime or 3
	Debris:AddItem(clone, cleanupTime)

	return clone
end

-------------------------------------------------
-- Stop: disable particle emitters on a running effect
-- (call this if you want to let particles fade out naturally)
-------------------------------------------------
function VFX.Stop(effectInstance)
	if not effectInstance or not effectInstance.Parent then return end
	for _, child in ipairs(effectInstance:GetDescendants()) do
		if child:IsA("ParticleEmitter") then
			child.Enabled = false
		end
	end
end

-------------------------------------------------
-- PlaySabotageVFX: Visual indicator for sabotaged objectives
-- Creates pulsing glitch effect + steam particles
-------------------------------------------------
function VFX.PlaySabotageVFX(object)
	local TweenService = game:GetService("TweenService")
	local base = object:IsA("BasePart") and object or object:FindFirstChildWhichIsA("BasePart")
	if not base then return end

	-- Create glitch overlay part
	local glitchPart = Instance.new("Part")
	glitchPart.Name = "GlitchOverlay"
	glitchPart.Size = base.Size * 1.1
	glitchPart.CFrame = base.CFrame
	glitchPart.Anchored = true
	glitchPart.CanCollide = false
	glitchPart.Transparency = 0.7
	glitchPart.Color = Color3.fromRGB(255, 0, 100)
	glitchPart.Material = Enum.Material.Neon
	glitchPart.Parent = object

	-- Pulsing effect loop
	task.spawn(function()
		while glitchPart and glitchPart.Parent do
			TweenService:Create(glitchPart, TweenInfo.new(0.5), {Transparency = 0.9}):Play()
			task.wait(0.5)
			TweenService:Create(glitchPart, TweenInfo.new(0.5), {Transparency = 0.5}):Play()
			task.wait(0.5)
		end
	end)

	-- Add steam particle effect if available
	local vfxFolder = getVFXFolder()
	if vfxFolder then
		local steamTemplate = vfxFolder:FindFirstChild("SabotageSteam")
		if steamTemplate then
			local steam = steamTemplate:Clone()
			steam.Parent = object
			for _, emitter in ipairs(steam:GetDescendants()) do
				if emitter:IsA("ParticleEmitter") then
					emitter.Enabled = true
				end
			end
		end
	end

	return glitchPart
end

return VFX
