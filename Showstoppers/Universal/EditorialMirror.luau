local Players             = game:GetService("Players")
local ReplicatedStorage   = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Showstopper = {
	Config = {
		Name               = "The Editorial Mirror",
		Duration           = 6,
		Radius             = 0,
		EffectType         = "Status",
		ReflectMultiplier  = 1.5,  -- reflected freeze = base * 1.5
		BaseFreezeDuration = 2,    -- base seconds a freeze normally lasts
	},
}

-- ─────────────────────────────────────────────────────────────────────────────
-- THE EDITORIAL MIRROR
-- • Reflection Shield: while MirrorActive=true, any incoming freeze/ability is
--   reflected back at the attacker at 150% power instead.
--   TagManager / AbilityService must call Showstopper.TryReflect(attacker, victim)
--   before applying effects. Returns true = absorbed; skip applying to victim.
-- • Strike Reverse: attacker earns a Strike from RelevanceSystem.
-- • VFX: crystal texture swap on self + Kaleidoscope filter on enemy screens.
-- ─────────────────────────────────────────────────────────────────────────────

function Showstopper.Execute(player)
	local ServiceRegistry = require(ServerScriptService:WaitForChild("ServiceRegistry"))
	local SoundService    = require(ReplicatedStorage:WaitForChild("SoundService"))
	local VFX             = require(ReplicatedStorage:WaitForChild("VFXModule"))

	local char = player.Character
	if not char then return end
	local root = char:FindFirstChild("HumanoidRootPart")
	if not root then return end

	local pos        = root.Position
	local playerTeam = player.Team

	local Remotes                 = ReplicatedStorage:WaitForChild("Remotes")
	local ShowstopperAnnounce     = Remotes:FindFirstChild("ShowstopperAnnounce")
	local ShowstopperLocalTrigger = Remotes:FindFirstChild("ShowstopperLocalTrigger")
	local MovementEffect          = Remotes:FindFirstChild("MovementEffect")

	-- ── 1. MARK PLAYER AS REFLECTING ──
	char:SetAttribute("MirrorActive", true)
	char:SetAttribute("FreezeImmune", true)
	char:SetAttribute("MirrorReflectMultiplier", Showstopper.Config.ReflectMultiplier)

	-- ── 2. VFX ON SELF ──
	-- PLACEHOLDER: "EditorialMirrorCrystal" = crystal texture burst on caster.
	-- PLACEHOLDER: "EditorialMirrorChime"   = crystalline chime soundscape.
	VFX.Play("EditorialMirrorCrystal", pos)
	SoundService.FireToAll("EditorialMirrorChime", pos)

	-- ── 3. KALEIDOSCOPE POST-PROCESS FILTER ON ALL ENEMIES ──
	-- MovementEffect(enemy, "Kaleidoscope", {Duration}) tells the client to apply
	-- its Kaleidoscope ColorCorrectionEffect for the given duration.
	if playerTeam and MovementEffect then
		local opposingName = playerTeam.Name == "Designers" and "Critics" or "Designers"
		local opposingTeam = game.Teams:FindFirstChild(opposingName)
		if opposingTeam then
			for _, enemy in ipairs(opposingTeam:GetPlayers()) do
				MovementEffect:FireClient(enemy, "Kaleidoscope", {
					Duration = Showstopper.Config.Duration,
				})
			end
		end
	end

	-- ── 4. ANNOUNCEMENT ──
	if ShowstopperAnnounce then
		ShowstopperAnnounce:FireAllClients(
			player.Name,
			"The Editorial Mirror",
			"EYES ON THE MIRROR: " .. player.Name .. " IS REFLECTING THE VIBE!"
		)
	end

	-- ── 5. LOCAL TRIGGER (client camera shake / local flash) ──
	if ShowstopperLocalTrigger then
		ShowstopperLocalTrigger:FireClient(player, {
			ShowstopperName = "The Editorial Mirror",
			Position        = pos,
			Duration        = Showstopper.Config.Duration,
		})
	end

	-- ── 6. CLEANUP AFTER DURATION ──
	task.delay(Showstopper.Config.Duration, function()
		if char and char.Parent then
			char:SetAttribute("MirrorActive", nil)
			char:SetAttribute("FreezeImmune", nil)
			char:SetAttribute("MirrorReflectMultiplier", nil)
		end
		-- Remove Kaleidoscope filter from enemy screens
		if playerTeam and MovementEffect then
			local opposingName = playerTeam.Name == "Designers" and "Critics" or "Designers"
			local opposingTeam = game.Teams:FindFirstChild(opposingName)
			if opposingTeam then
				for _, enemy in ipairs(opposingTeam:GetPlayers()) do
					MovementEffect:FireClient(enemy, "KaleidoscopeEnd", {})
				end
			end
		end
		print("[EDITORIAL MIRROR] Mirror expired for " .. player.Name)
	end)

	print("[EDITORIAL MIRROR] " .. player.Name .. " activated — reflecting all attacks for " .. Showstopper.Config.Duration .. "s")
