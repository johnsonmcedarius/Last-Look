local CombatRegistry = {}

-- ── SHOWSTOPPERS (Ultimates - Require 100 Charge) ──
CombatRegistry.Showstoppers = {
	["The Main Event"] = {
		Category = "Showstopper",
		ChargeCost = 100,
		Duration = 10,
		Radius = 20, -- Trend-Killer Aura radius
		AnimationId = "",
		VFXAssetName = "MainEventVFX",
		SFXId = "rbxassetid://0", -- High-energy house track
		EffectType = "GlobalBuff",
	},
	["The Glitch Gala"] = {
		Category = "Showstopper",
		ChargeCost = 100,
		Duration = 8,
		Radius = 30,
		AnimationId = "",
		VFXAssetName = "GlitchGalaVFX",
		SFXId = "rbxassetid://0",
		EffectType = "Zone",
	},
	["The Velvet Rope"] = {
		Category = "Showstopper",
		ChargeCost = 100,
		Duration = 7,
		Radius = 40,
		AnimationId = "",
		VFXAssetName = "VelvetRopeVFX",
		SFXId = "rbxassetid://0",
		EffectType = "Zone",
	},
	["The Flash Mob"] = {
		Category = "Showstopper",
		ChargeCost = 100,
		Duration = 12,
		Radius = 0,
		AnimationId = "",
		VFXAssetName = "FlashMobVFX",
		SFXId = "rbxassetid://0",
		EffectType = "GlobalBuff",
	},
	["The Editorial Mirror"] = {
		Category = "Showstopper",
		ChargeCost = 100,
		Duration = 6,
		Radius = 0,
		AnimationId = "",
		VFXAssetName = "EditorialMirrorVFX",
		SFXId = "rbxassetid://0",
		EffectType = "Status",
	},
	["The Paparazzi Swarm"] = {
		Category = "Showstopper",
		ChargeCost = 100,
		Duration = 9,
		Radius = 0, -- Global swarm
		AnimationId = "",
		VFXAssetName = "PaparazziSwarmVFX",
		SFXId = "rbxassetid://0",
		EffectType = "ScreenModify",
	},
	["The Afterparty"] = {
		Category = "Showstopper",
		ChargeCost = 100,
		Duration = 5,
		Radius = 0, -- Global
		AnimationId = "",
		VFXAssetName = "AfterpartyVFX",
		SFXId = "rbxassetid://0",
		EffectType = "Resurrection",
	},
}

-- ── TACTICAL ABILITIES (Require Cooldowns) ──
CombatRegistry.Abilities = {
	["The Smoke Machine"] = {
		Category = "Ability",
		Cooldown = 8,
		Duration = 5,
		Radius = 20,
		AnimationId = "",
		VFXAssetName = "SmokeMachineVFX",
		SFXId = "rbxassetid://0",
		EffectType = "Zone",
	},
	["Slippery Gloss"] = {
		Category = "Ability",
		Cooldown = 8,
		Duration = 2,
		Radius = 15,
		AnimationId = "",
		VFXAssetName = "SlipperyGlossVFX",
		SFXId = "rbxassetid://0",
		EffectType = "Physics",
	},
	["The Wind Machine"] = {
		Category = "Ability",
		Cooldown = 8,
		Duration = 3,
		Radius = 30, -- Linear pushback
		AnimationId = "",
		VFXAssetName = "WindMachineVFX",
		SFXId = "rbxassetid://0",
		EffectType = "Physics",
	},
	["Glitter Perfume Bomb"] = {
		Category = "Ability",
		Cooldown = 8,
		Duration = 2,
		Radius = 15,
		AnimationId = "",
		VFXAssetName = "PerfumeBombVFX",
		SFXId = "rbxassetid://0",
		EffectType = "Projectile",
	},
	["The Measuring Tape"] = {
		Category = "Ability",
		Cooldown = 8,
		Duration = 0, -- Instant pull
		Radius = 50, -- Range
		AnimationId = "",
		VFXAssetName = "MeasuringTapeVFX",
		SFXId = "rbxassetid://0",
		EffectType = "Physics",
	},
	["The Fabric Shield"] = {
		Category = "Ability",
		Cooldown = 8,
		Duration = 4,
		Radius = 10,
		AnimationId = "",
		VFXAssetName = "FabricShieldVFX",
		SFXId = "rbxassetid://0",
		EffectType = "Zone",
	},
	["The Mannequin Decoy"] = {
		Category = "Ability",
		Cooldown = 12,
		Duration = 5,
		Radius = 0,
		AnimationId = "",
		VFXAssetName = "MannequinDecoyVFX",
		SFXId = "rbxassetid://0",
		EffectType = "Illusion",
	}
}

return CombatRegistry

