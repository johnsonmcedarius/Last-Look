local HUDModule_WeaponState = {}

local TweenService = game:GetService("TweenService")

function HUDModule_WeaponState.Init(screenGui, remotes)
	local WeaponBusyState = remotes:WaitForChild("WeaponBusyState")
	
	-- ── Reference Physical UI ──
	local function getWeaponSlot()
		return screenGui:FindFirstChild("InventoryFrame", true) and 
		       screenGui.InventoryFrame:FindFirstChild("Slot1_Weapon")
	end
	
	-- Track busy state for weapon slot
	local busyState = {
		active = false,
		endTime = 0
	}
	
	-- Desaturate effect for weapon icon (references physical UI)
	local function setWeaponBusyState(isBusy, duration)
		local weaponSlot = getWeaponSlot()
		if not weaponSlot then return end
		
		-- Reference existing physical UI elements
		local busyOverlay = weaponSlot:FindFirstChild("BusyOverlay")
		local busyLabel = weaponSlot:FindFirstChild("BusyLabel")
		
		if isBusy then
			-- Show existing busy overlay and label
			if busyOverlay then
				busyOverlay.Visible = true
				
				-- Pulse animation for "premium" feel
				local pulseInfo = TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
				local pulseTween = TweenService:Create(busyOverlay, pulseInfo, {BackgroundTransparency = 0.7})
				pulseTween:Play()
				
				busyState.pulseTween = pulseTween
			end
			
			if busyLabel then
				busyLabel.Visible = true
			end
			
			busyState.active = true
			busyState.endTime = os.clock() + duration
		else
			-- Restore normal state
			if busyOverlay then busyOverlay.Visible = false end
			if busyLabel then busyLabel.Visible = false end
			
			if busyState.pulseTween then
				busyState.pulseTween:Cancel()
				busyState.pulseTween = nil
			end
			
			busyState.active = false
		end
	end
	
	-- Listen for server broadcasts
	WeaponBusyState.OnClientEvent:Connect(function(playerName, isBusy, duration)
		local Players = game:GetService("Players")
		local player = Players.LocalPlayer
		if playerName == player.Name then
			setWeaponBusyState(isBusy, duration)
		end
	end)
	
	-- Public API for local calls
	HUDModule_WeaponState.SetBusy = function(duration)
		setWeaponBusyState(true, duration)
	end
	
	HUDModule_WeaponState.SetAvailable = function()
		setWeaponBusyState(false, 0)
	end
end

return HUDModule_WeaponState