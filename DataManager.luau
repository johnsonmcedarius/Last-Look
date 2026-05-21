local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local ServiceRegistry = require(ServerScriptService:WaitForChild("ServiceRegistry"))
local Config = require(ReplicatedStorage:WaitForChild("SharedConfig"))

-- ── ProfileStore & ReplicaService ──
local ProfileStore = require(ServerScriptService.ProfileStore:WaitForChild("ProfileStore"))
local ReplicaService = require(ServerScriptService.ReplicaService:WaitForChild("ReplicaService"))

-- ── Remotes ──
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local ShowRewardPopup = Remotes:WaitForChild("ShowRewardPopup")

-- ── Signals ──
local DataLoaded = Instance.new("BindableEvent")
DataLoaded.Name = "DataLoaded"
DataLoaded.Parent = script

-- ── Constants ──
local PLAYER_DATA_CLASS_TOKEN = ReplicaService.NewClassToken("PlayerData")

local STARTING_DATA = {
	Coins = 500, 
	Level = 1, 
	XP = 0,
	OwnedItems = { 
		[Config.CATEGORIES.SKINS or "Skins"] = {"Default"}, 
		[Config.CATEGORIES.WEAPON_SKINS or "WeaponSkins"] = {"BasicScissors"}, 
		[Config.CATEGORIES.PODIUMS or "Podiums"] = {"BasicPodium"},
		[Config.CATEGORIES.SKIN_EFFECTS or "SkinEffects"] = {"None"},
		[Config.CATEGORIES.SHOWSTOPPERS or "Showstoppers"] = {},
		[Config.CATEGORIES.EMOTES or "Emotes"] = {"Wave"}
	},
	Equipped = { 
		Skin = "Default", 
		WeaponSkin = "BasicScissors", 
		Podium = "BasicPodium",
		SkinEffect = "None", 
		Ability1 = "", 
		Emote = "Wave"
	},
	PityCounter = {}, 
	Inventory = { CoinDesignerCrate = 0, RobuxDesignerCrate = 0 }, 
	RedeemedCodes = {}, 
	LoginStreak = 0, 
	LastLogin = 0,
}

local Profiles = {}
local Replicas = {}

-- ── Math Helpers ──
local function GetLevelFromXP(totalXP)
	if totalXP <= 0 then return 1 end
	-- Level = (XP / Base) ^ (1/Mult) + 1
	local calculatedLevel = math.floor((totalXP / Config.BASE_XP) ^ (1 / Config.XP_MULTIPLIER))
	return math.max(1, calculatedLevel + 1)
end

local DataManager = {}

-- ── Data Retrieval ──
function DataManager.GetProfile(player) return Profiles[player] end
function DataManager.GetData(player)    return Profiles[player] and Profiles[player].Data end
function DataManager.GetCoins(player)   local data = DataManager.GetData(player) return data and data.Coins or 0 end
function DataManager.OnDataLoaded(callback)
	return DataLoaded.Event:Connect(callback)
end

-- ── Core Reward System ──
function DataManager.AddReward(player, xp, coins, skipPopup)
	if (xp or 0) < 0 or (coins or 0) < 0 then
		warn("[DATA] Blocked negative reward attempt for " .. player.Name)
		return
	end

	local profile = Profiles[player]
	local replica = Replicas[player]
	if not profile or not replica then return end

	local finalXP = xp or 0
	local finalCoins = coins or 0

	-- Multiplier Check (VIP/Gamepasses)
	local xpMult = player:GetAttribute("XPMultiplier") or 1
	finalXP = math.floor(finalXP * xpMult)

	profile.Data.Coins = math.max(0, profile.Data.Coins + finalCoins)
	profile.Data.XP += finalXP

	-- Update Attributes for easy access
	player:SetAttribute("Coins", profile.Data.Coins)
	player:SetAttribute("XP", profile.Data.XP)

	-- Level Up Logic
	local newLevel = GetLevelFromXP(profile.Data.XP)
	if newLevel > profile.Data.Level then
		profile.Data.Level = newLevel
		player:SetAttribute("Level", newLevel)
		print("[LEVEL] " .. player.Name .. " is now Level " .. newLevel .. "! Pure talent.")
	end

	-- Sync to Client
	replica:SetValue({"Coins"}, profile.Data.Coins)
	replica:SetValue({"XP"}, profile.Data.XP)
	replica:SetValue({"Level"}, profile.Data.Level)

	if not skipPopup and (finalXP > 0 or finalCoins > 0) then
		local xpText = finalXP > 0 and "+"..finalXP.." XP" or ""
		local coinText = finalCoins > 0 and "+"..finalCoins.." Coins" or ""
		ShowRewardPopup:FireClient(player, xpText, coinText)
	end