end

-- ─────────────────────────────────────────────────────────────────────────────
-- TryReflect(attacker, victim)
-- Call this from TagManager/AbilityService BEFORE applying any freeze to victim.
-- Returns true  → hit absorbed + reflected; do NOT apply effect to victim.
-- Returns false → victim has no mirror; apply normally.
-- ─────────────────────────────────────────────────────────────────────────────
function Showstopper.TryReflect(attacker, victim)
	local SSS             = game:GetService("ServerScriptService")
	local RS              = game:GetService("ReplicatedStorage")
	local ServiceRegistry = require(SSS:WaitForChild("ServiceRegistry"))
	local StatusHandler   = require(SSS:WaitForChild("StatusHandler"))
	local VFX             = require(RS:WaitForChild("VFXModule"))

	local victimChar = victim.Character
	if not victimChar or not victimChar:GetAttribute("MirrorActive") then
		return false
	end

	local attackerChar = attacker.Character
	if not attackerChar then return true end -- absorbed but nothing to reflect to

	-- Reflect: base freeze 2s * 1.5 = 3s on attacker
	local reflectDuration = Showstopper.Config.BaseFreezeDuration * Showstopper.Config.ReflectMultiplier
	StatusHandler.ApplyFreeze(victim, attackerChar, reflectDuration)

	-- Attacker earns a Strike
	local RelevanceSystem = ServiceRegistry.Get("RelevanceSystem")
	if RelevanceSystem then
		RelevanceSystem.AddStrike(attacker)
		print("[EDITORIAL MIRROR] Strike reflected onto " .. attacker.Name)
	end

	-- PLACEHOLDER: "MirrorReflectHit" = sparkle/shatter burst at attacker.
	local attackerRoot = attackerChar:FindFirstChild("HumanoidRootPart")
	if attackerRoot then
		VFX.Play("MirrorReflectHit", attackerRoot.Position)
	end

	return true
end

return Showstopper

local Showstopper = {
	Config = {
		Name              = "The Editorial Mirror",
		Duration          = 6,
		Radius            = 0,
		EffectType        = "Status",
		ReflectMultiplier = 1.5,   -- reflected freeze = base * 1.5
		BaseFreezeDuration = 2,    -- base seconds a freeze normally lasts
	},
}

-- ─────────────────────────────────────────────────────────────────────────────
-- THE EDITORIAL MIRROR
-- • Reflection Shield: any freeze or damaging ability aimed at the user while
--   MirrorActive=true is reflected back at the attacker at 150% power.
--   TagManager / AbilityService must call Showstopper.TryReflect(attacker, victim)
--   before applying effects; it returns true if the hit was absorbed.
-- • Strike Reverse: attacker gains a Strike via RelevanceSystem.
-- • Client VFX: crystal texture on self + Kaleidoscope screen-filter on enemies.
-- ─────────────────────────────────────────────────────────────────────────────

