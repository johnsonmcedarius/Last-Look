-- ─────────────────────────────────────────────────────────────────────────────
-- CrateRegistry
-- Single source of truth for every crate in the game.
-- To add a new crate: add one entry to the table below.
-- No other scripts need to change.
--
-- Fields:
--   id          (string)  Internal key — used by GachaService, TriggerUnboxing, etc.
--   label       (string)  Display name shown on the purchase button
--   price       (string)  Display string for the price label (e.g. "99 R$")
--   currency    (string)  "Robux" | "Coins"
--   coinCost    (number?)  Required when currency == "Coins"
--   productId   (number?)  Required when currency == "Robux" (Developer Product ID)
--   order       (number)  Display order in the GachaCrateFrame (lower = first)
--   color       (Color3)  Accent color for the button border/glow
-- ─────────────────────────────────────────────────────────────────────────────

local CrateRegistry = {
	{
		id        = "RobuxDesignerCrate",
		label     = "DESIGNER DROP",
		price     = "99 R$",
		currency  = "Robux",
		productId = 0,          -- TODO: fill in real Developer Product ID
		order     = 1,
		color     = Color3.fromRGB(212, 175, 55),  -- gold
	},
	{
		id        = "CoinDesignerCrate",
		label     = "CREATIVE CRATE",
		price     = "500 COINS",
		currency  = "Coins",
		coinCost  = 500,
		productId = 0,
		order     = 2,
		color     = Color3.fromRGB(100, 200, 255),  -- cyan
	},
	-- ─── ADD NEW CRATES BELOW ─────────────────────────────────────────────────
	-- Example:
	-- {
	--     id        = "LegendaryCrate",
	--     label     = "LEGENDARY DROP",
	--     price     = "1,200 COINS",
	--     currency  = "Coins",
	--     coinCost  = 1200,
	--     productId = 0,
	--     order     = 3,
	--     color     = Color3.fromRGB(160, 50, 255),
	-- },
}

-- ── Helpers (used by server and client) ──────────────────────────────────────

-- Returns a crate definition by its id string
function CrateRegistry.GetById(id)
	for _, crate in ipairs(CrateRegistry) do
		if type(crate) == "table" and crate.id == id then
			return crate
		end
	end
	return nil
end

-- Returns all crate definitions sorted by order field
function CrateRegistry.GetAll()
	local list = {}
	for _, crate in ipairs(CrateRegistry) do
		if type(crate) == "table" then
			table.insert(list, crate)
		end
	end
	table.sort(list, function(a, b) return (a.order or 99) < (b.order or 99) end)
	return list
end

-- Returns true if the given id is a valid registered crate
function CrateRegistry.IsValid(id)
	return CrateRegistry.GetById(id) ~= nil
end

return CrateRegistry
