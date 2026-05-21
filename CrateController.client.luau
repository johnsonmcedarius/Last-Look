local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService      = game:GetService("TweenService")
local Debris            = game:GetService("Debris")
local RunService        = game:GetService("RunService")

local player = Players.LocalPlayer

local Remotes           = ReplicatedStorage:WaitForChild("Remotes")
local CrateResult       = Remotes:WaitForChild("CrateResult")
local BatchCrateResults = Remotes:WaitForChild("BatchCrateResults")
local BatchOpenCrate    = Remotes:WaitForChild("BatchOpenCrate")
local OpenCrate         = Remotes:WaitForChild("OpenCrate")

local SoundService = require(ReplicatedStorage:WaitForChild("SoundService"))

-- Rarity colors are stored as attributes on ReplicatedStorage.Assets.RevealBillboard
-- (Color_Common, Color_Rare, Color_Epic, Color_Legendary, Color_Mythic)
-- This helper reads them at runtime so designers can tweak colors in Studio
-- without touching any script.
local function getRarityColor(template, rarityName)
	local attrKey = "Color_" .. (rarityName or "Common")
	local col = template:GetAttribute(attrKey)
	return col or Color3.fromRGB(180, 180, 180)
end

local CIRCLE_RADIUS  = 6   -- studs around player
local RUMBLE_TIME    = 2   -- seconds of shaking before pop
local REVEAL_HOLD    = 3   -- seconds billboard stays visible


local function buildCrateModel(position, crateType)
	-- Try to find a pre-made crate asset
	local assets   = ReplicatedStorage:FindFirstChild("Assets")
	local crateAsset = assets and assets:FindFirstChild("Crates") and assets.Crates:FindFirstChild(crateType)

	local crateModel

	if crateAsset then
		crateModel = crateAsset:Clone()
	else
		-- Procedural placeholder
		crateModel = Instance.new("Model")
		crateModel.Name = crateType

		local body = Instance.new("Part")
		body.Name    = "Body"
		body.Size    = Vector3.new(2, 2, 2)
		body.BrickColor = crateType == "CoinDesignerCrate"
			and BrickColor.new("Bright yellow")
			or  BrickColor.new("Cyan")
		body.Material = Enum.Material.SmoothPlastic
		body.Anchored = true
		body.CFrame   = CFrame.new(position)
		body.Parent   = crateModel

		local lid = Instance.new("Part")
		lid.Name     = "Lid"
		lid.Size     = Vector3.new(2.1, 0.3, 2.1)
		lid.BrickColor = body.BrickColor
		lid.Material = Enum.Material.SmoothPlastic
		lid.Anchored  = true
		lid.CFrame    = CFrame.new(position + Vector3.new(0, 1.15, 0))
		lid.Parent    = crateModel

		crateModel.PrimaryPart = body
	end

	crateModel:PivotTo(CFrame.new(position))
	crateModel.Parent = workspace

	return crateModel
end


-- Place crates in a circle around the player

local function getCirclePositions(count)
	local positions = {}
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not root then return positions end

	local center = root.Position

	for i = 1, count do
		local angle = (2 * math.pi / count) * (i - 1)
		local x = center.X + CIRCLE_RADIUS * math.cos(angle)
		local z = center.Z + CIRCLE_RADIUS * math.sin(angle)
		table.insert(positions, Vector3.new(x, center.Y, z))
	end

	return positions
end


-- Rumble tween for one crate

local function rumbleCrate(crateModel)
	local body = crateModel:FindFirstChild("Body") or crateModel:FindFirstChildWhichIsA("BasePart")
	if not body then return end

	local originalCF = body.CFrame
	local intensity  = 0.15
	local started    = os.clock()

	local conn
	conn = RunService.Heartbeat:Connect(function()
		if os.clock() - started >= RUMBLE_TIME then
			conn:Disconnect()
			body.CFrame = originalCF
			return
		end
		local shake = CFrame.new(
			(math.random() - 0.5) * intensity,
			(math.random() - 0.5) * intensity * 0.5,
			(math.random() - 0.5) * intensity
		)
		body.CFrame = originalCF * shake
	end)

	return conn
