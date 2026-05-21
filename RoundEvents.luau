local RoundEvents = {}

-- BindableEvents — server-to-server only
local function makeEvent(name)
	local e = Instance.new("BindableEvent")
	e.Name = name
	return e
end

-- Fired when a round transitions to active (teams assigned, spawns done)
-- Payload: none
RoundEvents.RoundStarted = makeEvent("RoundStarted")

-- Fired when a round ends with a clear winner
-- Payload: winningTeamName (string)  e.g. "Designers" or "Critics"
RoundEvents.RoundEnded = makeEvent("RoundEnded")

-- Fired during intermission / map cleanup phase
-- Payload: none
RoundEvents.Intermission = makeEvent("Intermission")

-- Convenience wrappers used by RoundSystem only
function RoundEvents.FireRoundStarted()
	RoundEvents.RoundStarted:Fire()
end

function RoundEvents.FireRoundEnded(winningTeamName)
	assert(type(winningTeamName) == "string", "[RoundEvents] winningTeamName must be a string")
	RoundEvents.RoundEnded:Fire(winningTeamName)
end

function RoundEvents.FireIntermission()
	RoundEvents.Intermission:Fire()
end

return RoundEvents
