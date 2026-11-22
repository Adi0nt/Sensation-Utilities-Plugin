--!strict
--- The utility operations as one object. This is the only thing the UI talks to: it knows nothing about the UI framework or any GUI
--- and every function returns a `Types.Result` (or throws, which the UI turns into an error message).

local Bypass = require("./Bypass")
local Cleaner = require("./Cleaner")
local Marketplace = require("./Marketplace")
local Presets = require("./Presets")
local Sandbox = require("./Sandbox")
local Studio = require("./Studio")
local Types = require("./Types")

export type Operations = {
	env: Types.Env,

	-- Modules
	bypass: (mode: Types.BypassMode, methodName: string?) -> Types.Result,
	unbypass: () -> Types.Result,
	sandbox: () -> Types.Result,
	unsandbox: () -> Types.Result,
	cleanSounds: () -> Types.Result,
	--- Looks for asset references in the selection that Studio cannot load. Yields. `onProgress(done, total)` reports it.
	scanAssets: (onProgress: ((done: number, total: number) -> ())?) -> (Types.Result, Types.ScanReport?),
	--- Clears the given broken assets: blanks their properties, or removes the instances that hold them.
	cleanAssets: (broken: { Types.BrokenAsset }, removeInstances: boolean) -> Types.Result,
	insertPreset: (preset: Types.PresetName) -> Types.Result,

	-- Marketplace (insertAsset, saveSelection yield)
	insertAsset: (idText: string, versionText: string?, latest: boolean) -> Types.Result,
	uploadSelection: () -> Types.Result,
	saveSelection: () -> Types.Result,

	-- Studio (spawnCharacter yields)
	spawnCharacter: (rig: Types.RigType) -> Types.Result,
	hasStarterCharacter: () -> boolean,

	-- Impact estimates used to decide whether to ask for confirmation first
	countModules: (instances: { Instance }) -> number,
	affectedCount: (instances: { Instance }) -> number,
}

local Operations = {}

function Operations.new(env: Types.Env): Operations
	return {
		env = env,

		bypass = function(mode, methodName)
			return Bypass.bypass(env, mode, methodName)
		end,
		unbypass = function()
			return Bypass.unbypass(env)
		end,
		sandbox = function()
			return Sandbox.sandbox(env)
		end,
		unsandbox = function()
			return Sandbox.unsandbox(env)
		end,
		cleanSounds = function()
			return Cleaner.cleanSounds(env)
		end,
		scanAssets = function(onProgress)
			return Cleaner.scan(env, onProgress)
		end,
		cleanAssets = function(broken, removeInstances)
			return Cleaner.clean(env, broken, removeInstances)
		end,
		insertPreset = function(preset)
			return Presets.insert(env, preset)
		end,

		insertAsset = function(idText, versionText, latest)
			return Marketplace.insertAsset(env, idText, versionText, latest)
		end,
		uploadSelection = function()
			return Marketplace.uploadSelection(env)
		end,
		saveSelection = function()
			return Marketplace.saveSelection(env)
		end,

		spawnCharacter = function(rig)
			return Studio.spawnCharacter(env, rig)
		end,
		hasStarterCharacter = Studio.hasStarterCharacter,

		countModules = Bypass.countModules,
		affectedCount = Sandbox.affectedCount,
	}
end

return Operations
