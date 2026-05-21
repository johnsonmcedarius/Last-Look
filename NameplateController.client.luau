local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer

-- ── Config ───────────────────────────────────────────────────────────────────
local BILLBOARD_OFFSET = Vector3.new(0, 3, 0)
local VIP_COLOR = Color3.fromRGB(255, 215, 0) -- Gold
local NORMAL_COLOR = Color3.fromRGB(255, 255, 255)
local MAX_STRIKES = 3

-- ── Glitch Gala Garble Config ───────────────────────────────────────────────
local GARBLE_CHARS = {"@", "#", "$", "%", "&", "*", "!", "?", "0", "1"}
local GARBLE_WORDS = {"ERR0R", "GLITCH", "NULL", "VOID", "CORRUPT", "@@@@@@"}
local GLITCH_COLOR = Color3.fromRGB(255, 0, 100) -- Glitch pink/red

-- ── Garble State ─────────────────────────────────────────────────────────────
local isGarbled = false
local garbleConnections = {}
local originalNames = {} -- [player.UserId] = originalName
local garbleTask = nil

-- ── UI Builder ────────────────────────────────────────────────────────────────
-- Clones the physical NameplateTemplate from ReplicatedStorage.Assets.
-- To change nameplate appearance: edit the template in Studio, no script changes needed.
local _nameplateTemplate = nil
local function getNameplateTemplate()
	if _nameplateTemplate then return _nameplateTemplate end
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	_nameplateTemplate = assets and assets:FindFirstChild("NameplateTemplate")
	if not _nameplateTemplate then
		warn("[NameplateController] NameplateTemplate missing from ReplicatedStorage.Assets!")
	end
	return _nameplateTemplate
end

local function buildNameplate(targetPlayer)
	local template = getNameplateTemplate()
	if not template then return nil end

	local billboard = template:Clone()
	billboard.Name = "CustomNameplate"

	-- Set player name
	local nameLabel = billboard:FindFirstChild("NameLabel")
	if nameLabel then
		nameLabel.Text = targetPlayer.DisplayName or targetPlayer.Name
	end

	-- TeamAccent defaults to transparent until updateTeamColor sets it
	local accent = billboard:FindFirstChild("TeamAccent")
	if accent then
		accent.BackgroundTransparency = 1
	end

	return billboard
end

-- ── Logic ────────────────────────────────────────────────────────────────────
local function updateStars(tag, strikes)
	local starsContainer = tag:FindFirstChild("Stars")
	if not starsContainer then return end

	for i = 1, MAX_STRIKES do
		local star = starsContainer:FindFirstChild("Star" .. i)
		if star then
			local isStrike = (i <= strikes)
			star.Text = isStrike and "✕" or "★"
			star.TextColor3 = isStrike and Color3.new(1, 0, 0) or Color3.fromRGB(255, 220, 0)
			star.TextTransparency = isStrike and 0.4 or 0
		end
	end
end

