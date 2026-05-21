local Ability = {
	Config = {
		Name = "Slippery Gloss",
		Duration = 2,
		Radius = 15,
		EffectType = "Physics",
	},
}

function Ability.Execute(player)
	local ServerScriptService = game:GetService("ServerScriptService")
	local PhysicsHandler = require(ServerScriptService:WaitForChild("PhysicsHandler"))
	local pos = player.Character and player.Character.PrimaryPart and player.Character.PrimaryPart.Position
	if pos then
		PhysicsHandler.ApplyFrictionRemoval(player, Ability.Config.Duration, Ability.Config.Radius, pos)
	end
end

return Ability
