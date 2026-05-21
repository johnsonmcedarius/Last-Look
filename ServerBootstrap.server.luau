local ServerScriptService = game:GetService("ServerScriptService")
local ServiceRegistry = require(ServerScriptService:WaitForChild("ServiceRegistry"))

-- ── Replica Service Listeners (Critical for server-side replica handling) ──
require(ServerScriptService:WaitForChild("Experimental"):WaitForChild("ReplicaServiceListeners"))

-- Load all services here (they register themselves on require)
require(ServerScriptService:WaitForChild("DataManager"))
--require(ServerScriptService:WaitForChild("MarketplaceHandler"))
--require(ServerScriptService:WaitForChild("CodesService"))
--require(ServerScriptService:WaitForChild("DailyLookbook"))
require(ServerScriptService:WaitForChild("ShopManager"))
require(ServerScriptService:WaitForChild("GachaService"))
--require(ServerScriptService:WaitForChild("AbilityService"))
--require(ServerScriptService:WaitForChild("FabricManager"))

-- These might need to be converted to services
require(ServerScriptService:WaitForChild("RoundService")) 

ServiceRegistry.Bootstrap()
