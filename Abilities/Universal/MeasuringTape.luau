local Ability = {
	Config = {
		Name = "The Measuring Tape",
		Duration = 0,
		Radius = 50,
		EffectType = "Physics",
	},
}

function Ability.Execute(player)
	local ServerScriptService = game:GetService("ServerScriptService")
	local PhysicsHandler = require(ServerScriptService:WaitForChild("PhysicsHandler"))
	local char = player.Character
	if char and char.PrimaryPart then
		local targetPos = char.PrimaryPart.Position + char.PrimaryPart.CFrame.LookVector * Ability.Config.Radius
		PhysicsHandler.ApplyGrapple(player, targetPos)
	end
end

return Ability
