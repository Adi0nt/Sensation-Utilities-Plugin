--!strict
--- Module bypass: Insert / Append / Unbypass. The transformations are ported unchanged from the previous plugin;
--- only the method lookup is now deterministic and results are returned instead of only logged.

local Common = require("./Common")
local Result = require("./Result")
local Types = require("./Types")

local APPEND_LOADER_SOURCE =
	'local moduleScript=script:FindFirstChildWhichIsA("ModuleScript",true)\nmoduleScript.Parent=nil\nscript:ClearAllChildren()\nmoduleScript.Parent=script\nreturn require(moduleScript)'

local Bypass = {}

local function modulesOf(instances: { Instance }): { ModuleScript }
	local modules: { ModuleScript } = {}
	for _, value in instances do
		if value:IsA("ModuleScript") then
			table.insert(modules, value)
		end
	end
	return modules
end

--- Clones the module next to itself with the method's children inside it.
local function insertOne(env: Types.Env, moduleScript: ModuleScript, container: Instance): Instance
	env.log.info(`Inserted {moduleScript.Name} using {container.Name}`)

	local children = container:GetChildren()
	for index, child in children do
		children[index] = child:Clone()
	end

	local created = Common.clone(env, moduleScript:Clone() :: Instance, {
		Parent = moduleScript.Parent,
	}, children)
	env.selection:Set({ created })
	return created
end

--- Wraps the module in a new `MainModule` that requires it through the method.
local function appendOne(env: Types.Env, moduleScript: ModuleScript, container: Instance): Instance
	env.log.info(`Appended {moduleScript.Name} using {container.Name}`)

	local created = Common.create(env, "ModuleScript", {
		Parent = moduleScript.Parent,
		Name = "MainModule",
		Source = APPEND_LOADER_SOURCE,
	}, {
		Common.clone(env, container:GetChildren()[1], nil, { moduleScript:Clone() :: Instance }),
	})
	env.selection:Set({ created })
	return created
end

--- Extracts the original module from a bypassed one (or clones it as-is when nothing is embedded).
local function extractOne(env: Types.Env, moduleScript: ModuleScript): (Instance, boolean)
	local originalModule = moduleScript:FindFirstChildWhichIsA("ModuleScript", true)
	if not originalModule then
		env.log.info(`Extracted {moduleScript.Name} from itself.`)
		local created = Common.clone(env, moduleScript, { Parent = moduleScript.Parent })
		env.selection:Set({ created })
		return created, false
	end
	env.log.info(`Extracted {originalModule.Name} from {moduleScript.Name}`)
	local created = Common.clone(env, originalModule, { Parent = moduleScript.Parent })
	env.selection:Set({ created })
	return created, true
end

--- Bypasses the selected ModuleScripts with `methodName` in the given mode.
function Bypass.bypass(env: Types.Env, mode: Types.BypassMode, methodName: string?): Types.Result
	local selected = Common.selected(env)
	if #selected == 0 then
		env.log.info("Nothing is selected to bypass. Skipping...")
		return Result.skipped("Nothing is selected to bypass.")
	end

	local modules = modulesOf(selected)
	if #modules == 0 then
		return Result.skipped("Select one or more ModuleScripts to bypass.")
	end

	local resolvedName, container = env.methods:resolve(methodName)
	if resolvedName == nil or container == nil then
		env.log.warn("No bypass method available. Ensure methods.rbxm is loaded.")
		return Result.failure("No bypass method available. Reload the methods or check your connection.")
	end
	local method: Instance = container

	env.history:record(`Sensation: {mode} bypass`, function()
		for _, moduleScript in modules do
			if mode == "Insert" then
				insertOne(env, moduleScript, method)
			elseif mode == "Append" then
				appendOne(env, moduleScript, method)
			end
		end
	end)

	local noun = if #modules == 1 then "ModuleScript" else "ModuleScripts"
	return Result.success(`Bypassed {#modules} {noun} ({mode} · {resolvedName}).`, #modules)
end

--- Extracts the original modules from the selected bypassed ModuleScripts.
function Bypass.unbypass(env: Types.Env): Types.Result
	local selected = Common.selected(env)
	if #selected == 0 then
		env.log.info("Nothing is selected to unbypass. Skipping...")
		return Result.skipped("Nothing is selected to unbypass.")
	end

	local modules = modulesOf(selected)
	if #modules == 0 then
		return Result.skipped("Select one or more ModuleScripts to unbypass.")
	end

	local standalone = 0
	env.history:record("Sensation: Unbypass", function()
		for _, moduleScript in modules do
			local _, hadOriginal = extractOne(env, moduleScript)
			if not hadOriginal then
				standalone += 1
			end
		end
	end)

	local noun = if #modules == 1 then "ModuleScript" else "ModuleScripts"
	if standalone > 0 then
		return Result.warning(
			`Extracted {#modules} {noun}. {standalone} had no embedded module and was copied as-is.`,
			#modules
		)
	end
	return Result.success(`Extracted the original from {#modules} {noun}.`, #modules)
end

--- Counts how many ModuleScripts are in `instances` (for enabling buttons and for the confirmation threshold).
function Bypass.countModules(instances: { Instance }): number
	return #modulesOf(instances)
end

return Bypass
