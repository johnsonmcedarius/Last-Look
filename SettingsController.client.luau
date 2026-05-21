-- ─────────────────────────────────────────────────────────────────────────────
-- SettingsController: Handles user preferences and UI logic
-- ─────────────────────────────────────────────────────────────────────────────

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local PlayerGui = player:WaitForChild("PlayerGui")
local SettingsMenu = PlayerGui:WaitForChild("SettingsMenu")
local MainFrame = SettingsMenu:WaitForChild("MainFrame")
local Scroll = MainFrame:WaitForChild("SettingsList")

local ToggleTemplate = Scroll:WaitForChild("ToggleTemplate")
local SliderTemplate = Scroll:WaitForChild("SliderTemplate")

-- ── Settings State ──
local currentSettings = {
	MasterVolume = 1,
	MusicEnabled = true,
	SFXEnabled = true,
	CameraShake = 0.5,
}

-- ── Helpers ──
local function updateToggle(frame, enabled)
	local btn = frame:WaitForChild("ToggleButton")
	local dot = btn:WaitForChild("Dot")
	
	local targetPos = enabled and UDim2.new(1, -3, 0.5, 0) or UDim2.new(0, 3, 0.5, 0)
	local targetColor = enabled and Color3.fromRGB(100, 200, 100) or Color3.fromRGB(100, 100, 100)
	local dotAnchor = enabled and Vector2.new(1, 0.5) or Vector2.new(0, 0.5)
	
	dot.AnchorPoint = dotAnchor
	
	TweenService:Create(dot, TweenInfo.new(0.2), {Position = targetPos}):Play()
	TweenService:Create(btn, TweenInfo.new(0.2), {BackgroundColor3 = targetColor}):Play()
end

local function updateSlider(frame, value)
	local bar = frame:WaitForChild("Bar")
	local fill = bar:WaitForChild("Fill")
	local knob = bar:WaitForChild("Knob")
	
	fill.Size = UDim2.new(value, 0, 1, 0)
	knob.Position = UDim2.new(value, 0, 0.5, 0)
end

-- ── Build Rows ──
local function addToggle(name, labelText, default)
	local row = ToggleTemplate:Clone()
	row.Name = name
	row.Label.Text = labelText
	row.Visible = true
	row.Parent = Scroll
	
	updateToggle(row, default)
	
	row.ToggleButton.MouseButton1Click:Connect(function()
		currentSettings[name] = not currentSettings[name]
		updateToggle(row, currentSettings[name])
		print("[SETTINGS] " .. name .. " set to " .. tostring(currentSettings[name]))
		-- Save to server/attributes
		player:SetAttribute(name, currentSettings[name])
	end)
end

local function addSlider(name, labelText, default)
	local row = SliderTemplate:Clone()
	row.Name = name
	row.Label.Text = labelText
	row.Visible = true
	row.Parent = Scroll
	
	updateSlider(row, default)
	
	local knob = row.Bar.Knob
	local bar = row.Bar
	local isDragging = false
	
	local function update(input)
		local x = math.clamp((input.Position.X - bar.AbsolutePosition.X) / bar.AbsoluteSize.X, 0, 1)
		currentSettings[name] = x
		updateSlider(row, x)
		player:SetAttribute(name, x)
	end
	
	knob.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			isDragging = true
		end
	end)
	
	game:GetService("UserInputService").InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			isDragging = false
		end
	end)
	
	game:GetService("UserInputService").InputChanged:Connect(function(input)
		if isDragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			update(input)
		end
	end)
end

-- ── Initialization ──
addSlider("MasterVolume", "Master Volume", currentSettings.MasterVolume)
addToggle("MusicEnabled", "Music Enabled", currentSettings.MusicEnabled)
addToggle("SFXEnabled", "SFX Enabled", currentSettings.SFXEnabled)
addSlider("CameraShake", "Camera Shake Intensity", currentSettings.CameraShake)

print("[SETTINGS] SettingsController initialized")
