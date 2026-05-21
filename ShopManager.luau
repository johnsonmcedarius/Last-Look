-- // Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")

-- // Modules
local DataManager = require(script.Parent:WaitForChild("DataManager"))
local ServiceRegistry = require(script.Parent:WaitForChild("ServiceRegistry"))
local ItemDatabase = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("ItemDatabase"))
local RemoteRegistry = require(ReplicatedStorage:WaitForChild("RemoteRegistry"))

-- // Remotes
local ShopRequest = RemoteRegistry.Get("ShopRequest")

local ShopManager = {}

-- ── Rate Limiting State ──
local PurchaseRateLimits = {}
local SHOP_COOLDOWN = 0.5 

-- // CORE LOGIC
ShopRequest.OnServerEvent:Connect(function(player, action, itemName)
	-- ── Exploit Validation: Type and Sanity Checks ──
	if type(action) ~= "string" or type(itemName) ~= "string" then 
		return 
	end

	-- ── Exploit Validation: Rate Limiter ──
	local now = os.clock()
	local lastRequest = PurchaseRateLimits[player.UserId] or 0
	if now - lastRequest < SHOP_COOLDOWN then 
		return
	end
	PurchaseRateLimits[player.UserId] = now

	-- Fetch Player Save Data
	local profile = DataManager.GetProfile(player)
	if not profile then return end
	local data = profile.Data

	if action == "Purchase" then
		local itemData, category = ItemDatabase.GetItemData(itemName)
		if not category or not itemData then return end

		-- Validate data structure array exists inside player profile
		if not data.OwnedItems[category] then return end

		-- Check if already owned
		if table.find(data.OwnedItems[category], itemName) then
			print("WOAH " .. player.Name .. " already owns this item.")
			return
		end

		if itemData.Currency == "Coins" then
			-- Enforce integer validation check on item costs
			local cost = math.max(0, math.floor(itemData.Cost or 0))

			if DataManager.SubtractCoins(player, cost) then
				DataManager.GiveItem(player, category, itemName)
				print("++ " .. player.Name .. " bought " .. itemName)
			else
				-- Safe log output that doesn't overwhelm the thread execution environment
				warn("[SHOP] " .. player.Name .. " attempted to purchase " .. itemName .. " but lacks funding.")
			end
		elseif itemData.Currency == "Robux" then
			if not itemData.ProductId then return end
			-- Developer Product Purchases are validated and awarded securely via ProcessReceipt inside MarketplaceHandler
			MarketplaceService:PromptProductPurchase(player, itemData.ProductId)
		end

	elseif action == "Equip" then
		local itemData, category = ItemDatabase.GetItemData(itemName)
		if not category or not ItemDatabase[category] then return end

		-- Fetch explicit slot category dictionary mapping
		local equipKey = ItemDatabase[category].EquipSlot 
		if not equipKey or not data.OwnedItems[category] then return end

		-- Verify ownership server-side before updating save data state
		if table.find(data.OwnedItems[category], itemName) then
			data.Equipped[equipKey] = itemName

			-- Broadcast attributes
			player:SetAttribute("Equipped" .. equipKey, itemName)

			print("YAY " .. player.Name .. " equipped " .. itemName)
		end
	end
end)

-- Clear memory allocations when a user logs out
Players.PlayerRemoving:Connect(function(player)
	PurchaseRateLimits[player.UserId] = nil
end)

ServiceRegistry.Register("ShopManager", ShopManager)
return ShopManager