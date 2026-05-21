local HUDModule_Banners = {}

function HUDModule_Banners.Init(screenGui, remotes, SoundService, player)
	local TweenService = game:GetService("TweenService")

	local TrendTrackerActivate = remotes:WaitForChild("TrendTrackerActivate")
	local Show75Warning        = remotes:WaitForChild("Show75Warning")
	local ShowstopperAnnounce  = remotes:WaitForChild("ShowstopperAnnounce")
	local ShowCancelledBanner  = remotes:WaitForChild("ShowCancelledBanner")
	local SabotagePing         = remotes:WaitForChild("SabotagePing")
	local PlayerEliminated     = remotes:WaitForChild("PlayerEliminated")

	local StatusValues = game:GetService("ReplicatedStorage"):WaitForChild("StatusValues")
	local StatusText   = StatusValues:WaitForChild("StatusText")

	local function getFrame(name)
		return screenGui:FindFirstChild(name, true)
	end

	local function flashBanner(bannerName, duration, color)
		local banner = getFrame(bannerName)
		if not banner then return end
		banner.Visible = true
		if color then banner.BackgroundColor3 = color end
		for i = 0, 2 do
			task.delay(i * 0.5, function()
				TweenService:Create(banner, TweenInfo.new(0.15), {BackgroundTransparency = 0}):Play()
				task.delay(0.2, function()
					TweenService:Create(banner, TweenInfo.new(0.25), {BackgroundTransparency = 0.6}):Play()
				end)
			end)
		end
		task.delay(duration, function()
			TweenService:Create(banner, TweenInfo.new(0.5), {BackgroundTransparency = 1}):Play()
			task.delay(0.6, function() banner.Visible = false end)
		end)
	end

	-- Role reveal
	local roleRevealShown = false
	StatusText:GetPropertyChangedSignal("Value"):Connect(function()
		local val = StatusText.Value
		if not roleRevealShown and val:find("Game Starting") then
			roleRevealShown = true
			local frame = getFrame("RoleRevealFrame")
			local label = getFrame("RoleLabel")
			if frame and label and player.Team then
				if player.Team.Name == "Critics" then
					label.Text = "YOU ARE A CRITIC"
					label.TextColor3 = Color3.fromRGB(255, 60, 60)
					SoundService.PlayLocal("RoleRevealCritic")
				elseif player.Team.Name == "Designers" then
					label.Text = "YOU ARE A DESIGNER"
					label.TextColor3 = Color3.fromRGB(80, 200, 255)
					SoundService.PlayLocal("RoleRevealDesigner")
				end
				frame.Visible = true
				TweenService:Create(frame, TweenInfo.new(0.5), {BackgroundTransparency = 0}):Play()
				task.delay(2.5, function()
					TweenService:Create(frame, TweenInfo.new(0.6), {BackgroundTransparency = 1}):Play()
					task.delay(0.7, function() frame.Visible = false end)
				end)
			end
		end
		if val == "Intermission" or val == "Round Over!" then
			roleRevealShown = false
		end
	end)

	-- Trend Tracker banner
	TrendTrackerActivate.OnClientEvent:Connect(function(duration)
		SoundService.PlayLocal("TrendTrackerOn")
		flashBanner("TrendTrackerBanner", duration, Color3.fromRGB(255, 50, 150))
	end)

	-- 75% warning
	Show75Warning.OnClientEvent:Connect(function()
		SoundService.PlayLocal("TrendTrackerWarning")
		flashBanner("WarningBanner", 4, Color3.fromRGB(255, 60, 0))
	end)

	-- Showstopper announce slide-in banner
	ShowstopperAnnounce.OnClientEvent:Connect(function(playerName, title, message)
		local banner = getFrame("ShowstopperAnnounceBanner")
		if not banner then return end
		local label = banner:FindFirstChildOfClass("TextLabel")
		if label then label.Text = message end

		-- Slide in from top
		banner.Position = UDim2.new(0.5, 0, -0.1, 0)
		banner.Visible  = true
		TweenService:Create(banner, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Position = UDim2.new(0.5, 0, 0.05, 0)
		}):Play()

		SoundService.PlayLocal("ShowstopperActivate")

		task.delay(4, function()
			TweenService:Create(banner, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
				Position = UDim2.new(0.5, 0, -0.1, 0)
			}):Play()
			task.delay(0.5, function() banner.Visible = false end)
		end)
	end)

	-- Cancelled banner
	ShowCancelledBanner.OnClientEvent:Connect(function(cancelledName, message)
		local banner = getFrame("EliminationBanner")
		if not banner then return end
		local label = banner:FindFirstChildOfClass("TextLabel")
		if label then label.Text = message end
		banner.Visible = true
		TweenService:Create(banner, TweenInfo.new(0.3), {BackgroundTransparency = 0}):Play()
		task.delay(3, function()
			TweenService:Create(banner, TweenInfo.new(0.6), {BackgroundTransparency = 1}):Play()
			task.delay(0.7, function() banner.Visible = false end)
		end)
	end)

	-- Sabotage announce - dramatic global announcement
	local SabotageAnnounce = remotes:WaitForChild("SabotageAnnounce")
	SabotageAnnounce.OnClientEvent:Connect(function(teamName, objectName, message)
		-- Only show to the affected team
		if not (player.Team and player.Team.Name == teamName) then return end
		
		-- Flash dramatic banner
		SoundService.PlayLocal("PaparazziStorm")
		flashBanner("SabotagePingBanner", 4, Color3.fromRGB(255, 0, 80))
		
		-- Update banner text
		local banner = getFrame("SabotagePingBanner")
		if banner then
			local label = banner:FindFirstChildOfClass("TextLabel")
			if label then label.Text = message end
		end
	end)

	-- Sabotage ping - now receives (object, sabotagedTeam, objectName)
	-- Only show to the AFFECTED team
	SabotagePing.OnClientEvent:Connect(function(object, sabotagedTeam, objectName)
		if not (player.Team and player.Team.Name == sabotagedTeam) then return end
		
		-- Team-specific messages
		local message = sabotagedTeam == "Designers" 
			and "YOUR COLLECTION IS COMPROMISED!"
			or "YOUR INDUSTRIAL SHREDDER IS SABOTAGED!"
		
		SoundService.PlayLocal("PaparazziStorm")
		flashBanner("SabotagePingBanner", 3.5, Color3.fromRGB(255, 50, 50))
		
		-- Update banner text if label exists
		local banner = getFrame("SabotagePingBanner")
		if banner then
			local label = banner:FindFirstChildOfClass("TextLabel")
			if label then label.Text = message end
		end
	end)

	-- Elimination
	PlayerEliminated.OnClientEvent:Connect(function(eliminatedName)
		flashBanner("EliminationBanner", 3, Color3.fromRGB(200, 0, 0))
	end)
end

return HUDModule_Banners