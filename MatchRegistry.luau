local ServerScriptService = game:GetService("ServerScriptService")

local ServiceRegistry = require(ServerScriptService:WaitForChild("ServiceRegistry"))

local MatchRegistry = {}

-- Dynamic scaling configuration
-- Maps player count to match format and target score
local MATCH_CONFIG = {
	[2] = { format = "1v1", targetScore = 3 },
	[4] = { format = "2v2", targetScore = 5 },
	[6] = { format = "3v3", targetScore = 7 },
	[8] = { format = "4v4", targetScore = 8 },
	[10] = { format = "5v5", targetScore = 10 },
}

local currentMatchStyle = "2v2"
local targetScore = 5

--- Calculate match style based on player count
--- @param playerCount number
--- @return table matchConfig
function MatchRegistry.CalculateMatchStyle(playerCount)
	local bestMatch = MATCH_CONFIG[4] -- default 2v2
	
	for size, config in pairs(MATCH_CONFIG) do
		if playerCount >= size then
			bestMatch = config
		end
	end
	
	currentMatchStyle = bestMatch.format
	targetScore = bestMatch.targetScore
	
	print("[MATCHREGISTRY] Match style set to: " .. currentMatchStyle .. " with target score: " .. targetScore)
	
	return bestMatch
end

--- Get the current target score
--- @return number
function MatchRegistry.GetTargetScore()
	return targetScore
end

--- Get the current match style string (e.g., "2v2")
--- @return string
function MatchRegistry.GetCurrentStyle()
	return currentMatchStyle
end

--- Get the team size from current match style
--- @return number
function MatchRegistry.GetTeamSize()
	return tonumber(currentMatchStyle:sub(1, 1)) or 2
end

--- Reset match state for new round
function MatchRegistry.Reset()
	currentMatchStyle = "2v2"
	targetScore = 5
end

ServiceRegistry.Register("MatchRegistry", MatchRegistry)
return MatchRegistry