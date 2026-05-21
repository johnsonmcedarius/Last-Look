local ServiceRegistry = {}

local registered = {}       -- [name] = service table
local waiters    = {}       -- [name] = {thread, ...}
local initialized = false

--- Register a service. Call this at the END of each service script.
--- @param name    string   The service key (e.g. "DataManager")
--- @param service table    The public API table
function ServiceRegistry.Register(name, service)
	assert(type(name) == "string",  "[ServiceRegistry] name must be a string")
	assert(type(service) == "table","[ServiceRegistry] service must be a table")

	if registered[name] then
		warn("[ServiceRegistry] Re-registering: " .. name)
	end

	registered[name] = service
	print("[ServiceRegistry] Registered: " .. name)

	-- Wake up any threads waiting for this service
	if waiters[name] then
		for _, thread in ipairs(waiters[name]) do
			task.spawn(thread, service)
		end
		waiters[name] = nil
	end
end

--- Get a service immediately. Returns nil if not yet registered.
--- Use only when you're certain load order is satisfied.
function ServiceRegistry.Get(name)
	return registered[name]
end

--- Yield until the named service is registered, then return it.
--- Safe to call at any time — even before the service script runs.
--- @param name     string
--- @param timeout  number?   Optional max wait in seconds (default 10)
function ServiceRegistry.Await(name, timeout)
	if registered[name] then
		return registered[name]
	end

	timeout = timeout or 10
	local deadline = os.clock() + timeout

	if not waiters[name] then
		waiters[name] = {}
	end

	local thread = coroutine.running()
	table.insert(waiters[name], thread)

	-- Safety timeout so we never hang forever
	task.delay(timeout, function()
		if registered[name] then return end -- resolved in time
		-- Remove the waiter and warn
		if waiters[name] then
			for i, t in ipairs(waiters[name]) do
				if t == thread then table.remove(waiters[name], i) break end
			end
		end
		warn("[ServiceRegistry] TIMEOUT waiting for service: " .. name)
		task.spawn(thread, nil)
	end)

	return coroutine.yield()
end

--- Bootstraps all registered services by calling Init then Start
function ServiceRegistry.Bootstrap()
	if initialized then return end
	initialized = true

	print("[ServiceRegistry] Bootstrapping " .. #registered .. " services...")

	-- 1. Init Phase: Services setup their internal state, no cross-talk allowed
	for name, service in pairs(registered) do
		if service.Init then
			print("[ServiceRegistry] Initializing: " .. name)
			service:Init()
		end
	end

	-- 2. Start Phase: Services can now safely talk to each other via Registry.Get()
	for name, service in pairs(registered) do
		if service.Start then
			print("[ServiceRegistry] Starting: " .. name)
			task.spawn(function()
				service:Start()
			end)
		end
	end

	print("[ServiceRegistry] All services bootstrapped successfully.")
end

return ServiceRegistry
