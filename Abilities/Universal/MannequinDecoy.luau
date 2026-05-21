local Ability = {
	Config = {
		Name = "The Mannequin Decoy",
		Duration = 5,
		Radius = 0,
		EffectType = "Illusion",
	},
}

function Ability.Execute(player)
	local ServerScriptService = game:GetService("ServerScriptService")
	local IllusionHandler = require(ServerScriptService:WaitForChild("IllusionHandler"))
	local pos = player.Character and player.Character.PrimaryPart and player.Character.PrimaryPart.Position
	if pos then
		IllusionHandler.SpawnDecoy(player, Ability.Config.Duration, pos)
	end
end

return Ability
