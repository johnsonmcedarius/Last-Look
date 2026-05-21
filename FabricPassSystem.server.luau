local Players             = game:GetService("Players")
local ReplicatedStorage   = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local CollectionService   = game:GetService("CollectionService")

local ServiceRegistry    = require(ServerScriptService:WaitForChild("ServiceRegistry"))
local Config             = require(ReplicatedStorage:WaitForChild("SharedConfig"))
local ShowstopperService = ServiceRegistry.Await("ShowstopperService")
local SoundService       = require(ReplicatedStorage:WaitForChild("SoundService"))

local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local function getRemote(name)
	local r = Remotes:FindFirstChild(name)
	if not r then r = Instance.new("RemoteEvent") r.Name = name r.Parent = Remotes end
	return r
end

local PassFabric      = getRemote("PassFabric")
local PlayPoofVFX     = getRemote("PlayPoofVFX")
local SetTeammateGlow = getRemote("SetTeammateGlow")
local ShowRewardPopup = getRemote("ShowRewardPopup")

local PASS_RANGE     = Config.PASS_RANGE
local DESIGNER_TEAM  = Config.TEAMS.DESIGNER
local CRITIC_TEAM    = Config.TEAMS.CRITIC
local PASS_DEBOUNCE  = 1.5 
local UPDATE_INTERVAL = 0.3

-- ── FLASH MOB: TELE-PASS MULTIPLIER ──
local TELE_PASS_MULTIPLIER = 3

-- [userId] = last pass timestamp
local lastPassTime = {}

-- Track prompts by receiver: [receiverUserId] = { holderUserId, prompt, connection }
local receiverPrompts = {}

-- Track which holder owns which receivers: [holderUserId] = { receiverUserId, ... }
local holderReceivers = {}

local function getFabricTool(player)
    return (player.Character and player.Character:FindFirstChild("FBRoll"))
        or player.Backpack:FindFirstChild("FBRoll")
end

local function getRoot(player)
    return player.Character and player.Character:FindFirstChild("HumanoidRootPart")
end

local function isDesigner(player)
    return player.Team and player.Team.Name == DESIGNER_TEAM
end

local function isCritic(player)
    return player.Team and player.Team.Name == CRITIC_TEAM
end

local function isSameTeam(p1, p2)
    return p1.Team and p2.Team and p1.Team.Name == p2.Team.Name
end

-------------------------------------------------
-- Core pass logic (server-authoritative)
-- PHASE 3: Now works for both Designers AND Critics
-- FLASH MOB: Tele-Pass (triple range) + Momentum Reset
-------------------------------------------------
local function executePass(holder, targetPlayer)
    -- Both teams can now pass fabric to teammates
    if not isSameTeam(holder, targetPlayer) then return end
    if holder == targetPlayer then return end

    local now = os.clock()
    if (lastPassTime[holder.UserId] or 0) + PASS_DEBOUNCE > now then
        return
    end
    lastPassTime[holder.UserId] = now

    local fabricTool = getFabricTool(holder)
    if not fabricTool then return end

    local hr = getRoot(holder)
    local tr = getRoot(targetPlayer)
    if not hr or not tr then return end
    
    -- FLASH MOB: Tele-Pass - Triple the range
    local effectiveRange = PASS_RANGE
    if holder:GetAttribute("TelePassActive") then
        effectiveRange = PASS_RANGE * TELE_PASS_MULTIPLIER
    end
    
    if (hr.Position - tr.Position).Magnitude > effectiveRange + 5 then return end

    if getFabricTool(targetPlayer) then 
        ShowRewardPopup:FireClient(holder, "Teammate already has fabric!", "")
        return 
    end

    print("[PASS] " .. holder.Name .. " -> " .. targetPlayer.Name .. " (" .. holder.Team.Name .. ")")

    if holder.Character then
        holder.Character:SetAttribute("IsPassing", true)
        task.delay(0.5, function()
            if holder.Character then holder.Character:SetAttribute("IsPassing", nil) end
        end)
    end

    PlayPoofVFX:FireAllClients(hr.Position)
    SoundService.FireToAll("FabricPass", hr.Position)

    fabricTool.Parent = targetPlayer.Backpack

    task.wait(0.1)
    if tr and tr.Parent then PlayPoofVFX:FireAllClients(tr.Position) end

    ShowstopperService.OnFabricPass(holder, targetPlayer)

    -- FLASH MOB: Momentum Reset - Reset dash cooldown for both players
    local Remotes = ReplicatedStorage:FindFirstChild("Remotes")
    local DashCooldownUpdate = Remotes and Remotes:FindFirstChild("DashCooldownUpdate")
    if DashCooldownUpdate then
        -- Check if Flash Mob is active
        if holder:GetAttribute("FlashMobActive") or targetPlayer:GetAttribute("FlashMobActive") then
            DashCooldownUpdate:FireClient(holder, 0) -- Reset to 0
            DashCooldownUpdate:FireClient(targetPlayer, 0)
            print("[FLASH MOB] Momentum Reset - dash cooldown reset for " .. holder.Name .. " and " .. targetPlayer.Name)
        end
    end

    local lb = ServiceRegistry.Get("DailyLookbook")
    if lb then
        lb.AddProgress(holder,       "Passes", 1)
        lb.AddProgress(targetPlayer, "Passes", 1)
    end

    ShowRewardPopup:FireClient(holder,       "+10 Showstopper", "")
    ShowRewardPopup:FireClient(targetPlayer, "+10 Showstopper", "")
