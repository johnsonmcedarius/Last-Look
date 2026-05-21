local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Teams = game:GetService("Teams")

-- Dependencies
local ServiceRegistry = require(ServerScriptService:WaitForChild("ServiceRegistry"))
local RoundEvents = require(ServerScriptService:WaitForChild("RoundEvents"))
local GameConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("GameConfig"))
local PreGameModule = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("PreGameModule"))
local Maid = require(ReplicatedStorage:WaitForChild("ReplicatedStorage"):WaitForChild("MadworkMaid"))
local ReplicaService = require(ServerScriptService.ReplicaService:WaitForChild("ReplicaService"))

-- Remotes
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local _MatchStart = Remotes:WaitForChild("MatchStart")
local _MatchEnd = Remotes:WaitForChild("MatchEnd")
local _Intermission = Remotes:WaitForChild("MatchIntermission")

local RoundService = {}
RoundService.States = {
	LOBBY = "Lobby",
	INTERMISSION = "Intermission",
	SETUP = "Setup",
	ACTIVE = "Active",
	POST_ROUND = "PostRound"
}
RoundService.Phase = RoundService.States.LOBBY

local roundMaid = Maid.NewMaid()
local stateMaid = Maid.NewMaid() -- State-specific cleanup
local roundStateReplica = nil
local ROUND_STATE_TOKEN = ReplicaService.NewClassToken("RoundState")

-- Services (resolved in Start)
local MapService, TeamService, TimerService, RewardTracker, RelevanceSystem, FabricManager, MatchRegistry

function RoundService:Init()
	print("[RoundService] Initializing...")
end

function RoundService:Start()
	MapService = ServiceRegistry.Await("MapService")
	TeamService = ServiceRegistry.Await("TeamService")
	TimerService = ServiceRegistry.Await("TimerService")
	RewardTracker = ServiceRegistry.Await("RewardTracker")
	RelevanceSystem = ServiceRegistry.Await("RelevanceSystem")
	FabricManager = ServiceRegistry.Await("FabricManager")
	MatchRegistry = ServiceRegistry.Await("MatchRegistry")

	roundStateReplica = ReplicaService.NewReplica({
		ClassToken = ROUND_STATE_TOKEN,
		Data = {
			Phase = RoundService.States.LOBBY,
			Timer = 0,
			Status = "Waiting for players...",
			DesignerScore = 0,
			CriticScore = 0,
			TargetScore = MatchRegistry.GetTargetScore() or 5
		},
		Replication = "All"
	})

	self:SetState(RoundService.States.LOBBY)
end

function RoundService:SetState(newState)
	stateMaid:Cleanup() 
	stateMaid = Maid.NewMaid()

	RoundService.Phase = newState
	roundStateReplica:SetValue({"Phase"}, newState)

	print("[ROUND] Transitioning to state: " .. newState)
	
	if newState == RoundService.States.LOBBY then
		self:HandleLobby()
	elseif newState == RoundService.States.INTERMISSION then
		self:HandleIntermission()
	elseif newState == RoundService.States.SETUP then
		self:HandleSetup()
	elseif newState == RoundService.States.ACTIVE then
		self:HandleActive()
	elseif newState == RoundService.States.POST_ROUND then
		self:HandlePostRound()
	end
end

function RoundService:HandleLobby()
	roundStateReplica:SetValue({"Status"}, "Waiting for Players...")
	TimerService.SetStatus("Waiting for Players...")

	local function checkPlayers()
		if #Players:GetPlayers() >= GameConfig.MIN_PLAYERS then
			self:SetState(RoundService.States.INTERMISSION)
		end
	end

	stateMaid:AddCleanupTask(Players.PlayerAdded:Connect(checkPlayers))
	stateMaid:AddCleanupTask(Players.PlayerRemoving:Connect(checkPlayers))
	checkPlayers()
end

function RoundService:HandleIntermission()
	RoundEvents.FireIntermission()
	_Intermission:FireAllClients()
	
	local duration = GameConfig.INTERMISSION_DURATION or 15
	TimerService.StartCountdown(duration, "Intermission", function()
		self:SetState(RoundService.States.SETUP)
	end)
	roundStateReplica:SetValue({"Status"}, "Intermission")
end