end


-- Pop lid open

local function popLid(crateModel)
	local lid = crateModel:FindFirstChild("Lid")
	if not lid then return end

	TweenService:Create(lid, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		CFrame = lid.CFrame * CFrame.new(0, 2, 0) * CFrame.Angles(math.rad(-80), 0, 0)
	}):Play()
end


-- Reveal billboard over crate (uses physical template)

local function showRevealBillboard(crateModel, itemData)
	local body = crateModel:FindFirstChild("Body") or crateModel:FindFirstChildWhichIsA("BasePart")
	if not body then return end

	-- Get template from ReplicatedStorage.Assets
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local template = assets and assets:FindFirstChild("RevealBillboard")
	
	-- Template is guaranteed in ReplicatedStorage.Assets.RevealBillboard
	if not template then
		warn("[CrateController] RevealBillboard template missing from ReplicatedStorage.Assets!")
		return
	end

	local billboard = template:Clone()
	billboard.Adornee = body
	billboard.Parent  = body

	local bg = billboard:FindFirstChild("Background")
	if bg then
		-- Read rarity color from template attributes (set by designer in Studio)
		bg.BackgroundColor3 = getRarityColor(template, itemData.Rarity)

		local accentBar = bg:FindFirstChild("AccentBar")
		if accentBar then
			accentBar.BackgroundColor3 = getRarityColor(template, itemData.Rarity)
		end

		local itemNameLabel = bg:FindFirstChild("ItemName")
		if itemNameLabel then
			itemNameLabel.Text = itemData.Name or "UNKNOWN"
		end

		local rarityLabel = bg:FindFirstChild("RarityLabel")
		if rarityLabel then
			rarityLabel.Text = (itemData.Rarity or "Common"):upper()
		end
	end

	-- Fade out after hold time
	task.delay(REVEAL_HOLD, function()
		TweenService:Create(billboard, TweenInfo.new(0.5), {StudsOffsetWorldSpace = Vector3.new(0, 5, 0)}):Play()
		Debris:AddItem(billboard, 0.6)
	end)
end


-- Full open sequence for N crates

local function openCratesLocally(crateType, results)
	local count     = #results
	local positions = getCirclePositions(count)
	if #positions == 0 then return end

	SoundService.PlayLocal("BetPlaced")  -- opening anticipation sound

	local crateModels = {}
	for i, pos in ipairs(positions) do
		local model = buildCrateModel(pos, crateType)
		crateModels[i] = model
	end

	-- Stagger rumbles
	for i, model in ipairs(crateModels) do
		task.delay((i - 1) * 0.05, function()
			rumbleCrate(model)
		end)
	end

	-- After rumble time, pop all lids and reveal
	task.delay(RUMBLE_TIME, function()
		for i, model in ipairs(crateModels) do
			task.delay((i - 1) * 0.1, function()
				popLid(model)
				showRevealBillboard(model, results[i])
				SoundService.PlayLocal("FabricDunk")  -- satisfying thud on pop
			end)
		end

		-- Clean up crates after reveal
		task.delay(REVEAL_HOLD + 1, function()
			for _, model in ipairs(crateModels) do
				if model and model.Parent then
					TweenService:Create(
						model:FindFirstChildWhichIsA("BasePart") or model.PrimaryPart or Instance.new("Part"),
						TweenInfo.new(0.4),
						{}
					):Play()
					Debris:AddItem(model, 0.5)
				end
			end
		end)
	end)
end


-- Remote listeners

CrateResult.OnClientEvent:Connect(function(crateType, itemData)
	openCratesLocally(crateType, {itemData})
end)

BatchCrateResults.OnClientEvent:Connect(function(crateType, results)
	openCratesLocally(crateType, results)
end)