print("[SERVER] Initializing...")

local ServerScriptService = game:GetService("ServerScriptService")

-- ── 1. SERVICE REGISTRY (The Foundation) ───────────────────────────────────
-- This has to load first or everything else breaks.
require(ServerScriptService:WaitForChild("ServiceRegistry"))

-- ── 2. CORE INFRASTRUCTURE ────────────────────────────────────────────────
-- Data and backend services first.
require(ServerScriptService:WaitForChild("DataManager"))
require(ServerScriptService:WaitForChild("GachaService"))
require(ServerScriptService:WaitForChild("TeamService"))
require(ServerScriptService:WaitForChild("MapService"))
require(ServerScriptService:WaitForChild("TimerService"))
require(ServerScriptService:WaitForChild("RoundEvents"))
require(ServerScriptService:WaitForChild("FabricCarrierService"))
require(ServerScriptService:WaitForChild("ShopManager"))
require(ServerScriptService:WaitForChild("MatchRegistry"))

-- ── COLLISION SERVICE (Phase 4: Player-to-player Collision Management) ─────
require(ServerScriptService:WaitForChild("CollisionService"))

-- ── ROBLOX PLUS SERVICE (Phase 9: Subscription Integration) ──────────────
require(ServerScriptService:WaitForChild("RobloxPlusService"))

-- ── 3. GAMEPLAY & REWARD LOGIC ─────────────────────────────────────────────
-- RewardTracker is REQUIRED for FabricManager to track XP/Coins.
--require(ServerScriptService:WaitForChild("RewardTracker"))
--require(ServerScriptService:WaitForChild("ShowstopperService")) 
--require(ServerScriptService:WaitForChild("FabricManager"))
require(ServerScriptService:WaitForChild("SkinEffectService"))

print("[SERVER] All services initialized.")