end

function DataManager.AddCoins(player, amount) DataManager.AddReward(player, 0, amount, true) end
function DataManager.AddXP(player, amount)    DataManager.AddReward(player, amount, 0, true) end

-- ── Coin Management ──
function DataManager.SubtractCoins(player, amount)
	if amount <= 0 then
		warn("[DATA] Blocked non-positive SubtractCoins attempt: " .. tostring(amount))
		return false
	end

	local profile = Profiles[player]
	local replica = Replicas[player]
	if not profile or not replica then return false end

	if profile.Data.Coins >= amount then
		profile.Data.Coins -= amount

		-- Sync
		replica:SetValue({"Coins"}, profile.Data.Coins)
		player:SetAttribute("Coins", profile.Data.Coins)

		return true
	end
	return false
end

-- ── Item Management ──
function DataManager.GiveItem(player, category, itemName)
	local data = DataManager.GetData(player)
	if not data or not data.OwnedItems[category] then return false end

	if table.find(data.OwnedItems[category], itemName) then 
		return false -- Already owned
	end

	table.insert(data.OwnedItems[category], itemName)

	if Replicas[player] then 
		Replicas[player]:SetValue({"OwnedItems", category}, data.OwnedItems[category]) 
	end
	return true
end

function DataManager.HasItem(player, category, itemName)
	local data = DataManager.GetData(player)
	return data and data.OwnedItems[category] and table.find(data.OwnedItems[category], itemName) ~= nil
end

function DataManager.UpdateEquipped(player, key, value)
	local profile = Profiles[player]
	local replica = Replicas[player]
	if not profile or not replica then return end

	profile.Data.Equipped[key] = value
	replica:SetValue({"Equipped", key}, value)
	player:SetAttribute("Equipped" .. key, value)
end

-- ── Inventory & Pity State Synchronization ──
function DataManager.UpdateInventoryReplica(player)
	local profile = Profiles[player]
	local replica = Replicas[player]
	if not profile or not replica then return end

	-- Forces ReplicaService to sync the entire nested Inventory dictionary to the client UI
	replica:SetValue({"Inventory"}, profile.Data.Inventory)
end

function DataManager.UpdatePityReplica(player)
	local profile = Profiles[player]
	local replica = Replicas[player]
	if not profile or not replica then return end

	-- Forces ReplicaService to sync the PityCounter dictionary for UI updates
	replica:SetValue({"PityCounter"}, profile.Data.PityCounter)
end

-- ── Hitbox Parity Validation ──
function DataManager.ValidateHitboxParity(player, character)
	if not Config.HITBOX_PARITY or not Config.HITBOX_PARITY.ENABLE_VALIDATION then
		return true
	end

	if not character then return false end

	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not hrp then return false end

	local actualSize = hrp.Size
	local validSize = Config.HITBOX_PARITY.VALID_HITBOX_SIZE or Vector3.new(2, 2, 1)
	local maxDeviation = Config.HITBOX_PARITY.ALLOWED_DEVIATION or 0.05

	-- Calculate structural dimensional deviations
	local xDiff = math.abs(actualSize.X - validSize.X) / validSize.X
	local yDiff = math.abs(actualSize.Y - validSize.Y) / validSize.Y
	local zDiff = math.abs(actualSize.Z - validSize.Z) / validSize.Z

	if xDiff > maxDeviation or yDiff > maxDeviation or zDiff > maxDeviation then
		warn("[HITBOX] " .. player.Name .. " non-compliant size detected: " .. tostring(actualSize) .. ". Correcting size vector.")

		-- Override the size property directly instead of dropping character state via LoadCharacter
		hrp.Size = validSize

		-- Force non-canceling physics parity definitions
		if hrp:CanCollide() then
			hrp.CanCollide = true
		end

		return false
	end

	return true
