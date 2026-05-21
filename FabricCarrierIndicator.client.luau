-- ─────────────────────────────────────────────────────────────────────────────
-- FabricCarrierIndicator: Client-side floating icon controller
-- Shows fabric roll icon above teammates who are carrying fabric
-- ─────────────────────────────────────────────────────────────────────────────

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local Assets = ReplicatedStorage:WaitForChild("Assets")
local FabricRollIconTemplate = Assets:WaitForChild("FabricRollIcon")
local UIConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("UIConfig"))

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local FabricCarrierUpdate = Remotes:WaitForChild("FabricCarrierUpdate")

-- Track active icons
local activeIcons = {}  -- [playerUserId] = BillboardGui

-- ── Helper: Get team color ──
local function getTeamColor(teamName)
	if teamName == "Designers" then
		return UIConfig.TEAM_COLORS.Designers
	elseif teamName == "Critics" then
		return UIConfig.TEAM_COLORS.Critics
	end
	return Color3.new(1, 1, 1)
end

-- ── Helper: Create floating icon for a carrier ──
local function createCarrierIcon(carrierPlayer, teamName)
	-- Remove existing icon if any
	if activeIcons[carrierPlayer.UserId] then
		activeIcons[carrierPlayer.UserId]:Destroy()
		activeIcons[carrierPlayer.UserId] = nil
	end
	
	-- Wait for character
	local character = carrierPlayer.Character
	if not character then return end
	
	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not hrp then return end
	
	-- Clone the template
	local icon = FabricRollIconTemplate:Clone()
	icon.Name = "FabricRollIcon_" .. carrierPlayer.UserId
	icon.Adornee = hrp
	
	-- Set team color
	local teamColor = getTeamColor(teamName)
	local teamIndicator = icon.IconFrame:FindFirstChild("TeamIndicator")
	if teamIndicator then
		teamIndicator.BackgroundColor3 = teamColor
	end
	
	-- Set carrier name
	local nameLabel = icon:FindFirstChild("CarrierName")
	if nameLabel then
		nameLabel.Text = carrierPlayer.Name
		nameLabel.TextColor3 = teamColor
	end
	
	-- Set glow color
	local glow = icon.IconFrame:FindFirstChild("Glow")
	if glow then
		glow.ImageColor3 = teamColor
	end
	
	icon.Parent = carrierPlayer.Character
	
	-- Animate in
	icon.IconFrame.Size = UDim2.new(0, 0, 0, 0)
	TweenService:Create(icon.IconFrame, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Size = UDim2.new(1, 0, 1, 0)
	}):Play()
	
	-- Floating animation
	local floatTween = TweenService:Create(icon, TweenInfo.new(2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
		StudsOffset = Vector3.new(0, 3.5, 0)
	})
	floatTween:Play()
	
	activeIcons[carrierPlayer.UserId] = icon
	
	print("[FABRIC_ICON] Created floating icon for " .. carrierPlayer.Name)
end

-- ── Helper: Remove floating icon ──
local function removeCarrierIcon(carrierUserId)
	if activeIcons[carrierUserId] then
		local icon = activeIcons[carrierUserId]
		
		-- Animate out
		TweenService:Create(icon.IconFrame, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.In), {
			Size = UDim2.new(0, 0, 0, 0)
		}):Play()
		
		task.delay(0.2, function()
			if icon and icon.Parent then
				icon:Destroy()
			end
		end)
		
		activeIcons[carrierUserId] = nil
		print("[FABRIC_ICON] Removed floating icon for user " .. carrierUserId)
	end
end

-- ── Listen for carrier updates from server ──
FabricCarrierUpdate.OnClientEvent:Connect(function(teamName, carrierUserId, carrierName)
	if carrierUserId then
		-- Someone is now carrying fabric
		local carrierPlayer = Players:GetPlayerByUserId(carrierUserId)
		if carrierPlayer and carrierPlayer ~= player then
			-- Don't show icon for local player (they see it in their inventory slot)
			createCarrierIcon(carrierPlayer, teamName)
		end
	else
		-- Fabric was deposited or carrier was frozen
		-- Remove icon for this team's carrier
		for userId, icon in pairs(activeIcons) do
			local iconPlayer = Players:GetPlayerByUserId(userId)
			if iconPlayer and iconPlayer.Team and iconPlayer.Team.Name == teamName then
				removeCarrierIcon(userId)
				break
			end
		end
	end
end)

-- ── Handle character respawns (reattach icon) ──
Players.PlayerAdded:Connect(function(newPlayer)
	newPlayer.CharacterAdded:Connect(function()
		-- Check if this player is a carrier
		task.wait(0.5)  -- Wait for character to fully load
		-- Server will broadcast carrier status on respawn
	end)
end)

-- ── Cleanup on player leaving ──
Players.PlayerRemoving:Connect(function(leavingPlayer)
	removeCarrierIcon(leavingPlayer.UserId)
end)

print("[FABRIC_ICON] FabricCarrierIndicator initialized")