function Showstopper.Execute(player)
	local ServiceRegistry = require(ServerScriptService:WaitForChild("ServiceRegistry"))
	local StatusHandler   = require(ServerScriptService:WaitForChild("StatusHandler"))
	local SoundService    = require(ReplicatedStorage:WaitForChild("SoundService"))
	local VFX             = require(ReplicatedStorage:WaitForChild("VFXModule"))

	local char = player.Character
	if not char then return end
	local root = char:FindFirstChild("HumanoidRootPart")
	if not root then return end

	local pos        = root.Position
	local playerTeam = player.Team

	local Remotes                 = ReplicatedStorage:WaitForChild("Remotes")
	local ShowstopperAnnounce     = Remotes:FindFirstChild("ShowstopperAnnounce")
	local ShowstopperLocalTrigger = Remotes:FindFirstChild("ShowstopperLocalTrigger")
	local MovementEffect          = Remotes:FindFirstChild("MovementEffect")

	-- ── 1. MARK PLAYER AS REFLECTING ──
	char:SetAttribute("MirrorActive", true)
	char:SetAttribute("FreezeImmune", true)
	char:SetAttribute("MirrorReflectMultiplier", Showstopper.Config.ReflectMultiplier)

	-- ── 2. CLIENT VFX ON SELF ──
	-- Crystal/diamond texture swap + chime footstep audio handled client-side.
	-- PLACEHOLDER: replace "EditorialMirrorCrystal" with your real VFX asset name.
	VFX.Play("EditorialMirrorCrystal", pos)
	SoundService.FireToAll("EditorialMirrorChime", pos)

	-- ── 3. KALEIDOSCOPE FILTER ON ENEMY SCREENS ──
	-- MovementEffect remote with type "Kaleidoscope" fires a post-process filter
	-- on the receiving client's screen for the showstopper duration.
	if playerTeam and MovementEffect then
		local opposingName = playerTeam.Name == "Designers" and "Critics" or "Designers"
		local opposingTeam = game.Teams:FindFirstChild(opposingName)
		if opposingTeam then
			for _, enemy in ipairs(opposingTeam:GetPlayers()) do
				MovementEffect:FireClient(enemy, "Kaleidoscope", {
					Duration = Showstopper.Config.Duration,
				})
			end
		end
	end

	-- ── 4. ANNOUNCEMENT ──
	if ShowstopperAnnounce then
		ShowstopperAnnounce:FireAllClients(
			player.Name,
			"The Editorial Mirror",
			"EYES ON THE MIRROR: " .. player.Name .. " IS REFLECTING THE VIBE!"
		)
	end

	-- ── 5. LOCAL TRIGGER (camera shake / local flash on self) ──
	if ShowstopperLocalTrigger then
		ShowstopperLocalTrigger:FireClient(player, {
			ShowstopperName = "The Editorial Mirror",
			Position = pos,
			Duration = Showstopper.Config.Duration,
		})
	end

	-- ── 6. CLEANUP AFTER DURATION ──
	task.delay(Showstopper.Config.Duration, function()
		if char and char.Parent then
			char:SetAttribute("MirrorActive", nil)
			char:SetAttribute("FreezeImmune", nil)
			char:SetAttribute("MirrorReflectMultiplier", nil)
		end
		-- Tell enemy screens to remove the Kaleidoscope filter
		if playerTeam and MovementEffect then
			local opposingName = playerTeam.Name == "Designers" and "Critics" or "Designers"
			local opposingTeam = game.Teams:FindFirstChild(opposingName)
			if opposingTeam then
				for _, enemy in ipairs(opposingTeam:GetPlayers()) do
					MovementEffect:FireClient(enemy, "KaleidoscopeEnd", {})
				end
			end
		end
		print("[EDITORIAL MIRROR] Mirror expired for " .. player.Name)
	end)

	print("[EDITORIAL MIRROR] " .. player.Name .. " activated — reflecting all attacks for " .. Showstopper.Config.Duration .. "s")
end

-- ─────────────────────────────────────────────────────────────────────────────
-- TryReflect: called by TagManager / AbilityService BEFORE applying a freeze.
-- Pass (attacker, victim). Returns true if the hit was absorbed + reflected.
-- If returns true, the caller must NOT apply the freeze to the victim.
-- ─────────────────────────────────────────────────────────────────────────────
function Showstopper.TryReflect(attacker, victim)
	local SSS             = game:GetService("ServerScriptService")
	local RS              = game:GetService("ReplicatedStorage")
	local ServiceRegistry = require(SSS:WaitForChild("ServiceRegistry"))
	local StatusHandler   = require(SSS:WaitForChild("StatusHandler"))
	local VFX             = require(RS:WaitForChild("VFXModule"))

	local victimChar = victim.Character
	if not victimChar or not victimChar:GetAttribute("MirrorActive") then
		return false
	end

	local attackerChar = attacker.Character
	if not attackerChar then return true end -- absorbed but nothing to reflect to

	-- Reflect freeze back: base 2s * 1.5 = 3s
	local reflectDuration = Showstopper.Config.BaseFreezeDuration * Showstopper.Config.ReflectMultiplier
	StatusHandler.ApplyFreeze(victim, attackerChar, reflectDuration)

	-- Attacker earns a Strike for the attempted hit
	local RelevanceSystem = ServiceRegistry.Get("RelevanceSystem")
	if RelevanceSystem then
		RelevanceSystem.AddStrike(attacker)
		print("[EDITORIAL MIRROR] Strike reflected onto " .. attacker.Name)
	end

	-- VFX at attacker position
	-- PLACEHOLDER: replace "MirrorReflectHit" with your real VFX asset name.
	local attackerRoot = attackerChar:FindFirstChild("HumanoidRootPart")
	if attackerRoot then
		VFX.Play("MirrorReflectHit", attackerRoot.Position)
	end

	return true -- hit was absorbed; caller must skip applying effect to victim
