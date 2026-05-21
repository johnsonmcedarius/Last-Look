local PartCache = {}
PartCache.__index = PartCache

function PartCache.new(template, count, parent)
	local self = setmetatable({}, PartCache)
	self.Pool = {}
	self.Parent = parent or workspace
	
	for i = 1, count do
		local part = template:Clone()
		part.Parent = self.Parent
		part.CFrame = CFrame.new(0, 1000, 0) -- Move away
		table.insert(self.Pool, part)
	end
	
	return self
end

function PartCache:Get()
	local part = table.remove(self.Pool, 1)
	if not part then
		-- Grow pool if empty
		part = self.Pool[1]:Clone()
		part.Parent = self.Parent
	end
	return part
end

function PartCache:Return(part)
	part.CFrame = CFrame.new(0, 1000, 0)
	table.insert(self.Pool, part)
end

return PartCache
