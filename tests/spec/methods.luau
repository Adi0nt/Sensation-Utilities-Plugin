--!nocheck
local Methods = require("../../src/Core/Methods")

local function eq(actual: any, expected: any, label: string?)
	if actual ~= expected then
		error(`{label or "value"}: expected {tostring(expected)}, got {tostring(actual)}`, 2)
	end
end

local function sameList(actual: { string }, expected: { string })
	eq(table.concat(actual, ","), table.concat(expected, ","), "list")
end

--- Stand-ins for the Folder instances in methods.rbxm; the store never looks inside them.
local function containers(names: { string }): { [string]: any }
	local map = {}
	for _, name in names do
		map[name] = { Name = name }
	end
	return map
end

return {
	name = "Methods (bypass method store)",
	run = function(test)
		test("names are sorted case-insensitively and deterministically", function()
			local store = Methods.new()
			store:set(containers({ "recursion", "Alpha Method", "beta", "Zeta", "alpha method" }))
			sameList(store:names(), { "Alpha Method", "alpha method", "beta", "recursion", "Zeta" })
		end)

		test("ordering does not depend on insertion order", function()
			local a, b = Methods.new(), Methods.new()
			a:set(containers({ "x", "y", "z" }))
			b:set(containers({ "z", "x", "y" }))
			sameList(a:names(), b:names())
		end)

		test("resolve returns the requested method when it exists", function()
			local store = Methods.new()
			store:set(containers({ "One", "Two" }))
			local name, container = store:resolve("Two")
			eq(name, "Two")
			eq(container.Name, "Two")
		end)

		test("resolve falls back to the first sorted method", function()
			local store = Methods.new()
			store:set(containers({ "Two", "One" }))
			eq((store:resolve(nil)), "One")
			eq((store:resolve("")), "One")
			eq((store:resolve("Missing")), "One")
		end)

		test("resolve with no methods returns nothing", function()
			local store = Methods.new()
			local name, container = store:resolve("Anything")
			eq(name, nil)
			eq(container, nil)
		end)

		test("set replaces the whole method set", function()
			local store = Methods.new()
			store:set(containers({ "Old" }))
			store:set(containers({ "New" }))
			sameList(store:names(), { "New" })
			eq(store:get("Old"), nil)
		end)

		test("pick keeps the current method while it is still available", function()
			eq(Methods.pick({ "A", "B", "C" }, "B"), "B")
		end)

		test("pick falls back to the first method when the current one is gone", function()
			eq(Methods.pick({ "A", "C" }, "B"), "A")
			eq(Methods.pick({ "A", "C" }, ""), "A")
			eq(Methods.pick({ "A", "C" }, nil), "A")
		end)

		test("pick returns an empty string when there are no methods", function()
			eq(Methods.pick({}, "B"), "")
		end)

		test("a refreshed list keeps the user's selection (reload scenario)", function()
			local store = Methods.new()
			store:set(containers({ "Recursion Method", "Other" }))
			local selected = Methods.pick(store:names(), "Recursion Method")
			store:set(containers({ "Recursion Method", "Other", "Brand New" }))
			eq(Methods.pick(store:names(), selected), "Recursion Method")
			store:set(containers({ "Other" }))
			eq(Methods.pick(store:names(), selected), "Other")
		end)
	end,
}
