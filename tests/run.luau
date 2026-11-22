--!nocheck
--- Runs the pure-logic specs under Lune:  `lune run tests/run`
---
--- Only code that needs no Roblox engine is covered here (validation, formatting, method ordering, preset sources).
--- Everything that builds Instances or talks to Studio needs a manual run inside Studio (see the README).

local process = require("@lune/process")

local specs = {
	require("./spec/validation"),
	require("./spec/format"),
	require("./spec/methods"),
	require("./spec/presets"),
	require("./spec/cleaner"),
	require("./spec/placement"),
}

local passed, failed = 0, 0

local function test(name: string, fn: () -> ())
	local ok, err = pcall(fn)
	if ok then
		passed += 1
		print(`  ok    {name}`)
	else
		failed += 1
		print(`  FAIL  {name}\n        {tostring(err)}`)
	end
end

for _, spec in specs do
	print(spec.name)
	spec.run(test)
end

print(`\n{passed} passed, {failed} failed`)
if failed > 0 then
	process.exit(1)
end
