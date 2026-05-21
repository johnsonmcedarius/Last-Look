-- ─────────────────────────────────────────────────────────────────────────────
-- GameConfig: Core gameplay settings (round duration, team names, etc.)
-- ─────────────────────────────────────────────────────────────────────────────

return {
	-- Team Names
	TEAMS = {
		DESIGNER = "Designers",
		CRITIC = "Critics",
	},

	-- Round Settings
	ROUND_DURATION = 300,
	INTERMISSION_DURATION = 15,
	MIN_PLAYERS = 2,
	MAX_STRIKES = 3,

	-- Objective Settings
	TOTAL_FABRIC_NEEDED = 5,
	MAX_INTERACTION_DISTANCE = 15,
	PASS_RANGE = 8,

	-- Sabotage Settings
	SABOTAGE_LIMIT = 2,
	SABOTAGE_DURATION = 20,
	SABOTAGE_COOLDOWN = 45,

	-- Cancellation Timer
	CANCELLATION_TIME = 30,
	ANTI_CAMP_DISTANCE = 15,
	DUNK_DENIED_RANGE = 5,

	-- Character Stats
	MAX_CHARGE = 100,
}