local HUDModule_Cooldowns = {}

function HUDModule_Cooldowns.Init(screenGui, remotes)
	local HUDCooldownUpdate  = remotes:WaitForChild("HUDCooldownUpdate")
	local DashCooldownUpdate = remotes:WaitForChild("DashCooldownUpdate")
	local TweenService       = game:GetService("TweenService")

	local activeCooldowns = {}

	local function getFrame(name)
		return screenGui:FindFirstChild(name, true)
	end

	local function runCooldown(abilityName, duration)
		local slotName = abilityName .. "Slot"
		local slot     = getFrame(slotName)
		if not slot then return end

		local overlay = slot:FindFirstChild("CooldownOverlay")
		local label   = slot:FindFirstChild("CooldownLabel")

		if overlay then overlay.Visible = true end

		if activeCooldowns[abilityName] then
			task.cancel(activeCooldowns[abilityName])
		end

		local start = os.clock()
		activeCooldowns[abilityName] = task.spawn(function()
			while true do
				local rem = math.max(0, duration - (os.clock() - start))
				if label then
					label.Text    = string.format("%.1f", rem) .. "s"
					label.Visible = rem > 0
				end
				if overlay then
					local pct = rem / duration
					overlay.Size     = UDim2.new(1, 0, pct, 0)
					overlay.Position = UDim2.new(0, 0, 1 - pct, 0)
					overlay.Visible  = rem > 0
				end
				if rem <= 0 then
					activeCooldowns[abilityName] = nil
					break
				end
				task.wait(0.05)
			end
		end)
	end

	HUDCooldownUpdate.OnClientEvent:Connect(function(abilityName, duration)
		runCooldown(abilityName, duration)
	end)

	DashCooldownUpdate.OnClientEvent:Connect(function(duration)
		runCooldown("Dash", duration)
	end)
end

return HUDModule_Cooldowns