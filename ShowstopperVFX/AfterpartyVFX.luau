-- ─────────────────────────────────────────────────────────────────────────────
-- AfterpartyVFX: Client-side visual effects for 'The Afterparty'
-- ─────────────────────────────────────────────────────────────────────────────

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local player = Players.LocalPlayer

local AfterpartyVFX = {}

function AfterpartyVFX.Activate(playerArg, data)
	local targetPlayer = playerArg or player
	local char = targetPlayer.Character
	if not char or not char.PrimaryPart then return end
	
	local pos = char.PrimaryPart.Position
	
	print("[AfterpartyVFX] Activating pulse at " .. tostring(pos))

	-- ── 1. NEON PINK PULSE WAVE ──
	local pulse = Instance.new("Part")
	pulse.Name = "AfterpartyPulseWave"
	pulse.Shape = Enum.PartType.Ball
	pulse.Color = Color3.fromRGB(255, 0, 127) -- Neon Pink
	pulse.Material = Enum.Material.Neon
	pulse.Transparency = 0.5
	pulse.CanCollide = false
	pulse.Anchored = true
	pulse.Size = Vector3.new(1, 1, 1)
	pulse.CFrame = CFrame.new(pos)
	pulse.Parent = workspace
	
	TweenService:Create(pulse, TweenInfo.new(1.5, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
		Size = Vector3.new(100, 100, 100),
		Transparency = 1
	}):Play()
	Debris:AddItem(pulse, 1.5)
	
	-- ── 2. CONFETTI BURST ──
	local success, VFXModule = pcall(function()
		return require(ReplicatedStorage:WaitForChild("VFXModule"))
	end)
	
	if success and VFXModule and VFXModule.Play then
		-- Fire confetti burst map-wide (0, 20, 0 is a good map-center approximation)
		VFXModule.Play("AfterpartyConfetti", Vector3.new(0, 20, 0))
		
		-- Also a burst on the player
		VFXModule.Play("AfterpartyPulse", pos)
	end
	
	-- ── 3. SOUND ──
	local soundSuccess, SoundService = pcall(function()
		return require(ReplicatedStorage:WaitForChild("SoundService"))
	end)
	if soundSuccess and SoundService and SoundService.PlayLocal then
		SoundService.PlayLocal("AfterpartyActivate")
	end
end

function AfterpartyVFX.Deactivate()
	-- One-shot visual; no long-term state to cleanup
end

return AfterpartyVFX
