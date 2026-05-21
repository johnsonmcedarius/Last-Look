-- ─────────────────────────────────────────────────────────────────────────────
-- CratePurchaseService (ModuleScript — server only)
-- Programmatic API for other server scripts to trigger crate purchases.
-- All crate definitions sourced from CrateRegistry.
-- ─────────────────────────────────────────────────────────────────────────────

local Players             = game:GetService("Players")
local ReplicatedStorage   = game:GetService("ReplicatedStorage")
local MarketplaceService  = game:GetService("MarketplaceService")
local ServerScriptService = game:GetService("ServerScriptService")

local ServiceRegistry = require(ServerScriptService:WaitForChild("ServiceRegistry"))
local CrateRegistry   = require(ReplicatedStorage:WaitForChild("CrateRegistry"))

local Remotes         = ReplicatedStorage:WaitForChild("Remotes")
local TriggerUnboxing = Remotes:WaitForChild("TriggerUnboxing")
local ShowRewardPopup = Remotes:WaitForChild("ShowRewardPopup")

local PURCHASE_COOLDOWN  = 2
local purchaseCooldowns  = {}
local pendingPurchases   = {}

local function canPurchase(player)
	local now  = os.clock()
	local last = purchaseCooldowns[player.UserId] or 0
	if now - last < PURCHASE_COOLDOWN then
		return false, "Please wait before purchasing again."
	end
	return true, nil
end

local CratePurchaseService = {}

-- Generic buy function — works for any crate in the registry
function CratePurchaseService.BuyCrate(player, crateId)
	local crate = CrateRegistry.GetById(crateId)
	if not crate then
		return false, "Unknown crate: " .. tostring(crateId)
	end

	local canBuy, err = canPurchase(player)
	if not canBuy then return false, err end

	if crate.currency == "Coins" then
		local DataManager = ServiceRegistry.Get("DataManager")
		if not DataManager then return false, "Data service unavailable." end

		local coins = DataManager.GetCoins(player)
		local cost  = crate.coinCost or 0
		if coins < cost then
			ShowRewardPopup:FireClient(player, "NOT ENOUGH COINS!", "Need " .. cost .. " coins")
			return false, "Insufficient coins."
		end

		DataManager.SubtractCoins(player, cost)
		purchaseCooldowns[player.UserId] = os.clock()
		TriggerUnboxing:FireClient(player, crate.id)
		return true, "Purchase successful!"

	elseif crate.currency == "Robux" then
		local productId = crate.productId or 0
		if productId == 0 then
			ShowRewardPopup:FireClient(player, "COMING SOON", crate.label .. " not yet available!")
			return false, "Product ID not configured."
		end
		pendingPurchases[player.UserId] = crate.id
		MarketplaceService:PromptProductPurchase(player, productId)
		return true, "Purchase prompt shown."
	end

	return false, "Unknown currency type."
end

-- Convenience wrappers (kept for any existing call sites)
function CratePurchaseService.BuyCoinCrate(player)
	-- Find first Coins crate in registry
	for _, crate in ipairs(CrateRegistry.GetAll()) do
		if crate.currency == "Coins" then
			return CratePurchaseService.BuyCrate(player, crate.id)
		end
	end
	return false, "No coin crates registered."
end

function CratePurchaseService.BuyRobuxCrate(player)
	-- Find first Robux crate in registry
	for _, crate in ipairs(CrateRegistry.GetAll()) do
		if crate.currency == "Robux" then
			return CratePurchaseService.BuyCrate(player, crate.id)
		end
	end
	return false, "No Robux crates registered."
end

Players.PlayerRemoving:Connect(function(player)
	purchaseCooldowns[player.UserId] = nil
	pendingPurchases[player.UserId]  = nil
end)

ServiceRegistry.Register("CratePurchaseService", CratePurchaseService)
return CratePurchaseService