end

-- ─────────────────────────────────────────────────────────────────────────────
-- THE EDITORIAL MIRROR: Full Implementation
-- Reflection Shield: Any freeze or damaging ability aimed at the user is
--   reflected back at the attacker with 150% speed and power.
-- Strike Reverse: If an enemy tries to freeze the user, ATTACKER gains a Strike.
-- VFX: Crystal/diamond texture on user + Kaleidoscope filter on enemy screens.
-- ─────────────────────────────────────────────────────────────────────────────

function Showstopper.Execute(player)
	local ServiceRegistry = require(ServerScriptService:WaitForChild("ServiceRegistry"))
	local StatusHandler   = require(ServerScriptService:WaitForChild("StatusHandler"))
	local SoundService    = require(ReplicatedStorage:WaitForChild("SoundService"))
	local VFX             = require(ReplicatedStorage:WaitForChild("VFXModule"))

	local char = player.Character
	if not char then return end
	local root = char:FindFirstChild("HumanoidRootPart")
	if not root then return end

	local pos = root.Position
	local playerTeam = player.Team

	-- ── 1. MARK PLAYER AS REFLECTING ──
	-- TagManager / freeze code checks "MirrorActive" before applying freeze.
	char:SetAttribute("MirrorActive", true)
	char:SetAttribute("FreezeImmune", true)

	-- ── 2. FIRE CLIENT VFX: Crystal texture + sound on self ──
	local Remotes = ReplicatedStorage:FindFirstChild("Remotes")
	local ShowstopperLocalTrigger = Remotes and Remotes:FindFirstChild("ShowstopperLocalTrigger")
	if ShowstopperLocalTrigger then
		ShowstopperLocalTrigger:FireClient(player, {
			ShowstopperName = "The Editorial Mirror",
			Position = pos,
			Duration = Showstopper.Config.Duration,
		})
	end

	-- ── 3. FIRE KALEIDOSCOPE FILTER TO ENEMY TEAM SCREENS ──
	local BlindClient = Remotes and Remotes:FindFirstChild("BlindClient")
	local MovementEffect = Remotes and Remotes:FindFirstChild("MovementEffect")
	if playerTeam then
		local opposingTeamName = playerTeam.Name == "Designers" and "Critics" or "Designers"
		local opposingTeam = game.Teams:FindFirstChild(opposingTeamName)
		if opposingTeam then
			for _, enemy in ipairs(opposingTeam:GetPlayers()) do
				-- Kaleidoscope = MovementEffect with type "Kaleidoscope" (client renders filter)
				if MovementEffect then
					MovementEffect:FireClient(enemy, "Kaleidoscope", {
						Duration = Showstopper.Config.Duration,
					})
				end
			end
		end
	end

	-- ── 4. ABILITY REFLECTION LOOP ──
	-- Every 0.1s while active: check if any enemy ability hit the player.
	-- The TagManager/AbilityService should check char:GetAttribute("MirrorActive")
	-- before applying effects. This loop handles the REFLECT-BACK on freeze attempts.
	-- AbilityService is expected to call ShowstopperService.ReflectAbility(attacker, victim)
	-- when it detects MirrorActive. We set up the table here so it's ready.
	char:SetAttribute("MirrorReflectMultiplier", Showstopper.Config.ReflectMultiplier)

	-- ── 5. PLAY ACTIVATION SOUND + VFX ──
	-- Placeholder: "EditorialMirrorActivate" SFX and "EditorialMirrorVFX" asset.
	VFX.Play("EditorialMirrorActivate", pos)   -- PLACEHOLDER — replace with crystal burst
	SoundService.FireToAll("EditorialMirrorActivate", pos) -- PLACEHOLDER — replace with chime

	-- ── 6. ANNOUNCEMENT ──
	local ShowstopperAnnounce = Remotes and Remotes:FindFirstChild("ShowstopperAnnounce")
	if ShowstopperAnnounce then
		ShowstopperAnnounce:FireAllClients(
			player.Name,
			"The Editorial Mirror",
			"EYES ON THE MIRROR: " .. player.Name .. " IS REFLECTING THE VIBE!"
		)
	end

	-- ── 7. CLEANUP AFTER DURATION ──
	task.delay(Showstopper.Config.Duration, function()
		if char and char.Parent then
			char:SetAttribute("MirrorActive", nil)
			char:SetAttribute("FreezeImmune", nil)
			char:SetAttribute("MirrorReflectMultiplier", nil)
			print("[EDITORIAL MIRROR] Mirror effect ended for " .. player.Name)
		end
		-- Remove kaleidoscope filter from enemy screens
		if playerTeam then
			local opposingTeamName = playerTeam.Name == "Designers" and "Critics" or "Designers"
			local opposingTeam = game.Teams:FindFirstChild(opposingTeamName)
			if opposingTeam then
				local MovementEffectRemote = ReplicatedStorage:FindFirstChild("Remotes")
					and ReplicatedStorage.Remotes:FindFirstChild("MovementEffect")
				for _, enemy in ipairs(opposingTeam:GetPlayers()) do
					if MovementEffectRemote then
						MovementEffectRemote:FireClient(enemy, "KaleidoscopeEnd", {})
					end
				end
			end
		end
	end)

	print("[EDITORIAL MIRROR] " .. player.Name .. " is now reflecting all attacks for " .. Showstopper.Config.Duration .. "s")
