local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("SharedConfig"))

local JUMPPAD_TAG = Config.TAGS.JUMPPAD
local HEIGHT = Config.JUMPPAD.HEIGHT
local COOLDOWN = Config.JUMPPAD.COOLDOWN
local RESET_DELAY = Config.JUMPPAD.RESET_DELAY
local DEFAULT_JUMP_HEIGHT = Config.JUMPPAD.DEFAULT_JUMP_HEIGHT

-- Track debounce per character
local debounce = {}

-------------------------------------------------
-- Jump Handler
-------------------------------------------------
local function onJumpPadTouched(jumpPad, hitPart)
    local character = hitPart.Parent
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    if not humanoid then return end
    
    -- Debounce check
    local key = character.Name .. "_" .. jumpPad:GetFullName()
    if debounce[key] then return end
    
    debounce[key] = true
    
    -- Apply jump boost
    humanoid.JumpHeight = HEIGHT
    
    task.wait(RESET_DELAY)
    
    -- Reset to default
    if humanoid and humanoid.Parent then
        humanoid.JumpHeight = DEFAULT_JUMP_HEIGHT
    end
    
    task.wait(COOLDOWN)
    debounce[key] = false
end

-------------------------------------------------
-- Setup Jump Pad
-------------------------------------------------
local function setupJumpPad(jumpPad)
    if not jumpPad:IsA("BasePart") then return end
    
    -- Connect touch event
    local connection = jumpPad.Touched:Connect(function(hitPart)
        onJumpPadTouched(jumpPad, hitPart)
    end)
    
    -- Store connection for cleanup
    jumpPad:SetAttribute("JumpPadConnection", true)
end

-------------------------------------------------
-- Initialize all existing jump pads
-------------------------------------------------
for _, obj in ipairs(CollectionService:GetTagged(JUMPPAD_TAG)) do
    setupJumpPad(obj)
end

-- Listen for new jump pads added during gameplay
CollectionService:GetInstanceAddedSignal(JUMPPAD_TAG):Connect(function(obj)
    task.wait(0.1)
    setupJumpPad(obj)
end)

print("[JUMPPAD] Manager initialized. Using SharedConfig values.")
print("[JUMPPAD] Height: " .. HEIGHT .. " | Cooldown: " .. COOLDOWN)
