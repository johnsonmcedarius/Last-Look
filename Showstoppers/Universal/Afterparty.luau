local Players             = game:GetService("Players")
local ReplicatedStorage   = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local CollectionService   = game:GetService("CollectionService")
local Teams               = game:GetService("Teams")

local Showstopper = {
	Config = {
		Name                   = "The Afterparty",
		Duration               = 5,
		Radius                 = 0,
		EffectType             = "Resurrection",
		ObjectiveInvulnSeconds = 3,  -- Sabotage immunity on rebooted objective
		SabotageSearchRadius   = 20, -- Distance to auto-cleanse nearby objectives
	},
}

-- ─────────────────────────────────────────────────────────────────────────────
-- THE AFTERPARTY
-- • Guest List Revive: all eliminated teammates (on Lobby team) respawn at
--   the caster's position, re-assigned to the correct team.
-- • Strike Reset: every living teammate has their strikes zeroed.
-- • Sabotage Cleanse: if caster is within SabotageSearchRadius of their team's
--   bin/shredder and it's sabotaged, it's instantly rebooted + given
--   ObjectiveInvulnSeconds of immunity against the next sabotage.
-- • VFX: neon-pink pulse wave + confetti burst across map.
-- ─────────────────────────────────────────────────────────────────────────────

function Showstopper.Execute(player)
	local ServiceRegistry = require(ServerScriptService:WaitForChild("ServiceRegistry"))
	local RelevanceSystem = ServiceRegistry.Await("RelevanceSystem")
	local SoundService    = require(ReplicatedStorage:WaitForChild("SoundService"))
	local VFX             = require(ReplicatedStorage:WaitForChild("VFXModule"))

	local char = player.Character
	if not char then return end
	local root = char:FindFirstChild("HumanoidRootPart")
	if not root then return end

	local pos        = root.Position
	local playerTeam = player.Team
	if not playerTeam then return end

	local Remotes                 = ReplicatedStorage:WaitForChild("Remotes")
	local ShowstopperAnnounce     = Remotes:FindFirstChild("ShowstopperAnnounce")
	local ShowstopperLocalTrigger = Remotes:FindFirstChild("ShowstopperLocalTrigger")
	local ObjectiveWarning        = Remotes:FindFirstChild("ObjectiveWarning")

	-- ── 1. GUEST LIST REVIVE ──
	-- Any player currently on the "Lobby" team was eliminated this round.
	-- We restore them to the caster's team and LoadCharacter at caster position.
	local revived = {}
	for _, p in ipairs(Players:GetPlayers()) do
		if p ~= player and p.Team and p.Team.Name == "Lobby" then
			p.Team = playerTeam
			revived[p] = true
		end
	end

	-- LoadCharacter outside the loop to avoid race on Team assignment.
	-- After loading, teleport to caster. CharacterAdded fires async so we wait.
	for p, _ in pairs(revived) do
		task.spawn(function()
			p:LoadCharacter()
			-- Wait up to 5 seconds for character to appear
			local newChar
			local waited = 0
			while waited < 5 do
				newChar = p.Character
				if newChar and newChar:FindFirstChild("HumanoidRootPart") then break end
				task.wait(0.1)
				waited += 0.1
			end
			if newChar and newChar:FindFirstChild("HumanoidRootPart") then
				newChar.HumanoidRootPart.CFrame = CFrame.new(pos + Vector3.new(
					math.random(-4, 4), 3, math.random(-4, 4)
				))
				print("[AFTERPARTY] " .. p.Name .. " respawned at " .. player.Name .. "'s position")
			end
		end)
	end

	-- ── 2. STRIKE RESET ON ALL LIVING TEAMMATES ──
	for _, p in ipairs(playerTeam:GetPlayers()) do
		if RelevanceSystem then
			RelevanceSystem.ResetStrikes(p)
		end
	end
	print("[AFTERPARTY] Strikes reset for all " .. playerTeam.Name)

	-- ── 3. SABOTAGE CLEANSE + OBJECTIVE INVULNERABILITY ──
	-- Designers protect their bins; Critics protect their shredders.
	local ownedTags = playerTeam.Name == "Designers" and {"FabricBins"} or {"FabricShredders"}
	local opposingTeamName = playerTeam.Name == "Designers" and "Critics" or "Designers"

	for _, tag in ipairs(ownedTags) do
		for _, obj in ipairs(CollectionService:GetTagged(tag)) do
			local objPos = obj:GetPivot().Position
			if (objPos - pos).Magnitude <= Showstopper.Config.SabotageSearchRadius then
				if obj:GetAttribute("IsSabotaged") then
					-- Cleanse
					obj:SetAttribute("IsSabotaged", false)
					local rebootName = tag == "FabricBins" and "BinReboot" or "ShredderReboot"
					local rebootPrompt = obj:FindFirstChild(rebootName)
					if rebootPrompt then rebootPrompt:Destroy() end
					-- PLACEHOLDER: "AfterpartyCleanse" = pink pulse burst on objective.
					VFX.Play("AfterpartyCleanse", objPos)
					SoundService.FireToAll("AfterpartyCleanse", objPos)
					if ObjectiveWarning then
						ObjectiveWarning:FireAllClients(playerTeam.Name, false)
					end
					print("[AFTERPARTY] Cleansed sabotage on " .. obj.Name)
				end
				-- Apply temporary invulnerability: sabotage prompts are disabled
				obj:SetAttribute("SabotageImmune", true)
				task.delay(Showstopper.Config.ObjectiveInvulnSeconds, function()
					if obj and obj.Parent then
						obj:SetAttribute("SabotageImmune", nil)
						print("[AFTERPARTY] Objective invulnerability expired on " .. obj.Name)
					end
				end)
			end
		end
	end

	-- ── 4. VFX: pink pulse + confetti across map ──
	-- PLACEHOLDER: "AfterpartyPulse"    = neon-pink expanding sphere wave.
	-- PLACEHOLDER: "AfterpartyConfetti" = confetti burst particles map-wide.
	VFX.Play("AfterpartyPulse",    pos)
	VFX.Play("AfterpartyConfetti", Vector3.new(0, 10, 0))
	SoundService.FireToAll("AfterpartyActivate") -- PLACEHOLDER — replace with afterparty bass drop

	-- ── 5. ANNOUNCEMENT ──
	if ShowstopperAnnounce then
		ShowstopperAnnounce:FireAllClients(
			player.Name,
			"The Afterparty",
			"THE SHOW ISN'T OVER! WELCOME TO THE AFTERPARTY!"
		)
	end

	-- ── 6. LOCAL TRIGGER (camera flash on caster) ──
	if ShowstopperLocalTrigger then
		ShowstopperLocalTrigger:FireClient(player, {
			ShowstopperName = "The Afterparty",
			Position        = pos,
			Duration        = Showstopper.Config.Duration,
		})
	end

	print("[AFTERPARTY] " .. player.Name .. " triggered — " .. #revived .. " teammate(s) revived")
end

return Showstopper
