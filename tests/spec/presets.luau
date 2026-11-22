--!nocheck
local fs = require("@lune/fs")
local roblox = require("@lune/roblox")
local Presets = require("../../src/Core/Presets")

--- Golden files may be checked out with CRLF on Windows; Luau long strings are always LF.
local function lf(text: string): string
	return (string.gsub(text, "\r\n", "\n"))
end

local function eq(actual: any, expected: any, label: string?)
	if actual ~= expected then
		error(`{label or "value"}: expected {tostring(expected)}, got {tostring(actual)}`, 2)
	end
end

--- The built `presets.rbxm`, read the way the plugin reads it.
local function builtPresets()
	return Presets.parse(roblox.deserializeModel(fs.readFile("presets.rbxm")))
end

return {
	name = "Presets",
	run = function(test)
		-- The golden files are the preset sources exactly as the pre-Flux plugin shipped them.
		test("presets.rbxm: Basic Module source is unchanged from the previous plugin", function()
			eq(builtPresets()["Basic Module"].source, lf(fs.readFile("tests/golden/basic_module.txt")))
		end)

		test("presets.rbxm: Advanced Module source is unchanged from the previous plugin", function()
			eq(builtPresets()["Advanced Module"].source, lf(fs.readFile("tests/golden/advanced_module.txt")))
		end)

		test("presets.rbxm matches the files in presets/ (rebuild it with rojo after editing them)", function()
			local found = builtPresets()
			local count = 0
			for name, preset in found do
				count += 1
				eq(preset.source, lf(fs.readFile(`presets/{name}.luau`)), `{name} source is stale in presets.rbxm`)
			end
			local files = 0
			for _, file in fs.readDir("presets") do
				if string.match(file, "%.luau$") then
					files += 1
				end
			end
			eq(count, files, "every presets/*.luau file is in presets.rbxm")
		end)

		test("every preset in presets.rbxm has a source and a description", function()
			local count = 0
			for name, preset in builtPresets() do
				count += 1
				eq(#preset.source > 0, true, `{name} source`)
				eq(#preset.description > 0, true, `{name} description`)
			end
			eq(count, 2)
		end)

		test("the store sorts names case-insensitively and reports sources and descriptions", function()
			local store = Presets.new()
			store:set({
				zeta = { source = "z", description = "last" },
				["Alpha"] = { source = "a", description = "first" },
				beta = { source = "b", description = "" },
			})
			eq(table.concat(store:names(), ","), "Alpha,beta,zeta")
			eq(store:source("beta"), "b")
			eq(store:source("nope"), nil, "unknown preset has no source")
			eq(store:has("Alpha"), true)
			eq(store:has("nope"), false)
			eq(store:description("Alpha"), "first")
			eq(store:description("nope"), "", "unknown preset has an empty description")
		end)

		test("pick keeps a still-valid choice and otherwise falls back to the first", function()
			eq(Presets.pick({ "A", "B" }, "B"), "B")
			eq(Presets.pick({ "A", "B" }, "gone"), "A")
			eq(Presets.pick({}, "A"), "")
		end)

		test("parse reads scripts, looks through folders, and ignores everything else", function()
			local root = roblox.Instance.new("Folder")
			root.Name = "Presets"
			local one = roblox.Instance.new("ModuleScript")
			one.Name = "One"
			one.Source = "return 1"
			one:SetAttribute("Description", "the first")
			one.Parent = root
			local sub = roblox.Instance.new("Folder")
			sub.Name = "Sub"
			sub.Parent = root
			local two = roblox.Instance.new("Script")
			two.Name = "Two"
			two.Source = "return 2"
			two.Parent = sub
			local part = roblox.Instance.new("Part")
			part.Name = "NotAPreset"
			part.Parent = root

			local found = Presets.parse({ root })
			eq(found["One"].source, "return 1")
			eq(found["One"].description, "the first")
			eq(found["Two"].source, "return 2", "scripts inside folders are found")
			eq(found["Two"].description, "", "no attribute means an empty description")
			eq(found["NotAPreset"], nil, "non-scripts are ignored")
		end)
	end,
}
