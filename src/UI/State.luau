--!strict
--- UI state: one authoritative signal per value, plus the derived (computed) values the pages and components bind
--- to. Must be created inside a Flux scope (see `App.mount`) so its selection connections are torn down on unmount.
---
--- Nothing here performs an operation. That is `Actions`, which calls the `Core` layer.

local Flux = require("../Flux")
local ConfirmationDialog = require("./Components/ConfirmationDialog")
local Format = require("../Core/Format")
local Methods = require("../Core/Methods")
local Operations = require("../Core/Operations")
local StatusMessage = require("./Components/StatusMessage")
local Theme = require("./Theme")
local Types = require("../Core/Types")
local Validation = require("../Core/Validation")

export type Page = "Modules" | "Marketplace" | "Studio"

export type Status = {
	level: Types.Level,
	text: string,
	id: number,
}

--- `nil` means the action is available, otherwise the reason it is not (shown as a tooltip on the disabled control).
export type Gate = Flux.Node<string?>

export type State = {
	page: Flux.State<Page>,

	-- Studio selection (mirrors `Selection`, updated on SelectionChanged)
	selected: Flux.State<{ Instance }>,
	summary: Flux.Node<Format.Summary>,
	hasSelection: Flux.Node<boolean>,
	moduleCount: Flux.Node<number>,

	-- Modules
	methodNames: Flux.State<{ string }>,
	method: Flux.State<string>,
	mode: Flux.State<Types.BypassMode>,
	preset: Flux.State<Types.PresetName>,
	--- Outcome of the last sound clean ("Cleaned 3 sounds."), shown under the Clean button.
	cleanerResult: Flux.State<string?>,

	-- Marketplace
	assetId: Flux.State<string>,
	assetVersion: Flux.State<string>,
	assetIdError: Flux.Node<string?>,
	assetVersionError: Flux.Node<string?>,

	-- Feedback
	busy: Flux.State<string?>,
	busyLabel: Flux.State<string?>,
	status: Flux.State<Status?>,
	statusLine: Flux.Node<StatusMessage.Line>,
	confirm: Flux.State<ConfirmationDialog.Request?>,

	-- Chrome
	commit: Flux.State<string>,
	width: Flux.Node<number>,
	compactNav: Flux.Node<boolean>,
	stackCards: Flux.Node<boolean>,

	-- Which actions are currently available
	gate: {
		bypass: Gate,
		unbypass: Gate,
		sandbox: Gate,
		unsandbox: Gate,
		cleanSounds: Gate,
		insertPreset: Gate,
		insertLatest: Gate,
		insertVersion: Gate,
		upload: Gate,
		save: Gate,
		spawn: Gate,
		reloadMethods: Gate,
	},

	--- Re-reads the method store into `methodNames`, keeping the selected method when it still exists.
	refreshMethods: () -> (),
}

export type Config = {
	selection: Selection,
	operations: Operations.Operations,
	methods: Types.MethodStore,
	--- The dock widget (its size drives the responsive layout).
	widget: LayerCollector,
	commit: string,
}

--- Selected instances are watched for renames only up to this many, so a huge selection stays cheap.
local MAX_NAME_WATCH = 25

