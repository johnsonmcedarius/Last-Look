local Ability = {
	Config = {
		Name = "The Smoke Machine",
		Duration = 5,
		Radius = 20,
		EffectType = "Zone",
	},
}

function Ability.Execute(player)
	local ServerScriptService = game:GetService("ServerScriptService")
	local ZoneHandler = require(ServerScriptService:WaitForChild("ZoneHandler"))
	local pos = player.Character and player.Character.PrimaryPart and player.Character.PrimaryPart.Position
	if pos then
		ZoneHandler.CreateVisionDenialZone(player, Ability.Config.Duration, Ability.Config.Radius, pos)
	end
end

return Ability
