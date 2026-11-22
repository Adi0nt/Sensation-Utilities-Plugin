--!strict
--- Sensation Utilities: plugin lifecycle.
---
--- This file is fetched and run by `loader.luau` / `Plugin.rbxmx`. It only wires things together:
---   * downloads `packages.rbxm` (Maid, RawLib), `methods.rbxm` (bypass methods), `presets.rbxm` (module presets)
---     and `ui.rbxm` (Flux + the UI),
---   * creates the toolbar button and the place the panel lives in: a dockable widget (the default) or, for people who
---     do not want docking, a floating window in CoreGui (chosen on the Settings page and remembered),
---   * mounts the Flux UI into that place and unmounts it again when the plugin unloads.
---
--- The utility operations live in `src/Core`, the interface in `src/UI` (both packaged into `ui.rbxm`).

local selection = game:GetService("Selection")
local serializationService = game:GetService("SerializationService")
local changeHistoryService = game:GetService("ChangeHistoryService")
local coreGui = game:GetService("CoreGui")

local REPO = "Adi0nt/Sensation-Utilities-Plugin"
-- Development only: `dev/SensationDev.lua` sets `shared.SensationDevBase` (e.g. "http://localhost:8000/") so the
-- packages, methods, presets and UI are served from a local checkout instead of GitHub. Normal installs never set it.
local devBase = (shared :: any).SensationDevBase
local RAW_MAIN = if type(devBase) == "string" then devBase else `https://github.com/{REPO}/raw/refs/heads/main/`
local RAW_FRESH = if type(devBase) == "string"
	then devBase
	else `https://raw.githubusercontent.com/{REPO}/refs/heads/main/`

--- Marks the runtime folder so a leftover one (from an unload that never finished) is removed on the next start.
local RUNTIME_FOLDER_NAME = "SensationUtilities_Runtime"
local FLOATING_GUI_NAME = "SensationUtilities_Floating"
local WIDGET_ID = "SensationUtilities"

-- Plugin settings (kept by Studio, per user).
local SETTING_MODE = "SensationUtilities_WindowMode" -- "Dock" (default) | "Floating"
local SETTING_RECT = "SensationUtilities_FloatingRect" -- where the floating window was left
local SETTING_OPEN = "SensationUtilities_FloatingOpen" -- whether the floating window was open

local function println(output: string)
	print(`[Sensation Utilities]: {output}`)
end

local function warnln(output: string)
	warn(`[Sensation Utilities]: {output}`)
end

-- Toolbar ----------------------------------------------------------------------------------------------------------

local toolbar = plugin:CreateToolbar("Sensation")
local button =
	toolbar:CreateButton("Sensation Utilities", "Toggles the built-in interface.", Content.fromAssetId(16517502292).Uri :: string)
button.ClickableWhenViewportHidden = true

-- Downloading ------------------------------------------------------------------------------------------------------

local httpService = game:GetService("HttpService")

--- Same retrying download the plugin has always used.
local function getAsync(url: string, maxRetries: number?): string?
	local retries = maxRetries or 5
	local attempts = 0
	local success, body: any = false, nil

	repeat
		success, body = pcall(httpService.GetAsync, httpService, url)
		if success then
			return body :: string
		end

		attempts += 1
		if attempts <= retries then
			println(`Buffering... (Attempt {attempts}/{retries})`)
			task.wait(1)
		end
	until success or attempts > retries

	warnln(`Failed to fetch URL after {retries} attempts.`)
	return nil
end

local function deserializeInstancesAsync(...): { Instance }
	local ok, result = pcall(serializationService.DeserializeInstancesAsync, serializationService, ...)
	if ok then
		return result :: { Instance }
	end
	warnln(`Could not read a downloaded package: {tostring(result)}`)
	return {}
end

--- Downloads an .rbxm and returns its top-level instances (empty on failure).
local function fetchModel(url: string, maxRetries: number?): { Instance }
	local body = getAsync(url, maxRetries)
	if not body then
		return {}
	end
	return deserializeInstancesAsync(buffer.fromstring(body))
end

-- Lifecycle state --------------------------------------------------------------------------------------------------

local unloaded = false
local connections: { RBXScriptConnection } = {}
local cleanups: { () -> () } = {}

local function track(connection: RBXScriptConnection)
	table.insert(connections, connection)
