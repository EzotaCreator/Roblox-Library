--!nonstrict
local Action = require(script.Parent.Parent.Parent.Parent.Action)

return Action("ScriptProfiler" .. script.Name, function(isClient, frequency)
	return {
		isClient = isClient,
		frequency = frequency,
	}
end)
