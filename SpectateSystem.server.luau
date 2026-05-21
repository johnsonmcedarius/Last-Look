local Players             = game:GetService("Players")
local ReplicatedStorage   = game:GetService("ReplicatedStorage")
local Teams               = game:GetService("Teams")
local ServerScriptService = game:GetService("ServerScriptService")

local ServiceRegistry = require(ServerScriptService:WaitForChild("ServiceRegistry"))
local RoundEvents     = require(ServerScriptService:WaitForChild("RoundEvents"))

local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local function makeRemote(name)
	local r = Remotes:FindFirstChild(name)
	if not r then
		r        = Instance.new("RemoteEvent")
		r.Name   = name
		r.Parent = Remotes
	end
	return r
end

local StartSpectate    = makeRemote("StartSpectate")
local StopSpectate     = makeRemote("StopSpectate")
local CycleSpectate    = makeRemote("CycleSpectate")
local SpectateRequest  = makeRemote("SpectateRequest")

-- ── State ────────────────────────────────────────────────────────────────────
local spectators  = {}   -- [userId] = {target = player}
local roundActive = false

-- ── Helpers ──────────────────────────────────────────────────────────────────
local function isSpectator(player)
	return player.Team and player.Team.Name == "Lobby"
end

local function getActiveDesigners()
	local result = {}
	local designersTeam = Teams:FindFirstChild("Designers")
	if designersTeam then
		for _, p in ipairs(designersTeam:GetPlayers()) do
			table.insert(result, p)
		end
	end
	return result
end

local function assignSpectateTarget(spectator, specificTarget)
	local designers = getActiveDesigners()
	if #designers == 0 then
		StopSpectate:FireClient(spectator)
		return
	end

	local target = specificTarget

	-- If no specific target, find next in cycle or random
	if not target then
		local current = spectators[spectator.UserId]
		if current and current.target then
			local idx = 1
			for i, p in ipairs(designers) do
				if p == current.target then idx = i break end
			end
			target = designers[(idx % #designers) + 1]
		else
			target = designers[math.random(#designers)]
		end
	end

	if target and target.Character then
		spectators[spectator.UserId] = {target = target}
		StartSpectate:FireClient(spectator, target)
		print("[SPECTATE] " .. spectator.Name .. " is now watching " .. target.Name)
	end
end

-- ── Remote Listeners ─────────────────────────────────────────────────────────

-- Manual Request from UI
SpectateRequest.OnServerEvent:Connect(function(player, targetName)
	if not isSpectator(player) then return end

	local target = Players:FindFirstChild(targetName)
	if target and target.Character and target.Team and target.Team.Name ~= "Lobby" then
		assignSpectateTarget(player, target)
	end
end)

-- Cycle button
CycleSpectate.OnServerEvent:Connect(function(spectator)
	if not isSpectator(spectator) then return end
	assignSpectateTarget(spectator)
end)

-- ── Lifecycle ────────────────────────────────────────────────────────────────

RoundEvents.RoundStarted.Event:Connect(function()
	roundActive = true
	-- Automatic triggers removed per request. Players must manually request via UI.
end)

RoundEvents.RoundEnded.Event:Connect(function()
	roundActive  = false
	spectators   = {}
	for _, p in ipairs(Players:GetPlayers()) do
		StopSpectate:FireClient(p)
	end
end)

Players.PlayerRemoving:Connect(function(p)
	spectators[p.UserId] = nil
end)

-- ── Service Export ───────────────────────────────────────────────────────────
local SpectateSystem = {}

ServiceRegistry.Register("SpectateSystem", SpectateSystem)
return SpectateSystem