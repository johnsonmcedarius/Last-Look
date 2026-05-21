local Teams = game:GetService("Teams")
local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")

local ServiceRegistry = require(ServerScriptService:WaitForChild("ServiceRegistry"))

local TeamService = {}

local DesignersTeam = Teams:WaitForChild("Designers")
local CriticsTeam = Teams:WaitForChild("Critics")
local LobbyTeam = Teams:WaitForChild("Lobby")

function TeamService.ResetTeams()
	for _, player in ipairs(Players:GetPlayers()) do
		player.Team = LobbyTeam
	end
end

function TeamService.AssignTeams()
	local allPlayers = Players:GetPlayers()
	if #allPlayers < 2 then return {}, {} end

	-- Fisher-Yates Shuffle
	for i = #allPlayers, 2, -1 do
		local j = math.random(i)
		allPlayers[i], allPlayers[j] = allPlayers[j], allPlayers[i]
	end

	-- 50/50 split using math.floor
	local splitPoint = math.floor(#allPlayers / 2)
	local critics = {}
	local designers = {}

	for i, player in ipairs(allPlayers) do
		if i <= splitPoint then
			player.Team = CriticsTeam
			table.insert(critics, player)
		else
			player.Team = DesignersTeam
			table.insert(designers, player)
		end
	end

	-- Notify MatchRegistry of player count for dynamic scaling
	local MatchRegistry = ServiceRegistry.Get("MatchRegistry")
	if MatchRegistry then
		MatchRegistry.CalculateMatchStyle(#allPlayers)
	end

	print("[TEAMSERVICE] 50/50 Split: " .. #critics .. " Critics, " .. #designers .. " Designers")

	return critics, designers
end

ServiceRegistry.Register("TeamService", TeamService)
return TeamService