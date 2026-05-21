-- ─────────────────────────────────────────────────────────────────────────────
-- MetaMenusController: Handles AbilityMarketplace and PromoCodesModule
-- References physical UI in StarterGui.MetaMenus
-- ─────────────────────────────────────────────────────────────────────────────

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService      = game:GetService("TweenService")
local UserInputService  = game:GetService("UserInputService")

local player = Players.LocalPlayer
local PlayerGui = player:WaitForChild("PlayerGui")

-- ── Reference Physical UI ──
local screenGui = PlayerGui:WaitForChild("MetaMenus", 5)
if not screenGui then
	warn("[METAMENUS] MetaMenus ScreenGui not found!")
	return
end

local abilityMarketplace = screenGui:FindFirstChild("AbilityMarketplace")
local promoCodesModule = screenGui:FindFirstChild("PromoCodesModule")

-- AbilityMarketplace elements
local gachaCrateFrame       = abilityMarketplace and abilityMarketplace:FindFirstChild("GachaCrateFrame")
local slotUnlockPanel       = abilityMarketplace and abilityMarketplace:FindFirstChild("SlotUnlockPanel")
local robloxPlusBanner      = abilityMarketplace and abilityMarketplace:FindFirstChild("RobloxPlusBanner")
local closeMarketplaceButton = abilityMarketplace and abilityMarketplace:FindFirstChild("CloseButton")

-- ── Remotes ──
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local CratePurchaseRequest = Remotes:WaitForChild("CratePurchaseRequest")
local OpenMarketplace = Remotes:WaitForChild("OpenMarketplace")
local PromoCodeResult = Remotes:WaitForChild("PromoCodeResult")
local RedeemCode = Remotes:WaitForChild("RedeemCode")
local TriggerUnboxing = Remotes:WaitForChild("TriggerUnboxing")

-- ── Modular Crate Buttons (built from CrateRegistry, not hardcoded) ──────────
local CrateRegistry = require(ReplicatedStorage:WaitForChild("CrateRegistry"))

local function buildCrateButtons()
	if not gachaCrateFrame then return end

	local template = gachaCrateFrame:FindFirstChild("CrateButtonTemplate")
	if not template then
		warn("[METAMENUS] CrateButtonTemplate missing from GachaCrateFrame!")
		return
	end

	-- Clear any previously built buttons (keep template + layout)
	for _, child in ipairs(gachaCrateFrame:GetChildren()) do
		if child:IsA("TextButton") and child.Name ~= "CrateButtonTemplate" then
			child:Destroy()
		end
	end

	for _, crate in ipairs(CrateRegistry.GetAll()) do
		local btn = template:Clone()
		btn.Name        = crate.id
		btn.LayoutOrder = crate.order or 99
		btn.Visible     = true

		-- Labels
		local nameLabel  = btn:FindFirstChild("CrateNameLabel")
		local priceLabel = btn:FindFirstChild("PriceLabel")
		local stroke     = btn:FindFirstChild("UIStroke")

		if nameLabel  then nameLabel.Text  = crate.label end
		if priceLabel then priceLabel.Text = crate.price  end
		if stroke     then stroke.Color    = crate.color or Color3.fromRGB(212, 175, 55) end

		-- Wire purchase request
		btn.MouseButton1Click:Connect(function()
			CratePurchaseRequest:FireServer(crate.id)
			closeMarketplace()
		end)

		btn.Parent = gachaCrateFrame
	end
end

-- PromoCodesModule elements
local codeTextBox = promoCodesModule and promoCodesModule:FindFirstChild("CodeTextBox")
local claimButton = promoCodesModule and promoCodesModule:FindFirstChild("ClaimButton")

-- ── Remotes ──
-- (Moved up)

-- ── State ──
-- local isMarketplaceOpen = false
-- local isPromoOpen = false

-- ── Open/Close logic owned by HUDModule_MetaMenus (via _G.MetaMenus) ─────────
-- Use: _G.MetaMenus.OpenMarketplace() / .CloseMarketplace() etc.
-- These stubs are kept as thin delegates so existing call sites don't break.
local function openMarketplace()
	if _G.MetaMenus then _G.MetaMenus.OpenMarketplace() end
end

local function closeMarketplace()
	if _G.MetaMenus then _G.MetaMenus.CloseMarketplace() end
end

local function openPromoCodes()
	if _G.MetaMenus then _G.MetaMenus.OpenPromoCodes() end
end

local function closePromoCodes()
	if _G.MetaMenus then _G.MetaMenus.ClosePromoCodes() end
end

local function submitPromoCode()
	if not codeTextBox then return end
	
	local code = codeTextBox.Text
	if code == "" then return end
	
	-- Send to server
	RedeemCode:FireServer(code)
	
	-- Clear and close
	codeTextBox.Text = ""
end

-- ── Button Connections ──
-- CloseButton on AbilityMarketplace delegates to HUDModule_MetaMenus
if closeMarketplaceButton then
	closeMarketplaceButton.MouseButton1Click:Connect(closeMarketplace)
end

-- Crate buttons are wired dynamically inside buildCrateButtons() above

if claimButton then
	claimButton.MouseButton1Click:Connect(submitPromoCode)
end

if codeTextBox then
	-- Handle Enter key press
	codeTextBox.FocusLost:Connect(function(enterPressed)
		if enterPressed then
			submitPromoCode()
		end
	end)
end

-- ── Remote Listeners ──

-- PromoCodeResult: close modal on success; ShopUIHelper shows CodeResultLabel feedback
if PromoCodeResult then
	PromoCodeResult.OnClientEvent:Connect(function(success, message)
		if success then
			closePromoCodes()
		end
	end)
end

-- OpenMarketplace: server or other scripts trigger the marketplace to open
if OpenMarketplace then
	OpenMarketplace.OnClientEvent:Connect(function()
		openMarketplace()
	end)
end

-- ── Keyboard shortcuts handled by UITransitionController ──

-- Build modular crate buttons from registry
buildCrateButtons()

print("[METAMENUS] MetaMenusController initialized")