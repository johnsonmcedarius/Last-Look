-- ─────────────────────────────────────────────────────────────────────────────
-- UITransitionController  (LocalScript — StarterPlayerScripts)
-- Manages all Lobby ↔ Match UI transitions.
-- Listens to MatchStart / MatchEnd RemoteEvents (same ones MatchFlowController uses).
--
-- LOBBY HUD elements tweened OUT on match start:
--   BottomNav       → slides down off screen
--   CurrencyDisplay → slides up off screen
--   DailyLookbookButton → slides left off screen
--
-- GAMEPLAY HUD elements tweened IN on match start:
--   ScoreboardFrame → drops in from top
--   ActionHotbar    → slides up from bottom
--   UltimateModule  → slides up from bottom (slight delay)
--   StatusTracker   → slides in from left
--
-- Everything reverses cleanly on match end / intermission.
-- ─────────────────────────────────────────────────────────────────────────────

local Players      = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RS           = game:GetService("ReplicatedStorage")

local player    = Players.LocalPlayer
local PlayerGui = player:WaitForChild("PlayerGui")

-- ── Wait for both ScreenGuis ──────────────────────────────────────────────────
local LobbyHUD    = PlayerGui:WaitForChild("LobbyHUD",    15)
local GameplayHUD = PlayerGui:WaitForChild("GameplayHUD", 15)

if not LobbyHUD or not GameplayHUD then
	warn("[TRANSITION] Missing LobbyHUD or GameplayHUD — controller aborted.")
	return
end

-- ── Remotes (same as MatchFlowController) ────────────────────────────────────
local Remotes    = RS:WaitForChild("Remotes")
local MatchStart = Remotes:WaitForChild("MatchStart")
local MatchEnd   = Remotes:WaitForChild("MatchEnd")