end

PassFabric.OnServerEvent:Connect(executePass)

-------------------------------------------------
-- Prompt Management - Prompts on RECEIVERS
-------------------------------------------------
local function destroyPromptForReceiver(receiverUserId)
    local data = receiverPrompts[receiverUserId]
    if not data then return end
    
    if data.prompt and data.prompt.Parent then
        data.prompt:Destroy()
    end
    if data.connection then
        data.connection:Disconnect()
    end
    
    receiverPrompts[receiverUserId] = nil
    
    local holderList = holderReceivers[data.holderUserId]
    if holderList then
        for i, uid in ipairs(holderList) do
            if uid == receiverUserId then
                table.remove(holderList, i)
                break
            end
        end
    end
end

local function createPromptOnReceiver(holder, receiver)
    local hr = getRoot(holder)
    local rr = getRoot(receiver)
    if not hr or not rr then return end
    
    if receiverPrompts[receiver.UserId] then return end
    
    -- FLASH MOB: Tele-Pass - Triple the range
    local effectiveRange = PASS_RANGE
    if holder:GetAttribute("TelePassActive") then
        effectiveRange = PASS_RANGE * TELE_PASS_MULTIPLIER
    end
    
    local prompt = Instance.new("ProximityPrompt")
    prompt.Name = "GiveFabricPrompt"
    prompt.ActionText = "Give Fabric"
    prompt.ObjectText = "Pass to " .. receiver.Name
    prompt.HoldDuration = 0
    prompt.MaxActivationDistance = effectiveRange
    prompt.RequiresLineOfSight = false
    CollectionService:AddTag(prompt, "DesignerPrompt")
    prompt.Parent = rr
    
    local connection = prompt.Triggered:Connect(function(playerWhoTriggered)
        if playerWhoTriggered ~= holder then return end
        executePass(holder, receiver)
    end)
    
    receiverPrompts[receiver.UserId] = {
        holderUserId = holder.UserId,
        prompt = prompt,
        connection = connection
    }
    
    if not holderReceivers[holder.UserId] then
        holderReceivers[holder.UserId] = {}
    end
    table.insert(holderReceivers[holder.UserId], receiver.UserId)
end

local function destroyAllPromptsForHolder(holderUserId)
    local receivers = holderReceivers[holderUserId]
    if not receivers then return end
    
    for _, receiverUserId in ipairs(receivers) do
        local data = receiverPrompts[receiverUserId]
        if data and data.holderUserId == holderUserId then
            if data.prompt and data.prompt.Parent then
                data.prompt:Destroy()
            end
            if data.connection then
                data.connection:Disconnect()
            end
            receiverPrompts[receiverUserId] = nil
        end
    end
    
    holderReceivers[holderUserId] = nil
