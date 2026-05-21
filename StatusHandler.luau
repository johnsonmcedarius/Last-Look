-- ─────────────────────────────────────────────────────────────────────────────
-- StatusHandler: Handles buffs, debuffs, and stuns
-- ─────────────────────────────────────────────────────────────────────────────
local StatusHandler = {}

local CollectionService = game:GetService("CollectionService")

-- ── Core Logic ──

local function updateFinalSpeed(target)
	local humanoid = target:FindFirstChild("Humanoid")
	if not humanoid then return end
	
	local baseSpeed = 16 -- Default
	local buff = target:GetAttribute("SpeedBuff") or 0
	local debuff = target:GetAttribute("SpeedDebuff") or 0
	
	-- Special Case: Stun
	if target:GetAttribute("Stunned") then
		humanoid.WalkSpeed = 0
		return
	end
	
	-- Special Case: The Main Event
	if target:GetAttribute("MainEventActive") then
		humanoid.WalkSpeed = 45
		return
	end
	
	-- Calculate final speed
	local finalSpeed = baseSpeed + buff - debuff
	
	-- Special Case: Speed Cap (System Shock from Glitch Gala)
	-- Check player for SpeedCap attribute
	local player = game.Players:GetPlayerFromCharacter(target)
	local speedCap = player and player:GetAttribute("SpeedCap")
	if speedCap then
		finalSpeed = math.min(finalSpeed, speedCap)
	end
	
	humanoid.WalkSpeed = math.max(0, finalSpeed)
end

function StatusHandler.ApplySpeedDebuff(player, target, amount, duration)
	local current = target:GetAttribute("SpeedDebuff") or 0
	target:SetAttribute("SpeedDebuff", current + amount)
	
	updateFinalSpeed(target)
	
	task.delay(duration, function()
		if target and target.Parent then
			local now = target:GetAttribute("SpeedDebuff") or 0
			target:SetAttribute("SpeedDebuff", math.max(0, now - amount))
			updateFinalSpeed(target)
		end
	end)
end

function StatusHandler.ApplyStun(player, target, duration)
	-- Freeze Immunity Check: Main Event grants immunity to all freeze attempts
	if target:GetAttribute("FreezeImmune") or target:GetAttribute("MainEventActive") then
		print("[STATUS] " .. (target.Name or "Target") .. " is immune to freeze (FreezeImmune/MainEventActive)")
		return false
	end

	target:SetAttribute("Stunned", true)
	updateFinalSpeed(target)

	task.delay(duration, function()
		if target and target.Parent then
			target:SetAttribute("Stunned", nil)
			updateFinalSpeed(target)
		end
	end)

	return true
end

function StatusHandler.ApplyInputInversion(player, duration)
	-- Target character or player? Design says Editorial Mirror affects user (No U) 
	-- but also kaleidoscope for enemies. Let's apply to player.
	player:SetAttribute("ControlsInverted", true)
	
	task.delay(duration, function()
		if player then
			player:SetAttribute("ControlsInverted", nil)
		end
	end)
end

function StatusHandler.ApplyGlobalBuff(team, buffType, duration)
	local teamPlayers = {}
	if typeof(team) == "Instance" and team:IsA("Team") then
		teamPlayers = team:GetPlayers()
	else
		-- Universal?
		teamPlayers = game.Players:GetPlayers()
	end
	
	for _, p in ipairs(teamPlayers) do
		local char = p.Character
		if char then
			if buffType == "MainEvent" then
				char:SetAttribute("MainEventActive", true)
				updateFinalSpeed(char)
				task.delay(duration, function()
					if char and char.Parent then
						char:SetAttribute("MainEventActive", nil)
						updateFinalSpeed(char)
					end
				end)
			elseif buffType == "FlashMob" then
				char:SetAttribute("SpeedBuff", (char:GetAttribute("SpeedBuff") or 0) + 15)
				updateFinalSpeed(char)
				task.delay(duration, function()
					if char and char.Parent then
						local now = char:GetAttribute("SpeedBuff") or 0
						char:SetAttribute("SpeedBuff", math.max(0, now - 15))
						updateFinalSpeed(char)
					end
				end)
			end
		end
	end
end

function StatusHandler.Cleanup(player)
	-- Cleanup logic
end

function StatusHandler.CleanupAll()
	-- Cleanup logic
end

return StatusHandler
