local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local ServiceRegistry = require(ServerScriptService:WaitForChild("ServiceRegistry"))
local DataManager = ServiceRegistry.Await("DataManager")
local Config = require(ReplicatedStorage:WaitForChild("SharedConfig"))
local LootTable = require(ReplicatedStorage:WaitForChild("LootTable"))

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local CrateResult = Remotes:WaitForChild("CrateResult")
local BatchCrateResults = Remotes:WaitForChild("BatchCrateResults")
local GlobalAnnouncement = Remotes:WaitForChild("GlobalAnnouncement")

-- Lazy load DataManager --
local function getDataManager()
	return ServiceRegistry.Get("DataManager")
end

-- ── Rate Limiting ──
local RateLimits = {}
local SPIN_COOLDOWN = 1.5 

-- ── Optimized Weight Caching (Prefix Sums) ──
local PoolCaches = {}

local function rebuildPoolCache(crateType)
	local pool = LootTable[crateType]
	if not pool then return end

	local cache = {
		Normal = { items = {}, totalWeight = 0 },
		Pity = { items = {}, totalWeight = 0 }
	}

	for _, item in ipairs(pool) do
		local weight = Config.RARITY_WEIGHTS[item.Rarity] or 1

		-- Normal Pool logic
		cache.Normal.totalWeight += weight
		table.insert(cache.Normal.items, { item = item, threshold = cache.Normal.totalWeight })

		-- Pity Pool logic (Legendary/Mythic Only)
		if item.Rarity == "Legendary" or item.Rarity == "Mythic" then
			cache.Pity.totalWeight += weight
			table.insert(cache.Pity.items, { item = item, threshold = cache.Pity.totalWeight })
		end
	end

	PoolCaches[crateType] = cache
end

for crateName in pairs(LootTable) do rebuildPoolCache(crateName) end

-- ── Logic ──

local function pickItem(crateType, guaranteeLegendary)
	local poolData = PoolCaches[crateType]
	if not poolData then return nil end

	local targetPool = (guaranteeLegendary and poolData.Pity.totalWeight > 0) and poolData.Pity or poolData.Normal
	local roll = math.random() * targetPool.totalWeight

	-- Binary Search: O(log n) speed
	local low, high = 1, #targetPool.items
	while low <= high do
		local mid = math.floor((low + high) / 2)
		if targetPool.items[mid].threshold >= roll then
			if mid == 1 or targetPool.items[mid - 1].threshold < roll then
				return targetPool.items[mid].item
			end
			high = mid - 1
		else
			low = mid + 1
		end
	end
	return targetPool.items[#targetPool.items].item
end

local function processSpin(player, crateType)
	local DataManager = getDataManager()
	if not DataManager then return nil end

	local data = DataManager.GetData(player)
	if not data then return nil end

	local pity = (data.PityCounter and data.PityCounter[crateType]) or 0
	local guarantee = pity >= Config.PITY_THRESHOLD
	local item = pickItem(crateType, guarantee)

	if not item then return nil end

	-- Update Pity State
	if not data.PityCounter then data.PityCounter = {} end
	if item.Rarity == "Legendary" or item.Rarity == "Mythic" then
		data.PityCounter[crateType] = 0
	else
		data.PityCounter[crateType] = pity + 1
	end

	-- Sync Pity to Replica right after mutation so the UI updates instantly
	if DataManager.UpdatePityReplica then
		DataManager.UpdatePityReplica(player)
	end

	-- Inventory Logic
	local isDuplicate = DataManager.HasItem(player, item.Category, item.Name)
	local compensation = 0

	if isDuplicate then
		compensation = Config.DUPLICATE_REWARDS[item.Rarity] or 50
		DataManager.AddCoins(player, compensation)
	else
		DataManager.GiveItem(player, item.Category, item.Name)
	end

	-- Mythic Flexing
	if item.Rarity == "Mythic" and not isDuplicate then
		GlobalAnnouncement:FireAllClients(player.Name .. " just pulled a MYTHIC: " .. item.Name .. "!")
	end

	return { 
		Name = item.Name, 
		Category = item.Category, 
		Rarity = item.Rarity, 
		IsDuplicate = isDuplicate, 
		Compensation = compensation 
	}
end

-- ── Listeners ──

Remotes:WaitForChild("OpenCrate").OnServerEvent:Connect(function(player, crateType)
	-- Exploitation & Validation checks
	if type(crateType) ~= "string" or not LootTable[crateType] then return end

	local now = os.clock()
	if now - (RateLimits[player.UserId] or 0) < SPIN_COOLDOWN then return end
	RateLimits[player.UserId] = now

	local data = DataManager.GetData(player)
	if data and data.Inventory and (data.Inventory[crateType] or 0) > 0 then
		data.Inventory[crateType] -= 1

		-- Sync current crate counts down to client UI replica
		if DataManager.UpdateInventoryReplica then
			DataManager.UpdateInventoryReplica(player)
		end

		local result = processSpin(player, crateType)
		if result then CrateResult:FireClient(player, crateType, result) end
	end
end)

Remotes:WaitForChild("BatchOpenCrate").OnServerEvent:Connect(function(player, crateType, count)
	-- Exploitation & Validation checks
	if type(crateType) ~= "string" or not LootTable[crateType] then return end

	local now = os.clock()
	if now - (RateLimits[player.UserId] or 0) < SPIN_COOLDOWN then return end
	RateLimits[player.UserId] = now

	local cleanCount = math.clamp(math.floor(count or 1), 1, 10)
	local data = DataManager.GetData(player)

	if data and data.Inventory and (data.Inventory[crateType] or 0) >= cleanCount then
		data.Inventory[crateType] -= cleanCount

		-- Sync current crate counts down to client UI replica
		if DataManager.UpdateInventoryReplica then
			DataManager.UpdateInventoryReplica(player)
		end

		local results = {}
		for i = 1, cleanCount do
			local res = processSpin(player, crateType)
			if res then table.insert(results, res) end
		end
		BatchCrateResults:FireClient(player, crateType, results)
	end
end)

Players.PlayerRemoving:Connect(function(player)
	RateLimits[player.UserId] = nil
end)

-- ── Service Methods ──
local GachaService = {}

function GachaService.BuyCoinCrate(player)
	local cost = Config.COIN_CRATE_COST or 500
	if DataManager.SubtractCoins(player, cost) then
		GachaService.AddCrate(player, "CoinDesignerCrate", 1)
		return true
	end
	return false
end

function GachaService.AddCrate(player, crateType, amount)
	local data = DataManager.GetData(player)
	if data then
		if not data.Inventory then data.Inventory = {} end
		data.Inventory[crateType] = (data.Inventory[crateType] or 0) + (amount or 1)

		-- Sync right away when giving a crate externally (like your daily login reward pass)
		if DataManager.UpdateInventoryReplica then
			DataManager.UpdateInventoryReplica(player)
		end
	end
end

ServiceRegistry.Register("GachaService", GachaService)
return GachaService