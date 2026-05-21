local Ability = {
	Config = {
		Name = "Glitter Perfume Bomb",
		Duration = 2,
		Radius = 15,
		EffectType = "Projectile",
	},
}

function Ability.Execute(player)
	local ServerScriptService = game:GetService("ServerScriptService")
	local StatusHandler = require(ServerScriptService:WaitForChild("StatusHandler"))
	local Players = game:GetService("Players")
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local Debris = game:GetService("Debris")
	local Remotes = ReplicatedStorage:WaitForChild("Remotes")
	local PlayVFX = Remotes:WaitForChild("PlayVFX")

	print("[ABILITY] " .. player.Name .. " threw Perfume Bomb")
	local char = player.Character
	if char and char:FindFirstChild("HumanoidRootPart") then
		local root = char.HumanoidRootPart
		local spawnPos = root.Position + root.CFrame.LookVector * 2
		
		local bomb = Instance.new("Part")
		bomb.Name = "PerfumeBomb"
		bomb.Size = Vector3.new(1, 1, 1)
		bomb.Shape = Enum.PartType.Ball
		bomb.Position = spawnPos
		bomb.Color = Color3.fromRGB(255, 150, 255)
		bomb.Material = Enum.Material.Glass
		bomb.CanCollide = false
		bomb.Parent = workspace
		
		local bv = Instance.new("BodyVelocity")
		bv.MaxForce = Vector3.new(1, 1, 1) * 1000000
		bv.Velocity = (root.CFrame.LookVector * 60) + Vector3.new(0, 15, 0)
		bv.Parent = bomb
		Debris:AddItem(bv, 0.2)
		
		bomb.Touched:Connect(function(hit)
			if hit:IsDescendantOf(char) then return end
			local impactPos = bomb.Position
			bomb:Destroy()
			
			-- Explosion Logic
			local radius = 15
			local parts = workspace:GetPartBoundsInRadius(impactPos, radius)
			local affected = {}
			
			for _, p in ipairs(parts) do
				local targetChar = p.Parent
				local targetPlayer = Players:GetPlayerFromCharacter(targetChar)
				if targetPlayer and targetPlayer.Team ~= player.Team and not affected[targetPlayer] then
					affected[targetPlayer] = true
					StatusHandler.ApplyStun(player, targetChar, 2)
					targetChar:SetAttribute("Revealed", true)
					task.delay(5, function()
						if targetChar then targetChar:SetAttribute("Revealed", nil) end
					end)
				end
			end
			
			-- Fire VFX
			PlayVFX:FireAllClients("PerfumeExplosion", impactPos)
		end)
		
		Debris:AddItem(bomb, 5)
	end
end

return Ability
