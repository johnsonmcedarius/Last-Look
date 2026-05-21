-- GiftingService — REMOVED FOR MVP
--
-- The gifting system has been intentionally stripped for the initial launch.
-- Reason: scope reduction per MVP plan. No gifting UI, no gifting remotes,
-- no coin/crate transfer logic should be active.
--
-- TO RE-ADD POST-LAUNCH:
--   1. Restore from version control (original GiftingService script).
--   2. Re-add GiftItem and GiftReceived RemoteEvents to RemoteRegistry.
--   3. Wire up the gifting UI in ShopUIHelper.
--   4. Test economy balance before enabling in production.
--
-- ServiceRegistry stub so nothing errors if another script calls ServiceRegistry.Get("GiftingService")
local ServerScriptService = game:GetService("ServerScriptService")
local ServiceRegistry     = require(ServerScriptService:WaitForChild("ServiceRegistry"))

local GiftingService = {}  -- empty stub

ServiceRegistry.Register("GiftingService", GiftingService)
return GiftingService