local function watchSelection(selection: Selection, selected: Flux.State<{ Instance }>)
	local nameConnections: { RBXScriptConnection } = {}

	local function refresh()
		Flux.dispose(nameConnections)
		table.clear(nameConnections)

		local items = selection:Get()
		selected:set(items, true)
		for index = 1, math.min(#items, MAX_NAME_WATCH) do
			table.insert(
				nameConnections,
				items[index]:GetPropertyChangedSignal("Name"):Connect(function()
					selected:set(selected:peek(), true) -- names changed: re-run summaries without a new list
				end)
			)
		end
	end

	Flux.cleanup(selection.SelectionChanged:Connect(refresh))
	Flux.cleanup(function()
		Flux.dispose(nameConnections)
	end)
	refresh()
end

local State = {}

function State.new(config: Config): State
	local ops = config.operations

	local selected = Flux.signal({} :: { Instance })
	watchSelection(config.selection, selected)

	local summary = Flux.computed(function(): Format.Summary
		local items = selected()
		local plain: { Format.Item } = {}
		for index, instance in items do
			plain[index] = { name = instance.Name, className = instance.ClassName }
		end
		return Format.summarize(plain)
	end)
	local hasSelection = Flux.computed(function()
		return #selected() > 0
	end)
	local moduleCount = Flux.computed(function()
		return ops.countModules(selected())
	end)

	-- Bypass methods ---------------------------------------------------------------------------------------------
	local methodNames = Flux.signal({} :: { string })
	local method = Flux.signal("")

	local function refreshMethods()
		local names = config.methods:names()
		methodNames:set(names)
		method:set(Methods.pick(names, method:peek()))
	end
	refreshMethods()

	-- Marketplace inputs -----------------------------------------------------------------------------------------
	local assetId = Flux.signal("")
	local assetVersion = Flux.signal("")

	local assetIdError = Flux.computed(function(): string?
		local text = assetId()
		if text == "" then
			return nil -- do not nag before the user has typed anything
		end
		local _, message = Validation.parseAssetId(text)
		return message
	end)
	local assetVersionError = Flux.computed(function(): string?
		local _, message = Validation.parseVersion(assetVersion())
		return message
	end)
	local assetIdValid = Flux.computed(function()
		return (Validation.parseAssetId(assetId())) ~= nil
	end)
	local versionValue = Flux.computed(function(): number?
		return (Validation.parseVersion(assetVersion()))
	end)

	-- Feedback ---------------------------------------------------------------------------------------------------
	local busy = Flux.signal(nil :: string?)
	local busyLabel = Flux.signal(nil :: string?)
	local status = Flux.signal(nil :: Status?)
	local confirm = Flux.signal(nil :: ConfirmationDialog.Request?)

	local statusLine = Flux.computed(function(): StatusMessage.Line
		local working = busyLabel()
		if working ~= nil then
			return { level = "info", text = working, busy = true, dismissible = false }
		end
		local current = status()
		if current ~= nil then
			return { level = current.level, text = current.text, busy = false, dismissible = true }
		end
		return { level = "idle", text = "Ready", busy = false, dismissible = false }
	end)

	-- Layout -----------------------------------------------------------------------------------------------------
	local widgetSize = Flux.property(config.widget, "AbsoluteSize") :: Flux.Node<Vector2>
	local width = Flux.computed(function()
		return widgetSize().X
	end)
	local compactNav = Flux.computed(function()
		local current = width()
		return current > 0 and current < Theme.breakpoint.compactNav
	end)
	local stackCards = Flux.computed(function()
		-- Based on the room the page actually has: the window minus the sidebar and the page padding.
		local sidebar = if compactNav() then Theme.size.sidebarCompact else Theme.size.sidebar
		local content = width() - sidebar - Theme.size.pagePadding * 2
		return width() > 0 and content < Theme.breakpoint.stackCards
	end)

	-- Availability -----------------------------------------------------------------------------------------------
	local function gate(check: () -> string?): Gate
		return Flux.computed(function(): string?
			if busy() ~= nil then
				return "Another action is still running."
			end
			return check()
		end)
	end

	local function needsSelection(message: string): () -> string?
		return function()
			return if hasSelection() then nil else message
		end
	end

	return {
		page = Flux.signal("Modules" :: Page),

		selected = selected,
		summary = summary,
		hasSelection = hasSelection,
		moduleCount = moduleCount,

		methodNames = methodNames,
		method = method,
		mode = Flux.signal("Insert" :: Types.BypassMode),
		preset = Flux.signal("Advanced Module" :: Types.PresetName),
		cleanerResult = Flux.signal(nil :: string?),

		assetId = assetId,
		assetVersion = assetVersion,
		assetIdError = assetIdError,
		assetVersionError = assetVersionError,

		busy = busy,
		busyLabel = busyLabel,
		status = status,
		statusLine = statusLine,
		confirm = confirm,

		commit = Flux.signal(config.commit),
		width = width,
		compactNav = compactNav,
		stackCards = stackCards,

		gate = {
			bypass = gate(function()
				if not hasSelection() then
					return "Select one or more ModuleScripts in Explorer."
				elseif moduleCount() == 0 then
					return "The selection contains no ModuleScripts."
				elseif #methodNames() == 0 then
					return "No bypass methods are loaded. Try Reload."
				end
				return nil
			end),
			unbypass = gate(function()
				if not hasSelection() then
					return "Select one or more ModuleScripts in Explorer."
				elseif moduleCount() == 0 then
					return "The selection contains no ModuleScripts."
				end
				return nil
			end),
			sandbox = gate(needsSelection("Select an object in Explorer.")),
			unsandbox = gate(needsSelection("Select an object in Explorer.")),
			cleanSounds = gate(needsSelection("Select a Sound, or a model containing sounds.")),
			insertPreset = gate(needsSelection("Select where the module should be created.")),
			insertLatest = gate(function()
				if not assetIdValid() then
					return "Enter a valid asset ID."
				elseif not hasSelection() then
					return "Select where the asset should be inserted."
				end
				return nil
			end),
			insertVersion = gate(function()
				if not assetIdValid() then
					return "Enter a valid asset ID."
				elseif assetVersion() == "" then
					return "Enter a version number, or use Insert Latest."
				elseif versionValue() == nil then
					return assetVersionError() or "Enter a valid version number."
				elseif not hasSelection() then
					return "Select where the asset should be inserted."
				end
				return nil
			end),
			upload = gate(needsSelection("Select something to upload.")),
			save = gate(needsSelection("Select something to save.")),
			spawn = gate(function()
				return nil
			end),
			reloadMethods = gate(function()
				return nil
			end),
		},

		refreshMethods = refreshMethods,
	}
end

return State
