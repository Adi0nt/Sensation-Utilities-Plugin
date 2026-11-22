--!strict
--- Module presets. They are not in the code: they are the scripts inside `presets.rbxm`, downloaded at startup the
--- same way `methods.rbxm` is, so a preset can be swapped, added or edited without touching the plugin.
---
--- A preset is a ModuleScript (or any script) inside that model: its name is the preset's name, its `Source` is
--- what gets written into the new `MainModule`, and an optional string attribute `Description` is the line shown
--- under the picker. Folders are looked through, so the model can be organised however you like. In the repository
--- the scripts live in `presets/` (one `.luau` file each, plus an optional `.meta.json` for the attribute) and
--- `rojo build presets.project.json -o presets.rbxm` packs them.

local Common = require("./Common")
local Methods = require("./Methods")
local Result = require("./Result")
local Types = require("./Types")

local Presets = {}
Presets.__index = Presets

type Self = typeof(setmetatable({} :: { presets: { [string]: Types.Preset } }, Presets))

--- Same keep-or-fall-back rule as the method picker.
Presets.pick = Methods.pick

function Presets.new(): Types.PresetStore
	return setmetatable({ presets = {} }, Presets) :: any
end

--- Replaces the whole preset set.
function Presets.set(self: Self, presets: { [string]: Types.Preset })
	self.presets = table.clone(presets)
end

--- Names in a stable order: case-insensitive first, the exact name as the tie-breaker.
function Presets.names(self: Self): { string }
	local names: { string } = {}
	for name in self.presets do
		table.insert(names, name)
	end
	table.sort(names, function(a, b)
		local la, lb = string.lower(a), string.lower(b)
		if la ~= lb then
			return la < lb
		end
		return a < b
	end)
	return names
end

function Presets.has(self: Self, name: string): boolean
	return self.presets[name] ~= nil
end

function Presets.source(self: Self, name: string): string?
	local preset = self.presets[name]
	return if preset then preset.source else nil
end

function Presets.description(self: Self, name: string): string
	local preset = self.presets[name]
	return if preset then preset.description else ""
end

--- Reads the deserialized `presets.rbxm` (its top-level instances). Scripts are presets; folders and models are
--- looked through, anything else is ignored. A later script with the same name replaces an earlier one.
function Presets.parse(roots: { Instance }): { [string]: Types.Preset }
	local found: { [string]: Types.Preset } = {}

	local function visit(instance: Instance)
		if instance:IsA("LuaSourceContainer") then
			local description = instance:GetAttribute("Description")
			found[instance.Name] = {
				source = (instance :: any).Source,
				description = if type(description) == "string" then description else "",
			}
		elseif instance:IsA("Folder") or instance:IsA("Model") then
			for _, child in instance:GetChildren() do
				visit(child)
			end
		end
	end

	for _, root in roots do
		visit(root)
	end
	return found
end

--- Creates a `MainModule` ModuleScript with the chosen preset inside every selected instance.
function Presets.insert(env: Types.Env, presetName: Types.PresetName): Types.Result
	local selected = Common.selected(env)
	if #selected == 0 then
		env.log.info("Nothing is selected to insert the preset into. Skipping...")
		return Result.skipped("Nothing is selected to insert the preset into.")
	end

	local source = env.presets:source(presetName)
	if source == nil then
		env.log.warn(`Preset "{presetName}" is not loaded.`)
		return Result.failure(`The preset "{presetName}" is not loaded. Try Reload.`)
	end

	env.history:record(`Sensation: Insert {presetName}`, function()
		for _, value: Instance in selected do
			Common.create(env, "ModuleScript", {
				Parent = value,
				Name = "MainModule",
				Source = source,
			})
		end
	end)

	env.log.info(`Inserted {presetName} into {#selected} object(s).`)
	return Result.success(`Inserted {presetName} into {#selected} {if #selected == 1 then "object" else "objects"}.`, #selected)
end

return Presets
