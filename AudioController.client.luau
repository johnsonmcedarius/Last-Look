local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")

local SoundService = require(ReplicatedStorage:WaitForChild("SoundService"))
local PartCache = require(ReplicatedStorage:WaitForChild("ReplicatedStorage"):WaitForChild("PartCache"))
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local PlaySoundRemote = Remotes:WaitForChild("PlaySound")

-- Setup audio part pool
local audioPartTemplate = Instance.new("Part")
audioPartTemplate.Size = Vector3.new(0.1, 0.1, 0.1)
audioPartTemplate.Anchored = true
audioPartTemplate.Transparency = 1
audioPartTemplate.CanCollide = false
audioPartTemplate.Name = "AudioEmitter"

local pool = PartCache.new(audioPartTemplate, 20, workspace)

PlaySoundRemote.OnClientEvent:Connect(function(soundName, position)
	if not position then
		SoundService.PlayLocal(soundName)
	else
		local part = pool:Get()
		part.Position = position
		SoundService.PlayAt(soundName, part)
		
		-- Return to pool after sound duration (approx)
		task.delay(5, function()
			pool:Return(part)
		end)
	end
end)
