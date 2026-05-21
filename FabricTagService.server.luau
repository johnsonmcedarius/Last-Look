local Players           = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")

local DESIGNER_TEAM = "Designers"

local function isDesigner(player)
	return player.Team and player.Team.Name == DESIGNER_TEAM
end

local function tagCharacter(player)
	local char = player.Character
	if not char then return end
	if isDesigner(player) then
		CollectionService:AddTag(char, "HoldingFabric")
	end
end

local function untagCharacter(player)
	local char = player.Character
	if char then
		CollectionService:RemoveTag(char, "HoldingFabric")
	end
end

local function watchPlayer(player)
	local function onChildAdded(child)
		if child.Name == "FBRoll" then
			tagCharacter(player)
		end
	end

	local function onChildRemoved(child)
		if child.Name == "FBRoll" then
			-- Check if they still have one (edge case: two copies)
			local hasAnother = (player.Character and player.Character:FindFirstChild("FBRoll"))
				or player.Backpack:FindFirstChild("FBRoll")
			if not hasAnother then
				untagCharacter(player)
			end
		end
	end

	player.Backpack.ChildAdded:Connect(onChildAdded)
	player.Backpack.ChildRemoved:Connect(onChildRemoved)

	local function watchCharacter(char)
		char.ChildAdded:Connect(onChildAdded)
		char.ChildRemoved:Connect(onChildRemoved)

		-- Untag old character on respawn
		CollectionService:RemoveTag(char, "HoldingFabric")
	end

	player.CharacterAdded:Connect(function(char)
		untagCharacter(player)  -- old char is gone, clean up just in case
		watchCharacter(char)
	end)

	if player.Character then
		watchCharacter(player.Character)
	end
end

Players.PlayerAdded:Connect(watchPlayer)
for _, p in ipairs(Players:GetPlayers()) do
	watchPlayer(p)
end

Players.PlayerRemoving:Connect(function(p)
	untagCharacter(p)
end)