end

local function teardown()
	unloaded = true
	for _, connection in connections do
		connection:Disconnect()
	end
	table.clear(connections)
	-- Last registered, first cleaned (UI before the modules it runs from).
	for index = #cleanups, 1, -1 do
		local ok, err = pcall(cleanups[index])
		if not ok then
			warnln(`Cleanup error: {tostring(err)}`)
		end
	end
	table.clear(cleanups)
end

track(plugin.Unloading:Connect(function()
	println("Closing plugin...")
	teardown()
	println("Closed plugin.")
end))

-- Dependencies -----------------------------------------------------------------------------------------------------

-- A previous instance that never unloaded cleanly must not leave a second set of modules behind.
for _, leftover in coreGui:GetChildren() do
	if leftover.Name == RUNTIME_FOLDER_NAME or leftover.Name == FLOATING_GUI_NAME then
		leftover:Destroy()
	end
end

println("Loading packages...")
local packages: { [string]: Instance } = {}
for _, value in fetchModel(`{RAW_MAIN}packages.rbxm`) do
	packages[value.Name] = value
end
if next(packages) == nil then
	warnln("Critical Error: Packages failed to load.")
	return
end
println("Loaded packages.")

println("Loading UI...")
local runtime = Instance.new("Folder")
runtime.Name = RUNTIME_FOLDER_NAME
-- Kept inside the DataModel (CoreGui is never saved with the place) so the modules' relative requires resolve.
runtime.Parent = coreGui
table.insert(cleanups, function()
	runtime:Destroy()
end)

local uiRoot: Instance? = nil
for _, value in fetchModel(`{RAW_FRESH}ui.rbxm?t={os.time()}`) do
	if value.Name == "SensationUI" then
		uiRoot = value
	else
		value:Destroy()
	end
end
if not uiRoot then
	warnln("Critical Error: UI failed to load.")
	teardown()
	return
end
uiRoot.Parent = runtime
println("Loaded UI.")

local rawLib = require(packages.RawLib :: ModuleScript) :: any
local maid = (require(packages.Maid :: ModuleScript) :: any).new()
table.insert(cleanups, function()
	maid:Destroy()
end)

local Flux = require((uiRoot :: any).Flux) :: any
local Log = require((uiRoot :: any).Core.Log) :: any
local History = require((uiRoot :: any).Core.History) :: any
local Methods = require((uiRoot :: any).Core.Methods) :: any
local Http = require((uiRoot :: any).Core.Http) :: any
local Operations = require((uiRoot :: any).Core.Operations) :: any
local Presets = require((uiRoot :: any).Core.Presets) :: any
local Placement = require((uiRoot :: any).Core.Placement) :: any
local FloatingWindow = require((uiRoot :: any).UI.FloatingWindow) :: any
local App = require((uiRoot :: any).UI.App) :: any
local Theme = require((uiRoot :: any).UI.Theme) :: any

-- Bypass methods ---------------------------------------------------------------------------------------------------

local methods = Methods.new()

--- (Re)downloads methods.rbxm into the method store. Yields. Returns the method count, or `nil, reason`.
local function loadMethods(): (number?, string?)
	local body = Http.get(`{RAW_FRESH}methods.rbxm?t={os.time()}`, Log)
	if body == nil then
		return nil, "The download failed. Check your connection."
	end

	local containers: { [string]: Instance } = {}
	local count = 0
	for _, value in deserializeInstancesAsync(buffer.fromstring(body)) do
		containers[value.Name] = value
		count += 1
	end
	if count == 0 then
		return nil, "The download contained no methods."
	end
	methods:set(containers)
	return count, nil
end

println("Loading methods...")
local loadedCount = loadMethods()
if loadedCount then
	println(`Loaded {loadedCount} method(s).`)
else
	warnln("Critical Error: Methods failed to load.")
end

-- Module presets ---------------------------------------------------------------------------------------------------

local presets = Presets.new()

--- (Re)downloads presets.rbxm into the preset store. Yields. Returns the preset count, or `nil, reason`.
local function loadPresets(): (number?, string?)
	local body = Http.get(`{RAW_FRESH}presets.rbxm?t={os.time()}`, Log)
	if body == nil then
		return nil, "The download failed. Check your connection."
	end

	local found = Presets.parse(deserializeInstancesAsync(buffer.fromstring(body)))
	local count = 0
	for _ in found do
		count += 1
	end
	if count == 0 then
		return nil, "The download contained no presets."
	end
	presets:set(found)
	return count, nil