function RoundService:HandleSetup()
	TimerService.SetStatus("Selecting Map...")
	roundStateReplica:SetValue({"Status"}, "Selecting Map...")

	local map = MapService.SelectAndLoadMap()
	local critics, designers = TeamService.AssignTeams()

	RoundEvents.FireRoundStarted({ Critics = critics, Designers = designers })

	local mapName = map and map.Name or "UNKNOWN"
	local teamCounts = { Designers = #designers, Critics = #critics }
	local duration = PreGameModule.GetDuration() or 10
	
	-- PHASE 3 FIX: Pass top player UserIds for Viewport rendering
	local function getTopUserIds(playerList)
		local ids = {}
		for i = 1, math.min(#playerList, 3) do
			table.insert(ids, playerList[i].UserId)
		end
		return ids
	end

	local pregameData = {
		TeamCounts = teamCounts,
		MapName = mapName,
		Duration = duration,
		DesignerUserIds = getTopUserIds(designers),
		CriticUserIds = getTopUserIds(critics)
	}

	_MatchStart:FireAllClients(pregameData)

	task.wait(duration) -- Setup delay

	-- Spawn players
	MapService.TeleportPlayers(designers, MapService.GetSpawns(map, "DesignerSpawn"))
	MapService.TeleportPlayers(critics, MapService.GetSpawns(map, "CriticSpawn"))

	self:SetState(RoundService.States.ACTIVE)
end

function RoundService:HandleActive()
	roundStateReplica:SetValue({"Status"}, "The Show is Live!")
	
	-- Reset Round Scores in Replica
	roundStateReplica:SetValue({"DesignerScore"}, 0)
	roundStateReplica:SetValue({"CriticScore"}, 0)
	
	FabricManager.ResetScores()
	ReplicatedStorage:SetAttribute("AllDesignersFrozen", false)
	ReplicatedStorage:SetAttribute("AllCriticsFrozen", false)

	local function CheckWin()
		local winner = self:GetWinner()
		if winner then
			self.Winner = winner
			self:SetState(RoundService.States.POST_ROUND)
		end
	end

	stateMaid:AddCleanupTask(ReplicatedStorage:GetAttributeChangedSignal("AllDesignersFrozen"):Connect(CheckWin))
	stateMaid:AddCleanupTask(ReplicatedStorage:GetAttributeChangedSignal("AllCriticsFrozen"):Connect(CheckWin))
	stateMaid:AddCleanupTask(Players.PlayerRemoving:Connect(CheckWin))
	
	-- Sync scores from FabricManager to Replica
	stateMaid:AddCleanupTask(game:GetService("RunService").Heartbeat:Connect(function()
		local dScore = FabricManager.GetDesignerScore()
		local cScore = FabricManager.GetCriticScore()
		if dScore ~= roundStateReplica.Data.DesignerScore then
			roundStateReplica:SetValue({"DesignerScore"}, dScore)
			CheckWin()
		end
		if cScore ~= roundStateReplica.Data.CriticScore then
			roundStateReplica:SetValue({"CriticScore"}, cScore)
			CheckWin()
		end
	end))

	TimerService.StartCountdown(GameConfig.ROUND_DURATION, "Round Active", function()
		-- Timer expired
		local dScore = FabricManager.GetDesignerScore()
		local cScore = FabricManager.GetCriticScore()
		if dScore > cScore then
			self.Winner = "Designers"
		elseif cScore > dScore then
			self.Winner = "Critics"
		else
			self.Winner = "Draw"
		end
		self:SetState(RoundService.States.POST_ROUND)
	end)
end

function RoundService:GetWinner()
	local designersTeam = Teams:FindFirstChild("Designers")
	local criticsTeam = Teams:FindFirstChild("Critics")

	local aliveDesigners = designersTeam and #designersTeam:GetPlayers() or 0
	local aliveCritics = criticsTeam and #criticsTeam:GetPlayers() or 0

	local allDesignersFrozen = ReplicatedStorage:GetAttribute("AllDesignersFrozen")
	local allCriticsFrozen = ReplicatedStorage:GetAttribute("AllCriticsFrozen")

	local targetScore = MatchRegistry.GetTargetScore() or 5
	local dScore = FabricManager.GetDesignerScore()
	local cScore = FabricManager.GetCriticScore()

	if dScore >= targetScore then return "Designers" end
	if cScore >= targetScore then return "Critics" end

	if (allDesignersFrozen or aliveDesigners == 0) and aliveCritics > 0 then return "Critics" end
	if (allCriticsFrozen or aliveCritics == 0) and aliveDesigners > 0 then return "Designers" end
	
	if #Players:GetPlayers() < GameConfig.MIN_PLAYERS then return "Draw" end

	return nil
end

function RoundService:HandlePostRound()
	local winner = self.Winner or "Draw"
	TimerService.Stop()

	if winner == "Critics" then
		RelevanceSystem.CancelAllDesigners()
	elseif winner == "Designers" then
		RelevanceSystem.CancelAllCritics()
	end

	local winStatus = (winner == "Critics" and "CRITICS SHUT IT DOWN!") or (winner == "Designers" and "THE COLLECTION IS A HIT!") or "NO CONTEST"
	TimerService.SetStatus(winStatus)
	roundStateReplica:SetValue({"Status"}, winStatus)

	RoundEvents.FireRoundEnded(winner)
	_MatchEnd:FireAllClients(winner, 0)

	task.wait(15) -- Post-round results display
	
	MapService.Cleanup()
	TeamService.ResetTeams()
	
	self:SetState(RoundService.States.LOBBY)
end

ServiceRegistry.Register("RoundService", RoundService)
return RoundService
