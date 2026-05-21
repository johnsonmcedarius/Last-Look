-- ─────────────────────────────────────────────────────────────────────────────
-- HUDModule_FabricSlot: Premium fabric roll inventory slot
-- ZIndex 100 - Highest priority UI element (bottom-left corner)
-- REFACTORED: References physical UI in StarterGui.GameHUD
-- ─────────────────────────────────────────────────────────────────────────────

local HUDModule_FabricSlot = {}

local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

function HUDModule_FabricSlot.Init(screenGui, remotes)
	local player = Players.LocalPlayer
	local UIConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("UIConfig"))
	local SoundService = require(ReplicatedStorage:WaitForChild("SoundService"))
	
	local FabricCarrierUpdate = remotes:WaitForChild("FabricCarrierUpdate")
	
	-- ── Reference Physical UI from StarterGui ──
	local fabricSlot = screenGui:FindFirstChild("FabricSlot")
	if not fabricSlot then
		warn("[FABRIC_SLOT] FabricSlot not found in GameHUD!")
		return
	end
	
	-- Get existing child elements
	local glow = fabricSlot:FindFirstChild("Glow")
	local teamIndicator = fabricSlot:FindFirstChild("TeamIndicator")
	local border = fabricSlot:FindFirstChild("GoldBorder")
	local icon = fabricSlot:FindFirstChild("FabricIcon")
	local label = fabricSlot:FindFirstChild("SlotLabel")
	
	-- Pulse animation for glow (only if glow exists)
	local pulseTween = nil
	if glow then
		local pulseInfo = TweenInfo.new(1.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
		pulseTween = TweenService:Create(glow, pulseInfo, {ImageTransparency = 0.95})
		pulseTween:Play()
	end
	
	-- ── State Management ──
	local isShowing = false

	-- ── Helper: Check if player has fabric roll ──
	local function playerHasFabric()
		local char = player.Character
		if not char then return false end
		
		local inHand = char:FindFirstChild("FBRoll")
		local inBackpack = player.Backpack:FindFirstChild("FBRoll")
		
		return inHand ~= nil or inBackpack ~= nil
	end

	-- ── Helper: Update team color ──
	local function updateTeamColor()
		local teamName = player.Team and player.Team.Name
		local teamColor = Color3.fromRGB(255, 255, 255)
		
		if teamName == "Designers" then
			teamColor = UIConfig.TEAM_COLORS.Designers
		elseif teamName == "Critics" then
			teamColor = UIConfig.TEAM_COLORS.Critics
		end
		
		if teamIndicator then
			teamIndicator.BackgroundColor3 = teamColor
		end
		if glow then
			glow.ImageColor3 = teamColor
		end
	end

	-- ── Show fabric slot ──
	local function showFabricSlot()
		if isShowing then return end
		isShowing = true

		updateTeamColor()

		fabricSlot.Visible = true
		fabricSlot.Size = UDim2.new(0, 0, 0, 0)

		TweenService:Create(fabricSlot, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Size = UDim2.new(0, 80, 0, 80)
		}):Play()

		SoundService.PlayLocal("FabricPickup")
		print("[FABRIC_SLOT] Showing fabric slot")
	end

	-- ── Hide fabric slot ──
	local function hideFabricSlot()
		if not isShowing then return end
		isShowing = false

		TweenService:Create(fabricSlot, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.In), {
			Size = UDim2.new(0, 0, 0, 0)
		}):Play()

		task.delay(0.2, function()
			fabricSlot.Visible = false
		end)

		print("[FABRIC_SLOT] Hiding fabric slot")
	end
	
	-- ── Watch for fabric roll equipment ──
	local function checkFabricStatus()
		if playerHasFabric() then
			showFabricSlot()
		else
			hideFabricSlot()
		end
	end
	
	-- Character added/removed handling
	player.CharacterAdded:Connect(function()
		task.wait(0.5)  -- Wait for character to load
		checkFabricStatus()
		
		-- Watch for tool changes
		local char = player.Character
		if char then
			char.ChildAdded:Connect(function(child)
				if child.Name == "FBRoll" then
					task.wait(0.1)
					checkFabricStatus()
				end
			end)
			
			char.ChildRemoved:Connect(function(child)
				if child.Name == "FBRoll" then
					task.wait(0.1)
					checkFabricStatus()
				end
			end)
		end
		
		-- Watch backpack changes
		player.Backpack.ChildAdded:Connect(function(child)
			if child.Name == "FBRoll" then
				task.wait(0.1)
				checkFabricStatus()
			end
		end)
		
		player.Backpack.ChildRemoved:Connect(function(child)
			if child.Name == "FBRoll" then
				task.wait(0.1)
				checkFabricStatus()
			end
		end)
	end)
	
	-- Team change handling
	player:GetPropertyChangedSignal("Team"):Connect(function()
		updateTeamColor()
	end)
	
	-- Initial check
	if player.Character then
		checkFabricStatus()
	end
	
	-- ── Listen for carrier updates (when frozen/deposited) ──
	FabricCarrierUpdate.OnClientEvent:Connect(function(teamName, carrierUserId, carrierName)
		-- If this player is no longer the carrier, hide slot
		if carrierUserId == nil then
			-- Check if this was our team
			local myTeam = player.Team and player.Team.Name
			if teamName == myTeam then
				-- Someone on our team lost fabric (frozen or deposited)
				-- Check if it was us
				task.wait(0.2)
				checkFabricStatus()
			end
		end
	end)
	
	-- Public API
	HUDModule_FabricSlot.Show = showFabricSlot
	HUDModule_FabricSlot.Hide = hideFabricSlot
	HUDModule_FabricSlot.Refresh = checkFabricStatus
end

return HUDModule_FabricSlot