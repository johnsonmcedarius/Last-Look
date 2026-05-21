local Players             = game:GetService("Players")
local ReplicatedStorage   = game:GetService("ReplicatedStorage")
local Teams               = game:GetService("Teams")
local ServerScriptService = game:GetService("ServerScriptService")
local MarketplaceService  = game:GetService("MarketplaceService")

local ServiceRegistry = require(ServerScriptService:WaitForChild("ServiceRegistry"))
local RoundEvents     = require(ServerScriptService:WaitForChild("RoundEvents"))
local SoundService    = require(ReplicatedStorage:WaitForChild("SoundService"))

local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local function getRemote(name)
	local r = Remotes:FindFirstChild(name)
	if not r then r = Instance.new("RemoteEvent") r.Name = name r.Parent = Remotes end
	return r
end

local UpdateStrikes    = getRemote("UpdateStrikes")
local PlayerEliminated = getRemote("PlayerEliminated")
local PlayPoofVFX      = getRemote("PlayPoofVFX")
local ShowBanner       = getRemote("ShowBanner") 

-- ── Config ───────────────────────────────────────────────────────────────────
local VIP_PASS_ID = 123456789 -- CHANGE THIS to your real ID before release!
local MAX_STRIKES = 3
local DESIGNER_TEAM = "Designers"
local CRITIC_TEAM = "Critics"

local strikeData = {}

-- ── Internal Helpers ─────────────────────────────────────────────────────────

local function checkAndApplyVIP(player)
	local success, hasPass = pcall(function()
		return MarketplaceService:UserOwnsGamePassAsync(player.UserId, VIP_PASS_ID)
	end)

	if success and hasPass then
		player:SetAttribute("IsVIP", true)
		print("[VIP] " .. player.Name .. " is a verified icon.")
	else
		player:SetAttribute("IsVIP", false)
	end
end

local function getStrikes(player)
	return strikeData[player.UserId] or 0
end

local function eliminatePlayer(player)
	if not player or not player.Character then return end
	print("[RELEVANCE] " .. player.Name .. " is officially CANCELLED.")

	-- UI Banner for the victim
	ShowBanner:FireClient(player, "YOU HAVE BEEN CANCELED!!!", "The collection failed. Better luck next season.")

	-- VFX & SFX
	local root = player.Character:FindFirstChild("HumanoidRootPart")
	if root then
		PlayPoofVFX:FireAllClients(root.Position)
		SoundService.FireToAll("Strike3Eliminated", root.Position)
		SoundService.FireToAll("CrowdBoo",            root.Position)
	end

	-- Global Notification
	PlayerEliminated:FireAllClients(player.Name)

	-- Showstopper Announcer Hook
	local announcer = ServiceRegistry.Get("ShowstopperAnnouncer")
	if announcer then
		announcer.AnnounceCancelled(player)
	end

	-- Tool Cleanup
	local char = player.Character
	if char then
		local tool = char:FindFirstChild("FBRoll") or player.Backpack:FindFirstChild("FBRoll")
		if tool then tool:Destroy() end
		char:BreakJoints() -- Just in case
	end

	-- Session Management
	task.wait(0.5)
	player.Team = Teams:WaitForChild("Lobby")
	player:LoadCharacter()

	-- Win State Check
	local TagManager = ServiceRegistry.Get("TagManager")
	if TagManager and TagManager.CheckTotalFreeze then
		TagManager.CheckTotalFreeze()
	end
end

-- ── Public API ───────────────────────────────────────────────────────────────

local RelevanceSystem = {}

function RelevanceSystem.AddStrike(player)
	-- Universal - works for both teams
	if not player.Team then return false end
	if player.Team.Name ~= DESIGNER_TEAM and player.Team.Name ~= CRITIC_TEAM then return false end

	local strikes = getStrikes(player) + 1
	
	-- ── ABILITY HOOK: The Glitch Gala (Double Strikes) ──
	if player:GetAttribute("InGlitch") then
		strikes += 1
		print("[RELEVANCE] " .. player.Name .. " gained an extra strike due to GLITCH!")
	end
	
	strikeData[player.UserId] = strikes

	UpdateStrikes:FireClient(player, strikes, MAX_STRIKES)

	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")

	if strikes == 1 then
		if root then SoundService.FireToClient(player, "Strike1", root.Position) end
	elseif strikes == 2 then
		if root then SoundService.FireToClient(player, "Strike2", root.Position) end
	elseif strikes >= MAX_STRIKES then
		eliminatePlayer(player)
		return true
	end

	return false
end

-- // THE MASS CANCELLATION // --
function RelevanceSystem.CancelAllDesigners()
	local designersTeam = Teams:FindFirstChild(DESIGNER_TEAM)
	if not designersTeam then return end

	print("[RELEVANCE] Mass Cancellation initiated for Designers. Clearing the runway...")

	for _, player in ipairs(designersTeam:GetPlayers()) do
		eliminatePlayer(player)
	end
end

function RelevanceSystem.CancelAllCritics()
	local criticsTeam = Teams:FindFirstChild(CRITIC_TEAM)
	if not criticsTeam then return end

	print("[RELEVANCE] Mass Cancellation initiated for Critics. Clearing the runway...")

	for _, player in ipairs(criticsTeam:GetPlayers()) do
		eliminatePlayer(player)
	end
end

function RelevanceSystem.Eliminate(player)
	eliminatePlayer(player)
end

function RelevanceSystem.GetStrikes(player)
	return getStrikes(player)
end

function RelevanceSystem.ResetStrikes(player)
	strikeData[player.UserId] = 0
	UpdateStrikes:FireClient(player, 0, MAX_STRIKES)
end

-- ── Lifecycle ────────────────────────────────────────────────────────────────

local function onPlayerAdded(player)
	checkAndApplyVIP(player)

	-- Catch those mid-game purchases
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(purchaser, passId, wasPurchased)
		if wasPurchased and purchaser == player and passId == VIP_PASS_ID then
			player:SetAttribute("IsVIP", true)
		end
	end)
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayerAdded, player)
end

RoundEvents.Intermission.Event:Connect(function()
	for _, p in ipairs(Players:GetPlayers()) do
		RelevanceSystem.ResetStrikes(p)
	end
	strikeData = {}
end)

Players.PlayerRemoving:Connect(function(p)
	strikeData[p.UserId] = nil
end)

ServiceRegistry.Register("RelevanceSystem", RelevanceSystem)
return RelevanceSystem