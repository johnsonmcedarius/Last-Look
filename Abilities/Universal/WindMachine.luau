local Ability = {
	Config = {
		Name = "The Wind Machine",
		Duration = 3,
		Radius = 30,
		EffectType = "Physics",
	},
}

function Ability.Execute(player)
	local ServerScriptService = game:GetService("ServerScriptService")
	local PhysicsHandler = require(ServerScriptService:WaitForChild("PhysicsHandler"))
	local char = player.Character
	if char and char.PrimaryPart then
		local pos = char.PrimaryPart.Position
		local direction = char.PrimaryPart.CFrame.LookVector
		PhysicsHandler.ApplyDirectionalPushback(player, direction, Ability.Config.Duration, Ability.Config.Radius, pos)
	end
end

return Ability
