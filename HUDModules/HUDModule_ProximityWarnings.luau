-- ─────────────────────────────────────────────────────────────────────────────
-- HUDModule_ProximityWarnings: 15-stud enemy proximity detection warnings
-- Handles WarningOverlayCritic (blue) and WarningOverlayDesigner (purple)
-- ─────────────────────────────────────────────────────────────────────────────

local HUDModule_ProximityWarnings = {}

local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

function HUDModule_ProximityWarnings.Init(screenGui, remotes)
	local player = Players.LocalPlayer
	
	-- ── Configuration ──
	local PROXIMITY_THRESHOLD = 15 -- studs
	local UPDATE_INTERVAL = 0.3 -- seconds
	local FLASH_SPEED = 0.5 -- seconds per flash cycle
	
	-- ── Reference Physical UI ──
	local function getWarningOverlays()
		local statusTracker = screenGui:FindFirstChild("StatusTracker")
		if not statusTracker then return nil, nil end
		
		local inventoryFrame = statusTracker:FindFirstChild("InventoryFrame")
		if not inventoryFrame then return nil, nil end
		
		local fabricIcon = inventoryFrame:FindFirstChild("FabricRollIcon")
		if not fabricIcon then return nil, nil end
		
		return fabricIcon:FindFirstChild("WarningOverlayCritic"), fabricIcon:FindFirstChild("WarningOverlayDesigner")
	end
	
	-- ── State ──
	local isFlashingCritic = false
	local isFlashingDesigner = false
	local flashConnCritic = nil
	local flashConnDesigner = nil
	
	-- ── Flash Animation ──
	local function startFlashing(overlay, warningType)
		if not overlay then return end
		
		local flashConn = warningType == "Critic" and flashConnCritic or flashConnDesigner
		local isFlashing = warningType == "Critic" and isFlashingCritic or isFlashingDesigner
		
		if isFlashing then return end
		
		if warningType == "Critic" then
			isFlashingCritic = true
		else
			isFlashingDesigner = true
		end
		
		overlay.Visible = true
		
		-- Start flash loop
		flashConn = task.spawn(function()
			while (warningType == "Critic" and isFlashingCritic) or (warningType == "Designer" and isFlashingDesigner) do
				TweenService:Create(overlay, TweenInfo.new(FLASH_SPEED), {ImageTransparency = 0.3}):Play()
				task.wait(FLASH_SPEED)
				TweenService:Create(overlay, TweenInfo.new(FLASH_SPEED), {ImageTransparency = 0.8}):Play()
				task.wait(FLASH_SPEED)
			end
			overlay.Visible = false
		end)
		
		if warningType == "Critic" then
			flashConnCritic = flashConn
		else
			flashConnDesigner = flashConn
		end
	end
	
	local function stopFlashing(overlay, warningType)
		if not overlay then return end
		
		if warningType == "Critic" then
			isFlashingCritic = false
		else
			isFlashingDesigner = false
		end
		
		overlay.Visible = false
	end
	
	-- ── Proximity Check Loop ──
	local function checkProximity()
		local character = player.Character
		if not character then return end
		
		local hrp = character:FindFirstChild("HumanoidRootPart")
		if not hrp then return end
		
		local myTeam = player.Team and player.Team.Name
		local myPosition = hrp.Position
		
		local criticNearby = false
		local designerNearby = false
		
		-- Check all other players
		for _, otherPlayer in Players:GetPlayers() do
			if otherPlayer == player then continue end
			
			local otherChar = otherPlayer.Character
			if not otherChar then continue end
			
			local otherHrp = otherChar:FindFirstChild("HumanoidRootPart")
			if not otherHrp then continue end
			
			local distance = (otherHrp.Position - myPosition).Magnitude
			if distance > PROXIMITY_THRESHOLD then continue end
			
			local otherTeam = otherPlayer.Team and otherPlayer.Team.Name
			
			-- Only warn about enemy team members
			if myTeam == "Designers" and otherTeam == "Critics" then
				criticNearby = true
			elseif myTeam == "Critics" and otherTeam == "Designers" then
				designerNearby = true
			end
		end
		
		-- Update warning overlays
		local warningCritic, warningDesigner = getWarningOverlays()
		
		if criticNearby then
			startFlashing(warningCritic, "Critic")
		else
			stopFlashing(warningCritic, "Critic")
		end
		
		if designerNearby then
			startFlashing(warningDesigner, "Designer")
		else
			stopFlashing(warningDesigner, "Designer")
		end
	end
	
	-- ── Start Proximity Loop ──
	task.spawn(function()
		while true do
			checkProximity()
			task.wait(UPDATE_INTERVAL)
		end
	end)
	
	-- ── Public API ──
	HUDModule_ProximityWarnings.SetThreshold = function(studs)
		PROXIMITY_THRESHOLD = studs
	end
	
	HUDModule_ProximityWarnings.ForceCheck = checkProximity
end

return HUDModule_ProximityWarnings