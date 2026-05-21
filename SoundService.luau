local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SoundService = {}


-- SOUND ID REGISTRY

SoundService.Sounds = {

	-- Fabric / Objective
	FabricDunk        = "rbxassetid://0",  -- Heavy SWOOSH-THUMP + runway beat
	FabricPickup      = "rbxassetid://0",  -- Snip/zip
	FabricPass        = "rbxassetid://0",  -- Soft poof + sparkle chime
	FabricDeposit     = "rbxassetid://0",  -- Weight of contribution thud

	-- 75% Alarm
	PaparazziStorm    = "rbxassetid://0",  -- Frantic shutter clicks

	-- Abilities
	HairsprayHiss     = "rbxassetid://0",  -- High-pressure TSSSSST
	HairsprayWhiz     = "rbxassetid://0",  -- Projectile whizz in flight
	HairsprayExplode  = "rbxassetid://0",  -- Bomb explosion
	CameraFlash       = "rbxassetid://0",  -- Camera shutter
	HeelThud          = "rbxassetid://0",  -- 2lb weight THUD on floor
	AbilityHit        = "rbxassetid://0",  -- Weapon connects
	AbilityMiss       = "rbxassetid://0",  -- Weapon misses

	-- Hairspray camera shake (Critic gets stunned)
	StunShake         = "rbxassetid://0",  -- Hit impact sound for critic

	-- Tag / Freeze
	PodiumSpawn       = "rbxassetid://0",  -- Podium materializes
	PodiumDespawn     = "rbxassetid://0",  -- Podium disappears
	CrowdGasp         = "rbxassetid://0",  -- Crowd reacts to a freeze
	PlayerFrozen      = "rbxassetid://0",  -- Ice/freeze hit sound

	-- Strike system
	Strike1           = "rbxassetid://0",  -- Glass crack / scary ping
	Strike2           = "rbxassetid://0",  -- Louder glass crack
	Strike3Eliminated = "rbxassetid://0",  -- Dramatic orchestral hit
	CrowdBoo          = "rbxassetid://0",  -- Crowd booing fade

	-- Rescue
	PlayerUnfrozen    = "rbxassetid://0",  -- Rescue pop/sparkle

	-- Showstopper
	ShowstopperReady  = "rbxassetid://0",  -- Camera shutter + bass drop
	ShowstopperActivate = "rbxassetid://0", -- Ultimate fire sound
	MainEventMusic   = "rbxassetid://0",  -- High-energy house track for The Main Event
	AfterpartyActivate = "rbxassetid://0", -- Bass-heavy afterparty remix
	PaparazziShutterLoop = "rbxassetid://0", -- Loop of shutter clicks

	-- Round / Role
	RoleRevealDesigner = "rbxassetid://0", -- Fanfare for Designers
	RoleRevealCritic   = "rbxassetid://0", -- Ominous sting for Critics

	-- Trend Tracker
	TrendTrackerOn    = "rbxassetid://0",  -- Ping/whoosh for critic buff
	TrendTrackerWarning = "rbxassetid://0", -- Alarm for designers

	-- Spectate / Betting
	BetPlaced         = "rbxassetid://0",  -- Coin clink

	-- Dash
	FashionDash       = "rbxassetid://0",  -- Whoosh burst

	-- ── UI Button Sounds ─────────────────────────────────────────────────────
	-- Replace rbxassetid://0 with real IDs. UISoundController reads these by name.
	-- To add a new button sound: add an entry here + a rule in UISoundController.SoundMap.
	UI_Click          = "rbxassetid://6042053626",  -- Clean, snappy soft click
	UI_Hover          = "rbxassetid://6042053626",  -- Subtle hover tick (same or lighter)
	UI_Close          = "rbxassetid://5999302929",  -- Dismiss / swipe away
	UI_Claim          = "rbxassetid://4590662766",  -- Reward chime — coins jingle
	UI_Equip          = "rbxassetid://6042053626",  -- Confirm / equip snap
	UI_Purchase       = "rbxassetid://4590662766",  -- Purchase success chime
	UI_Error          = "rbxassetid://6042053626",  -- Negative buzz / denied
	UI_NavTab         = "rbxassetid://6042053626",  -- Light tab switch tick
	UI_OpenPanel      = "rbxassetid://6042053626",  -- Panel slides open
	UI_DailyOpen      = "rbxassetid://4590662766",  -- Lookbook opens — warm chime
	UI_DailyClaim     = "rbxassetid://4590662766",  -- Day claimed — coin shower
	UI_StreakRecover  = "rbxassetid://6042053626",  -- Streak recovered — snappy
	UI_CrateReveal    = "rbxassetid://4590662766",  -- Crate button pressed
}

-- ============================================================
-- PlayAt: attach a sound to a BasePart in world space (3D)
-- ============================================================
function SoundService.PlayAt(soundName, part, volume, pitch)
	local id = SoundService.Sounds[soundName]
	if not id or id == "rbxassetid://0" then
		-- Silent if ID not set yet
		return
	end
	if not part or not part.Parent then return end

	local sound = Instance.new("Sound")
	sound.SoundId = id
	sound.Volume = volume or 1
	sound.PlaybackSpeed = pitch or 1
	sound.RollOffMaxDistance = 60
	sound.Parent = part
	sound:Play()
	Debris:AddItem(sound, sound.TimeLength + 1)
end

-- ============================================================
-- PlayGlobal: fire to all clients to play a sound at a position
-- Called from server; clients handle actual playback via remote
-- ============================================================
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local PlaySoundRemote = Remotes:FindFirstChild("PlaySound") or Instance.new("RemoteEvent", Remotes)
PlaySoundRemote.Name = "PlaySound"

function SoundService.FireToAll(soundName, position)
	PlaySoundRemote:FireAllClients(soundName, position)
end

function SoundService.FireToClient(player, soundName, position)
	PlaySoundRemote:FireClient(player, soundName, position)
end

-- ============================================================
-- PlayLocal: for use inside LocalScripts (client-side only)
-- ============================================================
function SoundService.PlayLocal(soundName, volume, pitch)
	local id = SoundService.Sounds[soundName]
	if not id or id == "rbxassetid://0" then return end

	local camera = workspace.CurrentCamera
	local sound = Instance.new("Sound")
	sound.SoundId = id
	sound.Volume = volume or 1
	sound.PlaybackSpeed = pitch or 1
	sound.Parent = camera
	sound:Play()
	Debris:AddItem(sound, sound.TimeLength + 1)
end

return SoundService
