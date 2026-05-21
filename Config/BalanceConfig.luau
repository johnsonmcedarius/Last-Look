-- ─────────────────────────────────────────────────────────────────────────────
-- BalanceConfig: Rewards, cooldowns, points, and economy settings
-- ─────────────────────────────────────────────────────────────────────────────

return {
	-- Movement & Feel
	WALK_SPEED = 16,
	SPRINT_SPEED = 26,
	DASH_SPEED = 95,
	DASH_DURATION = 0.22,
	DASH_COOLDOWN = 0.8,
	JUMP_POWER = 50,

	-- Freeze Cooldown (Anti-Spam)
	FREEZE_COOLDOWN = 4.0,

	-- Competition Points (MVP Engine)
	POINTS = {
		FABRIC_COLLECT = 10,
		FABRIC_DUNK    = 50,
		SHRED_FABRIC   = 50,
		SABOTAGE       = 40,
		CLEAN_RUNWAY   = 100,
	},

	-- Reward Config (XP & Coins) - PARITY: Both teams have equal rewards
	REWARDS = {
		DesignerWin       = {XP = 175,  Coins = 60},
		CriticWin         = {XP = 175,  Coins = 60},
		FabricCollect     = {XP = 15,   Coins = 5},
		FabricDunk        = {XP = 25,   Coins = 10},
		FabricShred       = {XP = 25,   Coins = 10},
		UnfreezeAlly      = {XP = 50,   Coins = 15},
		SurvivalPerMinute = {XP = 10,   Coins = 2},
		FreezeDesigner    = {XP = 75,   Coins = 20},
		FreezeCritic      = {XP = 75,   Coins = 20},
		SabotageStation   = {XP = 25,   Coins = 10},
		ApplyPressure     = {XP = 10,   Coins = 3},
		DesignerMVP       = {XP = 100,  Coins = 50},
		CriticMVP         = {XP = 100,  Coins = 50},
	},

	-- MVP Scoring Weights
	MVP_WEIGHTS = {
		DUNK_MULTIPLIER = 10,
		FABRIC_MULTIPLIER = 2,
		UNFREEZE_MULTIPLIER = 5,
		NEVER_FROZEN_BONUS = 15,
		FREEZE_MULTIPLIER = 10,
		SABOTAGE_MULTIPLIER = 5,
	},

	-- Showstopper Charges
	CHARGES = {
		FabricDunk = 20,
		FabricShred = 20,
		FabricPass = 10,
		TeamRescue = 25,
		AbilityHit = 5,
		CloseDodge = 3,
		FreezeDesigner = 30,
		FreezeCritic = 30,
		DunkDenied = 35,
		ShredDenied = 35,
		FinalCancel = 40,
		InterceptPass = 15,
	},

	-- Pressure Detection
	PRESSURE = {
		DETECTION_RANGE = 10,
		TIME_THRESHOLD = 15,
	},

	-- Economics & Gacha
	COIN_CRATE_COST = 500,
	PITY_THRESHOLD = 50,
	ROBUX_PRODUCT_ID = 0,

	-- Rarity Weights (Total: 1000)
	RARITY_WEIGHTS = { 
		Common = 650, 
		Rare = 300, 
		Legendary = 40, 
		Mythic = 10 
	},

	-- Duplicate Rewards (Coins)
	DUPLICATE_REWARDS = {
		Common = 25,
		Rare = 75,
		Legendary = 1000,
		Mythic = 5000
	},
}