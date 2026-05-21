-- ─────────────────────────────────────────────────────────────────────────────
-- UISoundController  (LocalScript — StarterPlayerScripts)
--
-- Auto-wires click and hover sounds to EVERY TextButton / ImageButton
-- across EVERY ScreenGui in PlayerGui — present and future.
--
-- HOW TO ADD A NEW SOUND RULE:
--   1. Add the sound ID to ReplicatedStorage.SoundService.Sounds  (e.g. UI_MySound)
--   2. Add a rule to SoundMap below matching by button Name, ClassName, or parent
--   No other changes needed — the controller picks it up automatically.
--
-- HOW TO SILENCE A SPECIFIC BUTTON:
--   Add its Name to the MUTE_LIST table below.
--
-- All sound playback routes through SoundService.PlayLocal().
-- ─────────────────────────────────────────────────────────────────────────────

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService      = game:GetService("TweenService")

local player    = Players.LocalPlayer
local PlayerGui = player:WaitForChild("PlayerGui")
local SS        = require(ReplicatedStorage:WaitForChild("SoundService"))

-- ── Buttons to never wire sounds to ──────────────────────────────────────────
-- Add button Names here to opt them out of all sound wiring.
local MUTE_LIST = {
	DragHitbox   = true,   -- invisible rotation hitbox on InventoryMenu
	SkipButton   = true,   -- UnboxingCinematic skip (has its own sound logic)
}

-- ── Sound rules ───────────────────────────────────────────────────────────────
-- Checked top-to-bottom; first match wins.
-- Each rule: { match = function(btn) → bool, sound = "SoundServiceKey" }
-- "sound" can also be a function(btn) → string for dynamic selection.
local SoundMap = {

	-- ── Close / dismiss buttons ───────────────────────────────────────────────
	{
		match = function(btn)
			local n = btn.Name:lower()
			return n == "closebutton" or n == "closebtn" or n == "close" or btn.Text == "✕"
		end,
		sound = "UI_Close",
	},

	-- ── Claim / reward buttons ────────────────────────────────────────────────
	{
		match = function(btn)
			local n = btn.Name:lower()
			return n == "claimbutton" or n == "claimbtn" or n:find("claim") ~= nil
		end,
		sound = "UI_DailyClaim",
	},

	-- ── Recover streak ────────────────────────────────────────────────────────
	{
		match = function(btn)
			return btn.Name:lower():find("recover") ~= nil
		end,
		sound = "UI_StreakRecover",
	},

	-- ── Equip button ──────────────────────────────────────────────────────────
	{
		match = function(btn)
			local n = btn.Name:lower()
			return n == "equipbutton" or n == "equip"
		end,
		sound = "UI_Equip",
	},

	-- ── Purchase / crate buttons ──────────────────────────────────────────────
	{
		match = function(btn)
			local n = btn.Name:lower()
			return n:find("crate") ~= nil or n:find("purchase") ~= nil or n:find("buy") ~= nil
		end,
		sound = "UI_Purchase",
	},

	-- ── Crate reveal (GachaCrateFrame cloned buttons) ─────────────────────────
	{
		match = function(btn)
			local parent = btn.Parent
			return parent and parent.Name == "GachaCrateFrame"
		end,
		sound = "UI_CrateReveal",
	},

	-- ── DailyLookbook open button ─────────────────────────────────────────────
	{
		match = function(btn)
			return btn.Name == "DailyLookbookButton"
		end,
		sound = "UI_DailyOpen",
	},

	-- ── Navigation tabs (shop + inventory nav bars) ───────────────────────────
	{
		match = function(btn)
			local n = btn.Name
			return n:sub(1, 4) == "Btn_"
		end,
		sound = "UI_NavTab",
	},

	-- ── Bet target buttons (spectate panel) ──────────────────────────────────
	{
		match = function(btn)
			return btn.Name == "BetTargetButton" or btn.Name:find("Bet") ~= nil
		end,
		sound = "UI_Click",
	},

	-- ── Cycle / next buttons ──────────────────────────────────────────────────
	{
		match = function(btn)
			local n = btn.Name:lower()
			return n == "cyclebutton" or n:find("next") ~= nil or n:find("cycle") ~= nil
		end,
		sound = "UI_Click",
	},

	-- ── Reset / destructive buttons (subdued sound) ───────────────────────────
	{
		match = function(btn)
			local n = btn.Name:lower()
			return n == "resetbutton" or n:find("reset") ~= nil or n:find("cancel") ~= nil
		end,
		sound = "UI_Close",
	},

	-- ── Default fallback: anything else ───────────────────────────────────────
	{
		match = function(_) return true end,
		sound = "UI_Click",
	},
}

