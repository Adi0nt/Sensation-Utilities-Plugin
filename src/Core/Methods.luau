--!strict
--- The dynamically loaded bypass methods (`methods.rbxm`). Pure data plus deterministic ordering.

local Types = require("./Types")

local Methods = {}
Methods.__index = Methods

type Self = typeof(setmetatable({} :: { containers: { [string]: Instance } }, Methods))

local function sortedNames(containers: { [string]: Instance }): { string }
	local names: { string } = {}
	for name in containers do
		table.insert(names, name)
	end
	-- Case-insensitive first so ordering feels natural, exact name as the tie-breaker so it is fully deterministic.
	table.sort(names, function(a, b)
		local la, lb = string.lower(a), string.lower(b)
		if la ~= lb then
			return la < lb
		end
		return a < b
	end)
	return names
end

function Methods.new(): Types.MethodStore
	return setmetatable({ containers = {} }, Methods) :: any
end

--- Replaces the whole method set.
function Methods.set(self: Self, containers: { [string]: Instance })
	self.containers = table.clone(containers)
end

function Methods.names(self: Self): { string }
	return sortedNames(self.containers)
end

function Methods.get(self: Self, name: string): Instance?
	return self.containers[name]
end

--- Resolves `name` to an available method. Falls back to the first method in sorted order when `name` is
--- empty or no longer exists (the previous implementation fell back to an arbitrary `next()` entry).
function Methods.resolve(self: Self, name: string?): (string?, Instance?)
	if name ~= nil and name ~= "" then
		local container: Instance? = self.containers[name]
		if container ~= nil then
			return name, container
		end
	end
	local first = sortedNames(self.containers)[1]
	if first ~= nil then
		return first, self.containers[first]
	end
	return nil, nil
end

--- Keeps `current` if it is still in `names`, otherwise falls back to the first entry (or "" when empty).
function Methods.pick(names: { string }, current: string?): string
	if current ~= nil and current ~= "" and table.find(names, current) ~= nil then
		return current
	end
	return names[1] or ""
end

return Methods
