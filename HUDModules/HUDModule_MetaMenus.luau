-- ─────────────────────────────────────────────────────────────────────────────
-- HUDModule_MetaMenus
-- Manages AbilityMarketplace and PromoCodesModule inside MetaMenus ScreenGui.
-- Called by HUDController:  MetaMenusModule.Init(metaMenusGui, remotes, ss)
--
-- NOTE: MetaMenusController delegates open/close to this module via
--   _G.MetaMenus (set at bottom of Init). Other scripts call:
--   _G.MetaMenus.OpenMarketplace() / .CloseMarketplace() etc.
-- ─────────────────────────────────────────────────────────────────────────────

local HUDModule_MetaMenus = {}

local TweenService = game:GetService("TweenService")
local Players      = game:GetService("Players")

local POP_IN  = TweenInfo.new(0.32, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local POP_OUT = TweenInfo.new(0.20, Enum.EasingStyle.Back, Enum.EasingDirection.In)

function HUDModule_MetaMenus.Init(screenGui, remotes, soundService)

	-- ── UI refs ───────────────────────────────────────────────────────────────
	local abilityMarketplace = screenGui:FindFirstChild("AbilityMarketplace")
	local promoCodesModule   = screenGui:FindFirstChild("PromoCodesModule")

	-- ── State ─────────────────────────────────────────────────────────────────
	local isMarketplaceOpen = false
	local isPromoOpen       = false

	-- ── Helpers ───────────────────────────────────────────────────────────────
	local function playSound(key)
		if soundService and soundService.PlayLocal then
			soundService.PlayLocal(key, 0.85)
		end
	end

	-- popIn: panel grows from 0.95 → 1 anchored from its center.
	-- NEVER touches Position — stays exactly where designer placed it in Studio.
	-- restSize / restPos are the values captured from the physical frame at Init time.
	local function popIn(panel, restSize, restPos)
		-- Hard-reset to rest position first (in case a previous popOut left residue)
		panel.Position               = restPos
		panel.Size                   = UDim2.new(restSize.X.Scale * 0.95, restSize.X.Offset,
		                                          restSize.Y.Scale * 0.95, restSize.Y.Offset)
		panel.BackgroundTransparency = 0.5
		panel.Visible                = true
		TweenService:Create(panel, POP_IN, {
			Size                   = restSize,
			BackgroundTransparency = 0,
		}):Play()
	end

	-- popOut: panel shrinks to 0.95 + fades, then hard-resets to rest size/pos.
	-- Position is NEVER modified — only Size and Transparency animate.
	local function popOut(panel, restSize, restPos, callback)
		local shrinkSize = UDim2.new(restSize.X.Scale * 0.95, restSize.X.Offset,
		                              restSize.Y.Scale * 0.95, restSize.Y.Offset)
		TweenService:Create(panel, POP_OUT, {
			Size                   = shrinkSize,
			BackgroundTransparency = 0.8,
		}):Play()
		task.delay(POP_OUT.Time + 0.05, function()
			panel.Visible                = false
			-- Hard-reset: always return to exact rest values so next open is clean
			panel.Size                   = restSize
			panel.Position               = restPos
			panel.BackgroundTransparency = 0
			if callback then callback() end
		end)
	end

	-- ── AbilityMarketplace ────────────────────────────────────────────────────
	-- Rest size/pos: defined by the physical frame in StarterGui
	-- We read them once at init so designer can adjust in Studio freely
	local MARKET_REST_SIZE = abilityMarketplace and abilityMarketplace.Size
	local MARKET_REST_POS  = abilityMarketplace and abilityMarketplace.Position
	if abilityMarketplace then abilityMarketplace.Visible = false end

	function HUDModule_MetaMenus.OpenMarketplace()
		if isMarketplaceOpen or not abilityMarketplace then return end
		isMarketplaceOpen = true
		screenGui.Enabled = true
		popIn(abilityMarketplace, MARKET_REST_SIZE, MARKET_REST_POS)
		playSound("UI_OpenPanel")
	end

	function HUDModule_MetaMenus.CloseMarketplace()
		if not isMarketplaceOpen or not abilityMarketplace then return end
		popOut(abilityMarketplace, MARKET_REST_SIZE, MARKET_REST_POS, function()
			isMarketplaceOpen = false
			if not isPromoOpen then screenGui.Enabled = false end
		end)
		playSound("UI_Close")
	end

	function HUDModule_MetaMenus.ToggleMarketplace()
		if isMarketplaceOpen then
			HUDModule_MetaMenus.CloseMarketplace()
		else
			HUDModule_MetaMenus.OpenMarketplace()
		end
	end

	-- ── PromoCodesModule ──────────────────────────────────────────────────────
	local PROMO_REST_SIZE = promoCodesModule and promoCodesModule.Size
	local PROMO_REST_POS  = promoCodesModule and promoCodesModule.Position
	if promoCodesModule then promoCodesModule.Visible = false end

	function HUDModule_MetaMenus.OpenPromoCodes()
		if isPromoOpen or not promoCodesModule then return end
		isPromoOpen = true
		screenGui.Enabled = true
		popIn(promoCodesModule, PROMO_REST_SIZE, PROMO_REST_POS)
		playSound("UI_OpenPanel")
		-- Focus text box after pop-in settles
		task.delay(POP_IN.Time + 0.05, function()
			local tb = promoCodesModule:FindFirstChild("CodeTextBox")
			if tb then tb:CaptureFocus() end
		end)
	end

	function HUDModule_MetaMenus.ClosePromoCodes()
		if not isPromoOpen or not promoCodesModule then return end
		local tb = promoCodesModule:FindFirstChild("CodeTextBox")
		if tb then tb.Text = "" end
		popOut(promoCodesModule, PROMO_REST_SIZE, PROMO_REST_POS, function()
			isPromoOpen = false
			if not isMarketplaceOpen then screenGui.Enabled = false end
		end)
		playSound("UI_Close")
	end

	function HUDModule_MetaMenus.TogglePromoCodes()
		if isPromoOpen then
			HUDModule_MetaMenus.ClosePromoCodes()
		else
			HUDModule_MetaMenus.OpenPromoCodes()
		end
	end

	function HUDModule_MetaMenus.SubmitPromoCode(code)
		if not code or code == "" then return end
		local RedeemCode = remotes:FindFirstChild("RedeemCode")
		if RedeemCode then RedeemCode:FireServer(code) end
		-- Close the modal after submit — server response (PromoCodeResult) handles
		-- success/failure feedback via CodeResultLabel
		HUDModule_MetaMenus.ClosePromoCodes()
		playSound("UI_Claim")
	end

	-- ── Slot prices + banner ──────────────────────────────────────────────────
	function HUDModule_MetaMenus.UpdateSlotPrices(slot2Price, slot3Price)
		if not abilityMarketplace then return end
		local panel = abilityMarketplace:FindFirstChild("SlotUnlockPanel")
		if not panel then return end
		for slotIdx, price in ipairs({slot2Price, slot3Price}) do
			local slot = panel:FindFirstChild("Slot" .. (slotIdx + 1) .. "Unlock")
			if slot then
				local lbl = slot:FindFirstChild("PriceLabel")
				if lbl then lbl.Text = tostring(price) .. " Coins" end
			end
		end
	end

	function HUDModule_MetaMenus.SetBannerVisible(visible)
		if not abilityMarketplace then return end
		local banner = abilityMarketplace:FindFirstChild("RobloxPlusBanner")
		if banner then banner.Visible = visible end
	end

	function HUDModule_MetaMenus.IsOpen()
		return isMarketplaceOpen or isPromoOpen
	end

	-- ── Global accessor — lets MetaMenusController + LobbyHUD buttons delegate here
	_G.MetaMenus = HUDModule_MetaMenus

end

return HUDModule_MetaMenus