-- ── Tween configs ─────────────────────────────────────────────────────────────
local OUT_INFO = TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.In)
local IN_INFO  = TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local FAST_IN  = TweenInfo.new(0.30, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

-- ── Confirmed resting positions (from live UI audit) ─────────────────────────
-- LobbyHUD
local LOBBY_REST = {
	BottomNav        = UDim2.new(0.5, 0,  1, -14),   -- AnchorPoint 0.5,1
	CurrencyDisplay  = UDim2.new(1, -12,  0,  12),   -- AnchorPoint 1,0
	DailyLookbookButton = UDim2.new(0,  12,  0.5, 0),   -- AnchorPoint 0,0.5
}
local LOBBY_OFF = {
	BottomNav        = UDim2.new(0.5, 0,  1.25, 0),  -- below screen
	CurrencyDisplay  = UDim2.new(1, -12, -0.15, 0),  -- above screen
	DailyLookbookButton = UDim2.new(-0.15, 0, 0.5,  0), -- left of screen
}

-- GameplayHUD (resting positions from audit)
local HUD_REST = {
	ScoreboardFrame = UDim2.new(0.5, -150, 0.02, 0),  -- confirmed from audit
	ActionHotbar    = UDim2.new(0,    15,  1, -200),
	UltimateModule  = UDim2.new(0.5, -110, 1, -140),
	StatusTracker   = UDim2.new(0,    15,  1, -170),
}
local HUD_OFF = {
	ScoreboardFrame = UDim2.new(0.5, -150, -0.12, 0), -- above screen
	ActionHotbar    = UDim2.new(0,    15,  1.15,  0),  -- below screen
	UltimateModule  = UDim2.new(0.5, -110, 1.22,  0),  -- below screen
	StatusTracker   = UDim2.new(-0.22, 0,  1, -170),   -- left of screen
}

-- ── Helpers ───────────────────────────────────────────────────────────────────
local function tween(obj, info, props)
	if not obj then return end
	TweenService:Create(obj, info, props):Play()
end

local function getEl(gui, name)
	return gui:FindFirstChild(name, true)
end

-- ── State ─────────────────────────────────────────────────────────────────────
local inMatch = false

-- ── LOBBY → MATCH ─────────────────────────────────────────────────────────────
local function transitionToMatch()
	if inMatch then return end
	inMatch = true

	-- Snap HUD elements to their OFF positions before enabling
	GameplayHUD.Enabled = true
	local sf = getEl(GameplayHUD, "ScoreboardFrame")
	local ah = getEl(GameplayHUD, "ActionHotbar")
	local um = getEl(GameplayHUD, "UltimateModule")
	local st = getEl(GameplayHUD, "StatusTracker")

	if sf then sf.Position = HUD_OFF.ScoreboardFrame end
	if ah then ah.Position = HUD_OFF.ActionHotbar    end
	if um then um.Position = HUD_OFF.UltimateModule  end
	if st then st.Position = HUD_OFF.StatusTracker   end

	-- Tween LobbyHUD OUT simultaneously
	local bn  = getEl(LobbyHUD, "BottomNav")
	local cd  = getEl(LobbyHUD, "CurrencyDisplay")
	local dlb = getEl(LobbyHUD, "DailyLookbookButton")

	tween(bn,  OUT_INFO, {Position = LOBBY_OFF.BottomNav})
	tween(cd,  OUT_INFO, {Position = LOBBY_OFF.CurrencyDisplay})
	tween(dlb, OUT_INFO, {Position = LOBBY_OFF.DailyLookbookButton})

	-- Tween GameplayHUD IN with staggered delays
	task.delay(0.12, function()
		tween(sf, IN_INFO, {Position = HUD_REST.ScoreboardFrame})
	end)
	task.delay(0.20, function()
		tween(ah, IN_INFO, {Position = HUD_REST.ActionHotbar})
	end)
	task.delay(0.28, function()
		tween(um, IN_INFO, {Position = HUD_REST.UltimateModule})
	end)
	task.delay(0.22, function()
		tween(st, FAST_IN, {Position = HUD_REST.StatusTracker})
	end)

	-- Disable LobbyHUD after its elements have slid off
	task.delay(0.5, function()
		LobbyHUD.Enabled = false
		-- Reset lobby elements silently so they're ready to tween back in
		if bn  then bn.Position  = LOBBY_OFF.BottomNav        end
		if cd  then cd.Position  = LOBBY_OFF.CurrencyDisplay  end
		if dlb then dlb.Position = LOBBY_OFF.DailyLookbookButton end
	end)
end

-- ── MATCH → LOBBY ─────────────────────────────────────────────────────────────
local function transitionToLobby()
	if not inMatch then return end
	inMatch = false

	-- Re-enable LobbyHUD with elements already off-screen
	LobbyHUD.Enabled = true
	local bn  = getEl(LobbyHUD, "BottomNav")
	local cd  = getEl(LobbyHUD, "CurrencyDisplay")
	local dlb = getEl(LobbyHUD, "DailyLookbookButton")

	-- Ensure starting from off-screen
	if bn  then bn.Position  = LOBBY_OFF.BottomNav        end
	if cd  then cd.Position  = LOBBY_OFF.CurrencyDisplay  end
	if dlb then dlb.Position = LOBBY_OFF.DailyLookbookButton end

	-- Tween GameplayHUD elements OUT
	local sf = getEl(GameplayHUD, "ScoreboardFrame")
	local ah = getEl(GameplayHUD, "ActionHotbar")
	local um = getEl(GameplayHUD, "UltimateModule")
	local st = getEl(GameplayHUD, "StatusTracker")

	tween(sf, OUT_INFO, {Position = HUD_OFF.ScoreboardFrame})
	tween(ah, OUT_INFO, {Position = HUD_OFF.ActionHotbar})
	tween(um, OUT_INFO, {Position = HUD_OFF.UltimateModule})
	tween(st, OUT_INFO, {Position = HUD_OFF.StatusTracker})

	-- Tween LobbyHUD IN staggered
	task.delay(0.10, function()
		tween(cd,  IN_INFO, {Position = LOBBY_REST.CurrencyDisplay})
	end)
	task.delay(0.18, function()
		tween(bn,  IN_INFO, {Position = LOBBY_REST.BottomNav})
	end)
	task.delay(0.26, function()
		tween(dlb, IN_INFO, {Position = LOBBY_REST.DailyLookbookButton})
	end)

	-- Disable GameplayHUD after it has cleared the screen
	task.delay(0.55, function()
		GameplayHUD.Enabled = false
	end)
end

-- ── Remote Listeners ──────────────────────────────────────────────────────────
MatchStart.OnClientEvent:Connect(function()
	transitionToMatch()
end)

MatchEnd.OnClientEvent:Connect(function()
	-- Give PostGameSummary (MatchFlowController) a 0.2s head-start before
	-- we start pulling the HUD away, so it doesn't feel abrupt
	task.delay(0.2, transitionToLobby)
end)

-- ── Initial state: show Lobby, hide Gameplay ─────────────────────────────────
-- GameplayHUD starts disabled; its elements are snapped to rest positions
-- so they tween in correctly the first time a match starts.
GameplayHUD.Enabled = false
LobbyHUD.Enabled    = true

do
	local sf  = getEl(GameplayHUD, "ScoreboardFrame")
	local ah  = getEl(GameplayHUD, "ActionHotbar")
	local um  = getEl(GameplayHUD, "UltimateModule")
	local st  = getEl(GameplayHUD, "StatusTracker")
	if sf then sf.Position = HUD_OFF.ScoreboardFrame end
	if ah then ah.Position = HUD_OFF.ActionHotbar    end
	if um then um.Position = HUD_OFF.UltimateModule  end
	if st then st.Position = HUD_OFF.StatusTracker   end
end

print("[TRANSITION] UITransitionController initialized — watching for MatchStart / MatchEnd")
