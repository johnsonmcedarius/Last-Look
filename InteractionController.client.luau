local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer

-- Direct requires
local VFXModule = require(ReplicatedStorage:WaitForChild("VFXModule"))

-- Tracking connections to avoid memory leaks or double-sparkles
local connectedPrompts = {}

-------------------------------------------------
-- Interaction VFX Hook
-------------------------------------------------
local function onInteractionSuccess(target)
    -- Target is the actual object (Rack, Fabric, etc.)
    VFXModule.PlayInteractionSparkle(target)
    print("[VFX] Sparkle triggered on: " .. target.Name)
end

-------------------------------------------------
-- Logic for single prompts
-------------------------------------------------
local function updateSinglePrompt(obj)
    local prompt = obj:IsA("ProximityPrompt") and obj or obj:FindFirstChildOfClass("ProximityPrompt")

    if not prompt then
        prompt = obj:WaitForChild("DesignerPickup", 2) 
            or obj:WaitForChild("CriticSabotage", 2) 
            or obj:FindFirstChildOfClass("ProximityPrompt")
    end

    if not prompt then return end

    -- Hook the VFX trigger once per prompt lifetime
    if not connectedPrompts[prompt] then
        connectedPrompts[prompt] = prompt.Triggered:Connect(function()
            onInteractionSuccess(obj)
        end)
    end

    local char = player.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")

    -- If anchored, you're either on a podium or frozen (game over vibes)
    local isFrozen = root and root.Anchored or false

    local teamName = (player.Team and player.Team.Name) or ""
    local isDesigner = (teamName == "Designers")
    local isCritic = (teamName == "Critics")

    -- Designer Logic
    if CollectionService:HasTag(obj, "DesignerPrompt") or CollectionService:HasTag(prompt, "DesignerPrompt") then
        -- Check if this is a "Give Fabric" prompt (on a receiver)
        if prompt.ActionText:find("Give") then
            -- This prompt is on a RECEIVER - only the HOLDER should see it
            local hasFabric = player.Backpack:FindFirstChild("FBRoll") or (char and char:FindFirstChild("FBRoll"))
            prompt.Enabled = (hasFabric ~= nil) and isDesigner and not isFrozen
        else
            -- Regular designer prompt (pickup, etc.)
            if isDesigner and not isFrozen then
                prompt.Enabled = true
            else
                prompt.Enabled = false
            end
        end

        -- Critic Logic
    elseif CollectionService:HasTag(obj, "CriticPrompt") or CollectionService:HasTag(prompt, "CriticPrompt") then
        prompt.Enabled = isCritic and not isFrozen
    end
end

-------------------------------------------------
-- Refresh & Lifecycle
-------------------------------------------------
local function updateAllPrompts()
    for _, obj in ipairs(CollectionService:GetTagged("DesignerPrompt")) do
        updateSinglePrompt(obj)
    end
    for _, obj in ipairs(CollectionService:GetTagged("CriticPrompt")) do
        updateSinglePrompt(obj)
    end
end

local function hookCharacter(char)
    char.ChildAdded:Connect(updateAllPrompts)
    char.ChildRemoved:Connect(updateAllPrompts)

    local root = char:WaitForChild("HumanoidRootPart", 5)
    if root then
        root:GetPropertyChangedSignal("Anchored"):Connect(updateAllPrompts)
    end

    updateAllPrompts()
end

player.CharacterAdded:Connect(hookCharacter)
if player.Character then hookCharacter(player.Character) end

-- Inventory check for fabric logic
player.Backpack.ChildAdded:Connect(updateAllPrompts)
player.Backpack.ChildRemoved:Connect(updateAllPrompts)

-- Team update
player:GetPropertyChangedSignal("Team"):Connect(updateAllPrompts)

-- CollectionService Listeners for dynamically spawned objects
CollectionService:GetInstanceAddedSignal("DesignerPrompt"):Connect(function(obj)
    task.wait(0.1) 
    updateSinglePrompt(obj)
end)

CollectionService:GetInstanceAddedSignal("CriticPrompt"):Connect(function(obj)
    task.wait(0.1)
    updateSinglePrompt(obj)
end)

-- The "safety net" loop
task.spawn(function()
    while task.wait(2) do
        updateAllPrompts()
    end
end)

print("[CLIENT] InteractionController ready")
