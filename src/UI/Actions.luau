--!strict
--- Connects the UI to the utility operations. Every operation runs through `run`, which:
---   * refuses to start while another action is running (no accidental double submits),
---   * marks the UI busy and shows a "working" status,
---   * asks for confirmation first when an operation could touch many instances,
---   * catches errors and turns every outcome into a status message.
---
--- Must be created inside a Flux scope so its timers are cancelled on unmount.

local Flux = require("../Flux")
local Operations = require("../Core/Operations")
local Result = require("../Core/Result")
local State = require("./State")
local Types = require("../Core/Types")

export type Actions = {
	bypass: () -> (),
	unbypass: () -> (),
	sandbox: () -> (),
	unsandbox: () -> (),
	cleanSounds: () -> (),
	insertPreset: () -> (),
	insertLatest: () -> (),
	insertVersion: () -> (),
	upload: () -> (),
	save: () -> (),
	spawn: (rig: Types.RigType) -> (),
	reloadMethods: () -> (),
	dismissStatus: () -> (),
	navigate: (page: State.Page) -> (),
	toggleNav: () -> (),
}

export type Config = {
	operations: Operations.Operations,
	log: Types.Log,
	--- Re-downloads the bypass methods into the method store. Yields. Returns the method count, or `nil, reason`.
	reloadMethods: () -> (number?, string?),
}

--- Operations touching more than this ask for confirmation first.
local CONFIRM_INSTANCES = 250 -- instances changed by sandbox / unsandbox / sound cleaning (including descendants)
local CONFIRM_TARGETS = 10 -- ModuleScripts bypassed, or objects an asset / preset is inserted into

--- Success and info messages fade back to "Ready" after this many seconds. Warnings and errors stay.
local AUTO_DISMISS_SECONDS = 10

local Actions = {}

