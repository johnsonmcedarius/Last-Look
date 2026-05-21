-- ─────────────────────────────────────────────────────────────────────────────
-- LiveOpsConfig: Event scheduling for featured modes and bonuses
-- ─────────────────────────────────────────────────────────────────────────────

return {
	-- Scheduled Events (add events here when LiveOpsEnabled = true)
	-- Example:
	-- {
	-- 	Name = "Double XP Weekend",
	-- 	Type = "XPBoost",
	-- 	Multiplier = 2.0,
	-- 	Description = "Earn double XP all weekend!",
	-- 	StartTime = os.time({year=2024, month=1, day=1, hour=0}),
	-- 	EndTime = os.time({year=2024, month=1, day=3, hour=0}),
	-- },

	Events = {},

	-- Event Types
	EVENT_TYPES = {
		XPBoost     = "XPBoost",
		CoinBoost   = "CoinBoost",
		FeaturedMode = "FeaturedMode",
		Seasonal    = "Seasonal",
	},
}