local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local camera = workspace.CurrentCamera
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local CameraShake = Remotes:WaitForChild("CameraShake")

CameraShake.OnClientEvent:Connect(function()
	local started = os.clock()
	local duration = 0.5
	local intensity = 0.4
	
	local conn
	conn = RunService.RenderStepped:Connect(function()
		local elapsed = os.clock() - started
		if elapsed >= duration then 
			conn:Disconnect() 
			return 
		end
		
		local decay = 1 - (elapsed / duration)
		camera.CFrame = camera.CFrame * CFrame.new(
			(math.random() - 0.5) * intensity * decay,
			(math.random() - 0.5) * intensity * decay * 0.5,
			0
		)
	end)
end)
