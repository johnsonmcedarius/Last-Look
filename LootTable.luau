local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("SharedConfig"))

local LootTable = {}

LootTable.CoinDesignerCrate = {
	{Name = "Lava Flow",         Category = Config.CATEGORIES.SKIN_EFFECTS, Rarity = "Legendary"},
	{Name = "Ice Shimmer",       Category = Config.CATEGORIES.SKIN_EFFECTS, Rarity = "Rare"},
	{Name = "Static Glitch",     Category = Config.CATEGORIES.SKIN_EFFECTS, Rarity = "Common"},
	{Name = "Golden Scissors",   Category = Config.CATEGORIES.WEAPON_SKINS, Rarity = "Legendary"},
	{Name = "Chrome Basic Scissors", Category = Config.CATEGORIES.WEAPON_SKINS, Rarity = "Rare"},
	{Name = "Fashion Pulse",     Category = Config.CATEGORIES.SHOWSTOPPERS, Rarity = "Mythic"},
	{Name = "Neon Snippers",     Category = Config.CATEGORIES.WEAPON_SKINS, Rarity = "Common"},
}

LootTable.RobuxDesignerCrate = {
	{Name = "Popstar Diva",      Category = Config.CATEGORIES.SKINS,        Rarity = "Mythic"},
	{Name = "Diamond Throne",    Category = Config.CATEGORIES.PODIUMS,      Rarity = "Mythic"},
	{Name = "Galaxy Skin",       Category = Config.CATEGORIES.SKIN_EFFECTS, Rarity = "Legendary"},
	{Name = "Runway Finale",     Category = Config.CATEGORIES.SHOWSTOPPERS, Rarity = "Legendary"},
	{Name = "Vogue Strut",       Category = Config.CATEGORIES.EMOTES,       Rarity = "Rare"},
	{Name = "The Visionary",  Category = Config.CATEGORIES.SKINS,        Rarity = "Rare"},
}

return LootTable