end

println("Loading presets...")
local loadedPresets = loadPresets()
if loadedPresets then
	println(`Loaded {loadedPresets} preset(s).`)
else
	warnln("Presets failed to load. Module presets are unavailable until you press Reload.")
end

-- Window -----------------------------------------------------------------------------------------------------------
-- The panel lives in a "host": a dock widget (default) or the floating CoreGui window. Both are layer collectors with an
-- `Enabled` property, so the toolbar button treats them the same. `container` is what the UI is mounted into.

type WindowMode = "Dock" | "Floating"
type Host = {
	gui: any, -- DockWidgetPluginGui | ScreenGui
	container: GuiBase2d,
	destroy: () -> (),
}

local function readSetting(key: string): any
	local ok, value = pcall(function()
		return plugin:GetSetting(key)
	end)
	return if ok then value else nil
end

local function writeSetting(key: string, value: any)
	pcall(function()
		plugin:SetSetting(key, value)
	end)
end

local widgetInfo = DockWidgetPluginGuiInfo.new(
	Enum.InitialDockState.Right, -- first-time placement; Studio remembers where the user docks it afterwards
	false, -- not enabled until the toolbar button is used
	false, -- keep the user's previous enabled state
	400, -- floating width
	680, -- floating height
	320, -- minimum width
	400 -- minimum height
)

--- CreateDockWidgetPluginGui is deprecated in favour of the yielding CreateDockWidgetPluginGuiAsync.
local function createWidget(): DockWidgetPluginGui
	local pluginAny: any = plugin
	local hasAsync, asyncMethod = pcall(function()
		return pluginAny.CreateDockWidgetPluginGuiAsync
	end)
	if hasAsync and asyncMethod ~= nil then
		return pluginAny:CreateDockWidgetPluginGuiAsync(WIDGET_ID, widgetInfo)
	end
	return pluginAny:CreateDockWidgetPluginGui(WIDGET_ID, widgetInfo)
end

-- Created the first time the dock is needed and kept for the session (a widget id can only be created once). Someone who
-- only uses the floating window never gets a dock widget at all.
local dockWidget: DockWidgetPluginGui? = nil

local function dockHost(enabled: boolean?): Host
	if dockWidget == nil then
		local created = createWidget()
		created.Name = WIDGET_ID
		created.Title = "Sensation Utilities"
		created.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
		dockWidget = created
	end
	local widget = dockWidget :: DockWidgetPluginGui
	if enabled ~= nil then
		widget.Enabled = enabled
	end
	return {
		gui = widget,
		container = widget,
		-- The widget stays (it cannot be created again); switching away just hides it.
		destroy = function()
			widget.Enabled = false
		end,
	}
end

local floatingRect = Placement.decode(readSetting(SETTING_RECT))

local function floatingHost(enabled: boolean?): Host
	local window = FloatingWindow.create({
		parent = coreGui,
		title = "Sensation Utilities",
		rect = floatingRect,
		enabled = enabled == true,
		onRect = function(placed)
			floatingRect = placed
			writeSetting(SETTING_RECT, placed)
		end,
	})
	return {
		gui = window.gui,
		container = window.content,
		destroy = function()
			-- Remember a placement the user has not moved yet too, so a rebuilt window reopens where it was.
			floatingRect = window.rect() or floatingRect
			window.destroy()
		end,
	}
end

local currentMode: WindowMode = if readSetting(SETTING_MODE) == "Floating" then "Floating" else "Dock"

--- Builds the host for `mode`. The floating window can fail to open (CoreGui is protected); fall back to the dock then.
local function createHost(mode: WindowMode, enabled: boolean?): (Host, WindowMode)
	if mode == "Floating" then
		local ok, host = pcall(floatingHost, enabled)
		if ok then
			return host, "Floating"
		end
		warnln(`Could not open the floating window ({tostring(host)}). Using the dock widget instead.`)
	end
	return dockHost(enabled), "Dock"
end

local host: Host
host, currentMode =
	createHost(currentMode, if currentMode == "Floating" then readSetting(SETTING_OPEN) == true else nil)

