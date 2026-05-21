local SharedConfig = {
	DATA_VERSION = "v1.5",

	-- ── Team Names ──
	TEAMS = {
		DESIGNER = "Designers",
		CRITIC = "Critics",
	},

	-- ── Core Gameplay Constants ──
	MAX_INTERACTION_DISTANCE = 15, 
	TOTAL_FABRIC_NEEDED = 5,
	ROUND_DURATION = 300,
	INTERMISSION_DURATION = 15,
	RACK_COOLDOWN = 5,
	PASS_RANGE = 8,
	FREEZE_COOLDOWN = 4.0,  -- Anti-spam for weapon freeze attempts

	-- ── Sabotage Balance ──
	SABOTAGE_LIMIT = 2,       
	SABOTAGE_DURATION = 20,       
	SABOTAGE_COOLDOWN = 45,       

	-- ── Movement & Feel ──
	WALK_SPEED = 16,
	SPRINT_SPEED = 26,            
	DASH_SPEED = 95,
	DASH_DURATION = 0.22,
	DASH_COOLDOWN = 0.8,          
	JUMP_POWER = 50,

	-- ── Economics & Gacha ──
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

	-- ── Inventory Categories ──
	CATEGORIES = {
		SKINS = "Skins",
		PODIUMS = "Podiums",
		WEAPON_SKINS = "WeaponSkins",
		SKIN_EFFECTS = "SkinEffects",
		SHOWSTOPPERS = "Showstoppers",
		EMOTES = "Emotes",
		ABILITIES = "Abilities",
	},

	-- ── Progression ──
	BASE_XP = 100,
	XP_MULTIPLIER = 1.18,

	LOGIN_REWARDS = {
		[1] = {Type = "Coins", Amount = 200},
		[2] = {Type = "Coins", Amount = 400},
		[3] = {Type = "Coins", Amount = 600},
		[4] = {Type = "Coins", Amount = 800},
		[5] = {Type = "Coins", Amount = 1000},
		[6] = {Type = "Coins", Amount = 1500},
		[7] = {Type = "Crate", Amount = 1, CrateType = "CoinDesignerCrate"}
	},

	-- ── Competition Points (MVP Engine) ──
	POINTS = {
		FABRIC_COLLECT = 10,
		FABRIC_DUNK    = 50,
		SHRED_FABRIC   = 50,
		SABOTAGE       = 40,
		CLEAN_RUNWAY   = 100,
	},

	-- ── Reward Config (XP & Coins) ──
	-- PARITY: Both teams have equal rewards
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
		
		-- PHASE 7: Universal objective completion reward
		-- DataManager doesn't need to check which team did what
		ObjectiveComplete  = {XP = 25,   Coins = 10},
	},

	-- ── MVP Scoring Weights ──
	MVP_WEIGHTS = {
		DUNK_MULTIPLIER = 10,
		FABRIC_MULTIPLIER = 2,
		UNFREEZE_MULTIPLIER = 5,
		NEVER_FROZEN_BONUS = 15,
		FREEZE_MULTIPLIER = 10,
		SABOTAGE_MULTIPLIER = 5,
	},

	-- ── Pressure Detection ──
	PRESSURE = {
		DETECTION_RANGE = 10,
		TIME_THRESHOLD = 15,
	},

	-- ── Redeemable Codes ──
	CODES = {
		LASTLOOK  = {Reward = "Coins",             Amount = 100, Active = true},
		RUNWAY100 = {Reward = "Coins",             Amount = 100, Active = true},
		VIPACCESS = {Reward = "CoinDesignerCrate", Amount = 1,   Active = true},
		XPBOOST   = {Reward = "XP",                Amount = 200, Active = true},
	},

	-- ── Jump Pad Settings ──
	JUMPPAD = {
		HEIGHT = 100,
		COOLDOWN = 0.1,
		RESET_DELAY = 0.1,
		DEFAULT_JUMP_HEIGHT = 7.2,
	},

	-- ── CollectionService Tags ──
	TAGS = {
		JUMPPAD = "JumpPad",
		DESIGNER_PROMPT = "DesignerPrompt",
		CRITIC_PROMPT = "CriticPrompt",
	},

	-- ── Hitbox Parity (PHASE 2: Anti Pay-to-Win) ──
	HITBOX_PARITY = {
		-- Standard character hitbox dimensions
		VALID_HITBOX_SIZE = Vector3.new(4, 5, 1),
		-- Maximum allowed deviation from standard (percentage)
		ALLOWED_DEVIATION = 0.1, -- 10% tolerance
		-- Whether to log warnings for non-compliant skins
		ENABLE_VALIDATION = true,
	},

	-- ── Character Stats & Abilities ──
	MAX_CHARGE = 100,
	CANCELLATION_TIME = 30,
	ANTI_CAMP_DISTANCE = 15,
	DUNK_DENIED_RANGE = 5,

	CHARGES = {
		-- Shared Events
		FabricDunk = 20,
		FabricShred = 20,
		FabricPass = 10,
		TeamRescue = 25,
		AbilityHit = 5,
		CloseDodge = 3,

		-- Freeze Events (Both Teams)
		FreezeDesigner = 30,
		FreezeCritic = 30,
		DunkDenied = 35,
		ShredDenied = 35,
		FinalCancel = 40,
		InterceptPass = 15,
	}
}

return SharedConfig