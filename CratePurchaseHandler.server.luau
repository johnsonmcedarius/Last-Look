-- ─────────────────────────────────────────────────────────────────────────────
-- CratePurchaseHandler (Server Script)
-- Validates and routes crate purchases. All crate types defined in CrateRegistry.
-- To add a new purchasable crate: add it to ReplicatedStorage.CrateRegistry only.
-- ─────────────────────────────────────────────────────────────────────────────

local Players             = game:GetService("Players")
local ReplicatedStorage   = game:GetService("ReplicatedStorage")
local MarketplaceService  = game:GetService("MarketplaceService")
local ServerScriptService = game:GetService("ServerScriptService")

local ServiceRegistry = require(ServerScriptService:WaitForChild("ServiceRegistry"))
local CrateRegistry   = require(ReplicatedStorage:WaitForChild("CrateRegistry"))

local Remotes              = ReplicatedStorage:WaitForChild("Remotes")
local CratePurchaseRequest = Remotes:WaitForChild("CratePurchaseRequest")
local TriggerUnboxing      = Remotes:WaitForChild("TriggerUnboxing")
local ShowRewardPopup      = Remotes:WaitForChild("ShowRewardPopup")

-- ── Rate Limiting ─────────────────────────────────────────────────────────────
local PURCHASE_COOLDOWN = 2  -- seconds
local purchaseCooldowns = {} -- [userId] = timestamp
local pendingPurchases  = {} -- [userId] = crateId (for Robux flow)

local function canPurchase(player)
	local now  = os.clock()
	local last = purchaseCooldowns[player.UserId] or 0
	if now - last < PURCHASE_COOLDOWN then
		return false, "Please wait before purchasing again."
	end
	return true, nil
end

-- ── Main purchase handler ─────────────────────────────────────────────────────
CratePurchaseRequest.OnServerEvent:Connect(function(player, crateId)
	-- Validate against registry (prevents spoofed crate IDs)
	local crate = CrateRegistry.GetById(crateId)
	if not crate then
		warn("[CRATE] Invalid crate id from " .. player.Name .. ": " .. tostring(crateId))
		return
	end

	-- Rate limit
	local canBuy, err = canPurchase(player)
	if not canBuy then
		ShowRewardPopup:FireClient(player, "WAIT", err)
		return
	end
	-- Lock the cooldown instantly for BOTH Coins and Robux flows
	purchaseCooldowns[player.UserId] = os.clock()

	if crate.currency == "Coins" then
		-- ── Coin purchase ──────────────────────────────────────────────────────
		local DataManager = ServiceRegistry.Get("DataManager")
		if not DataManager then
			ShowRewardPopup:FireClient(player, "ERROR", "Data service unavailable.")
			return
		end

		local coins = DataManager.GetCoins(player)
		local cost  = crate.coinCost or 0

		if coins < cost then
			ShowRewardPopup:FireClient(
				player,
				"NOT ENOUGH COINS!",
				"Need " .. cost .. " coins for " .. crate.label
			)
			return
		end

		-- Deduct coins and add crate to inventory
		DataManager.SubtractCoins(player, cost)
		
		-- Add crate to player's inventory via GachaService
		local GachaService = ServiceRegistry.Get("GachaService")
		if GachaService then
			GachaService.AddCrate(player, crate.id, 1)
		else
			warn("[CRATE] GachaService not available - crate not added to inventory!")
		end
		
		TriggerUnboxing:FireClient(player, crate.id)

		print(string.format("[CRATE] %s purchased %s for %d coins", player.Name, crate.id, cost))

	elseif crate.currency == "Robux" then
		-- ── Robux purchase ─────────────────────────────────────────────────────
		local productId = crate.productId or 0
		if productId == 0 then
			ShowRewardPopup:FireClient(player, "COMING SOON", crate.label .. " is not yet available!")
			return
		end

		pendingPurchases[player.UserId] = crate.id
		MarketplaceService:PromptProductPurchase(player, productId)

		print(string.format("[CRATE] %s initiated Robux purchase for %s (productId=%d)",
			player.Name, crate.id, productId))
	end
end)

-- ── Cleanup ───────────────────────────────────────────────────────────────────
Players.PlayerRemoving:Connect(function(player)
	purchaseCooldowns[player.UserId] = nil
	pendingPurchases[player.UserId]  = nil
end)

print("[CRATE] CratePurchaseHandler initialized — " 
	.. #CrateRegistry.GetAll() .. " crate(s) registered")
