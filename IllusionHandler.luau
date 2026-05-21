-- ─────────────────────────────────────────────────────────────────────────────
-- IllusionHandler: Handles decoys and visual tricks
-- ─────────────────────────────────────────────────────────────────────────────
local IllusionHandler = {}

local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")

local ENTITY_TAG = "CombatEntity"

-- ── Helpers ──
local function tagForCleanup(obj, owner)
	CollectionService:AddTag(obj, ENTITY_TAG)
	if owner then
		obj:SetAttribute("OwnerId", owner.UserId)
	end
end

-- ── Core Logic ──

function IllusionHandler.SpawnDecoy(player, duration, position)
	local char = player.Character
	if not char then return end
	
	-- Simplified Decoy: Clone character model
	char.Archivable = true
	local decoy = char:Clone()
	char.Archivable = false
	
	-- Strip logic
	for _, desc in ipairs(decoy:GetDescendants()) do
		if desc:IsA("LuaSourceContainer") or desc:IsA("LocalScript") or desc:IsA("Script") then
			desc:Destroy()
		end
	end
	
	decoy:SetPrimaryPartCFrame(CFrame.new(position))
	decoy.Parent = workspace
	
	tagForCleanup(decoy, player)
	Debris:AddItem(decoy, duration)
	
	-- Give it a fake FBRoll if caster has one (placeholder logic)
	print("[ILLUSION] Spawned Decoy for", player.Name)
end

function IllusionHandler.Cleanup(player)
	for _, obj in ipairs(CollectionService:GetTagged(ENTITY_TAG)) do
		if obj:GetAttribute("OwnerId") == player.UserId then
			obj:Destroy()
		end
	end
end

function IllusionHandler.CleanupAll()
	for _, obj in ipairs(CollectionService:GetTagged(ENTITY_TAG)) do
		obj:Destroy()
	end
end

return IllusionHandler
