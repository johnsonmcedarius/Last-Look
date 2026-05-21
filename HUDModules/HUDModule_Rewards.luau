local HUDModule_Rewards = {}

function HUDModule_Rewards.Init(screenGui, remotes, SoundService)
	local ShowRewardPopup    = remotes:WaitForChild("ShowRewardPopup")
	local GlobalAnnouncement = remotes:WaitForChild("GlobalAnnouncement")
	local GiftReceived       = remotes:WaitForChild("GiftReceived")
	local TweenService       = game:GetService("TweenService")

	local queue  = {}
	local active = false

	local function getFrame(name)
		return screenGui:FindFirstChild(name, true)
	end

	local function showNext()
		if active or #queue == 0 then return end
		active = true

		local data   = table.remove(queue, 1)
		local popup  = getFrame("RewardPopup")
		if not popup then active = false showNext() return end

		popup.Text     = data.xpText .. "  " .. data.coinsText
		popup.Visible  = true
		popup.TextTransparency = 0
		popup.Position = UDim2.new(0.5, 0, 0.4, 0)

		TweenService:Create(popup, TweenInfo.new(1.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Position         = UDim2.new(0.5, 0, 0.28, 0),
			TextTransparency = 1,
		}):Play()

		task.delay(1.3, function()
			popup.Visible = false
			active = false
			showNext()
		end)
	end

	ShowRewardPopup.OnClientEvent:Connect(function(xpText, coinsText)
		table.insert(queue, {xpText = xpText, coinsText = coinsText})
		showNext()
	end)

	GlobalAnnouncement.OnClientEvent:Connect(function(message)
		local banner = getFrame("GlobalAnnouncementBanner")
		if not banner then return end
		local label = banner:FindFirstChildOfClass("TextLabel")
		if label then label.Text = message end
		banner.Visible = true
		SoundService.PlayLocal("ShowstopperReady")
		task.delay(5, function()
			TweenService:Create(banner, TweenInfo.new(0.5), {BackgroundTransparency = 1}):Play()
			task.delay(0.6, function() banner.Visible = false end)
		end)
	end)

	GiftReceived.OnClientEvent:Connect(function(senderName, itemType)
		local banner = getFrame("GiftBanner")
		if not banner then return end
		local label = banner:FindFirstChildOfClass("TextLabel")
		if label then label.Text = senderName .. " sent you a " .. itemType .. "!" end
		banner.Visible = true
		task.delay(4, function() banner.Visible = false end)
	end)
end

return HUDModule_Rewards