end

function DataManager.ValidateEquippedItems(player)
	local data = DataManager.GetData(player)
	if not data then return true end

	local equippedSkin = data.Equipped and data.Equipped.SkinEffect
	if equippedSkin and equippedSkin ~= "None" then
		print("[HITBOX] Auditing " .. player.Name .. " skin effect: " .. equippedSkin)
	end

	return true
end

-- ── Session Handling ──
local function PlayerAdded(player)
	local store = ProfileStore.New("Player_Data_" .. Config.DATA_VERSION, STARTING_DATA)
	local profile = store:StartSessionAsync(tostring(player.UserId))

	if profile then
		profile:Reconcile()

		if not profile.Data.PityCounter then
			profile.Data.PityCounter = {}
		end

		profile.OnSessionEnd:Connect(function()
			Profiles[player] = nil
			if Replicas[player] then 
				Replicas[player]:Destroy()
				Replicas[player] = nil 
			end
			if player.Parent then player:Kick("Session ended. Rejoin to fix your fit.") end
		end)

		if player:IsDescendantOf(Players) then
			Profiles[player] = profile

			Replicas[player] = ReplicaService.NewReplica({
				ClassToken = PLAYER_DATA_CLASS_TOKEN,
				Data = profile.Data,
				Replication = player
			})

			-- ── LOGIN STREAK HANDLING ──
			local data = profile.Data
			local now = os.time() 
			local last = data.LastLogin or 0

			local function getMidnight(timestamp)
				local date = os.date("!*t", timestamp)
				return os.time({year=date.year, month=date.month, day=date.day, hour=0, min=0, sec=0})
			end

			local lastMidnight = getMidnight(last)
			local todayMidnight = getMidnight(now)
			local DAY_SECONDS = 86400

			if todayMidnight > lastMidnight then
				if (todayMidnight - lastMidnight) <= DAY_SECONDS then
					data.LoginStreak = (data.LoginStreak or 0) + 1
				else
					data.LoginStreak = 1 
				end
				data.LastLogin = now

				-- DEFER CODES & REWARDS
				task.defer(function()
					local rewardTier = Config.LOGIN_REWARDS[data.LoginStreak]
					if rewardTier then
						if rewardTier.Type == "Coins" then
							DataManager.AddCoins(player, rewardTier.Amount)
						elseif rewardTier.Type == "Crate" then
							local Gacha = ServiceRegistry.Get("GachaService")
							if Gacha then 
								Gacha.AddCrate(player, rewardTier.CrateType, rewardTier.Amount) 
							else
								warn("[DATA] GachaService missing during login reward payout for " .. player.Name)
							end
						end
					end
				end)
			end

			-- ── PITY RESET ──
			Replicas[player]:SetValue({"LoginStreak"}, data.LoginStreak or 1)
			Replicas[player]:SetValue({"LastLogin"}, data.LastLogin or now)

			-- Initial Sync
			player:SetAttribute("Coins", data.Coins)
			player:SetAttribute("XP", data.XP)
			player:SetAttribute("Level", data.Level)
			for key, val in pairs(data.Equipped) do
				player:SetAttribute("Equipped" .. key, val)
			end

			DataLoaded:Fire(player)
			print("[DATA] " .. player.Name .. " loaded in successfully.")
		else
			profile:EndSession()
		end
	else
		player:Kick("Data failed to load. We can't let you play without your fit saved.")
	end
end

-- ── Lifecycle Registration ──
-- Expose a Start method so the registry executes this ONLY when everything else is alive
function DataManager:Start()
	Players.PlayerAdded:Connect(PlayerAdded)
	for _, p in ipairs(Players:GetPlayers()) do task.spawn(PlayerAdded, p) end
end

Players.PlayerRemoving:Connect(function(player)
	local profile = Profiles[player]
	if profile then profile:EndSession() end
end)

game:BindToClose(function()
	for _, player in ipairs(Players:GetPlayers()) do
		local profile = Profiles[player]
		if profile then profile:EndSession() end
	end
end)

ServiceRegistry.Register("DataManager", DataManager)
return DataManager