-- ── Hover sound (same for all — subtle tick) ─────────────────────────────────
local HOVER_SOUND  = "UI_Hover"
local HOVER_VOLUME = 0.25  -- quieter than click

-- ── Core: resolve which sound a button should play ───────────────────────────
local function resolveSound(btn)
	for _, rule in ipairs(SoundMap) do
		local ok, result = pcall(rule.match, btn)
		if ok and result then
			if type(rule.sound) == "function" then
				return rule.sound(btn)
			end
			return rule.sound
		end
	end
	return "UI_Click"
end

-- ── Core: wire a single button ───────────────────────────────────────────────
local wired = {} -- weak set to avoid double-wiring

local function wireButton(btn)
	-- Skip muted buttons and already-wired ones
	if MUTE_LIST[btn.Name] then return end
	if wired[btn] then return end
	wired[btn] = true

	-- Click sound
	btn.MouseButton1Click:Connect(function()
		SS.PlayLocal(resolveSound(btn), 0.85)
	end)

	-- Hover sound (desktop only — no hover on mobile)
	btn.MouseEnter:Connect(function()
		SS.PlayLocal(HOVER_SOUND, HOVER_VOLUME)
	end)

	-- Hover scale tween (springy 1.05× on enter, back on leave)
	-- Only applied to buttons that aren't full-width layout items
	local isLayoutItem = btn.Parent and btn.Parent:FindFirstChildWhichIsA("UIListLayout") ~= nil
		and btn.Size.X.Scale > 0.5  -- full-width buttons skip scale tween

	if not isLayoutItem then
		local BASE_SIZE = btn.Size
		btn.MouseEnter:Connect(function()
			TweenService:Create(btn,
				TweenInfo.new(0.12, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
				{Size = UDim2.new(
					BASE_SIZE.X.Scale * 1.05, BASE_SIZE.X.Offset * 1.05,
					BASE_SIZE.Y.Scale * 1.05, BASE_SIZE.Y.Offset * 1.05
				)}
			):Play()
		end)
		btn.MouseLeave:Connect(function()
			TweenService:Create(btn,
				TweenInfo.new(0.10, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
				{Size = BASE_SIZE}
			):Play()
		end)
		-- Tactile click: quick 0.9× shrink then spring back
		btn.MouseButton1Down:Connect(function()
			TweenService:Create(btn,
				TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
				{Size = UDim2.new(
					BASE_SIZE.X.Scale * 0.92, BASE_SIZE.X.Offset * 0.92,
					BASE_SIZE.Y.Scale * 0.92, BASE_SIZE.Y.Offset * 0.92
				)}
			):Play()
		end)
		btn.MouseButton1Up:Connect(function()
			TweenService:Create(btn,
				TweenInfo.new(0.14, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
				{Size = BASE_SIZE}
			):Play()
		end)
	end
end

-- ── Walk a ScreenGui and wire all buttons ─────────────────────────────────────
local function wireGui(gui)
	for _, desc in ipairs(gui:GetDescendants()) do
		if desc:IsA("TextButton") or desc:IsA("ImageButton") then
			wireButton(desc)
		end
	end
	-- Also wire any buttons added later (e.g. CrateButtonTemplate clones)
	gui.DescendantAdded:Connect(function(desc)
		if desc:IsA("TextButton") or desc:IsA("ImageButton") then
			-- Small delay so the button is fully parented + named before wiring
			task.defer(function()
				if desc and desc.Parent then
					wireButton(desc)
				end
			end)
		end
	end)
end

-- ── Wire all current + future ScreenGuis ─────────────────────────────────────
for _, gui in ipairs(PlayerGui:GetChildren()) do
	if gui:IsA("ScreenGui") then
		wireGui(gui)
	end
end

PlayerGui.ChildAdded:Connect(function(child)
	if child:IsA("ScreenGui") then
		-- Brief wait for the full hierarchy to replicate
		task.wait(0.05)
		wireGui(child)
	end
end)

print(string.format("[UI_SOUND] UISoundController initialized — %d ScreenGuis wired",
	#PlayerGui:GetChildren()))
