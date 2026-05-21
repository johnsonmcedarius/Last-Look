-- ─────────────────────────────────────────────────────────────────────────────
-- PaparazziSwarmVFX: Client-side visual effects for 'The Paparazzi Swarm'
-- ─────────────────────────────────────────────────────────────────────────────

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local player = Players.LocalPlayer

local PaparazziSwarmVFX = {}

local activeHighlights = {} -- [player] = Highlight
local scriptConnections = {} -- List of connections to disconnect on Deactivate

-- ── Helper: Apply Outline to Enemy ──
local function applyHighlight(otherPlayer)
	if not otherPlayer or otherPlayer == player then return end
	
	local function doHighlight()
		-- Only highlight if they are an enemy
		if otherPlayer.Team == player.Team then return end
		
		local char = otherPlayer.Character
		if char then
			local highlight = char:FindFirstChild("PaparazziTrackingHighlight")
			if not highlight then
				highlight = Instance.new("Highlight")
				highlight.Name = "PaparazziTrackingHighlight"
				highlight.FillColor = Color3.fromRGB(255, 255, 255)
				highlight.FillTransparency = 0.8
				highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
				highlight.OutlineTransparency = 0
				highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
				highlight.Parent = char
			end
			activeHighlights[otherPlayer] = highlight
		end
	end
	
	-- Only highlight if they have the "Revealed" attribute (set by server)
	-- The server sets Revealed = true for the duration.
	local char = otherPlayer.Character
	if char and char:GetAttribute("Revealed") then
		doHighlight()
	end
	
	-- Watch for attribute changes
	local function watchAttribute(c)
		local conn = c:GetAttributeChangedSignal("Revealed"):Connect(function()
			if c:GetAttribute("Revealed") then
				doHighlight()
			elseif activeHighlights[otherPlayer] then
				activeHighlights[otherPlayer]:Destroy()
				activeHighlights[otherPlayer] = nil
			end
		end)
		table.insert(scriptConnections, conn)
	end
	
	if char then watchAttribute(char) end
	local charConn = otherPlayer.CharacterAdded:Connect(watchAttribute)
	table.insert(scriptConnections, charConn)
end

function PaparazziSwarmVFX.Activate(playerArg, data)
	local targetPlayer = playerArg or player
	
	-- If we are on the caster's team, we see the highlights
	if player.Team ~= targetPlayer.Team then return end

	print("[PaparazziSwarmVFX] Activating tracking for team " .. tostring(player.Team))

	-- ── 1. SOUNDS ──
	local success, SoundService = pcall(function()
		return require(ReplicatedStorage:WaitForChild("SoundService"))
	end)
	if success and SoundService then
		SoundService.PlayLocal("PaparazziStorm")
	end
	
	-- ── 2. TRACKING LEAK (Highlights) ──
	for _, p in ipairs(Players:GetPlayers()) do
		applyHighlight(p)
	end
	
	-- Watch for new players joining
	local joinConn = Players.PlayerAdded:Connect(applyHighlight)
	table.insert(scriptConnections, joinConn)
end

function PaparazziSwarmVFX.Deactivate()
	print("[PaparazziSwarmVFX] Deactivating highlights")
	
	for _, conn in ipairs(scriptConnections) do
		conn:Disconnect()
	end
	scriptConnections = {}
	
	for p, highlight in pairs(activeHighlights) do
		if highlight and highlight.Parent then 
			highlight:Destroy() 
		end
	end
	activeHighlights = {}
end

return PaparazziSwarmVFX
