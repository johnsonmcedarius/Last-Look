local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CombatRegistry = require(ReplicatedStorage:WaitForChild("CombatRegistry"))

local AbilityConfig = {
	-- ── Ability Prices (Coins) ──
	PRICES = {
		Common    = 500,
		Rare      = 1200,
		Legendary = 7500,
		Mythic    = 20000,
	},
	-- ── Ability Cooldowns (Seconds) ──
	DEFAULT_COOLDOWNS = {
		DEFAULT = 8, 
	},
	
	-- ── Ability Pool ──
	ABILITIES = {
		{Name = "Glitter Perfume Bomb", Rarity = "Common"},
		{Name = "The Smoke Machine",   Rarity = "Common"},
		{Name = "Slippery Gloss",      Rarity = "Common"},
		{Name = "The Wind Machine",    Rarity = "Rare"},
		{Name = "The Measuring Tape",  Rarity = "Rare"},
		{Name = "The Fabric Shield",   Rarity = "Rare"},
		{Name = "The Mannequin Decoy", Rarity = "Legendary"},
	},

	-- ── Helper Functions ──
	GetAbilityData = function(self, name)
		for _, ability in ipairs(self.ABILITIES) do
			if ability.Name == name then return ability end
		end
		return nil
	end,

	GetPrice = function(self, rarity)
		return self.PRICES[rarity] or 500
	end,

	
	GetCooldown = function(self, name)
		-- First check CombatRegistry for the ability
		local registryData = CombatRegistry.Abilities[name]
		if registryData and registryData.Cooldown then
			return registryData.Cooldown
		end

		return self.DEFAULT_COOLDOWNS.DEFAULT or 8
	end,
}

return AbilityConfig