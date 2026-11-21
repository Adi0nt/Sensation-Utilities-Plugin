--!nocheck
local fs = require("@lune/fs")
local Presets = require("../../src/Core/Presets")

--- Golden files may be checked out with CRLF on Windows; Luau long strings are always LF.
local function golden(path: string): string
	return (string.gsub(fs.readFile(path), "\r\n", "\n"))
end

local function eq(actual: any, expected: any, label: string?)
	if actual ~= expected then
		error(`{label or "value"}: expected {tostring(expected)}, got {tostring(actual)}`, 2)
	end
end

return {
	name = "Presets",
	run = function(test)
		-- The golden files are the preset sources exactly as the pre-Flux plugin shipped them.
		test("Basic Module source is unchanged from the previous plugin", function()
			eq(Presets.source("Basic Module"), golden("tests/golden/basic_module.txt"))
		end)

		test("Advanced Module source is unchanged from the previous plugin", function()
			eq(Presets.source("Advanced Module"), golden("tests/golden/advanced_module.txt"))
		end)

		test("an unknown preset falls back to the old placeholder", function()
			eq(Presets.source("Nope"), "-- Invalid Preset")
		end)

		test("every listed preset has a source and a description", function()
			eq(#Presets.names, 2)
			for _, name in Presets.names do
				eq(Presets.source(name) ~= "-- Invalid Preset", true, name)
				eq(type(Presets.descriptions[name]), "string", name)
			end
		end)
	end,
}
