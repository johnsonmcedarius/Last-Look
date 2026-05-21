-- ─────────────────────────────────────────────────────────────────────────────
-- HUDModule_Showstopper: ShowstopperBar with neon pulse effect at 100%
-- Handles charge bar updates and visual feedback
-- ─────────────────────────────────────────────────────────────────────────────

local HUDModule_Showstopper = {}

local TweenService = game:GetService("TweenService")

function HUDModule_Showstopper.Init(screenGui, remotes, SoundService)
	local UpdateShowstopperCharge = remotes:WaitForChild("UpdateShowstopperCharge")
	local ShowstopperFullAlert    = remotes:WaitForChild("ShowstopperFullAlert")
	
	-- ── Reference Physical UI ──
	local function getShowstopperBar()
		local ultimateModule = screenGui:FindFirstChild("UltimateModule")
		if not ultimateModule then return nil end
		return ultimateModule:FindFirstChild("ShowstopperBar")
	end
	
	-- ── State ──
	local isNeonPulsing = false
	local neonPulseConn = nil
	
	-- ── Neon Pulse Animation (when at 100%) ──
	local function startNeonPulse(neonPulse)
		if isNeonPulsing or not neonPulse then return end
		isNeonPulsing = true
		neonPulse.Visible = true
		
		neonPulseConn = task.spawn(function()
			while isNeonPulsing do
				TweenService:Create(neonPulse, TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {ImageTransparency = 0.3}):Play()
				task.wait(0.5)
				TweenService:Create(neonPulse, TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {ImageTransparency = 0.7}):Play()
				task.wait(0.5)
			end
			neonPulse.Visible = false
		end)
	end
	
	local function stopNeonPulse(neonPulse)
		isNeonPulsing = false
		if neonPulse then
			neonPulse.Visible = false
		end
	end
	
	-- ── Charge Update Handler ──
	UpdateShowstopperCharge.OnClientEvent:Connect(function(charge, maxCharge)
		local showstopperBar = getShowstopperBar()
		if not showstopperBar then return end
		
		local progressFill = showstopperBar:FindFirstChild("ProgressFill")
		local neonPulse = showstopperBar:FindFirstChild("NeonPulse")
		local percentLabel = showstopperBar:FindFirstChild("PercentLabel")
		
		local pct = math.clamp(charge / maxCharge, 0, 1)
		
		-- Update progress fill
		if progressFill then
			TweenService:Create(progressFill, TweenInfo.new(0.3, Enum.EasingStyle.Quad), {
				Size = UDim2.new(pct, 0, 1, 0)
			}):Play()
			
			-- Color based on charge level
			if pct >= 1 then
				progressFill.BackgroundColor3 = Color3.fromRGB(255, 80, 200) -- Neon pink at 100%
			elseif pct >= 0.75 then
				progressFill.BackgroundColor3 = Color3.fromRGB(255, 200, 0) -- Gold at 75%+
			elseif pct >= 0.5 then
				progressFill.BackgroundColor3 = Color3.fromRGB(255, 150, 50) -- Orange at 50%+
			else
				progressFill.BackgroundColor3 = Color3.fromRGB(180, 180, 180) -- Gray at low charge
			end
		end
		
		-- Update percentage label
		if percentLabel then
			percentLabel.Text = math.floor(pct * 100) .. "%"
			percentLabel.TextColor3 = pct >= 1 and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(200, 200, 200)
		end
		
		-- Handle neon pulse at 100%
		if pct >= 1 then
			startNeonPulse(neonPulse)
		else
			stopNeonPulse(neonPulse)
		end
	end)
	
	-- ── Full Alert Handler ──
	ShowstopperFullAlert.OnClientEvent:Connect(function()
		if SoundService then
			SoundService.PlayLocal("ShowstopperReady")
		end
		
		local showstopperBar = getShowstopperBar()
		if not showstopperBar then return end
		
		-- Flash the entire bar
		for i = 1, 2 do
			task.delay((i-1) * 0.3, function()
				TweenService:Create(showstopperBar, TweenInfo.new(0.1), {BackgroundColor3 = Color3.new(1,1,1)}):Play()
				task.delay(0.15, function()
					TweenService:Create(showstopperBar, TweenInfo.new(0.3), {BackgroundColor3 = Color3.fromRGB(20, 20, 30)}):Play()
				end)
			end)
		end
	end)
	
	-- ── Public API ──
	HUDModule_Showstopper.SetCharge = function(charge, maxCharge)
		-- Manual charge update (for local calls)
		local pct = math.clamp(charge / maxCharge, 0, 1)
		local showstopperBar = getShowstopperBar()
		if not showstopperBar then return end
		
		local progressFill = showstopperBar:FindFirstChild("ProgressFill")
		if progressFill then
			progressFill.Size = UDim2.new(pct, 0, 1, 0)
		end
	end
end

return HUDModule_Showstopper