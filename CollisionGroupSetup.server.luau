-- ─────────────────────────────────────────────────────────────────────────────
-- CollisionGroupSetup: Initializes groups for combat filtering
-- ─────────────────────────────────────────────────────────────────────────────

local PhysicsService = game:GetService("PhysicsService")

local GROUPS = {
	"Designers",
	"Critics",
	"DesignerBarrier",
	"CriticBarrier"
}

-- Ensure groups exist
for _, name in ipairs(GROUPS) do
	pcall(function()
		PhysicsService:RegisterCollisionGroup(name)
	end)
end

-- Configure Interactions
-- Barriers should NOT collide with their own team
PhysicsService:CollisionGroupSetCollidable("Designers", "DesignerBarrier", false)
PhysicsService:CollisionGroupSetCollidable("Critics", "CriticBarrier", false)

-- Barriers SHOULD collide with the OPPOSING team
PhysicsService:CollisionGroupSetCollidable("Critics", "DesignerBarrier", true)
PhysicsService:CollisionGroupSetCollidable("Designers", "CriticBarrier", true)

-- Players shouldn't collide with each other (optional but usually smoother)
PhysicsService:CollisionGroupSetCollidable("Designers", "Designers", false)
PhysicsService:CollisionGroupSetCollidable("Critics", "Critics", false)

-- ── Player Assignment ──
local function assignPlayer(player)
	player.CharacterAdded:Connect(function(char)
		local teamName = player.Team and player.Team.Name
		if teamName == "Designers" or teamName == "Critics" then
			for _, desc in ipairs(char:GetDescendants()) do
				if desc:IsA("BasePart") then
					desc.CollisionGroup = teamName
				end
			end
		end
	end)
end

game.Players.PlayerAdded:Connect(assignPlayer)
for _, p in ipairs(game.Players:GetPlayers()) do assignPlayer(p) end

print("[PHYSICS] Collision Groups Initialized")
