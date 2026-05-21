local ItemDatabase = {
	Skins = {
		EquipSlot = "Skin",
		Items = {
			-- ROBUX SKINS
			["K-Pop Star"] = {Cost = nil, Currency = "Robux", ProductId = 12384901},
			["Popstar Diva"] = {Cost = nil, Currency = "Robux", ProductId = 12345678},
			["The Visionary"] = {Cost = nil, Currency = "Robux", ProductId = 87654322}, 

			-- COIN SKINS
			["The Intern"] = {Cost = 500, Currency = "Coins", ProductId = nil},
			["The Thriftier"] = {Cost = 500, Currency = "Coins", ProductId = nil},
			["The Curator"] = {Cost = 500, Currency = "Coins", ProductId = nil},
			["The Ghost"] = {Cost = 500, Currency = "Coins", ProductId = nil},
		}
	},
	WeaponSkins = { 
		EquipSlot = "WeaponSkin", 
		Items = {
			["Antique Scissors"] = {Cost = 2000, Currency = "Coins"},
			["Golden Shears"] = {Cost = nil, Currency = "Robux", ProductId = 87654321},
		}
	},
	Podiums = {
		EquipSlot = "Podium",
		Items = {
			["Vogue Pedestal"] = {Cost = 800, Currency = "Coins"},
			["Neon Stage"] = {Cost = 1500, Currency = "Coins"},
		}
	},
	Emotes = {
		EquipSlot = "Emote",
		Items = {
			["Catwalk Strut"] = {Cost = 1000, Currency = "Coins"},
			["Slay Pose"] = {Cost = 500, Currency = "Coins"},
		}
	},
	SkinEffects = { 
		EquipSlot = "SkinEffect", 
		Items = {
			["Gold"] = {Cost = 3000, Currency = "Coins"},
			["Ice"] = {Cost = 2500, Currency = "Coins"},
		}
	}
}

function ItemDatabase.GetItemCategory(itemName)
	for category, data in pairs(ItemDatabase) do
		if typeof(data) == "table" and data.Items and data.Items[itemName] then 
			return category 
		end
	end
	return nil
end

function ItemDatabase.GetItemData(itemName)
	local category = ItemDatabase.GetItemCategory(itemName)
	if category then
		return ItemDatabase[category].Items[itemName], category
	end
	return nil
end

return ItemDatabase