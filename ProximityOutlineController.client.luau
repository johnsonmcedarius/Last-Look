-- ─────────────────────────────────────────────────────────────────────────────
-- ProximityOutlineController: Screen border glow when enemies are near
-- REFACTORED: References physical UI in StarterGui.ProximityOutlineGui
-- ─────────────────────────────────────────────────────────────────────────────

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local Config = require(ReplicatedStorage:WaitForChild("SharedConfig"))

-- ── Screen Outline Configuration ─────────────────────────────────────────────
local PROXIMITY_RANGE = 15 -- Studs
local DESIGNER_COLOR = Color3.fromRGB(100, 150, 255) -- Blue outline for Designers
local CRITIC_COLOR = Color3.fromRGB(150, 50, 200) -- Purple outline for Critics
local OUTLINE_TRANSPARENCY = 0.85

-- ── Reference Physical UI from StarterGui ───────────────────────────────────────
local PlayerGui = player:WaitForChild("PlayerGui")
local outlineGui = PlayerGui:WaitForChild("ProximityOutlineGui", 5)

if not outlineGui then
    warn("[PROXIMITY] ProximityOutlineGui not found in PlayerGui!")
    return
end

local outline = outlineGui:FindFirstChild("OutlineFrame")
local uiStroke = outline and outline:FindFirstChild("OutlineStroke")

if not outline or not uiStroke then
    warn("[PROXIMITY] Required UI elements not found in ProximityOutlineGui!")
    return
end

-- ── Proximity Detection Loop ────────────────────────────────────────────────
local function updateOutline()
	local char = player.Character
	if not char then 
		outline.Visible = false
		return 
	end
	
	local root = char:FindFirstChild("HumanoidRootPart")
	if not root then 
		outline.Visible = false
		return 
	end
	
	local myTeam = player.Team and player.Team.Name
	if not myTeam or (myTeam ~= "Designers" and myTeam ~= "Critics") then
		outline.Visible = false
		return
	end
	
	local enemyTeam = myTeam == "Designers" and "Critics" or "Designers"
	local nearestDist = math.huge
	
	-- Find nearest enemy player
	for _, p in ipairs(Players:GetPlayers()) do
		if p == player then continue end
		if not p.Team or p.Team.Name ~= enemyTeam then continue end
		
		local pChar = p.Character
		if not pChar then continue end
		
		local pRoot = pChar:FindFirstChild("HumanoidRootPart")
		if not pRoot then continue end
		
		local dist = (root.Position - pRoot.Position).Magnitude
		nearestDist = math.min(nearestDist, dist)
	end
	
	-- Show outline if enemy is within proximity range
	if nearestDist < PROXIMITY_RANGE then
		outline.Visible = true
		uiStroke.Color = myTeam == "Designers" and DESIGNER_COLOR or CRITIC_COLOR
		
		-- Intensity based on distance (closer = more visible)
		local intensity = 1 - (nearestDist / PROXIMITY_RANGE)
		uiStroke.Transparency = OUTLINE_TRANSPARENCY + (intensity * 0.1)
	else
		outline.Visible = false
	end
end

-- ── Run Loop ─────────────────────────────────────────────────────────────────
RunService.RenderStepped:Connect(updateOutline)

print("[PROXIMITY] Outline controller initialized.")