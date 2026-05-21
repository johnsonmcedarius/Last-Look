local PreGameModule = {}

-- Config
PreGameModule.DURATION = 5 -- Default duration

-- Models (to be set or loaded)
PreGameModule.DesignerModel = nil
PreGameModule.CriticModel = nil

function PreGameModule.SetDuration(duration)
	PreGameModule.DURATION = duration
end

function PreGameModule.GetDuration()
	return PreGameModule.DURATION
end

return PreGameModule
