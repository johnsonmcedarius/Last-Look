local Players             = game:GetService("Players")
local ReplicatedStorage   = game:GetService("ReplicatedStorage")
local MarketplaceService  = game:GetService("MarketplaceService")
local ServerScriptService = game:GetService("ServerScriptService")
local ItemDatabase = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("ItemDatabase"))

print("[MARKETPLACE] Loading dependencies...")
local ServiceRegistry = require(ServerScriptService:WaitForChild("ServiceRegistry"))
local Registry        = require(ReplicatedStorage:WaitForChild("MarketplaceRegistry"))
print("[MARKETPLACE] MarketplaceRegistry loaded.")

-- Await hard dependencies before setting ProcessReceipt
local DataManager    = ServiceRegistry.Await("DataManager")
local GachaService   = ServiceRegistry.Await("GachaService")
local GiftingService = ServiceRegistry.Await("GiftingService")

local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local function getRemote(name)
	local r = Remotes:FindFirstChild(name)
	if not r then r = Instance.new("RemoteEvent") r.Name = name r.Parent = Remotes end
	return r
end

local GiftReceived       = getRemote("GiftReceived")
local AbilitySlotUnlock  = getRemote("AbilitySlotUnlock")
local GlobalAnnouncement = getRemote("GlobalAnnouncement")
local TriggerUnboxing     = getRemote("TriggerUnboxing")

local CrateRegistry = require(ReplicatedStorage:WaitForChild("CrateRegistry"))

-- ── Gamepass perks on join ────────────────────────────────────────────────────
local function applyGamepassPerks(player)
	for passKey, pass in pairs(Registry.GamePasses) do
		if pass.Id == 0 then continue end

		local ok, owns = pcall(function()
			return MarketplaceService:UserOwnsGamePassAsync(player.UserId, pass.Id)
		end)

		if not ok then
			warn("[MARKETPLACE] Failed to check gamepass " .. passKey .. " for " .. player.Name)
			continue
		end
		if not owns then continue end

		local perks = pass.Perks or {}

		if perks.IsVIP then
			player:SetAttribute("IsVIP", true)
			local data = DataManager.GetData(player)
			if data and data.Equipped then
				if data.Equipped.Podium == "BasicPodium" and perks.AutoPodium then
					DataManager.SetEquipped(player, "Podium", perks.AutoPodium)
				end
			end
			if perks.CoinBonus then
				player:SetAttribute("VIPCoinBonus", perks.CoinBonus)
			end
		end

		if perks.CoinsMultiplier then
			player:SetAttribute("CoinsMultiplier", perks.CoinsMultiplier)
		end

		if perks.XPMultiplier then
			player:SetAttribute("XPMultiplier", perks.XPMultiplier)
		end

		if perks.AbilitySlot then
			local current = player:GetAttribute("UnlockedAbilitySlots") or 1
			if perks.AbilitySlot > current then
				player:SetAttribute("UnlockedAbilitySlots", perks.AbilitySlot)
			end
		end
	end

	for bundleKey, bundle in pairs(Registry.Bundles) do
		if bundle.Id == 0 then continue end
		local ok, owns = pcall(function()
			return MarketplaceService:UserOwnsGamePassAsync(player.UserId, bundle.Id)
		end)
		if ok and owns then DataManager.UnlockBundle(player, bundleKey) end
	end

	for itemKey, item in pairs(Registry.Items) do
		if item.Id == 0 then continue end
		local ok, owns = pcall(function()
			return MarketplaceService:UserOwnsGamePassAsync(player.UserId, item.Id)
		end)
		if ok and owns then DataManager.GiveItem(player, item.Category, item.ItemName) end
	end

	print("[MARKETPLACE] Gamepass perks applied for " .. player.Name)
end

-- ── Subscription check ────────────────────────────────────────────────────────
local function applySubscriptionPerks(player)
	local subId = Registry.Subscription.SubscriptionId
	if not subId or subId == "EXP-0000000000" then return end

	local ok, status = pcall(function()
		return MarketplaceService:GetUserSubscriptionStatusAsync(player, subId)
	end)

	if not ok then
		warn("[MARKETPLACE] Subscription check failed for " .. player.Name)
		return
	end

	if status and status.IsSubscribed then
		player:SetAttribute("IsSubscribed", true)

		local data = DataManager.GetData(player)
		if data and not data.SubscriptionCoinGrantedThisMonth then
			DataManager.AddCoins(player, Registry.Subscription.Perks.MonthlyCoins or 300)
			data.SubscriptionCoinGrantedThisMonth = true
			print("[MARKETPLACE] Subscription monthly coins granted to " .. player.Name)
		end

		print("[MARKETPLACE] " .. player.Name .. " is a Roblox Plus subscriber.")
	end
