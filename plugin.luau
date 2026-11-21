--!strict
--- Sensation Utilities: plugin lifecycle.
---
--- This file is fetched and run by `loader.luau` / `Plugin.rbxmx`. It only wires things together:
---   * downloads `packages.rbxm` (Maid, RawLib), `methods.rbxm` (bypass methods) and `ui.rbxm` (Flux + the UI),
---   * creates the toolbar button and the dockable widget,
---   * mounts the Flux UI into the widget and unmounts it again when the plugin unloads.
---
--- The utility operations live in `src/Core`, the interface in `src/UI` (both packaged into `ui.rbxm`).

local selection = game:GetService("Selection")
local serializationService = game:GetService("SerializationService")
local changeHistoryService = game:GetService("ChangeHistoryService")
local coreGui = game:GetService("CoreGui")

local REPO = "Adi0nt/Sensation-Utilities-Plugin"
-- Development only: `dev/SensationDev.lua` sets `shared.SensationDevBase` (e.g. "http://localhost:8000/") so the
-- packages, methods and UI are served from a local checkout instead of GitHub. Normal installs never set it.
local devBase = (shared :: any).SensationDevBase
local RAW_MAIN = if type(devBase) == "string" then devBase else `https://github.com/{REPO}/raw/refs/heads/main/`
local RAW_FRESH = if type(devBase) == "string"
	then devBase
	else `https://raw.githubusercontent.com/{REPO}/refs/heads/main/`

--- Marks the runtime folder so a leftover one (from an unload that never finished) is removed on the next start.
local RUNTIME_FOLDER_NAME = "SensationUtilities_Runtime"
local WIDGET_ID = "SensationUtilities"

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
	if leftover.Name == RUNTIME_FOLDER_NAME then
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

-- Widget -----------------------------------------------------------------------------------------------------------

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

local widget = createWidget()
widget.Name = WIDGET_ID
widget.Title = "Sensation Utilities"
widget.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

if unloaded then
	return
end

-- UI ---------------------------------------------------------------------------------------------------------------

local operations = Operations.new({
	plugin = plugin,
	selection = selection,
	history = History.new(changeHistoryService, Log),
	log = Log,
	methods = methods,
	newIndex = rawLib.instance_newindex,
})

local function mountApp(commit: string): any
	return App.mount({
		widget = widget,
		operations = operations,
		methods = methods,
		log = Log,
		commit = commit,
		reloadMethods = function()
			local count, reason = loadMethods()
			if count then
				Log.info(`Loaded {count} method(s).`)
			end
			return count, reason
		end,
	})
end

local app = mountApp("main")

-- The panel follows Studio's theme. Components read their colours when they are built, so a theme change refreshes
-- the palette and rebuilds the interface (keeping the page you were on).
local studioSettings: any = nil
pcall(function()
	studioSettings = (settings() :: any).Studio
end)
if studioSettings ~= nil then
	track(studioSettings.ThemeChanged:Connect(function()
		local page, commit = app.state.page:peek(), app.state.commit:peek()
		app.unmount()
		Theme.refresh()
		app = mountApp(commit)
		app.state.page:set(page)
	end))
end

table.insert(cleanups, function()
	app.unmount()
	-- Flux registers one frame connection per loaded copy that it cannot remove itself; park it so it does no work.
	pcall(Flux.Clock.manual, true)
end)

-- Toolbar button <-> widget ----------------------------------------------------------------------------------------

button:SetActive(widget.Enabled)
track(button.Click:Connect(function()
	widget.Enabled = not widget.Enabled
end))
track(widget:GetPropertyChangedSignal("Enabled"):Connect(function()
	button:SetActive(widget.Enabled)
end))

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