end

-------------------------------------------------
-- Update Loop - Find nearby receivers and create prompts
-- PHASE 3: Works for both Designers AND Critics
-- FLASH MOB: Tele-Pass (triple range)
-------------------------------------------------
local function updatePromptsForHolder(holder)
    if not getFabricTool(holder) then
        destroyAllPromptsForHolder(holder.UserId)
        SetTeammateGlow:FireClient(holder, {}, false)
        return
    end
    
    local hr = getRoot(holder)
    if not hr then return end
    
    -- FLASH MOB: Tele-Pass - Triple the range
    local effectiveRange = PASS_RANGE
    if holder:GetAttribute("TelePassActive") then
        effectiveRange = PASS_RANGE * TELE_PASS_MULTIPLIER
    end
    
    local nearbyReceivers = {}
    for _, p in ipairs(Players:GetPlayers()) do
        if p == holder then continue end
        -- PHASE 3: Both teams can pass to teammates
        if not isSameTeam(holder, p) then continue end
        if getFabricTool(p) then continue end
        
        local pr = getRoot(p)
        if not pr then continue end
        
        local dist = (hr.Position - pr.Position).Magnitude
        if dist <= effectiveRange then
            table.insert(nearbyReceivers, p)
        end
    end
    
    local currentReceivers = holderReceivers[holder.UserId] or {}
    for i = #currentReceivers, 1, -1 do
        local receiverUserId = currentReceivers[i]
        local stillInRange = false
        for _, p in ipairs(nearbyReceivers) do
            if p.UserId == receiverUserId then
                stillInRange = true
                break
            end
        end
        if not stillInRange then
            destroyPromptForReceiver(receiverUserId)
        end
    end
    
    for _, receiver in ipairs(nearbyReceivers) do
        if not receiverPrompts[receiver.UserId] then
            createPromptOnReceiver(holder, receiver)
        end
    end
    
    SetTeammateGlow:FireClient(holder, nearbyReceivers, true)
end

-------------------------------------------------
-- Main Update Loop
-- PHASE 3: Both teams can pass fabric
-------------------------------------------------
task.spawn(function()
    while true do
        task.wait(UPDATE_INTERVAL)
        
        for _, p in ipairs(Players:GetPlayers()) do
            -- PHASE 3: Both Designers AND Critics can pass
            if (isDesigner(p) or isCritic(p)) and getFabricTool(p) then
                updatePromptsForHolder(p)
            end
        end
    end
end)

-------------------------------------------------
-- Watcher Logic
-- PHASE 3: Both teams can pass fabric
-------------------------------------------------
local function watchPlayer(player)
    local function onChildAdded(child)
        if child.Name == "FBRoll" and (isDesigner(player) or isCritic(player)) then
            print("[FABRIC] " .. player.Name .. " picked up FBRoll - prompts will appear on nearby teammates")
        end
    end

    local function onChildRemoved(child)
        if child.Name == "FBRoll" then
            destroyAllPromptsForHolder(player.UserId)
            SetTeammateGlow:FireClient(player, {}, false)
        end
    end

    player.Backpack.ChildAdded:Connect(onChildAdded)
    player.Backpack.ChildRemoved:Connect(onChildRemoved)

    local function watchCharacter(char)
        char.ChildAdded:Connect(onChildAdded)
        char.ChildRemoved:Connect(onChildRemoved)
    end

    player.CharacterAdded:Connect(function(char)
        destroyAllPromptsForHolder(player.UserId)
        watchCharacter(char)
    end)

    if player.Character then watchCharacter(player.Character) end
end

Players.PlayerAdded:Connect(watchPlayer)
for _, p in ipairs(Players:GetPlayers()) do watchPlayer(p) end

Players.PlayerRemoving:Connect(function(p)
    destroyAllPromptsForHolder(p.UserId)
    lastPassTime[p.UserId] = nil
end)

print("[FABRICPASS] System ready - using SharedConfig values")