function Actions.new(state: State.State, config: Config): Actions
	local ops = config.operations
	local selection = ops.env.selection

	local statusId = 0
	local dismissTimer: thread? = nil

	local function cancelDismissTimer()
		if dismissTimer ~= nil then
			Flux.Clock.cancel(dismissTimer)
			dismissTimer = nil
		end
	end
	Flux.cleanup(cancelDismissTimer)

	local function setStatus(level: Types.Level, text: string)
		cancelDismissTimer()
		statusId += 1
		local id = statusId
		state.status:set({ level = level, text = text, id = id })

		if level == "success" or level == "info" then
			dismissTimer = Flux.Clock.delay(AUTO_DISMISS_SECONDS, function()
				dismissTimer = nil
				local current = state.status:peek()
				if current ~= nil and current.id == id then
					state.status:set(nil)
				end
			end)
		end
	end

	--- Yields the calling action until the user answers the dialog.
	local function confirm(title: string, message: string, confirmLabel: string): boolean
		local thread = coroutine.running()
		state.confirm:set({
			title = title,
			message = message,
			confirmLabel = confirmLabel,
			resolve = function(confirmed: boolean)
				state.confirm:set(nil)
				task.spawn(thread, confirmed)
			end,
		})
		return coroutine.yield() :: boolean
	end

	--- `work` returns the operation's result, or `nil` when the user cancelled a confirmation.
	local function run(key: string, label: string, work: () -> Types.Result?)
		if state.busy:peek() ~= nil then
			return
		end
		state.busy:set(key)
		state.busyLabel:set(label)

		task.spawn(function()
			local ok, result: any = pcall(work)

			state.busy:set(nil)
			state.busyLabel:set(nil)

			if not ok then
				config.log.warn(`Unexpected error in {key}: {tostring(result)}`)
				setStatus("error", `Something went wrong: {tostring(result)}`)
			elseif result == nil then
				setStatus("info", "Cancelled. Nothing was changed.")
			else
				local outcome = result :: Types.Result
				setStatus(outcome.level, outcome.message)
			end
		end)
	end

	local function selectedCount(): number
		return #selection:Get()
	end

	return {
		bypass = function()
			run("bypass", "Bypassing ModuleScripts...", function()
				local modules = ops.countModules(selection:Get())
				if modules > CONFIRM_TARGETS then
					local mode, method = state.mode:peek(), state.method:peek()
					if not confirm(
						"Bypass many modules?",
						`This will bypass {modules} ModuleScripts ({mode} mode, "{method}").`,
						"Bypass"
					) then
						return nil
					end
				end
				return ops.bypass(state.mode:peek(), state.method:peek())
			end)
		end,

		unbypass = function()
			run("unbypass", "Extracting original modules...", function()
				local modules = ops.countModules(selection:Get())
				if modules > CONFIRM_TARGETS then
					if not confirm(
						"Unbypass many modules?",
						`This will extract the original from {modules} ModuleScripts.`,
						"Unbypass"
					) then
						return nil
					end
				end
				return ops.unbypass()
			end)
		end,

		sandbox = function()
			run("sandbox", "Sandboxing selection...", function()
				local affected = ops.affectedCount(selection:Get())
				if affected > CONFIRM_INSTANCES then
					if not confirm(
						"Sandbox many instances?",
						`The selection and its descendants add up to {affected} instances. All of them will be sandboxed.`,
						"Sandbox"
					) then
						return nil
					end
				end
				return ops.sandbox()
			end)
		end,

		unsandbox = function()
			run("unsandbox", "Unsandboxing selection...", function()
				local affected = ops.affectedCount(selection:Get())
				if affected > CONFIRM_INSTANCES then
					if not confirm(
						"Unsandbox many instances?",
						`The selection and its descendants add up to {affected} instances. All of them will be unsandboxed.`,
						"Unsandbox"
					) then
						return nil
					end
				end
				return ops.unsandbox()
			end)
		end,

		cleanSounds = function()
			run("clean", "Cleaning sounds...", function()
				local affected = ops.affectedCount(selection:Get())
				if affected > CONFIRM_INSTANCES then
					if not confirm(
						"Scan a large selection?",
						`The selection and its descendants add up to {affected} instances. Unloaded sounds in all of them will lose their SoundId.`,
						"Clean"
					) then
						return nil
					end
				end
				local result = ops.cleanSounds()
				if result.ok or result.level ~= "warning" then
					state.cleanerResult:set(result.message)
				end
				return result
			end)
		end,

		insertPreset = function()
			run("preset", "Inserting preset...", function()
				local targets = selectedCount()
				if targets > CONFIRM_TARGETS then
					if not confirm(
						"Insert into many objects?",
						`A MainModule will be created inside each of the {targets} selected objects.`,
						"Insert"
					) then
						return nil
					end
				end
				return ops.insertPreset(state.preset:peek())
			end)
		end,

		insertLatest = function()
			run("latest", "Loading the latest version...", function()
				local targets = selectedCount()
				if targets > CONFIRM_TARGETS then
					if not confirm(
						"Insert into many objects?",
						`The asset will be cloned into each of the {targets} selected objects.`,
						"Insert"
					) then
						return nil
					end
				end
				return ops.insertAsset(state.assetId:peek(), nil, true)
			end)
		end,

		insertVersion = function()
			run("version", "Loading the asset version...", function()
				local targets = selectedCount()
				if targets > CONFIRM_TARGETS then
					if not confirm(
						"Insert into many objects?",
						`The asset will be cloned into each of the {targets} selected objects.`,
						"Insert"
					) then
						return nil
					end
				end
				return ops.insertAsset(state.assetId:peek(), state.assetVersion:peek(), false)
			end)
		end,

		upload = function()
			run("upload", "Opening the upload prompt...", function()
				return ops.uploadSelection()
			end)
		end,

		save = function()
			run("save", "Waiting for the save dialog...", function()
				return ops.saveSelection()
			end)
		end,

		spawn = function(rig: Types.RigType)
			run(`spawn{rig}`, `Creating the {rig} StarterCharacter...`, function()
				if ops.hasStarterCharacter() then
					if not confirm(
						"Add another StarterCharacter?",
						"StarterPlayer already contains a StarterCharacter. Roblox only uses one, so you will need to delete the extra.",
						"Spawn anyway"
					) then
						return nil
					end
				end
				return ops.spawnCharacter(rig)
			end)
		end,

		reloadMethods = function()
			run("reload", "Reloading bypass methods...", function()
				local count, reason = config.reloadMethods()
				if count == nil then
					return Result.failure(`Could not reload the methods. {reason or ""}`)
				end
				state.refreshMethods()
				return Result.success(`Loaded {count} bypass {if count == 1 then "method" else "methods"}.`, count)
			end)
		end,

		dismissStatus = function()
			cancelDismissTimer()
			state.status:set(nil)
		end,

		toggleNav = function()
			state.navOverride:set(not state.compactNav:peek())
		end,

		navigate = function(page: State.Page)
			state.page:set(page)
		end,
	}
end

return Actions
