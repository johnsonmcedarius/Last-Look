local Players             = game:GetService("Players")
local ReplicatedStorage   = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local ServiceRegistry = require(ServerScriptService:WaitForChild("ServiceRegistry"))
local Config         = require(ReplicatedStorage:WaitForChild("SharedConfig"))
local DataManager     = ServiceRegistry.Await("DataManager")
local GachaService    = ServiceRegistry.Await("GachaService")
local RateLimiter     = require(ReplicatedStorage:WaitForChild("ReplicatedStorage"):WaitForChild("RateLimiter"))

-- Create a custom limiter that allows a max of 2 actions per second
local codeLimiter     = RateLimiter.NewRateLimiter(2) 

local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local function getRemote(name)
	local r = Remotes:FindFirstChild(name)
	if not r then 
		r = Instance.new("RemoteEvent") 
		r.Name = name 
		r.Parent = Remotes 
	end
	return r
end

local RedeemCode = getRemote("RedeemCode")
local CodeResult = getRemote("CodeResult")

-- ── Debounce cache ──
local activeRedemptions = {}

-- Helper to safely grab player data
local function getRedeemedCodes(player)
	local data = DataManager.GetData(player)
	if not data then return nil end
	if not data.RedeemedCodes then data.RedeemedCodes = {} end
	return data.RedeemedCodes
end

RedeemCode.OnServerEvent:Connect(function(player, code)
	
	if not codeLimiter:CheckRate(player) then return end
	activeRedemptions[player.UserId] = true

	local function finish(success, message)
		activeRedemptions[player.UserId] = nil
		CodeResult:FireClient(player, success, message)
	end

	-- 1. Sanitize input
	if type(code) ~= "string" then 
		activeRedemptions[player.UserId] = nil
		return 
	end
	code = code:upper():gsub("%s+", "")

	local codeData = Config.CODES[code]

	-- 2. Basic Validation
	if not codeData then
		finish(false, "Invalid code.")
		return
	end

	if not codeData.Active then
		finish(false, "This code has expired.")
		return
	end

	-- 3. Data Check
	local redeemed = getRedeemedCodes(player)
	if not redeemed then 
		finish(false, "Data not loaded. Try again.")
		return 
	end

	if redeemed[code] then
		finish(false, "Already redeemed!")
		return
	end

	-- 4. Mark as Redeemed
	redeemed[code] = true

	-- 5. Distribute Rewards
	if codeData.Reward == "Coins" then
		DataManager.AddCoins(player, codeData.Amount)
		finish(true, "+" .. codeData.Amount .. " Coins!")

	elseif codeData.Reward == "XP" then
		DataManager.AddXP(player, codeData.Amount)
		finish(true, "+" .. codeData.Amount .. " XP!")

	elseif codeData.Reward == "CoinDesignerCrate" then
		GachaService.AddCrate(player, "CoinDesignerCrate", codeData.Amount)
		finish(true, "Crate added to inventory!")
	else
		activeRedemptions[player.UserId] = nil
	end

	-- 6. Log for sanity
	print(string.format("[CODES] %s successfully redeemed: %s", player.Name, code))
end)