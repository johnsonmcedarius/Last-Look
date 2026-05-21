local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local RemoteRegistry = {}


local REMOTE_NAMES = {
	-- Core
	"FreezeEvent", "NotifyCritics", "UpdateFabricUI",
	"StunCritic", "StunCriticRadius",

	-- Fabric
	"PlayProximitySound", "ShowExitWaypoint", "DepositVFX",
	"SabotagePing", "RackStateChanged", "ObjectiveWarning", "SabotageAnnounce",

	-- Pass system
	"PassFabric", "PlayPoofVFX", "SetTeammateGlow",

	-- Showstopper
	"ActivateShowstopper", "UpdateShowstopperCharge", "ShowstopperFullAlert",
	"ShowstopperAnnounce", "ShowstopperLocalTrigger",

	-- HUD / Rewards
	"ShowRewardPopup", "HUDCooldownUpdate", "AbilityCooldownUpdate",
	"DashCooldownUpdate",

	-- Abilities
	"AbilityHit", "HairsprayExplode", "PlaceHeelTrap",
	"AbilitySlotUnlock", "SpinAbility",

	-- Freeze / Tag
	"SpawnPodiumVFX", "DespawnPodiumVFX", "UpdateCancelTimer",
	"UpdateStrikes", "PlayerEliminated",

	-- Trend / Buff
	"TrendTrackerActivate", "Show75Warning",
	"BlindClient", "PlayDazedAnim", "CameraShake",
	"ShowExplosionVFX",

	-- Spectate
	"StartSpectate", "StopSpectate", "CycleSpectate",
	"PlaceBet", "BetResult", "UpdateBetTargets",

	-- MVP / End round
	"ShowMVP", "ShowEndStats", "PostMatchXP",

	-- Sound
	"PlaySound",

	-- Gacha / Crates
	"OpenCrate", "CrateResult", "BatchOpenCrate", "BatchCrateResults",
	"GlobalAnnouncement",

	-- Daily Lookbook
	"GetDailyChallenges", "CompleteChallengeProgress", "DailyChallengeUpdate",

	-- Codes
	"RedeemCode", "CodeResult",

	-- Gifting
	"GiftItem", "GiftReceived",

	-- Nameplate
	"UpdateNameplate", "ShowCancelledBanner", 
	
	-- Shop / Economy
	"ShopRequest",
}

-- Cache
local cache = {}

function RemoteRegistry.Get(name)
	if cache[name] then return cache[name] end

	local existing = Remotes:FindFirstChild(name)
	if existing then
		cache[name] = existing
		return existing
	end

	-- Name BEFORE parent to avoid race condition
	local remote = Instance.new("RemoteEvent")
	remote.Name   = name
	remote.Parent = Remotes

	cache[name] = remote
	return remote
end

function RemoteRegistry.GetFunction(name)
	if cache[name] then return cache[name] end

	local existing = Remotes:FindFirstChild(name)
	if existing then
		cache[name] = existing
		return existing
	end

	local rf = Instance.new("RemoteFunction")
	rf.Name   = name
	rf.Parent = Remotes

	cache[name] = rf
	return rf
end

-- Pre-create all remotes at startup
for _, name in ipairs(REMOTE_NAMES) do
	RemoteRegistry.Get(name)
end

return RemoteRegistry