-- ─────────────────────────────────────────────────────────────────────────────
-- UIConfig: Colors, fonts, and visual settings for the HUD
-- ─────────────────────────────────────────────────────────────────────────────

return {
	-- Team Colors
	TEAM_COLORS = {
		Designers = Color3.fromRGB(100, 200, 255),  -- Light Blue
		Critics   = Color3.fromRGB(255, 100, 150),  -- Pink/Red
	},

	-- Score UI Colors
	SCORE_COLORS = {
		Designer = Color3.fromRGB(100, 200, 255),
		Critic   = Color3.fromRGB(255, 100, 150),
		Neutral  = Color3.fromRGB(255, 255, 255),
		Clutch   = Color3.fromRGB(255, 255, 0),
	},

	-- Showstopper Charge Bar Colors
	CHARGE_BAR_COLORS = {
		Empty   = Color3.fromRGB(180, 180, 180),
		Half    = Color3.fromRGB(255, 200, 0),
		Full    = Color3.fromRGB(255, 80, 200),
	},

	-- Strike Colors
	STRIKE_COLORS = {
		Active   = Color3.fromRGB(80, 80, 80),
		Inactive = Color3.fromRGB(255, 80, 80),
	},

	-- Fonts
	FONT = {
		Main     = Enum.Font.GothamBold,
		Score    = Enum.Font.GothamBlack,
		Timer     = Enum.Font.GothamBold,
		Subtitle = Enum.Font.Gotham,
	},

	-- Animation Durations
	ANIMATION = {
		ScoreFlash     = 0.2,
		ClutchFlash    = 0.15,
		BarFill        = 0.3,
		FadeOut        = 0.5,
	},

	-- Screen Layout
	LAYOUT = {
		ScoreYPosition  = 0.05,
		TimerYPosition  = 0.02,
		ChargeYPosition = 0.92,
	},
}