end

-- ── ProcessReceipt ────────────────────────────────────────────────────────────
MarketplaceService.ProcessReceipt = function(receiptInfo)
	local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
	if not player then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	-- Gift check first
	local handled = GiftingService.ProcessGiftReceipt(receiptInfo)
	if handled then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end

	local productId    = receiptInfo.ProductId
	
	-- ── Crate Purchase Check ──
	for _, crate in ipairs(CrateRegistry.GetAll()) do
		if crate.productId == productId then
			TriggerUnboxing:FireClient(player, crate.id)
			print(string.format("[MARKETPLACE] %s completed Robux purchase for %s", player.Name, crate.id))
			return Enum.ProductPurchaseDecision.PurchaseGranted
		end
	end

	local productEntry = Registry.GetProductById(productId)

	if productEntry then
		local reward = productEntry.Reward

		if reward.Coins then
			DataManager.AddCoins(player, reward.Coins)
			print("[MARKETPLACE] " .. player.Name .. " bought " .. reward.Coins .. " coins.")
			return Enum.ProductPurchaseDecision.PurchaseGranted
		end

		if reward.Crate then
			GachaService.AddCrate(player, reward.Crate, reward.Amount or 1)
			print("[MARKETPLACE] " .. player.Name .. " bought " .. reward.Crate)
			return Enum.ProductPurchaseDecision.PurchaseGranted
		end
	end

	-- ── ItemDatabase check ──
	for category, data in pairs(ItemDatabase) do
		if typeof(data) == "table" and data.Items then
			for itemName, itemData in pairs(data.Items) do
				if itemData.ProductId == productId then
					local profile = DataManager.GetProfile(player)
					if profile and not table.find(profile.Data.OwnedItems[category], itemName) then
						DataManager.GiveItem(player, category, itemName)
						print(string.format("[MARKETPLACE] %s processed Robux purchase: %s", player.Name, itemName))
						return Enum.ProductPurchaseDecision.PurchaseGranted
					end
				end
			end
		end
	end

	local passEntry = Registry.GetGamepassById(productId)
	if passEntry and passEntry.Perks and passEntry.Perks.AbilitySlot then
		local slot    = passEntry.Perks.AbilitySlot
		local current = player:GetAttribute("UnlockedAbilitySlots") or 1
		if slot > current then
			player:SetAttribute("UnlockedAbilitySlots", slot)
			AbilitySlotUnlock:FireClient(player, slot)
			print("[MARKETPLACE] " .. player.Name .. " unlocked ability slot " .. slot)
		end
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end

	warn("[MARKETPLACE] Unknown product ID: " .. tostring(productId))
	return Enum.ProductPurchaseDecision.NotProcessedYet
end

-- ── Gamepass purchase (same-session grant) ────────────────────────────────────
local function onGamepassPurchased(player, passId, purchased)
	if not purchased then return end

	local bundle = Registry.GetBundleById(passId)
	if bundle then
		DataManager.UnlockBundle(player,
			Registry.GetBundleKeyById and Registry.GetBundleKeyById(passId) or "")
		GlobalAnnouncement:FireAllClients(player.Name .. " unlocked the " .. bundle.Name .. "!")
		print("[MARKETPLACE] " .. player.Name .. " purchased bundle: " .. bundle.Name)
		return
	end

	local item = Registry.GetItemById(passId)
	if item then
		DataManager.GiveItem(player, item.Category, item.ItemName)
		print("[MARKETPLACE] " .. player.Name .. " purchased item: " .. item.Name)
		return
	end

	local pass = Registry.GetGamepassById(passId)
	if pass then
		applyGamepassPerks(player)
		print("[MARKETPLACE] " .. player.Name .. " purchased gamepass: " .. pass.Name)
	end
end

MarketplaceService.PromptGamePassPurchaseFinished:Connect(onGamepassPurchased)

-- ── Subscription prompt relay ─────────────────────────────────────────────────
local PromptSubscription = getRemote("PromptSubscription")
PromptSubscription.OnServerEvent:Connect(function(player)
	local SubIdRemote = getRemote("SubscriptionIdRelay")
	SubIdRemote:FireClient(player, Registry.Subscription.SubscriptionId)
end)

-- ── Player lifecycle ──────────────────────────────────────────────────────────
-- No more task.wait(3) — DataManager is already loaded via Await above
local function onPlayerAdded(player)
	applyGamepassPerks(player)
	applySubscriptionPerks(player)
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, p in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayerAdded, p)
end

print("[MARKETPLACE] MarketplaceHandler ready.")
