local HUDModule_Abilities = {}

function HUDModule_Abilities.Init(screenGui, remotes, SoundService)
	local UpdateAbilitySlots = remotes:WaitForChild("UpdateAbilitySlots")

	
	local RARITY_COLORS = {
		Common    = Color3.fromRGB(180, 180, 180),
		Rare      = Color3.fromRGB(80, 130, 255),
		Legendary = Color3.fromRGB(255, 180, 0),
		Mythic    = Color3.fromRGB(255, 50, 150),
	}

	local AbilityRarities = {
		-- Common
		["Glitter Perfume Bomb"] = "Common", 
		["Camera Flash"] = "Common", 
		["High Heel Trap"] = "Common",
		-- Rare
		["Double Spray"]   = "Rare",   
		["Chain Flash"]  = "Rare",
		["Heel Storm"]     = "Rare",   
		["Fashion Surge"] = "Rare",
		-- Legendary
		["The Takedown"]   = "Legendary",
		-- Mythic
		["Style Shock"]    = "Mythic",
	}

	local function getFrame(name)
		return screenGui:FindFirstChild(name, true)
	end

	
	UpdateAbilitySlots.OnClientEvent:Connect(function(slots, unlockedSlots)
		-- Dynamic slot count - supports 1-3+ slots
		local maxSlots = math.max(#slots, 3)
		
		for i = 1, maxSlots do
			local slot = getFrame("Slot" .. i .. "_Weapon") or getFrame("Slot" .. i .. "_Dash") or getFrame("Slot" .. i .. "_Ability")
		-- Try alternate naming conventions
		if not slot then
			-- Try ActionHotbar slot naming: Slot1_Weapon, Slot2_Dash, Slot3_Ability
			local slotNames = {"Slot1_Weapon", "Slot2_Dash", "Slot3_Ability"}
			if i <= #slotNames then
				slot = getFrame(slotNames[i])
			end
		end
		
		if not slot then continue end

		local nameLabel = slot:FindFirstChild("AbilityNameLabel")
		local rarityBorder = slot:FindFirstChild("RarityBorder")
		local lockOverlay = slot:FindFirstChild("LockOverlay")
		local abilityName = slots[i]

		
		if nameLabel then
			if abilityName and abilityName ~= "" and abilityName ~= "Empty" then
				nameLabel.Text = abilityName
			else
				nameLabel.Text = i == 1 and "Visit Shop!" or ""
			end
		end

		
		if rarityBorder then
			local rarity = AbilityRarities[abilityName]
			if rarity then
				rarityBorder.BackgroundColor3 = RARITY_COLORS[rarity]
				rarityBorder.Visible = true
				rarityBorder.BackgroundTransparency = 0.5
			else
				
				rarityBorder.Visible = false
			end
		end

		
		if lockOverlay then
			
			lockOverlay.Visible = (i > (unlockedSlots or 1))
		end
	end
	end)
end

return HUDModule_Abilities