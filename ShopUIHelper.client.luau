local Players            = game:GetService("Players")
local ReplicatedStorage  = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")
local TweenService       = game:GetService("TweenService")

local player = Players.LocalPlayer

local Registry    = require(ReplicatedStorage:WaitForChild("MarketplaceRegistry"))
local SoundService = require(ReplicatedStorage:WaitForChild("SoundService"))

local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local function getRemote(name)
	local r = Remotes:WaitForChild(name, 5)
	if r then return r end
	r        = Instance.new("RemoteEvent")
	r.Name   = name
	r.Parent = Remotes
	return r
end

local GetProductInfoRemote = getRemote("GetProductInfo")
local ProductInfoResult    = getRemote("ProductInfoResult")
local PromptSubscription   = getRemote("PromptSubscription")
local SubscriptionIdRelay  = getRemote("SubscriptionIdRelay")
local GiftItem             = getRemote("GiftItem")
local OpenCrate            = getRemote("OpenCrate")
local BatchOpenCrate       = getRemote("BatchOpenCrate")
local RedeemCode           = getRemote("RedeemCode")
local CodeResult           = getRemote("CodeResult")

-- Price cache: [assetId] = {info = info, timestamp = timestamp}
local priceCache       = {}
local CACHE_EXPIRY     = 300 -- 5 minutes
local pendingCallbacks = {}  -- [assetId] = {callback, ...}

-- ── Live price fetching ───────────────────────────────────────────────────────
local function getLivePrice(assetId, infoType, callback)
	local cached = priceCache[assetId]
	if cached and (os.time() - cached.timestamp) < CACHE_EXPIRY then
		callback(cached.info)
		return
	end

	if not pendingCallbacks[assetId] then
		pendingCallbacks[assetId] = {}
		GetProductInfoRemote:FireServer(assetId, infoType or Enum.InfoType.Product)
	end

	table.insert(pendingCallbacks[assetId], callback)
end

ProductInfoResult.OnClientEvent:Connect(function(assetId, info)
	priceCache[assetId] = {
		info = info,
		timestamp = os.time()
	}

	local callbacks = pendingCallbacks[assetId]
	pendingCallbacks[assetId] = nil

	if callbacks then
		for _, cb in ipairs(callbacks) do cb(info) end
	end
end)

-- ── Public API ────────────────────────────────────────────────────────────────
local ShopUIHelper = {}

-- Populate a button's PriceLabel with live Robux price
function ShopUIHelper.SetButtonPrice(button, assetId, infoType)
	if not button then return end
	local priceLabel = button:FindFirstChild("PriceLabel")
	if not priceLabel then return end

	priceLabel.Text = "Loading..."

	getLivePrice(assetId, infoType, function(info)
		if info and info.IsForSale then
			priceLabel.Text = info.PriceInRobux .. " R$"
		else
			priceLabel.Text = "Unavailable"
			button.Active   = false
		end
	end)
end

-- Show/hide a shop container based on limited-time bundle window
function ShopUIHelper.UpdateBundleVisibility(bundleKey, container)
	if not container then return end
	local isActive = Registry.IsBundleActive(bundleKey)
	container.Visible = isActive

	if isActive then
		local bundle = Registry.Bundles[bundleKey]
		if bundle and bundle.EndTime and bundle.EndTime > 0 then
			local timeLabel = container:FindFirstChild("TimerLabel")
			if timeLabel then
				local remaining = bundle.EndTime - os.time()
				local days = math.floor(remaining / 86400)
				timeLabel.Text = "Ends in " .. days .. " day(s)"
			end
		end
	end
end

-- Prompt developer product purchase (Robux)
function ShopUIHelper.BuyProduct(productId)
	if type(productId) ~= "number" or productId == 0 then
		warn("[SHOP] Invalid product ID.")
		return
	end
	MarketplaceService:PromptProductPurchase(player, productId)
end

-- Prompt gamepass purchase
function ShopUIHelper.BuyGamepass(passId)
	if type(passId) ~= "number" or passId == 0 then
		warn("[SHOP] Invalid gamepass ID.")
		return
	end
	MarketplaceService:PromptGamePassPurchase(player, passId)
end

-- Roblox Plus subscription prompt
function ShopUIHelper.PromptSubscription()
	PromptSubscription:FireServer()
end

SubscriptionIdRelay.OnClientEvent:Connect(function(subscriptionId)
	if not subscriptionId or subscriptionId == "EXP-0000000000" then
		warn("[SHOP] Subscription ID not set yet.")
		return
	end

	local ok, err = pcall(function()
		MarketplaceService:PromptRobloxSubscriptionPurchase(player, subscriptionId)
	end)
	if not ok then
		warn("[SHOP] PromptRobloxSubscriptionPurchase failed: " .. tostring(err))
	end
end)

-- Gift an item to another player
function ShopUIHelper.GiftTo(targetUserId, itemType)
	if type(targetUserId) ~= "number" then return end
	GiftItem:FireServer(targetUserId, itemType)
end

-- Open crates (single or batch)
function ShopUIHelper.OpenCrate(crateType, count)
	count = math.clamp(count or 1, 1, 10)
	if count == 1 then
		OpenCrate:FireServer(crateType)
	else
		BatchOpenCrate:FireServer(crateType, count)
	end
end

-- Redeem a promo code
function ShopUIHelper.RedeemCode(code)
	if type(code) ~= "string" or #code == 0 then return end
	RedeemCode:FireServer(code)
end

CodeResult.OnClientEvent:Connect(function(success, message)
	print("[SHOP] Code result: " .. (success and "SUCCESS" or "FAIL") .. " - " .. message)

	local screenGui = player.PlayerGui:FindFirstChild("MetaMenus")
	if screenGui then
		local label = screenGui:FindFirstChild("CodeResultLabel", true)
		if label then
			label.Text       = message
			label.TextColor3 = success
				and Color3.fromRGB(100, 255, 100)
				or  Color3.fromRGB(255, 100, 100)
			label.Visible    = true
			task.delay(3, function() label.Visible = false end)
		end
	end
end)

-- No _G assignment — use require() from other LocalScripts instead:
-- local ShopUIHelper = require(game.Players.LocalPlayer.PlayerScripts.ShopUIHelper)
return ShopUIHelper
