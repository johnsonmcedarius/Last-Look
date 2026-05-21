-- ─────────────────────────────────────────────────────────────────────────────
-- UINavigationController: Centralized UI Navigation & Menu Management
-- ─────────────────────────────────────────────────────────────────────────────

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService      = game:GetService("TweenService")
local UserInputService  = game:GetService("UserInputService")

local player = Players.LocalPlayer
local PlayerGui = player:WaitForChild("PlayerGui")

-- ── Menus Configuration ──────────────────────────────────────────────────────
local Menus = {
	Shop = {
		Gui = PlayerGui:WaitForChild("ShopMenu"),
		Frame = PlayerGui.ShopMenu:WaitForChild("ShopFrame"),
	},
	Inventory = {
		Gui = PlayerGui:WaitForChild("InventoryMenu"),
		Frame = PlayerGui.InventoryMenu:WaitForChild("MainWrapper"),
	},
	Lookbook = {
		Gui = PlayerGui:WaitForChild("DailyLookbook"),
		Frame = PlayerGui.DailyLookbook:WaitForChild("MainModal"),
	},
	Marketplace = {
		Gui = PlayerGui:WaitForChild("MetaMenus"),
		Frame = PlayerGui.MetaMenus:WaitForChild("AbilityMarketplace"),
	},
	Promo = {
		Gui = PlayerGui:WaitForChild("MetaMenus"),
		Frame = PlayerGui.MetaMenus:WaitForChild("PromoCodesModule"),
	},
	Quests = {
		Gui = PlayerGui:WaitForChild("QuestMenu"),
		Frame = PlayerGui.QuestMenu:WaitForChild("MainFrame"),
	},
	Settings = {
		Gui = PlayerGui:WaitForChild("SettingsMenu"),
		Frame = PlayerGui.SettingsMenu:WaitForChild("MainFrame"),
	}
}