if unloaded then
	if currentMode == "Floating" then
		host.destroy()
	end
	return
end

-- UI ---------------------------------------------------------------------------------------------------------------

local operations = Operations.new({
	plugin = plugin,
	selection = selection,
	history = History.new(changeHistoryService, Log),
	log = Log,
	methods = methods,
	presets = presets,
	contentProvider = game:GetService("ContentProvider"),
	newIndex = rawLib.instance_newindex,
})

local app: any
local remount: (mode: WindowMode, rebuildHost: boolean) -> ()

local function mountApp(commit: string): any
	return App.mount({
		widget = host.container,
		windowMode = currentMode,
		-- Called from a click inside the UI that is about to be rebuilt, so the switch waits until that click has finished.
		setWindowMode = function(mode: WindowMode)
			task.defer(function()
				if unloaded or mode == currentMode then
					return
				end
				writeSetting(SETTING_MODE, mode)
				remount(mode, true)
			end)
		end,
		operations = operations,
		methods = methods,
		presets = presets,
		log = Log,
		commit = commit,
		reloadMethods = function()
			local count, reason = loadMethods()
			if count then
				Log.info(`Loaded {count} method(s).`)
			end
			return count, reason
		end,
		reloadPresets = function()
			local count, reason = loadPresets()
			if count then
				Log.info(`Loaded {count} preset(s).`)
			end
			return count, reason
		end,
	})
end

-- Toolbar button <-> host ------------------------------------------------------------------------------------------

local hostConnection: RBXScriptConnection? = nil

--- Points the toolbar button (and the remembered open state) at the current host.
local function bindHost()
	if hostConnection then
		hostConnection:Disconnect()
	end
	local gui = host.gui
	button:SetActive(gui.Enabled)
	hostConnection = gui:GetPropertyChangedSignal("Enabled"):Connect(function()
		button:SetActive(gui.Enabled)
		if currentMode == "Floating" then
			writeSetting(SETTING_OPEN, gui.Enabled)
		end
	end)
end

track(button.Click:Connect(function()
	host.gui.Enabled = not host.gui.Enabled
end))

--- Rebuilds the interface, keeping the page you were on. With `rebuildHost` the window is made again too: after a switch
--- between dock and floating, or when the floating window's own chrome needs the new theme colours.
function remount(mode: WindowMode, rebuildHost: boolean)
	local page, commit = app.state.page:peek(), app.state.commit:peek()
	local enabled = host.gui.Enabled
	app.unmount()
	Theme.refresh()

	if rebuildHost or mode ~= currentMode then
		if hostConnection then
			hostConnection:Disconnect()
			hostConnection = nil
		end
		host.destroy()
		-- The open state carries across, so switching while the panel is open leaves it open in the new place.
		host, currentMode = createHost(mode, enabled)
		bindHost()
		if currentMode == "Floating" then
			writeSetting(SETTING_OPEN, host.gui.Enabled)
		end
	end

	app = mountApp(commit)
	app.state.page:set(page)
end

app = mountApp("main")
bindHost()

-- The panel follows Studio's theme. Components read their colours when they are built, so a theme change refreshes
-- the palette and rebuilds the interface (keeping the page you were on).
local studioSettings: any = nil
pcall(function()
	studioSettings = (settings() :: any).Studio
end)
if studioSettings ~= nil then
	track(studioSettings.ThemeChanged:Connect(function()
		remount(currentMode, currentMode == "Floating")
	end))
end

table.insert(cleanups, function()
	if hostConnection then
		hostConnection:Disconnect()
		hostConnection = nil
	end
	app.unmount()
	-- The dock widget goes with the plugin; the floating window is ours to remove.
	if currentMode == "Floating" then
		host.destroy()
	end
	-- Flux registers one frame connection per loaded copy that it cannot remove itself; park it so it does no work.
	pcall(Flux.Clock.manual, true)
end)

-- Version label ----------------------------------------------------------------------------------------------------

task.spawn(function()
	local body = Http.get(`https://github.com/{REPO}/commit/main.patch`, Log, 2)
	if body == nil or unloaded then
		return
	end
	local firstLine = string.split(body, "\n")[1]
	local commit = string.match(firstLine, "^From (%x%x%x%x%x%x%x)")
	if commit then
		app.state.commit:set(commit)
	end
end)

println("Loaded.")
