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

		test("breakdown is capped with a +N more suffix", function()
			eq(Format.classBreakdown(items({ "A", "B", "C", "D" })), "A · B · +2 more")
		end)

		test("breakdown ordering is deterministic: count desc, then name", function()
			eq(Format.classBreakdown(items({ "Zed", "Alpha", "Zed", "Mid" })), "Zed ×2 · Alpha · +1 more")
			eq(Format.classBreakdown(items({ "Mid", "Alpha", "Zed" })), "Alpha · Mid · +1 more")
		end)
	end,
}
