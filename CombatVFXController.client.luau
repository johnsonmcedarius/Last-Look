-- ─────────────────────────────────────────────────────────────────────────────
-- CombatVFXController: Client-side VFX router for showstoppers and abilities
-- Refactored to use ModuleScript architecture for scalability
-- ─────────────────────────────────────────────────────────────────────────────

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local PlayVFX = Remotes:WaitForChild("PlayVFX")
local ShowstopperLocalTrigger = Remotes:WaitForChild("ShowstopperLocalTrigger")

-- ── Module Registry ─────────────────────────────────────────────────────────
-- Dynamically load VFX modules from ShowstopperVFX folder
local StarterPlayer = game:GetService("StarterPlayer")
local StarterPlayerScripts = StarterPlayer:WaitForChild("StarterPlayerScripts")
local ShowstopperVFXFolder = StarterPlayerScripts:WaitForChild("ShowstopperVFX")

local VFXModules = {}

-- Module name mapping (showstopper name -> module file name)
local MODULE_MAP = {
	["The Main Event"] = "MainEventVFX",
	["MainEvent"] = "MainEventVFX",
	["The Glitch Gala"] = "GlitchGalaVFX",
	["GlitchGala"] = "GlitchGalaVFX",
	["The Velvet Rope"] = "VelvetRopeVFX",
	["VelvetRope"] = "VelvetRopeVFX",
	["The Flash Mob"] = "FlashMobVFX",
	["FlashMob"] = "FlashMobVFX",
	["The Paparazzi Swarm"] = "PaparazziSwarmVFX",
	["PaparazziSwarm"] = "PaparazziSwarmVFX",
	["The Afterparty"] = "AfterpartyVFX",
	["Afterparty"] = "AfterpartyVFX",
	-- Add more mappings as new showstoppers are implemented
}

-- Cache for loaded modules
local loadedModules = {}

-- ── Module Loading ──────────────────────────────────────────────────────────

local function getVFXModule(showstopperName)
	-- Check cache first
	if loadedModules[showstopperName] then
		return loadedModules[showstopperName]
	end
	
	-- Map to module file name
	local moduleName = MODULE_MAP[showstopperName]
	if not moduleName then
		warn("[CombatVFXController] No module mapping for: " .. tostring(showstopperName))
		return nil
	end
	
	-- Find and require the module
	local moduleScript = ShowstopperVFXFolder:FindFirstChild(moduleName)
	if not moduleScript then
		warn("[CombatVFXController] Module not found: " .. moduleName)
		return nil
	end
	
	local success, module = pcall(require, moduleScript)
	if not success then
		warn("[CombatVFXController] Failed to load module: " .. moduleName .. " - " .. tostring(module))
		return nil
	end
	
	-- Cache it
	loadedModules[showstopperName] = module
	return module
end

-- ── Active Showstopper Tracking ─────────────────────────────────────────────
local activeShowstoppers = {} -- [showstopperName] = true

-- ── VFX Router Functions ─────────────────────────────────────────────────────

local function activateShowstopperVFX(showstopperName, data, targetPlayer)
	local module = getVFXModule(showstopperName)
	if not module then return end
	
	if module.Activate then
		-- Pass targetPlayer if provided, else default to local player
		module.Activate(targetPlayer or player, data)
		activeShowstoppers[showstopperName] = true
		print("[CombatVFXController] Activated VFX for: " .. showstopperName .. " (Target: " .. (targetPlayer and targetPlayer.Name or "Local") .. ")")
	else
		warn("[CombatVFXController] Module missing Activate function: " .. showstopperName)
	end
end

local function deactivateShowstopperVFX(showstopperName)
	local module = getVFXModule(showstopperName)
	if not module then return end
	
	if module.Deactivate then
		module.Deactivate()
		activeShowstoppers[showstopperName] = nil
		print("[CombatVFXController] Deactivated VFX for: " .. showstopperName)
	end
end

-- ── Standard VFX Listener (Legacy Support) ──────────────────────────────────
local VFXModule = nil
pcall(function()
	VFXModule = require(ReplicatedStorage:FindFirstChild("VFXModule") or ReplicatedStorage:WaitForChild("VFX", 1))
end)

local function getDistance(pos1, pos2)
	return (pos1 - pos2).Magnitude
end

PlayVFX.OnClientEvent:Connect(function(vfxName, targetCharacter)
	if not targetCharacter or not targetCharacter.PrimaryPart then return end
	
	-- Try to route to a complex Showstopper VFX module first
	local targetPlayer = Players:GetPlayerFromCharacter(targetCharacter)
	local showstopperNameFound = nil
	
	-- Reverse map from VFXAssetName to Showstopper Name
	for showName, moduleName in pairs(MODULE_MAP) do
		if vfxName == moduleName then
			showstopperNameFound = showName
			break
		end
	end
	
	if showstopperNameFound then
		activateShowstopperVFX(showstopperNameFound, {Character = targetCharacter}, targetPlayer)
		return
	end

	-- Fallback to simple standard VFX
	local targetPos = targetCharacter.PrimaryPart.Position
	local myPos = player.Character and player.Character.PrimaryPart and player.Character.PrimaryPart.Position or Vector3.new()
	
	if getDistance(targetPos, myPos) > 300 then return end
	
	if VFXModule and VFXModule.PlayAt then
		VFXModule.PlayAt(vfxName, targetCharacter.PrimaryPart)
	end
end)

-- ── Zero-Latency Showstopper Triggers ────────────────────────────────────────
ShowstopperLocalTrigger.OnClientEvent:Connect(function(data)
	local showstopperName = data.ShowstopperName or data.showstopperName
	if not showstopperName then return end
	
	activateShowstopperVFX(showstopperName, data, player)
end)

-- ── Status/Attribute Listeners ───────────────────────────────────────────────
local function watchCharacter(character)
	local targetPlayer = Players:GetPlayerFromCharacter(character)

	-- Smoke effect status
	character:GetAttributeChangedSignal("InSmoke"):Connect(function()
		if character:GetAttribute("InSmoke") then
			print("[STATUS] Player " .. character.Name .. " is in SMOKE")
		end
	end)

	-- Main Event status (attribute-based trigger)
	character:GetAttributeChangedSignal("MainEventActive"):Connect(function()
		local isActive = character:GetAttribute("MainEventActive")
		if isActive then
			activateShowstopperVFX("MainEvent", {}, targetPlayer)
		else
			deactivateShowstopperVFX("MainEvent")
		end
	end)
	
	-- Glitch Gala status (attribute-based trigger)
	character:GetAttributeChangedSignal("GlitchGalaActive"):Connect(function()
		local isActive = character:GetAttribute("GlitchGalaActive")
		if isActive then
			activateShowstopperVFX("GlitchGala", {}, targetPlayer)
		else
			deactivateShowstopperVFX("GlitchGala")
		end
	end)
end

player.CharacterAdded:Connect(watchCharacter)
if player.Character then watchCharacter(player.Character) end

-- ── The Single Master Render Loop ───────────────────────────────────────────
RunService.RenderStepped:Connect(function(deltaTime)
	-- Route per-frame updates to all active showstopper modules
	for showstopperName, _ in pairs(activeShowstoppers) do
		local module = getVFXModule(showstopperName)
		if module and module.OnRenderStepped then
			module.OnRenderStepped(deltaTime)
		end
	end
end)

print("[VFX] CombatVFXController initialized (Router Mode)")