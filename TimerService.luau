local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local ServiceRegistry = require(ServerScriptService:WaitForChild("ServiceRegistry"))
local StatusValues = ReplicatedStorage:WaitForChild("StatusValues")
local TimerValue = StatusValues:WaitForChild("Timer")
local StatusText = StatusValues:WaitForChild("StatusText")

local TimerService = {}
local currentTimerThread = nil

function TimerService.SetStatus(text)
	StatusText.Value = text
end

function TimerService.StartCountdown(seconds, statusText, onComplete)
	if currentTimerThread and currentTimerThread ~= coroutine.running() and coroutine.status(currentTimerThread) ~= "dead" then 
		task.cancel(currentTimerThread) 
	end

	currentTimerThread = task.spawn(function()
		for i = seconds, 0, -1 do
			TimerValue.Value = i
			StatusText.Value = statusText or ""
			task.wait(1)
		end

		if currentTimerThread == coroutine.running() then
			currentTimerThread = nil
		end

		if onComplete then onComplete() end
	end)
end

function TimerService.Stop()
	if currentTimerThread then
		task.cancel(currentTimerThread)
		currentTimerThread = nil
	end
end

ServiceRegistry.Register("TimerService", TimerService)
return TimerService