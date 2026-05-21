local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local function getRemote(name)
	local r = Remotes:FindFirstChild(name)
	if not r then
		r = Instance.new("RemoteEvent")
		r.Name   = name
		r.Parent = Remotes
	end
	return r
end

local DashCooldownUpdate = getRemote("DashCooldownUpdate")

-- Server owns this value. Client fires to trigger it, but we reply with OUR number.
local DEFAULT_DASH_COOLDOWN = 0.8

-- Rate limit: prevent even this benign relay from being spammed
local lastFired = {}  -- [userId] = os.clock()

DashCooldownUpdate.OnServerEvent:Connect(function(player)
	local char = player.Character
	local cooldown = DEFAULT_DASH_COOLDOWN
	
	if char then
		if char:GetAttribute("MainEventActive") then
			cooldown = 0
		elseif player:GetAttribute("InGlitch") then
			cooldown = 999 -- Disabled
		end
	end

	local now = os.clock()
	if now - (lastFired[player.UserId] or 0) < (cooldown - 0.1) then
		return  -- Too fast, ignore
	end
	lastFired[player.UserId] = now

	-- Reply with server-authoritative cooldown value
	DashCooldownUpdate:FireClient(player, cooldown)
end)

local Players = game:GetService("Players")
Players.PlayerRemoving:Connect(function(p)
	lastFired[p.UserId] = nil
end)