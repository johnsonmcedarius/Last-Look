-- ─────────────────────────────────────────────────────────────────────────────
-- CratePromptController: Dynamic crate prompt handling
-- Updates CratePromptGui labels based on crate type (Robux/Coin)
-- ─────────────────────────────────────────────────────────────────────────────

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local ProximityPromptService = game:GetService("ProximityPromptService")

local player = Players.LocalPlayer
local PlayerGui = player:WaitForChild("PlayerGui")

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local CratePurchaseRequest = Remotes:WaitForChild("CratePurchaseRequest")

-- ── Constants ──
local COIN_CRATE_COST = 500
local ROBUX_CRATE_COST = 99

-- ── Reference Physical UI ──
local CratePromptGui = PlayerGui:WaitForChild("CratePromptGui")
local PromptContainer = CratePromptGui:WaitForChild("PromptContainer")
local InnerFrame = PromptContainer:WaitForChild("InnerFrame")
local CrateLabel = InnerFrame:FindFirstChild("CrateLabel")
local PriceLabel = InnerFrame:FindFirstChild("PriceLabel")
local ActionLabel = InnerFrame:FindFirstChild("ActionLabel")
local Glow = PromptContainer:FindFirstChild("Glow")

-- ── State ──
local currentCrateType = nil
local currentPrompt = nil

-- ── Helper: Update prompt UI based on crate type ──
local function updatePromptUI(crateType)
	currentCrateType = crateType
	
	if crateType == "RobuxCrate" then
		if CrateLabel then 
			CrateLabel.Text = "DESIGNER DROP" 
			CrateLabel.TextColor3 = Color3.fromRGB(255, 200, 50) -- Gold
		end
		if PriceLabel then 
			PriceLabel.Text = ROBUX_CRATE_COST .. " R$" 
			PriceLabel.TextColor3 = Color3.fromRGB(255, 200, 50)
		end
		if ActionLabel then ActionLabel.Text = "[E] OPEN" end
		if Glow then Glow.ImageColor3 = Color3.fromRGB(255, 200, 50) end
		
	elseif crateType == "CoinCrate" then
		if CrateLabel then 
			CrateLabel.Text = "CREATIVE CRATE" 
			CrateLabel.TextColor3 = Color3.fromRGB(100, 200, 255) -- Blue
		end
		if PriceLabel then 
			PriceLabel.Text = COIN_CRATE_COST .. " COINS" 
			PriceLabel.TextColor3 = Color3.fromRGB(100, 200, 255)
		end
		if ActionLabel then ActionLabel.Text = "[E] OPEN" end
		if Glow then Glow.ImageColor3 = Color3.fromRGB(100, 200, 255) end
		
	else
		-- Unknown crate type
		if CrateLabel then CrateLabel.Text = "MYSTERY CRATE" end
		if PriceLabel then PriceLabel.Text = "???" end
		if ActionLabel then ActionLabel.Text = "[E] OPEN" end
	end
end

-- ── Helper: Get device-specific action text ──
local function getActionText()
	if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then
		return "TAP TO OPEN"
	elseif UserInputService.GamepadEnabled then
		return "[A] OPEN"
	else
		return "[E] OPEN"
	end
end

-- ── Helper: Get crate type from prompt ──
local function getCrateTypeFromPrompt(prompt)
	-- Walk up the hierarchy to find the podium
	local promptHitch = prompt.Parent
	if not promptHitch then return "CoinCrate" end
	
	local parentPart = promptHitch.Parent
	if not parentPart then return "CoinCrate" end
	
	local modelContainer = parentPart.Parent
	if not modelContainer then return "CoinCrate" end
	
	local podium = modelContainer.Parent
	if not podium then return "CoinCrate" end
	
	-- Check CrateType attribute or name
	local crateType = podium:GetAttribute("CrateType")
	if crateType then return crateType end
	
	-- Fallback: check podium name
	if podium.Name == "RobuxGachaCratePodium" then
		return "RobuxCrate"
	end
	
	return "CoinCrate"
end

-- ── Show prompt with animation ──
local function showPrompt(prompt)
	currentPrompt = prompt
	
	local crateType = getCrateTypeFromPrompt(prompt)
	updatePromptUI(crateType)
	
	-- Update action text for device
	if ActionLabel then
		ActionLabel.Text = getActionText()
	end
	
	-- Animate in
	PromptContainer.Visible = true
	PromptContainer.Size = UDim2.new(0, 0, 0, 0)
	PromptContainer.Position = UDim2.new(0.5, 0, 0.85, 0)
	
	TweenService:Create(PromptContainer, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Size = UDim2.new(0, 300, 0, 100),
		Position = UDim2.new(0.5, -150, 0.85, -50)
	}):Play()
end

-- ── Hide prompt with animation ──
local function hidePrompt()
	TweenService:Create(PromptContainer, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.In), {
		Size = UDim2.new(0, 0, 0, 0),
		Position = UDim2.new(0.5, 0, 0.85, 0)
	}):Play()
	
	task.delay(0.2, function()
		PromptContainer.Visible = false
	end)
	
	currentPrompt = nil
	currentCrateType = nil
end

-- ── Listen for prompts being triggered ──
local function onPromptTriggered(prompt, inputType)
	if not prompt or prompt.Name ~= "CratePrompt" then return end
	
	local crateType = getCrateTypeFromPrompt(prompt)
	
	-- Fire purchase request to server
	CratePurchaseRequest:FireServer(crateType)
	
	hidePrompt()
	
	print("[CRATE_PROMPT] Player triggered " .. crateType .. " purchase")
end

-- ── Connect to ProximityPromptService ──
ProximityPromptService.PromptShown:Connect(function(prompt)
	if prompt.Style == Enum.ProximityPromptStyle.Custom and prompt.Name == "CratePrompt" then
		showPrompt(prompt)
	end
end)

ProximityPromptService.PromptHidden:Connect(function(prompt)
	if prompt == currentPrompt then
		hidePrompt()
	end
end)

ProximityPromptService.PromptTriggered:Connect(function(prompt, playerWhoTriggered)
	if playerWhoTriggered ~= player then return end
	onPromptTriggered(prompt)
end)

-- ── Handle input for custom prompts ──
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	
	-- E key or A button on gamepad
	if input.KeyCode == Enum.KeyCode.E or input.KeyCode == Enum.KeyCode.ButtonA then
		if currentPrompt then
			onPromptTriggered(currentPrompt, input.KeyCode)
		end
	end
end)

print("[CRATE_PROMPT] CratePromptController initialized")