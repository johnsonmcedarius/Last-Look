local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local PlayerGui = player:WaitForChild("PlayerGui")

-- ── Reference Physical UI ──
local LobbyHUD      = PlayerGui:WaitForChild("LobbyHUD", 10)
local CoinDisplay   = LobbyHUD and LobbyHUD:WaitForChild("CurrencyDisplay", 5)
local CoinAmount    = CoinDisplay and CoinDisplay:WaitForChild("CoinAmount", 5)

if not CoinAmount then
	warn("[COIN_DISPLAY] CoinAmount label not found in LobbyHUD.CurrencyDisplay — check Phase 1 build layout.")
	return
end

-- ── State ──
local currentCoins = -1 -- Initialized to -1 so an initial state of 0 coins still triggers the update pass
local isAnimating = false

-- ── Helper: Format number with commas ──
local function formatNumber(num)
	local formatted = tostring(num)
	local k = 0

	while true do
		formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", "%1,%2")
		if k == 0 then break end
	end

	return formatted
end

-- ── Update coin display with animation ──
local function updateCoinDisplay(newCoins, animate)
	if currentCoins == newCoins then return end
	currentCoins = newCoins

	-- Update text parameters safely
	CoinAmount.Text = formatNumber(newCoins)

	-- Scale pulse: tween parent CoinDisplay size (TextScaled=true so TextSize is locked)
	if animate and not isAnimating then
		isAnimating = true

		local originalSize = CoinDisplay.Size
		local bigSize = UDim2.new(
			originalSize.X.Scale, originalSize.X.Offset,
			originalSize.Y.Scale, originalSize.Y.Offset + 6
		)
		CoinDisplay.Size = bigSize
		local tween = TweenService:Create(CoinDisplay,
			TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
			{Size = originalSize}
		)
		tween:Play()
		tween.Completed:Connect(function()
			isAnimating = false
		end)
	end
end

-- ── Listen for coin changes from server ──
local function setupReplicaListener()
	-- Dynamic path discovery: looks for a nested ReplicatedStorage directory first, then checks root directly
	local rFolder = ReplicatedStorage:FindFirstChild("ReplicatedStorage") or ReplicatedStorage
	local rModule = rFolder:FindFirstChild("ReplicaController")

	if rModule then
		local success, ReplicaController = pcall(require, rModule)
		if success and ReplicaController and ReplicaController.ReplicaOfClassCreated then

			ReplicaController.ReplicaOfClassCreated("PlayerData", function(replica)
				-- Single explicit source of truth listener hook
				replica:ListenToChange({"Coins"}, function(newCoins)
					updateCoinDisplay(newCoins, true)
					print("[COIN_DISPLAY] Coins updated via Replica: " .. newCoins)
				end)

				-- Initial update - get coins immediately
				local data = replica.Data
				if data and data.Coins then
					updateCoinDisplay(data.Coins, false)
					print("[COIN_DISPLAY] Initial coins set via Replica: " .. data.Coins)
				else
					updateCoinDisplay(0, false) -- Fallback if data is clean/new
				end

				print("[COIN_DISPLAY] Replica listener set up successfully")
			end)
			return true
		else
			warn("[COIN_DISPLAY] ReplicaController initialization failed")
		end
	else
		warn("[COIN_DISPLAY] ReplicaController module not found at designated path targets")
	end

	return false
end

-- ── Initial Setup Flow ──
-- IMPORTANT: Set up listener BEFORE calling RequestData() to avoid race condition

-- Step 1: Set up the replica listener FIRST
local replicaListenerSuccess = setupReplicaListener()

-- Step 2: THEN request data from server
local rFolder = ReplicatedStorage:FindFirstChild("ReplicatedStorage") or ReplicatedStorage
local rModule = rFolder:FindFirstChild("ReplicaController")
if rModule then
	local success, ReplicaController = pcall(require, rModule)
	if success and ReplicaController and ReplicaController.RequestData then
		ReplicaController.RequestData()
		print("[COIN_DISPLAY] RequestData() called - listener ready, waiting for server data")
	else
		warn("[COIN_DISPLAY] Failed to load ReplicaController for RequestData")
	end
else
	warn("[COIN_DISPLAY] ReplicaController module not found - cannot request data")
end

-- Step 3: Fallback to attributes if replica system failed
if not replicaListenerSuccess then
	-- Fallback: Listen to player attributes cleanly if replica modules aren't resolved
	local function updateFromAttribute()
		local coins = player:GetAttribute("Coins")
		if coins then
			updateCoinDisplay(coins, true)
		end
	end

	-- Initial update pass
	local initialCoins = player:GetAttribute("Coins") or 0
	updateCoinDisplay(initialCoins, false)

	-- Bind change signals
	player:GetAttributeChangedSignal("Coins"):Connect(updateFromAttribute)
	print("[COIN_DISPLAY] Fallback attribute synchronization active")
end

print("[COIN_DISPLAY] CoinDisplayController fully initialized and listening")