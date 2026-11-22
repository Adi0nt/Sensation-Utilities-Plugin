--!nocheck
local Format = require("../../src/Core/Format")

local function eq(actual: any, expected: any, label: string?)
	if actual ~= expected then
		error(`{label or "value"}: expected {tostring(expected)}, got {tostring(actual)}`, 2)
	end
end

local function items(classes: { string }): { Format.Item }
	local list = {}
	for index, className in classes do
		table.insert(list, { name = `Item{index}`, className = className })
	end
	return list
end

return {
	name = "Format (selection summary)",
	run = function(test)
		test("no selection", function()
			local summary = Format.summarize({})
			eq(summary.kind, "none")
			eq(summary.count, 0)
			eq(summary.title, "No selection")
			eq(summary.detail, "Select an object in Explorer.")
			eq(summary.className, nil, "no icon when nothing is selected")
		end)

		test("single selection shows the name and class", function()
			local summary = Format.summarize({ { name = "MainModule", className = "ModuleScript" } })
			eq(summary.kind, "single")
			eq(summary.title, "MainModule")
			eq(summary.detail, "ModuleScript")
		end)

		test("multiple selection shows a count and a class breakdown", function()
			local summary = Format.summarize(items({ "Part", "Part", "Part", "Script", "Script" }))
			eq(summary.kind, "multi")
			eq(summary.count, 5)
			eq(summary.title, "5 objects selected")
			eq(summary.detail, "Part ×3 · Script ×2")
		end)

		test("the icon class is the shared class of the selection, or nothing when mixed", function()
			eq(Format.summarize({ { name = "Handler", className = "Script" } }).className, "Script")
			eq(Format.summarize(items({ "Part", "Part", "Part" })).className, "Part")
			eq(Format.summarize(items({ "Part", "Script" })).className, nil)
		end)

		test("one-line form for the chip", function()
			eq(Format.oneLine(Format.summarize({})), "No selection")
			eq(Format.oneLine(Format.summarize({ { name = "Handler", className = "Script" } })), "Handler · Script")
			eq(Format.oneLine(Format.summarize({ { name = "ModuleScript", className = "ModuleScript" } })), "ModuleScript")
			eq(
				Format.oneLine(Format.summarize(items({ "Part", "Part", "Script" }))),
				"3 objects selected · Part ×2 · Script"
			)
		end)

		test("breakdown is capped with a +N more suffix", function()
			eq(Format.classBreakdown(items({ "A", "B", "C", "D" })), "A · B · +2 more")
		end)

		test("breakdown ordering is deterministic: count desc, then name", function()
			eq(Format.classBreakdown(items({ "Zed", "Alpha", "Zed", "Mid" })), "Zed ×2 · Alpha · +1 more")
			eq(Format.classBreakdown(items({ "Mid", "Alpha", "Zed" })), "Alpha · Mid · +1 more")
		end)

		test("asset uses: counted per class and property, commonest first, capped", function()
			local function use(className: string, property: string)
				return { className = className, property = property }
			end
			eq(Format.assetUses({ use("MeshPart", "MeshId") }), "MeshPart.MeshId", "a single use has no count")
			eq(
				Format.assetUses({ use("Decal", "Texture"), use("MeshPart", "TextureID"), use("MeshPart", "TextureID") }),
				"MeshPart.TextureID ×2 · Decal.Texture"
			)
			eq(
				Format.assetUses({ use("B", "p"), use("A", "p"), use("C", "p"), use("D", "p") }),
				"A.p · B.p · +2 more",
				"ties are alphabetical and the list is capped"
			)
			eq(Format.assetUses({}), "", "no uses, no text")
		end)
	end,
}
