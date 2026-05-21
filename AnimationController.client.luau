local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local PlayDazedAnim = Remotes:WaitForChild("PlayDazedAnim")

local DAZED_ANIM_ID = "rbxassetid://0" -- Replace with real ID

PlayDazedAnim.OnClientEvent:Connect(function(duration)
	local char = player.Character
	if not char then return end
	local hum = char:FindFirstChildOfClass("Humanoid")
	if not hum then return end
	local animator = hum:FindFirstChildOfClass("Animator")
	if not animator or DAZED_ANIM_ID == "rbxassetid://0" then return end
	
	local anim = Instance.new("Animation")
	anim.AnimationId = DAZED_ANIM_ID
	local track = animator:LoadAnimation(anim)
	track.Priority = Enum.AnimationPriority.Action2
	track:Play()
	
	task.delay(duration, function()
		if track then track:Stop() end
	end)
end)
