local MarketplaceRegistry = {}

-- GAME PASSES (one-time purchase, permanent)

MarketplaceRegistry.GamePasses = {

	VIPItGirl = {
		Id          = 0,           -- TODO
		Name        = "VIP It Girl",
		Description = "VIP nameplate tag, auto VIP Podium, +20% Coins every match.",
		Perks = {
			IsVIP        = true,
			CoinBonus    = 0.20,     -- 20% multiplier on all coin gains
			AutoPodium   = "VIPPodium",
		},
	},

	TrustFund = {
		Id          = 0,           -- TODO
		Name        = "Trust Fund",
		Description = "Double Coins on all end-of-match payouts.",
		Perks = {
			CoinsMultiplier = 2,
		},
	},

	Trendsetter = {
		Id          = 0,           -- TODO
		Name        = "Trendsetter",
		Description = "Double XP on all end-of-match payouts.",
		Perks = {
			XPMultiplier = 2,
		},
	},

	AbilitySlot2 = {
		Id          = 0,           -- TODO: 149 Robux
		Name        = "Ability Slot 2",
		Description = "Unlock your second ability spin slot.",
		Perks = {
			AbilitySlot = 2,
		},
	},

	AbilitySlot3 = {
		Id          = 0,           -- TODO: 149 Robux
		Name        = "Ability Slot 3",
		Description = "Unlock your third ability spin slot.",
		Perks = {
			AbilitySlot = 3,
		},
	},
}

-- ============================================================
-- DEVELOPER PRODUCTS (re-purchasable)
-- ============================================================
MarketplaceRegistry.Products = {

	-- Coin packs
	Coins500 = {
		Id     = 0,       -- TODO
		Name   = "500 Coins",
		Reward = {Coins = 500},
	},
	Coins1200 = {
		Id     = 0,       -- TODO
		Name   = "1,200 Coins",
		Reward = {Coins = 1200},
	},
	Coins2800 = {
		Id     = 0,       -- TODO
		Name   = "2,800 Coins",
		Reward = {Coins = 2800},
	},

	-- Crate purchases
	RobuxDesignerCrate = {
		Id     = 0,       -- TODO: 99 Robux
		Name   = "Robux Designer Crate",
		Reward = {Crate = "RobuxDesignerCrate", Amount = 1},
	},

	-- Gift products
	GiftCoinCrate = {
		Id     = 0,       -- TODO: 99 Robux (for gifting)
		Name   = "Gift: Coin Crate",
		Reward = {GiftCrate = "CoinDesignerCrate", Amount = 1},
	},

	GiftRobuxCrate = {
		Id     = 0,       -- TODO: 99 Robux (for gifting)
		Name   = "Gift: Robux Crate",
		Reward = {GiftCrate = "RobuxDesignerCrate", Amount = 1},
	},
}

-- ============================================================
-- INDIVIDUAL ROBUX ITEMS (Gamepasses used as permanent unlocks)
-- ============================================================
MarketplaceRegistry.Items = {

	-- Skins
	KPopStarSkin = {
		Id       = 0,     -- TODO
		Name     = "K-Pop Star Skin",
		Category = "Skins",
		ItemName = "K-Pop Star",
	},

	VisionarySkin = {
		Id       = 0,     -- TODO
		Name     = "Visionary Skin",
		Category = "Skins",
		ItemName = "Visionary",
	},

	-- Weapons
	DiamondLightStick = {
		Id       = 0,     -- TODO
		Name     = "Diamond Light Stick",
		Category = "WeaponSkins",
		ItemName = "Diamond LightStick",
	},

	GoldenScissors = {
		Id       = 0,     -- TODO
		Name     = "Golden Scissors",
		Category = "WeaponSkins",
		ItemName = "Golden Scissors",
	},
}

-- ============================================================
-- BUNDLES (multiple items granted at once, time-limited or permanent)
-- ============================================================
MarketplaceRegistry.Bundles = {

	KPopBundle = {
		Id          = 0,       -- TODO Gamepass ID
		Name        = "K-Pop Star Bundle",
		Description = "K-Pop Star Skin + Neon Scissors + Crystal Stage Podium.",
		-- Limited time window (os.time() values). Set both to 0 for permanent.
		StartTime   = 0,       -- TODO: os.time() for June 12 2026 00:00 UTC
		EndTime     = 0,       -- TODO: os.time() for August 31 2026 23:59 UTC
		Contents    = {
			{Category = "Skins",   ItemName = "K-Pop Star"},
			{Category = "WeaponSkins", ItemName = "Neon Scissors"},
			{Category = "Podiums", ItemName = "Crystal Stage"},
		},
	},

	VisionaryBundle = {
		Id          = 0,       -- TODO Gamepass ID
		Name        = "Visionary Bundle",
		Description = "Visionary Skin + Golden Scissors + Gold Pedestal.",
		StartTime   = 0,
		EndTime     = 0,
		Contents    = {
			{Category = "Skins",   ItemName = "Visionary"},
			{Category = "WeaponSkins", ItemName = "Golden Scissors"},
			{Category = "Podiums", ItemName = "Gold Pedestal"},
		},
	},
}

-- ============================================================
-- ROBLOX PLUS / SUBSCRIPTION
-- Use PromptRobloxSubscriptionPurchase API
-- ============================================================
MarketplaceRegistry.Subscription = {
	-- Roblox Plus subscription ID for premium in-game perks.
	-- Shown to players who aren't subscribed via PromptRobloxSubscriptionPurchase.
	SubscriptionId = "EXP-0000000000",  -- TODO: Replace with your real subscription ID
	Perks = {
		-- Shown in UI; actual perk granting is done via UserSubscriptionStatusAsync
		MonthlyCoins    = 300,
		CrateDiscount   = 0.10,  -- 10% off coin crate purchases
		ExclusiveBadge  = true,
	},
}

-- ============================================================
-- Helpers
-- ============================================================

-- Returns the gamepass entry for a given pass ID (server-side lookup)
function MarketplaceRegistry.GetGamepassById(passId)
	for _, pass in pairs(MarketplaceRegistry.GamePasses) do
		if pass.Id == passId then return pass end
	end
	return nil
end

-- Returns the product entry for a given product ID
function MarketplaceRegistry.GetProductById(productId)
	for _, product in pairs(MarketplaceRegistry.Products) do
		if product.Id == productId then return product end
	end
	return nil
end

-- Returns the bundle entry for a given gamepass ID
function MarketplaceRegistry.GetBundleById(passId)
	for _, bundle in pairs(MarketplaceRegistry.Bundles) do
		if bundle.Id == passId then return bundle end
	end
	return nil
end

-- Returns the item entry for a given gamepass ID
function MarketplaceRegistry.GetItemById(passId)
	for _, item in pairs(MarketplaceRegistry.Items) do
		if item.Id == passId then return item end
	end
	return nil
end

-- Checks whether a limited-time bundle is currently available
function MarketplaceRegistry.IsBundleActive(bundleKey)
	local bundle = MarketplaceRegistry.Bundles[bundleKey]
	if not bundle then return false end
	if bundle.StartTime == 0 and bundle.EndTime == 0 then return true end
	local now = os.time()
	return now >= bundle.StartTime and now <= bundle.EndTime
end

return MarketplaceRegistry