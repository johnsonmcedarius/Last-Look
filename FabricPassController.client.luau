local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local player = Players.LocalPlayer

-- Remotes
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local SetTeammateGlow = Remotes:WaitForChild("SetTeammateGlow")
local PlayPoofVFX = Remotes:WaitForChild("PlayPoofVFX")
local PlayProximitySound = Remotes:WaitForChild("PlayProximitySound")
local PassFabric = Remotes:WaitForChild("PassFabric")

-- Track active highlight objects
local activeHighlights = {} -- [player.UserId] = Highlight instance


local function applyGlow(targetPlayer)
    if activeHighlights[targetPlayer.UserId] then return end

    local char = targetPlayer.Character
    if not char then return end

    local highlight = Instance.new("Highlight")
    highlight.Name = "PassHighlight"
    highlight.Adornee = char
    highlight.FillTransparency = 0.8 -- Slight fill for visibility
    highlight.FillColor = Color3.fromRGB(100, 200, 255) -- Light blue for receivers
    highlight.OutlineColor = Color3.new(1, 1, 1) -- Pure white outline
    highlight.OutlineTransparency = 0
    highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop -- See through walls
    highlight.Parent = char

    activeHighlights[targetPlayer.UserId] = highlight
end

local function removeGlow(targetPlayer)
    local h = activeHighlights[targetPlayer.UserId]
    if h then
        h:Destroy()
        activeHighlights[targetPlayer.UserId] = nil
    end
end

-- Server sends list of receivers to highlight
SetTeammateGlow.OnClientEvent:Connect(function(teammates, shouldGlow)
    -- Build a quick lookup set of who should glow
    local glowSet = {}
    for _, tm in ipairs(teammates) do
        glowSet[tm.UserId] = true
    end

    -- Apply glows to new targets (receivers)
    if shouldGlow then
        for _, tm in ipairs(teammates) do
            applyGlow(tm)
        end
    end

    -- Remove glows from anyone no longer in range
    for userId, _ in pairs(activeHighlights) do
        if not glowSet[userId] then
            local p = Players:GetPlayerByUserId(userId)
            if p then removeGlow(p) end
        end
    end
end)

-- Cleanup on character removal
player.CharacterRemoving:Connect(function()
    for userId, h in pairs(activeHighlights) do
        h:Destroy()
        activeHighlights[userId] = nil
    end
end)

-------------------------------------------------
-- Poof VFX (placeholder - replace with my real asset clone)
-------------------------------------------------
PlayPoofVFX.OnClientEvent:Connect(function(position)
    -- Placeholder poof: a quick expanding sphere
    local poof = Instance.new("Part")
    poof.Shape = Enum.PartType.Ball
    poof.Size = Vector3.new(1, 1, 1)
    poof.Position = position
    poof.Anchored = true
    poof.CanCollide = false
    poof.Material = Enum.Material.Neon
    poof.BrickColor = BrickColor.new("Carnation pink")
    poof.CastShadow = false
    poof.Parent = workspace

    TweenService:Create(poof, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        Size = Vector3.new(6, 6, 6),
        Transparency = 1
    }):Play()

    Debris:AddItem(poof, 0.4)
end)


-- Snip/Zip proximity sound

PlayProximitySound.OnClientEvent:Connect(function(sourcePart, soundType)
    if soundType ~= "SnipZip" then return end
    if not sourcePart or not sourcePart.Parent then return end

    -- Check if local player is close enough to hear it
    local char = player.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    local partPos = sourcePart:IsA("BasePart") and sourcePart.Position
        or (sourcePart:FindFirstChildWhichIsA("BasePart") and sourcePart:FindFirstChildWhichIsA("BasePart").Position)

    if not root or not partPos then return end
    if (root.Position - partPos).Magnitude > 20 then return end

    -- Play the sound (attach to part so it's 3D)
    local sound = Instance.new("Sound")
    sound.SoundId = "rbxassetid://0" -- TODO: Replace with your snip/zip sound ID
    sound.Volume = 0.8
    sound.RollOffMaxDistance = 25
    sound.Parent = sourcePart
    sound:Play()

    Debris:AddItem(sound, 3)
end)

print("[CLIENT] FabricPassController ready")