-- ── Glitch Gala Garble Functions ─────────────────────────────────────────────
local function getRandomGarble()
	-- 50% chance for word, 50% for random chars
	if math.random() < 0.5 then
		local word = GARBLE_WORDS[math.random(1, #GARBLE_WORDS)]
		return word
	else
		local length = math.random(4, 8)
		local result = ""
		for i = 1, length do
			result = result .. GARBLE_CHARS[math.random(1, #GARBLE_CHARS)]
		end
		return result
	end
end

local function garbleNameplate(targetPlayer)
	local char = targetPlayer.Character
	if not char then return end
	
	local head = char:FindFirstChild("Head")
	if not head then return end
	
	local nameplate = head:FindFirstChild("CustomNameplate")
	if not nameplate then return end
	
	local nameLabel = nameplate:FindFirstChild("NameLabel")
	if not nameLabel then return end
	
	-- Store original name if not already stored
	if not originalNames[targetPlayer.UserId] then
		originalNames[targetPlayer.UserId] = nameLabel.Text
	end
	
	-- Apply garble
	nameLabel.Text = getRandomGarble()
	nameLabel.TextColor3 = GLITCH_COLOR
end

local function restoreNameplate(targetPlayer)
	local char = targetPlayer.Character
	if not char then return end
	
	local head = char:FindFirstChild("Head")
	if not head then return end
	
	local nameplate = head:FindFirstChild("CustomNameplate")
	if not nameplate then return end
	
	local nameLabel = nameplate:FindFirstChild("NameLabel")
	if not nameLabel then return end
	
	-- Restore original name
	if originalNames[targetPlayer.UserId] then
		nameLabel.Text = originalNames[targetPlayer.UserId]
		-- Note: Team color will be restored by updateTeamColor
		originalNames[targetPlayer.UserId] = nil
	end
end

local function garbleAllNameplates()
	for _, p in ipairs(Players:GetPlayers()) do
		if p ~= player then -- Don't garble own nameplate
			garbleNameplate(p)
		end
	end
end

local function restoreAllNameplates()
	for _, p in ipairs(Players:GetPlayers()) do
		restoreNameplate(p)
	end
end

local function startGarbleLoop()
	-- Stop existing loop if any
	if garbleTask then
		task.cancel(garbleTask)
	end
	
	garbleTask = task.spawn(function()
		while isGarbled do
			garbleAllNameplates()
			task.wait(0.3 + math.random() * 0.4) -- Random interval for glitch effect
		end
	end)
end

local function stopGarbleLoop()
	if garbleTask then
		task.cancel(garbleTask)
		garbleTask = nil
	end
end

local function setupNameplate(player)
	player.CharacterAdded:Connect(function(character)
		local head = character:WaitForChild("Head", 10)
		local humanoid = character:WaitForChild("Humanoid", 10)
		if not head or not humanoid then return end

		-- Hide default name
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None

		-- Build and Attach
		local tag = buildNameplate(player)
		tag.Adornee = head
		tag.Parent = head

		-- ── Attribute Listeners (The "Live" Update Logic) ──

		-- Sync Strikes (Stars)
		player:GetAttributeChangedSignal("Strikes"):Connect(function()
			updateStars(tag, player:GetAttribute("Strikes") or 0)
		end)
		updateStars(tag, player:GetAttribute("Strikes") or 0)

		-- Sync VIP Status (Gold Name)
		player:GetAttributeChangedSignal("IsVIP"):Connect(function()
			local isVIP = player:GetAttribute("IsVIP")
			tag.NameLabel.TextColor3 = isVIP and VIP_COLOR or NORMAL_COLOR
		end)
		if player:GetAttribute("IsVIP") then tag.NameLabel.TextColor3 = VIP_COLOR end

		-- Sync Team Colors
		local function updateTeamColor()
			if not player.Team then return end
			local accent = tag:FindFirstChild("TeamAccent")
			if player.Team.Name == "Designers" then
				tag.Stars.Visible = true
				if not player:GetAttribute("IsVIP") then
					tag.NameLabel.TextColor3 = Color3.fromRGB(100, 200, 255)
				end
				if accent then
					accent.BackgroundColor3     = Color3.fromRGB(100, 200, 255)
					accent.BackgroundTransparency = 0.4
				end
			elseif player.Team.Name == "Critics" then
				tag.Stars.Visible = false
				if not player:GetAttribute("IsVIP") then
					tag.NameLabel.TextColor3 = Color3.fromRGB(255, 80, 80)
				end
				if accent then
					accent.BackgroundColor3     = Color3.fromRGB(255, 80, 80)
					accent.BackgroundTransparency = 0.4
				end
			else
				tag.Stars.Visible = false
				if not player:GetAttribute("IsVIP") then
					tag.NameLabel.TextColor3 = NORMAL_COLOR
				end
				if accent then
					accent.BackgroundTransparency = 1
				end
			end
		end

		player:GetPropertyChangedSignal("Team"):Connect(updateTeamColor)
		updateTeamColor()
	end)

	-- Force trigger for existing characters
	if player.Character then
		task.spawn(function()
			-- characterAdded logic is wrapped in the connection above, 
			-- so we just need to re-trigger it once manually if they already spawned
			-- (Wait for character to be fully in game)
		end)
	end
end

-- ── Initialization ───────────────────────────────────────────────────────────
for _, p in ipairs(Players:GetPlayers()) do
	setupNameplate(p)
end

Players.PlayerAdded:Connect(setupNameplate)

-- ── Glitch Gala: Watch for InGlitch attribute on local player ──────────────────
local function watchForGlitch(character)
	character:GetAttributeChangedSignal("InGlitch"):Connect(function()
		local inGlitch = character:GetAttribute("InGlitch")
		if inGlitch and not isGarbled then
			-- Entered glitch zone
			isGarbled = true
			startGarbleLoop()
			print("[NAMEPLATE] Glitch garble started")
		elseif not inGlitch and isGarbled then
			-- Left glitch zone
			isGarbled = false
			stopGarbleLoop()
			restoreAllNameplates()
			print("[NAMEPLATE] Glitch garble stopped")
		end
	end)
end

player.CharacterAdded:Connect(watchForGlitch)
if player.Character then watchForGlitch(player.Character) end