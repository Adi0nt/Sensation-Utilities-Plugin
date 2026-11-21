--!strict
--- Pure presentation helpers for Studio selections. Inputs are plain data so this runs under Lune.

export type Item = { name: string, className: string }

export type Summary = {
	kind: "none" | "single" | "multi",
	count: number,
	--- Main line: the object's name, or "N objects selected".
	title: string,
	--- Second line: the class, a class breakdown, or a hint.
	detail: string,
	--- The class to show an icon for: the object's class, or the shared class of a multi-selection (`nil` when the
	--- classes differ or nothing is selected).
	className: string?,
}

local MAX_CLASSES_SHOWN = 2

local Format = {}

--- "Part ×3 · Script ×2 · +1 more" for a list of items, most common classes first (ties alphabetical).
function Format.classBreakdown(items: { Item }): string
	local counts: { [string]: number } = {}
	local order: { string } = {}
	for _, item in items do
		if counts[item.className] == nil then
			counts[item.className] = 0
			table.insert(order, item.className)
		end
		counts[item.className] += 1
	end
	table.sort(order, function(a, b)
		if counts[a] ~= counts[b] then
			return counts[a] > counts[b]
		end
		return a < b
	end)

	local parts: { string } = {}
	for index = 1, math.min(#order, MAX_CLASSES_SHOWN) do
		local className = order[index]
		table.insert(parts, if counts[className] > 1 then `{className} ×{counts[className]}` else className)
	end
	if #order > MAX_CLASSES_SHOWN then
		table.insert(parts, `+{#order - MAX_CLASSES_SHOWN} more`)
	end
	return table.concat(parts, " · ")
end

function Format.summarize(items: { Item }): Summary
	local count = #items
	if count == 0 then
		return { kind = "none", count = 0, title = "No selection", detail = "Select an object in Explorer.", className = nil }
	end
	if count == 1 then
		return { kind = "single", count = 1, title = items[1].name, detail = items[1].className, className = items[1].className }
	end
	local shared: string? = items[1].className
	for _, item in items do
		if item.className ~= shared then
			shared = nil
			break
		end
	end
	return {
		kind = "multi",
		count = count,
		title = `{count} objects selected`,
		detail = Format.classBreakdown(items),
		className = shared,
	}
end

--- One line for the compact chip: "No selection", "MainModule · ModuleScript", "5 objects selected · Part ×3 · Script ×2".
--- When an object's name is its class name the class is not repeated.
function Format.oneLine(summary: Summary): string
	if summary.kind == "none" then
		return summary.title
	end
	if summary.detail == "" or summary.detail == summary.title then
		return summary.title
	end
	return `{summary.title} · {summary.detail}`
end

return Format
