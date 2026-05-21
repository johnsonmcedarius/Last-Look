-- ─────────────────────────────────────────────────────────────────────────────
-- LiveOpsService: Event scheduling, bonus multipliers, featured modes
-- FEATURE FLAG: LiveOpsEnabled = false keeps this completely dormant
-- ─────────────────────────────────────────────────────────────────────────────

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local ServiceRegistry = require(ServerScriptService:WaitForChild("ServiceRegistry"))

-- ── FEATURE FLAG: Keep dormant during playtesting ──
local LiveOpsEnabled = false  -- SET TO true WHEN READY FOR LIVE OPS

local LiveOpsService = {}
local currentEvent = nil
local eventSchedule = {}  -- Will load from LiveOpsConfig when enabled

-- ── Public API (all gated by LiveOpsEnabled) ──

function LiveOpsService.GetCurrentEvent()
	if not LiveOpsEnabled then return nil end
	
	local now = os.time()
	for _, event in ipairs(eventSchedule) do
		if now >= event.StartTime and now < event.EndTime then
			return event
		end
	end
	return nil
end

function LiveOpsService.GetBonusMultiplier(player)
	if not LiveOpsEnabled then return 1.0 end
	
	local event = LiveOpsService.GetCurrentEvent()
	if event and event.Type == "XPBoost" then
		return event.Multiplier or 1.5
	end
	return 1.0
end

function LiveOpsService.GetCoinMultiplier(player)
	if not LiveOpsEnabled then return 1.0 end
	
	local event = LiveOpsService.GetCurrentEvent()
	if event and event.Type == "CoinBoost" then
		return event.Multiplier or 1.5
	end
	return 1.0
end

function LiveOpsService.IsEventActive()
	if not LiveOpsEnabled then return false end
	return currentEvent ~= nil
end

function LiveOpsService.GetEventName()
	if not LiveOpsEnabled then return "None" end
	local event = LiveOpsService.GetCurrentEvent()
	return event and event.Name or "None"
end

-- ── Utility for checking if enabled ──
function LiveOpsService.IsEnabled()
	return LiveOpsEnabled
end

-- ── Internal: Load event schedule (only when enabled) ──
local function loadEventSchedule()
	if not LiveOpsEnabled then return end
	
	local success, config = pcall(function()
		return require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("LiveOpsConfig"))
	end)
	
	if success and config then
		eventSchedule = config.Events or {}
		print("[LIVEOPS] Loaded " .. #eventSchedule .. " scheduled events")
	else
		warn("[LIVEOPS] Failed to load LiveOpsConfig - using empty schedule")
		eventSchedule = {}
	end
end

-- ── Internal Event Loop (only runs when enabled) ──
if LiveOpsEnabled then
	loadEventSchedule()
	
	task.spawn(function()
		while true do
			task.wait(60)
			
			local newEvent = LiveOpsService.GetCurrentEvent()
			if newEvent ~= currentEvent then
				currentEvent = newEvent
				if currentEvent then
					print("[LIVEOPS] Event started: " .. currentEvent.Name)
					-- Notify all clients of event change
					local GlobalAnnouncement = ReplicatedStorage:FindFirstChild("Remotes")
					if GlobalAnnouncement then
						GlobalAnnouncement = GlobalAnnouncement:FindFirstChild("GlobalAnnouncement")
						if GlobalAnnouncement then
							GlobalAnnouncement:FireAllClients("EVENT", currentEvent.Name, currentEvent.Description or "")
						end
					end
				else
					print("[LIVEOPS] No active event")
				end
			end
		end
	end)
	
	print("[LIVEOPS] Service initialized and ACTIVE")
else
	print("[LIVEOPS] Service initialized but DORMANT (LiveOpsEnabled = false)")
end

ServiceRegistry.Register("LiveOpsService", LiveOpsService)
return LiveOpsService