-- ── Animation Settings ────────────────────────────────────────────────────────
local TWEEN_INFO = TweenInfo.new(0.35, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
local SLIDE_OFFSET = 50 -- Pixels to slide up/down

-- ── State ─────────────────────────────────────────────────────────────────────
local activeMenu = nil
local isAnimating = false
local debounceTime = 0.5
local lastClickTime = 0

-- ── Store original/resting positions for each menu (prevents sliding bug) ────
local REST_POSITIONS = {}

local function storeRestPositions()
	for menuName, menu in pairs(Menus) do
		if menu.Frame then
			REST_POSITIONS[menuName] = menu.Frame.Position
		end
	end
end

-- ── Helpers ───────────────────────────────────────────────────────────────────
local function setCanvasAlpha(frame, alpha)
	local canvasGroup = frame:FindFirstChildWhichIsA("CanvasGroup")
	if canvasGroup then
		canvasGroup.GroupTransparency = 1 - alpha
	else
		-- Fallback: If no CanvasGroup, just set the main frame's transparency
		frame.BackgroundTransparency = 1 - alpha
		for _, child in ipairs(frame:GetDescendants()) do
			if child:IsA("GuiObject") then
				if child:IsA("TextLabel") or child:IsA("TextButton") or child:IsA("TextBox") then
					child.TextTransparency = 1 - alpha
				end
				if child:IsA("ImageLabel") or child:IsA("ImageButton") then
					child.ImageTransparency = 1 - alpha
				end
				if child:IsA("UIStroke") then
					child.Transparency = 1 - alpha
				end
			end
		end
	end
end

-- ── Core Logic ────────────────────────────────────────────────────────────────
local function closeMenu(menuName, silent)
	local menu = Menus[menuName]
	if not menu or not menu.Frame.Visible then return end
	
	if silent then
		menu.Frame.Visible = false
		-- Only disable ScreenGui if no other frames in it are visible
		local otherVisible = false
		for _, m in pairs(Menus) do
			if m.Gui == menu.Gui and m.Frame.Visible then
				otherVisible = true
				break
			end
		end
		if not otherVisible then
			menu.Gui.Enabled = false
		end
		if activeMenu == menuName then activeMenu = nil end
		return
	end

	-- Use stored rest position to prevent sliding bug
	local targetPos = REST_POSITIONS[menuName] or menu.Frame.Position
	local hiddenPos = UDim2.new(targetPos.X.Scale, targetPos.X.Offset, targetPos.Y.Scale, targetPos.Y.Offset + SLIDE_OFFSET)
	
	isAnimating = true
	
	-- We'll use a NumberValue to tween the alpha
	local alphaVal = Instance.new("NumberValue")
	alphaVal.Value = 1
	alphaVal.Changed:Connect(function(val)
		setCanvasAlpha(menu.Frame, val)
	end)
	
	local tween = TweenService:Create(menu.Frame, TWEEN_INFO, {
		Position = hiddenPos,
	})
	
	local alphaTween = TweenService:Create(alphaVal, TWEEN_INFO, {Value = 0})
	
	tween:Play()
	alphaTween:Play()
	
	tween.Completed:Connect(function()
		menu.Frame.Visible = false
		-- Only disable ScreenGui if no other frames in it are visible
		local otherVisible = false
		for _, m in pairs(Menus) do
			if m.Gui == menu.Gui and m.Frame.Visible then
				otherVisible = true
				break
			end
		end
		if not otherVisible then
			menu.Gui.Enabled = false
		end
		
		if activeMenu == menuName then activeMenu = nil end
		isAnimating = false
		alphaVal:Destroy()
	end)
end

local function openMenu(menuName)
	if isAnimating then return end
	
	-- Close active menu if it's different
	if activeMenu and activeMenu ~= menuName then
		closeMenu(activeMenu, true) -- Close instantly to avoid overlap
	end
	
	local menu = Menus[menuName]
	if not menu then return end
	
	-- Toggle off if already open
	if activeMenu == menuName then
		closeMenu(menuName)
		return
	end
	
	activeMenu = menuName
	isAnimating = true
	
	-- Use stored rest position to prevent sliding bug
	local targetPos = REST_POSITIONS[menuName] or menu.Frame.Position
	local startPos = UDim2.new(targetPos.X.Scale, targetPos.X.Offset, targetPos.Y.Scale, targetPos.Y.Offset + SLIDE_OFFSET)
	
	menu.Frame.Position = startPos
	menu.Frame.Visible = true
	setCanvasAlpha(menu.Frame, 0)
	menu.Gui.Enabled = true
	
	-- Ensure other frames in the same Gui are hidden
	for _, m in pairs(Menus) do
		if m.Gui == menu.Gui and m.Frame ~= menu.Frame then
			m.Frame.Visible = false
		end
	end
	
	-- Fade and Slide In
	local alphaVal = Instance.new("NumberValue")
	alphaVal.Value = 0
	alphaVal.Changed:Connect(function(val)
		setCanvasAlpha(menu.Frame, val)
	end)
	
	local tween = TweenService:Create(menu.Frame, TWEEN_INFO, {
		Position = targetPos,
	})
	
	local alphaTween = TweenService:Create(alphaVal, TWEEN_INFO, {Value = 1})
	
	tween:Play()
	alphaTween:Play()
	
	tween.Completed:Connect(function()
		isAnimating = false
		alphaVal:Destroy()
	end)
end

local function closeAll()
	if activeMenu then
		closeMenu(activeMenu)
	end
end

-- ── Button Wiring ─────────────────────────────────────────────────────────────
local function wireButtons()
	local lobbyHUD = PlayerGui:WaitForChild("LobbyHUD")
	local nav = lobbyHUD:WaitForChild("BottomNav"):WaitForChild("ButtonContainer")
	
	local mappings = {
		Btn_Shop = "Shop",
		Btn_Inventory = "Inventory",
		Btn_Codes = "Promo",
		Btn_Quests = "Quests",
		Btn_Settings = "Settings"
	}
	
	for btnName, menuName in pairs(mappings) do
		local btn = nav:FindFirstChild(btnName)
		if btn and menuName then
			btn.MouseButton1Click:Connect(function()
				local now = tick()
				if now - lastClickTime < debounceTime then return end
				lastClickTime = now
				
				openMenu(menuName)
			end)
		end
	end
	
	-- Wire DailyLookbookButton
	local lookbookBtn = lobbyHUD:FindFirstChild("DailyLookbookButton")
	if lookbookBtn then
		lookbookBtn.MouseButton1Click:Connect(function()
			local now = tick()
			if now - lastClickTime < debounceTime then return end
			lastClickTime = now
			
			openMenu("Lookbook")
		end)
	end
	
	-- Wire internal close buttons
	for _, menu in pairs(Menus) do
		local closeBtn = menu.Frame:FindFirstChild("CloseButton", true)
		if closeBtn then
			closeBtn.MouseButton1Click:Connect(function()
				closeMenu(activeMenu)
			end)
		end
	end
end

-- ── Failsafe Listeners ────────────────────────────────────────────────────────
local function setupFailsafes()
	-- Reset/Death
	player.CharacterAdded:Connect(function()
		closeAll()
	end)
	
	-- Match Start
	local Remotes = ReplicatedStorage:WaitForChild("Remotes")
	local MatchStart = Remotes:WaitForChild("MatchStart")
	
	MatchStart.OnClientEvent:Connect(function()
		closeAll()
	end)
	
	-- Elimination Event
	local PlayerEliminated = Remotes:FindFirstChild("PlayerEliminated")
	if PlayerEliminated then
		PlayerEliminated.OnClientEvent:Connect(function(eliminatedPlayer)
			if eliminatedPlayer == player then
				closeAll()
			end
		end)
	end
end

-- ── Initialization ──
for _, menu in pairs(Menus) do
	menu.Frame.Visible = false
end

-- Store original positions before any animations
storeRestPositions()

wireButtons()
setupFailsafes()

-- ── Keyboard Shortcuts (REMOVED) ──
-- ...

-- Export closeAll to a global helper
_G.CloseAllMenus = closeAll

print("[NAVIGATION] UINavigationController initialized")
