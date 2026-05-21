local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local ServiceRegistry = require(ServerScriptService:WaitForChild("ServiceRegistry"))
local MarketplaceRegistry = require(ReplicatedStorage:WaitForChild("MarketplaceRegistry"))

-- ── Roblox Plus Integration ───────────────────────────────────────
local RobloxPlusService = {}

-- Cache subscription status to avoid repeated API calls
local subscriptionCache = {}
local CACHE_DURATION = 300 -- 5 minutes

-- ── Check if player is subscribed to Roblox Plus ──────────────────────────────
function RobloxPlusService.IsSubscribed(player)
	-- Check cache first
	local cached = subscriptionCache[player.UserId]
	if cached and (os.time() - cached.timestamp) < CACHE_DURATION then
		return cached.isSubscribed
	end
	
	-- Get subscription ID from registry
	local subscriptionId = MarketplaceRegistry.Subscription and MarketplaceRegistry.Subscription.SubscriptionId
	if not subscriptionId or subscriptionId == "EXP-0000000000" then
		-- Placeholder ID, return false
		return false
	end
	
	-- Check subscription status via API
	local success, status = pcall(function()
		return MarketplaceService:GetUserSubscriptionStatusAsync(player, subscriptionId)
	end)

	if success and status then
		local isSubscribed = status.IsSubscribed or false
		-- Cache the result
		subscriptionCache[player.UserId] = {
			isSubscribed = isSubscribed,
			timestamp = os.time()
		}
		return isSubscribed
	end
	
	return false
end

-- ── Get discounted price for subscribers ─────────────────────────────────────
function RobloxPlusService.GetDiscountedPrice(player, originalPrice)
	if RobloxPlusService.IsSubscribed(player) then
		local discount = MarketplaceRegistry.Subscription and MarketplaceRegistry.Subscription.Perks and MarketplaceRegistry.Subscription.Perks.CrateDiscount or 0.10
		return math.floor(originalPrice * (1 - discount))
	end
	return originalPrice
end

-- ── Get discount percentage for display ───────────────────────────────────────
function RobloxPlusService.GetDiscountPercentage(player)
	if RobloxPlusService.IsSubscribed(player) then
		return MarketplaceRegistry.Subscription and MarketplaceRegistry.Subscription.Perks and MarketplaceRegistry.Subscription.Perks.CrateDiscount or 0.10
	end
	return 0
end

-- ── Check if player has exclusive badge perk ───────────────────────────────────
function RobloxPlusService.HasExclusiveBadge(player)
	if not RobloxPlusService.IsSubscribed(player) then return false end
	return MarketplaceRegistry.Subscription and MarketplaceRegistry.Subscription.Perks and MarketplaceRegistry.Subscription.Perks.ExclusiveBadge or false
end

-- ── Get monthly coins perk amount ─────────────────────────────────────────────
function RobloxPlusService.GetMonthlyCoins(player)
	if not RobloxPlusService.IsSubscribed(player) then return 0 end
	return MarketplaceRegistry.Subscription and MarketplaceRegistry.Subscription.Perks and MarketplaceRegistry.Subscription.Perks.MonthlyCoins or 0
end

-- ── Clear cache on player leaving ─────────────────────────────────────────────
Players.PlayerRemoving:Connect(function(player)
	subscriptionCache[player.UserId] = nil
end)

-- ── Instant cache invalidation on successful purchase ─────────────────────────
MarketplaceService.PromptRobloxSubscriptionPurchaseFinished:Connect(function(player, subscriptionId, success)
	if success then
		subscriptionCache[player.UserId] = nil
		print("[VIP] " .. player.Name .. " successfully subscribed! Wiped cache for instant updates.")
	end
end)

-- ── Register Service ─────────────────────────────────────────────────────────
ServiceRegistry.Register("RobloxPlusService", RobloxPlusService)
return RobloxPlusService