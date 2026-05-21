local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService      = game:GetService("TweenService")

local Assets            = ReplicatedStorage:WaitForChild("Assets")
local Templates         = Assets:WaitForChild("SkinEffectTemplates")

local TEXTURE_SCROLL_SPEED = 50

local function clearSkinEffects(char)
	for _, part in ipairs(char:GetDescendants()) do
		if part:IsA("BasePart") then
			for _, child in ipairs(part:GetChildren()) do
				if child:GetAttribute("IsSkinEffect") then
					child:Destroy()
				end
			end
		end
	end
end

local function applySkinEffect(player, char, effectName)
	clearSkinEffects(char)
	if not effectName or effectName == "None" then return end

	local template = Templates:FindFirstChild(effectName)
	if not template then return end

	local scrollSpeed = template:GetAttribute("ScrollSpeed") or TEXTURE_SCROLL_SPEED

	for _, part in ipairs(char:GetChildren()) do
		-- ONLY target body parts, ignore Accessories (3D clothes)
		if part:IsA("BasePart") and not part:FindFirstAncestorOfClass("Accessory") then
			for _, item in ipairs(template:GetChildren()) do
				if item:IsA("Texture") or item:IsA("Decal") then
					local clone = item:Clone()
					clone:SetAttribute("IsSkinEffect", true)
					clone.Parent = part

					if clone:IsA("Texture") then
						local tileSize  = clone.StudsPerTileU > 0 and clone.StudsPerTileU or 4
						local cycleSecs = tileSize / scrollSpeed

						TweenService:Create(
							clone,
							TweenInfo.new(cycleSecs, Enum.EasingStyle.Linear, Enum.EasingDirection.Out, -1, false),
							{OffsetStudsU = clone.StudsPerTileU, OffsetStudsV = clone.StudsPerTileV}
						):Play()
					end
				elseif item:IsA("ParticleEmitter") then
					local clone = item:Clone()
					clone:SetAttribute("IsSkinEffect", true)
					clone.Parent = part
				end
			end
		end
	end
end

local function onPlayerAdded(player)
	player:GetAttributeChangedSignal("EquippedSkinEffect"):Connect(function()
		if player.Character then
			applySkinEffect(player, player.Character, player:GetAttribute("EquippedSkinEffect"))
		end
	end)

	player.CharacterAdded:Connect(function(char)
		task.wait(0.1) -- Ensure attributes are replicated
		applySkinEffect(player, char, player:GetAttribute("EquippedSkinEffect"))
	end)
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, p in ipairs(Players:GetPlayers()) do onPlayerAdded(p) end

return { ApplyManual = applySkinEffect, ClearManual = clearSkinEffects }