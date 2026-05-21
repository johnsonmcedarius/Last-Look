local Players             = game:GetService("Players")
local ReplicatedStorage   = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local ServiceRegistry = require(ServerScriptService:WaitForChild("ServiceRegistry"))
local RoundEvents     = require(ServerScriptService:WaitForChild("RoundEvents"))

local IMMUNITY_WINDOW           = 15
local DIMINISHING_RETURN_FACTOR = 0.75
local MIN_EFFECT_MULTIPLIER     = 0.25

local criticState = {}

local function getState(critic)
	if not criticState[critic.UserId] then
		criticState[critic.UserId] = {immuneUntil = 0, hitCount = 0}
	end
	return criticState[critic.UserId]
end

local function canHit(critic)
	if not critic or not critic.Parent then return false end
	return os.clock() >= getState(critic).immuneUntil
end

local function registerHit(critic)
	if not critic or not critic.Parent then return 1 end
	local state = getState(critic)

	local multiplier = math.max(
		MIN_EFFECT_MULTIPLIER,
		DIMINISHING_RETURN_FACTOR ^ state.hitCount
	)

	state.hitCount   += 1
	state.immuneUntil = os.clock() + IMMUNITY_WINDOW

	print("[IMMUNITY] " .. critic.Name
		.. " hit #" .. state.hitCount
		.. " | immunity for " .. IMMUNITY_WINDOW .. "s"
		.. " | effect multiplier: " .. string.format("%.2f", multiplier))

	return multiplier
end

local function resetCritic(critic)
	criticState[critic.UserId] = {immuneUntil = 0, hitCount = 0}
end

local AbilityImmunity = {
	CanHit      = canHit,
	RegisterHit = registerHit,
	ResetCritic = resetCritic,
	TryHit      = function(critic)
		if not canHit(critic) then
			print("[IMMUNITY] " .. (critic and critic.Name or "?") .. " is immune. Hit blocked.")
			return nil
		end
		return registerHit(critic)
	end,
}

RoundEvents.Intermission.Event:Connect(function()
	criticState = {}
	print("[IMMUNITY] All critic immunity states reset.")
end)

Players.PlayerRemoving:Connect(function(p)
	criticState[p.UserId] = nil
end)

ServiceRegistry.Register("AbilityImmunity", AbilityImmunity)
print("[IMMUNITY] AbilityImmunityService ready. Window=" .. IMMUNITY_WINDOW .. "s")
return AbilityImmunity
