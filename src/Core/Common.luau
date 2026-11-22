--!strict
--- Instance construction helpers ported from the previous implementation. Property writes go through the raw
--- `Instance.__newindex` (via RawLib) wrapped in `pcall`, exactly as before.

local Types = require("./Types")

local Common = {}

local function apply(env: Types.Env, instance: Instance, properties: { [string]: any }?, children: { Instance }?): Instance
	local newIndex = env.newIndex
	if properties then
		local parent = nil
		for property, value in properties do
			if string.lower(property) == "parent" then
				parent = value
				continue
			end
			pcall(newIndex, instance, property, value)
		end
		if parent then
			pcall(newIndex, instance, "Parent", parent)
		end
	end
	if children then
		for _, child in children do
			pcall(newIndex, child, "Parent", instance)
		end
	end
	return instance
end

function Common.create(env: Types.Env, className: string, properties: { [string]: any }?, children: { Instance }?): Instance
	return apply(env, Instance.new(className :: any), properties, children)
end

function Common.clone(env: Types.Env, source: Instance, properties: { [string]: any }?, children: { Instance }?): Instance
	return apply(env, source:Clone() :: Instance, properties, children)
end

--- The current selection, filtered to instances that still exist in the DataModel.
function Common.selected(env: Types.Env): { Instance }
	return env.selection:Get()
end

--- Number of descendants below `instances` (not counting the instances themselves).
function Common.countDescendants(instances: { Instance }): number
	local total = 0
	for _, instance in instances do
		total += #instance:GetDescendants()
	end
	return total
end

return Common
