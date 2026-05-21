local Ability = {
	Config = {
		Name = "The Fabric Shield",
		Duration = 4,
		Radius = 10,
		EffectType = "Zone",
	},
}

function Ability.Execute(player)
	local ServerScriptService = game:GetService("ServerScriptService")
	local ZoneHandler = require(ServerScriptService:WaitForChild("ZoneHandler"))
	local pos = player.Character and player.Character.PrimaryPart and player.Character.PrimaryPart.Position
	if pos then
		ZoneHandler.CreateProjectileBarrier(player, Ability.Config.Duration, Ability.Config.Radius, pos)
	end
end

return Ability
