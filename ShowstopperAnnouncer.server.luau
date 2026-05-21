local ReplicatedStorage   = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local ServiceRegistry    = require(ServerScriptService:WaitForChild("ServiceRegistry"))
local ShowstopperService = ServiceRegistry.Await("ShowstopperService")

local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local function getRemote(name)
	local r = Remotes:FindFirstChild(name)
	if not r then r = Instance.new("RemoteEvent") r.Name = name r.Parent = Remotes end
	return r
end

local ShowstopperAnnounce = getRemote("ShowstopperAnnounce")
local ShowCancelledBanner = getRemote("ShowCancelledBanner")
local ActivateShowstopper = getRemote("ActivateShowstopper")
local SabotageAnnounce = getRemote("SabotageAnnounce")

local ShowstopperTitles = {
	Trendsetter     = "THE TALENT: TRENDSETTER",
	FinalLook       = "THE TALENT: FINAL LOOK",
	TheCancellation = "THE CRITIC: THE CANCELLATION",
	CeaseAndDesist  = "THE CRITIC: CEASE AND DESIST",
	["The Main Event"] = "THE MAIN EVENT",
	MainEvent       = "THE MAIN EVENT",
	["The Glitch Gala"] = "THE GLITCH GALA",
	GlitchGala      = "THE GLITCH GALA",
	["The Velvet Rope"] = "THE VELVET ROPE",
	VelvetRope      = "THE VELVET ROPE",
	["The Flash Mob"] = "THE FLASH MOB",
	FlashMob        = "THE FLASH MOB",
	["The Editorial Mirror"] = "THE EDITORIAL MIRROR",
	EditorialMirror = "THE EDITORIAL MIRROR",
	["The Paparazzi Swarm"] = "THE PAPARAZZI SWARM",
	PaparazziSwarm  = "THE PAPARAZZI SWARM",
	["The Afterparty"] = "THE AFTERPARTY",
	Afterparty      = "THE AFTERPARTY",
}

-- Special message formats for certain showstoppers
local ShowstopperMessages = {
	["The Main Event"] = "IS TAKING THE STAGE!",
	MainEvent       = "IS TAKING THE STAGE!",
	["The Glitch Gala"] = "ERROR: THE GALA IS GLITCHED!",
	GlitchGala      = "ERROR: THE GALA IS GLITCHED!",
	["The Velvet Rope"] = "HAS OPENED THE VIP LOUNGE!",
	VelvetRope      = "HAS OPENED THE VIP LOUNGE!",
	["The Flash Mob"] = "SQUAD GOALS: THE FLASH MOB IS TRENDING!",
	FlashMob        = "SQUAD GOALS: THE FLASH MOB IS TRENDING!",
}

-- Listen to activation for announcement only
-- (ShowstopperService handles the actual execution)
ActivateShowstopper.OnServerEvent:Connect(function(player, moduleName)
	local charge = ShowstopperService.GetCharge(player)
	if not charge or charge < 100 then return end

	local teamName       = player.Team and player.Team.Name or ""
	local resolvedModule = moduleName

	if not resolvedModule then
		local ShowstoppersFolder = ReplicatedStorage:FindFirstChild("Showstoppers")
		if ShowstoppersFolder then
			local folder = ShowstoppersFolder:FindFirstChild(teamName)
			if folder and #folder:GetChildren() > 0 then
				resolvedModule = folder:GetChildren()[1].Name
			end
		end
	end

	if not resolvedModule then return end

	local displayTitle = ShowstopperTitles[resolvedModule] or resolvedModule:upper()
	local specialMessage = ShowstopperMessages[resolvedModule]
	local message
	
	if specialMessage then
		message = player.Name .. " " .. specialMessage
	else
		message = player.Name .. " IS DROPPING " .. displayTitle .. "!"
	end

	print("[ANNOUNCE] " .. message)
	ShowstopperAnnounce:FireAllClients(player.Name, displayTitle, message)
end)

local ShowstopperAnnouncer = {
	AnnounceCancelled = function(cancelledPlayer)
		local msg = cancelledPlayer.Name .. " HAS BEEN CANCELLED"
		ShowCancelledBanner:FireAllClients(cancelledPlayer.Name, msg)
		print("[ANNOUNCE] " .. msg)
	end,

	AnnounceSabotage = function(teamName, objectName)
		-- Team-specific dramatic messages
		local message = teamName == "Designers" 
			and "THE COLLECTION IS COMPROMISED!"
			or "THE INDUSTRIAL SHREDDER IS SABOTAGED!"
		
		local fullMessage = objectName .. " - " .. message
		print("[ANNOUNCE] " .. fullMessage)
		
		-- Fire to all clients - HUDModule_Banners will filter by team
		SabotageAnnounce:FireAllClients(teamName, objectName, message)
	end,
}

ServiceRegistry.Register("ShowstopperAnnouncer", ShowstopperAnnouncer)
return ShowstopperAnnouncer
