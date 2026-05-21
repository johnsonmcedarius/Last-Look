local bulbsModel = script.Parent
local TweenService = game:GetService("TweenService")

-- Our signature Cedaire aesthetic
local colorStart = Color3.fromRGB(0, 170, 255)  -- Signature Blue
local colorEnd = Color3.fromRGB(170, 0, 255)    -- Electric Purple

local tweenInfo = TweenInfo.new(
	2.5, -- How many seconds to fade. (Make it 0.2 for a scary horror pulse!)
	Enum.EasingStyle.Sine,
	Enum.EasingDirection.InOut,
	-1,   -- Repeat forever
	true  -- Reverse back to blue
)

-- Loop through the group
for _, bulb in ipairs(bulbsModel:GetChildren()) do
	if bulb:IsA("BasePart") then
		-- Force the luxury glow
		bulb.Material = Enum.Material.Neon
		bulb.Color = colorStart

		-- Create and play the fade
		local tween = TweenService:Create(bulb, tweenInfo, {Color = colorEnd})
		tween:Play()
	end
end

print("Last Look stage lights are officially live.")