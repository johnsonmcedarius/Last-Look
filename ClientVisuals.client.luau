local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local DEGREES_PER_SECOND = 90 

local function startSpinning(model)
	if not model:IsA("Model") then return end

	local connection
	connection = RunService.RenderStepped:Connect(function(dt)
		if model and model.Parent then
			local rotationAngle = math.rad(DEGREES_PER_SECOND * dt)
			model:PivotTo(model:GetPivot() * CFrame.Angles(0, rotationAngle, 0))
		else
			if connection then connection:Disconnect() end
		end
	end)
end

for _, model in pairs(CollectionService:GetTagged("SpinnyCrate")) do
	task.spawn(startSpinning, model)
end

CollectionService:GetInstanceAddedSignal("SpinnyCrate"):Connect(startSpinning)