end

-- ── HOOK: Called by TagManager/AbilityService when a freeze is attempted ──
-- If the target has MirrorActive, call this instead of applying the freeze.
function Showstopper.OnFreezeAttempted(attacker, victim)
	local ServerScriptServiceLocal = game:GetService("ServerScriptService")
	local ServiceRegistry = require(ServerScriptServiceLocal:WaitForChild("ServiceRegistry"))
	local RelevanceSystem = ServiceRegistry.Get("RelevanceSystem")
	local StatusHandler   = require(ServerScriptServiceLocal:WaitForChild("StatusHandler"))
	local VFXLocal        = require(game:GetService("ReplicatedStorage"):WaitForChild("VFXModule"))

	local victimChar = victim.Character
	if not victimChar or not victimChar:GetAttribute("MirrorActive") then return false end

	local attackerChar = attacker.Character
	if not attackerChar then return true end

	-- Reflect the freeze back at the attacker with 150% power (longer duration)
	local reflectDuration = 2 * Showstopper.Config.ReflectMultiplier -- base 2s freeze * 1.5 = 3s
	StatusHandler.ApplyFreeze(victim, attackerChar, reflectDuration)

	-- Attacker gains a Strike from the RelevanceSystem
	if RelevanceSystem then
		RelevanceSystem.AddStrike(attacker)
		print("[EDITORIAL MIRROR] Strike reflected onto " .. attacker.Name)
	end

	-- VFX on attacker position
	local attackerRoot = attackerChar:FindFirstChild("HumanoidRootPart")
	if attackerRoot then
		VFXLocal.Play("MirrorReflectHit", attackerRoot.Position) -- PLACEHOLDER
	end

	return true -- signals: freeze was absorbed + reflected, do NOT apply to victim
end

return Showstopper
local Showstopper = {
	Config = {
		Name = "The Editorial Mirror",
		Duration = 6,
		Radius = 0,
		EffectType = "Status",
	},
}

function Showstopper.Execute(player)
	local ServerScriptService = game:GetService("ServerScriptService")
	local StatusHandler = require(ServerScriptService:WaitForChild("StatusHandler"))
	StatusHandler.ApplyInputInversion(player, Showstopper.Config.Duration)
end

return Showstopper
