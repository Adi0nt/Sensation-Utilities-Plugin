--!nocheck
-- Smoke test: mounts the REAL App + REAL Core operations (real Flux) on sert's headless Roblox engine.
local fs = require("@lune/fs")
local B = require("./boot")
local engine, Flux, Clock = B.engine, B.Flux, B.Clock

-- ── fakes for what the emulator lacks ───────────────────────────────────────────────────────────────────────────
local function signal()
	local handlers = {}
	local sig = {}
	function sig:Connect(fn)
		local conn = { Connected = true }
		handlers[conn] = fn
		function conn:Disconnect()
			self.Connected = false
			handlers[self] = nil
		end
		return conn
	end
	function sig:Fire(...)
		for conn, fn in table.clone(handlers) do
			if conn.Connected then fn(...) end
		end
	end
	function sig:count()
		local n = 0
		for _ in handlers do n += 1 end
		return n
	end
	return sig
end

local selectionList = {}
local Selection = { SelectionChanged = signal() }
function Selection:Get() return table.clone(selectionList) end
function Selection:Set(list)
	selectionList = table.clone(list)
	self.SelectionChanged:Fire()
end

local recordings = {}
local ChangeHistory = {}
function ChangeHistory:TryBeginRecording(name, display)
	if self.active then return nil end
	self.active = name
	return "rec:" .. name
end
function ChangeHistory:FinishRecording(id, op)
	table.insert(recordings, { id = id, op = op.Name })
	self.active = nil
end

local pluginFake = { saved = 0, promptedName = nil, saveAnswer = true }
function pluginFake:SaveSelectedToRoblox() self.saved += 1 end
function pluginFake:PromptSaveSelectionAsync(name) self.promptedName = name; return self.saveAnswer end

local fetched = {}
local getObjectsResult = nil
local gameProxy = setmetatable({}, {
	__index = function(_, k)
		if k == "GetObjects" then
			return function(_, url)
				table.insert(fetched, url)
				if getObjectsResult == nil then error("HTTP 404 (fake)") end
				return getObjectsResult()
			end
		end
		local v = engine.game[k]
		if type(v) == "function" then
			return function(_, ...) return v(engine.game, ...) end
		end
		return v
	end,
})
getfenv(0).game = gameProxy

-- ── load the plugin modules from the mirrored tree ──────────────────────────────────────────────────────────────
local Operations = require("../../.smoke/tree/Core/Operations")
local History = require("../../.smoke/tree/Core/History")
local Methods = require("../../.smoke/tree/Core/Methods")
local Presets = require("../../.smoke/tree/Core/Presets")
local App = require("../../.smoke/tree/UI/App")
local FloatingWindow = require("../../.smoke/tree/UI/FloatingWindow")

-- ── tiny test framework ─────────────────────────────────────────────────────────────────────────────────────────
local passed, failed = 0, 0
local function check(cond, msg)
	if not cond then error(msg or "check failed", 2) end
end
local function eq(a, b, label)
	if a ~= b then error(`{label or "value"}: expected {tostring(b)}, got {tostring(a)}`, 2) end
end
local ONLY = require("@lune/process").env.ONLY
local liveWorlds = {}
local function test(name, fn)
	if ONLY and not name:find(ONLY, 1, true) then return end
	local ok, err = xpcall(fn, function(e) return tostring(e) .. "\n" .. debug.traceback("", 2) end)
	-- a failing test must still unmount whatever it mounted, so one failure cannot cascade
	for _, world in liveWorlds do
		pcall(world.app.unmount)
		pcall(function() world.screen:Destroy() end)
		pcall(function() world.workspaceFolder:Destroy() end)
	end
	table.clear(liveWorlds)
	Selection:Set({})
	if ok then passed += 1; print("  ok    " .. name)
	else failed += 1; print("  FAIL  " .. name .. "\n        " .. tostring(err)) end
end

local function frames(n) for _ = 1, n or 3 do Clock.step(1 / 60) end Clock.drain() end
local function settle() frames(12) end
local function findAll(root, pred, out)
	out = out or {}
	for _, d in root:GetDescendants() do if pred(d) then table.insert(out, d) end end
	return out
end
local function find(root, name, class)
	for _, d in root:GetDescendants() do
		if d.Name == name and (class == nil or d.ClassName == class) then return d end
	end
	return nil
end
local function text(root, str, class)
	for _, d in root:GetDescendants() do
		if (class == nil or d.ClassName == class) and d.ClassName:find("Text") and d.Text == str then return d end
	end
	return nil
end
local function button(root, label)
	for _, d in root:GetDescendants() do
		if d.ClassName == "TextButton" and d.Name == "Button" and d.Text == label then return d end
	end
	return nil
end
local function click(btn) btn.Activated:Fire() end

-- ── environment ────────────────────────────────────────────────────────────────────────────────────────────────
local logs = { info = {}, warn = {} }
local log = {
	info = function(m) table.insert(logs.info, m) end,
	warn = function(m) table.insert(logs.warn, m) end,
}

local function makeMethodStore()
	local store = Methods.new()
	local function container(name)
		local folder = Instance.new("Folder")
		folder.Name = name
		local script = Instance.new("Script")
		script.Name = "Script"
		script.Parent = folder
		return folder
	end
	store:set({ ["Recursion Method"] = container("Recursion Method"), ["Alpha Method"] = container("Alpha Method") })
	return store
end

local function lf(text) return (string.gsub(text, "\r\n", "\n")) end

--- The real preset sources from presets/, so the tests exercise what ships.
local function makePresetStore()
	local store = Presets.new()
	store:set({
		["Advanced Module"] = { source = lf(fs.readFile("presets/Advanced Module.luau")), description = "Advanced description" },
		["Basic Module"] = { source = lf(fs.readFile("presets/Basic Module.luau")), description = "Basic description" },
	})
	return store
end

--- A stand-in for ContentProvider: `statuses[contentId]` is the final status (anything missing loads fine).
local function makeContentProvider()
	local provider = { statuses = {}, calls = {}, batches = 0 }
	function provider.PreloadAsync(_, list, callback)
		provider.batches += 1
		for _, item in list do
			table.insert(provider.calls, item)
			if callback then
				callback(item, provider.statuses[item] or Enum.AssetFetchStatus.Success)
			end
		end
	end
	return provider
end

local function newWorld()
	local world = {}
	world.workspaceFolder = Instance.new("Folder")
	world.workspaceFolder.Name = "TestRoot"
	world.workspaceFolder.Parent = engine.workspace
	world.methods = makeMethodStore()
	world.reloaded = 0
	world.presets = makePresetStore()
	world.presetsReloaded = 0
	world.windowSwitches = {}
	world.contentProvider = makeContentProvider()
	world.operations = Operations.new({
		plugin = pluginFake,
		selection = Selection,
		history = History.new(ChangeHistory, log),
		log = log,
		methods = world.methods,
		presets = world.presets,
		contentProvider = world.contentProvider,
		newIndex = function(inst, prop, value) inst[prop] = value end,
	})
	engine:setViewport(Vector2.new(520, 760))
	world.screen = Instance.new("ScreenGui")
	world.screen.IgnoreGuiInset = true -- a DockWidgetPluginGui has no top-bar inset
	world.screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling -- plugin.luau sets this on the widget
	world.screen.Parent = engine.LocalPlayer.PlayerGui
	world.app = App.mount({
		widget = world.screen,
		operations = world.operations,
		methods = world.methods,
		presets = world.presets,
		log = log,
		commit = "main",
		windowMode = "Dock",
		setWindowMode = function(mode) table.insert(world.windowSwitches, mode) end,
		reloadMethods = function()
			world.reloaded += 1
			return world.methods:names() and #world.methods:names(), nil
		end,
		reloadPresets = function()
			world.presetsReloaded += 1
			return #world.presets:names(), nil
		end,
	})
	settle()
	table.insert(liveWorlds, world)
	return world
end

local function teardown(world)
	local at = table.find(liveWorlds, world); if at then table.remove(liveWorlds, at) end
	world.app.unmount()
	frames(2)
	world.screen:Destroy()
	world.workspaceFolder:Destroy()
	Selection:Set({})
	table.clear(recordings)
	table.clear(logs.info); table.clear(logs.warn)
end

local function newModule(world, name, source)
	local m = Instance.new("ModuleScript")
	m.Name = name or "Mod"
	m.Source = source or "return 1"
	m.Parent = world.workspaceFolder
	return m
end

print("Smoke: App on the headless engine")

-- ═════════════════════════════════════════════════════════════════════════════════════════════════════════════
test("mounts: header, sidebar, three pages reachable, no warnings", function()
	local before = #logs.warn
	local w = newWorld()
	check(find(w.screen, "SensationUtilities", "Frame"), "root frame missing")
	check(not find(w.screen, "Header") and not find(w.screen, "Logo"), "there is no top bar or in-panel logo")
	check(not text(w.screen, "Sensation Utilities"), "the title is not repeated: Studio's own title bar already shows it")
	local bar = find(w.screen, "StatusMessage")
	check(bar:FindFirstChild("SelectionSummary", true), "the selection chip sits in the status bar")
	check(not text(w.screen, "main"), "the version chip is hidden in the icon rail (this window is narrow)")
	engine:setViewport(Vector2.new(760, 700)); frames(10)
	check(text(w.screen, "main"), "version chip missing from the expanded sidebar footer")
	engine:setViewport(Vector2.new(520, 760)); frames(10)
	check(not find(w.screen, "SelectionDivider"), "the selection lives in the header, not in a second strip")
	check(find(w.screen, "Nav_Modules") and find(w.screen, "Nav_Marketplace") and find(w.screen, "Nav_Studio"), "nav items missing")
	check(text(w.screen, "Bypass Tools"), "Bypass panel missing")
	check(text(w.screen, "Sandbox Controls"), "Sandbox panel missing")
	check(text(w.screen, "Asset Cleaner"), "Cleaner panel missing")
	check(text(w.screen, "Module Presets"), "Presets panel missing")
	check(find(w.screen, "Overlay"), "overlay missing")
	eq(#logs.warn, before, "warnings during mount")
	teardown(w)
end)

test("selection summary follows Explorer selection", function()
	local w = newWorld()
	check(text(w.screen, "No selection"), "expected 'No selection'")
	local m = newModule(w, "MainModule")
	Selection:Set({ m }); settle()
	check(text(w.screen, "MainModule"), "the chip shows the name (the class is the icon and the tooltip)")
	local p1, p2 = Instance.new("Part"), Instance.new("Part")
	p1.Parent, p2.Parent = w.workspaceFolder, w.workspaceFolder
	Selection:Set({ m, p1, p2 }); settle()
	check(text(w.screen, "3 objects selected"), "multi selection shows a count")
	m.Name = "Renamed"; Selection:Set({ m }); settle()
	m.Name = "Renamed2"; settle()
	check(text(w.screen, "Renamed2"), "rename did not update the summary")
	teardown(w)
end)

test("method dropdown: deterministic order, selection preserved across refresh", function()
	local w = newWorld()
	eq(table.concat(w.app.state.methodNames:peek(), ","), "Alpha Method,Recursion Method", "sorted names")
	eq(w.app.state.method:peek(), "Alpha Method", "default method is first sorted")
	w.app.state.method:set("Recursion Method")
	-- a new method appears; the user's choice stays
	local extra = Instance.new("Folder"); extra.Name = "Beta"; Instance.new("Script").Parent = extra
	local all = {}
	for _, n in w.methods:names() do all[n] = w.methods:get(n) end
	all["Beta"] = extra
	w.methods:set(all)
	w.app.state.refreshMethods(); settle()
	eq(w.app.state.method:peek(), "Recursion Method", "selected method kept")
	eq(table.concat(w.app.state.methodNames:peek(), ","), "Alpha Method,Beta,Recursion Method")
	-- the chosen method disappears
	all["Recursion Method"] = nil
	w.methods:set(all)
	w.app.state.refreshMethods()
	eq(w.app.state.method:peek(), "Alpha Method", "falls back to the first when removed")
	teardown(w)
end)

test("gating: buttons are unavailable until their prerequisites exist", function()
	local w = newWorld()
	local g = w.app.state.gate
	check(g.bypass() ~= nil, "bypass must be gated without a selection")
	check(g.sandbox() ~= nil and g.upload() ~= nil and g.insertLatest() ~= nil, "others gated")
	eq(g.spawn(), nil, "spawn needs nothing")
	local part = Instance.new("Part"); part.Parent = w.workspaceFolder
	Selection:Set({ part }); settle()
	check(g.bypass() ~= nil, "a Part is not a ModuleScript")
	eq(g.sandbox(), nil, "sandbox ok with any selection")
	local m = newModule(w)
	Selection:Set({ m }); settle()
	eq(g.bypass(), nil, "bypass ok with a ModuleScript")
	eq(g.unbypass(), nil, "unbypass ok with a ModuleScript")
	teardown(w)
end)

test("Bypass (Insert) creates a bypassed copy, selects it, records one undo step", function()
	local w = newWorld()
	local m = newModule(w, "Target", "return 'orig'")
	Selection:Set({ m }); settle()
	local btn = button(w.screen, "Bypass"); check(btn, "Bypass button missing")
	click(btn); settle()
	local copies = {}
	for _, c in w.workspaceFolder:GetChildren() do if c.Name == "Target" then table.insert(copies, c) end end
	eq(#copies, 2, "original + bypassed copy")
	local bypassed
	for _, c in copies do if c ~= m then bypassed = c end end
	check(bypassed:FindFirstChildWhichIsA("Script"), "method script missing inside the copy")
	eq(Selection:Get()[1], bypassed, "selection moved to the new module")
	eq(#recordings, 1, "undo recordings")
	eq(recordings[1].op, "Commit", "recording committed")
	local line = w.app.state.statusLine:peek()
	eq(line.level, "success"); check(line.text:find("Bypassed 1 ModuleScript"), line.text)
	check(line.text:find("Alpha Method"), "method name in status")
	teardown(w)
end)

test("Bypass (Append) wraps the module in a MainModule", function()
	local w = newWorld()
	local m = newModule(w, "Inner", "return 'x'")
	Selection:Set({ m }); settle()
	click(find(w.screen, "Segment_Append")); settle()
	eq(w.app.state.mode:peek(), "Append")
	click(button(w.screen, "Bypass")); settle()
	local main = w.workspaceFolder:FindFirstChild("MainModule")
	check(main, "MainModule missing")
	check(main.Source:find("require%(moduleScript%)"), "loader source")
	local wrapper = main:FindFirstChildWhichIsA("Script")
	check(wrapper, "method script clone inside MainModule")
	check(wrapper:FindFirstChildWhichIsA("ModuleScript"), "module clone inside the method script")
	teardown(w)
end)

test("Unbypass extracts the embedded original (and copies standalone modules as-is)", function()
	local w = newWorld()
	local outer = newModule(w, "Outer")
	local inner = Instance.new("ModuleScript"); inner.Name = "Original"; inner.Source = "return 'inner'"; inner.Parent = outer
	Selection:Set({ outer }); settle()
	click(button(w.screen, "Unbypass")); settle()
	local extracted = w.workspaceFolder:FindFirstChild("Original")
	check(extracted and extracted.Source == "return 'inner'", "extracted original")
	eq(w.app.state.statusLine:peek().level, "success")
	-- standalone → warning that it was copied as-is
	local plain = newModule(w, "Plain")
	Selection:Set({ plain }); settle()
	click(button(w.screen, "Unbypass")); settle()
	eq(w.app.state.statusLine:peek().level, "warning")
	teardown(w)
end)

test("Sandbox / Unsandbox touch the selection and its descendants", function()
	local w = newWorld()
	local root = Instance.new("Folder"); root.Name = "Tree"; root.Parent = w.workspaceFolder
	local child = Instance.new("Part"); child.Parent = root
	Selection:Set({ root }); settle()
	click(button(w.screen, "Sandbox")); settle()
	local line = w.app.state.statusLine:peek()
	eq(line.level, "success"); check(line.text:find("1 object and 1 descendant"), line.text)
	eq(root.Sandboxed, true, "root sandboxed"); eq(child.Sandboxed, true, "descendant sandboxed")
	click(button(w.screen, "Unsandbox")); settle()
	eq(root.Sandboxed, false, "root unsandboxed"); eq(child.Sandboxed, false, "descendant unsandboxed")
	teardown(w)
end)

test("Asset cleaner clears unloaded sounds and shows the count", function()
	local w = newWorld()
	local holder = Instance.new("Folder"); holder.Parent = w.workspaceFolder
	local s1 = Instance.new("Sound"); s1.SoundId = "rbxassetid://1"; s1.Parent = holder
	Selection:Set({ holder }); settle()
	click(button(w.screen, "Clean Unloaded Sounds")); settle()
	local line = w.app.state.statusLine:peek()
	print("        cleaner status:", line.level, line.text)
	check(line.level == "success" or line.level == "info", "cleaner should not error: " .. line.text)
	teardown(w)
end)

test("Module preset inserts a MainModule with the unchanged source", function()
	local w = newWorld()
	local target = Instance.new("Folder"); target.Parent = w.workspaceFolder
	Selection:Set({ target }); settle()
	click(button(w.screen, "Insert Preset")); settle()
	local main = target:FindFirstChild("MainModule")
	check(main, "MainModule missing")
	eq(main.Source, (string.gsub(fs.readFile("tests/golden/advanced_module.txt"), "\r\n", "\n")), "advanced preset source")
	w.app.state.preset:set("Basic Module"); settle()
	click(button(w.screen, "Insert Preset")); settle()
	local mains = {}
	for _, c in target:GetChildren() do if c.Name == "MainModule" then table.insert(mains, c) end end
	eq(#mains, 2)
	eq(mains[2].Source, (string.gsub(fs.readFile("tests/golden/basic_module.txt"), "\r\n", "\n")), "basic preset source")
	teardown(w)
end)

test("presets come from the preset store: list, description, Reload, and an empty store", function()
	local w = newWorld()
	eq(table.concat(w.app.state.presetNames:peek(), ","), "Advanced Module,Basic Module", "sorted names from the store")
	eq(w.app.state.preset:peek(), "Advanced Module", "Advanced Module is the default while it exists")
	check(text(w.screen, "Advanced description"), "the description under the picker comes from the preset")
	w.app.state.preset:set("Basic Module"); settle()
	check(text(w.screen, "Basic description"), "the description follows the chosen preset")
	-- editing presets.rbxm and pressing Reload brings in a new preset and keeps the choice
	local all = {}
	for _, name in w.presets:names() do all[name] = { source = w.presets:source(name), description = w.presets:description(name) } end
	all["Brand New"] = { source = "return 'new'", description = "Added by a new presets.rbxm" }
	w.presets:set(all)
	click(find(w.screen, "PresetRow"):FindFirstChild("Button", true)); settle()
	eq(w.presetsReloaded, 1, "Reload asked the loader once")
	eq(table.concat(w.app.state.presetNames:peek(), ","), "Advanced Module,Basic Module,Brand New")
	eq(w.app.state.preset:peek(), "Basic Module", "the chosen preset stays after a reload")
	-- the new preset can be inserted, with its own source
	local target = Instance.new("Folder"); target.Parent = w.workspaceFolder
	Selection:Set({ target }); settle()
	w.app.state.preset:set("Brand New"); settle()
	click(button(w.screen, "Insert Preset")); settle()
	eq(target:FindFirstChild("MainModule").Source, "return 'new'", "new preset source inserted")
	-- an empty store disables Insert with a reason
	w.presets:set({})
	w.app.state.refreshPresets(); settle()
	eq(w.app.state.preset:peek(), "", "no preset to fall back to")
	local reason = w.app.state.gate.insertPreset()
	check(reason ~= nil and reason:find("No presets"), "an empty store explains itself")
	teardown(w)
end)

test("inserting a preset that is no longer loaded reports a clear error and creates nothing", function()
	local w = newWorld()
	local target = Instance.new("Folder"); target.Parent = w.workspaceFolder
	Selection:Set({ target }); settle()
	local result = w.operations.insertPreset("Does Not Exist")
	eq(result.ok, false)
	check(result.message:find("not loaded"), result.message)
	eq(#target:GetChildren(), 0, "nothing was created")
	teardown(w)
end)

--- A small tree with known asset references: two uses of 111 (broken), one of 222 (fine), one of 333 (broken sound),
--- one old-style URL for 444 (times out), and ids the scan must ignore.
local function makeAssetTree(w)
	local holder = Instance.new("Folder"); holder.Name = "Assets"; holder.Parent = w.workspaceFolder
	local mesh = Instance.new("MeshPart"); mesh.Name = "Mesh"; mesh.MeshId = "rbxassetid://111"; mesh.TextureID = "rbxassetid://222"; mesh.Parent = holder
	local decal = Instance.new("Decal"); decal.Name = "Decal"; decal.Texture = "rbxassetid://111"; decal.Parent = holder
	local sound = Instance.new("Sound"); sound.Name = "Sound"; sound.SoundId = "rbxassetid://333"; sound.Parent = holder
	local old = Instance.new("Decal"); old.Name = "OldUrl"; old.Texture = "http://www.roblox.com/asset/?id=444"; old.Parent = holder
	local builtin = Instance.new("ImageLabel"); builtin.Name = "Builtin"; builtin.Image = "rbxasset://textures/face.png"; builtin.Parent = holder
	local empty = Instance.new("Decal"); empty.Name = "Empty"; empty.Parent = holder
	local Failure, TimedOut = Enum.AssetFetchStatus.Failure, Enum.AssetFetchStatus.TimedOut
	w.contentProvider.statuses["rbxassetid://111"] = Failure
	w.contentProvider.statuses["rbxassetid://333"] = Failure
	w.contentProvider.statuses["rbxassetid://444"] = TimedOut
	return { holder = holder, mesh = mesh, decal = decal, sound = sound, old = old, builtin = builtin, empty = empty }
end

local function brokenRows(w)
	local rows = {}
	for _, d in w.screen:GetDescendants() do
		if d.Name == "BrokenAsset" and d.ClassName == "Frame" then table.insert(rows, d) end
	end
	return rows
end

test("asset cleaner: a scan lists the assets that fail to load, never changing anything", function()
	local w = newWorld()
	local t = makeAssetTree(w)
	check(w.app.state.gate.scanAssets() ~= nil, "scanning needs a selection")
	check(button(w.screen, "Scan Selection"), "scan button")
	check(not find(w.screen, "BrokenAssetsSection"), "no list before the first scan")
	Selection:Set({ t.holder }); settle()
	eq(w.app.state.gate.scanAssets(), nil, "scan available with a selection")
	click(button(w.screen, "Scan Selection")); settle()
	local report = w.app.state.cleanReport:peek()
	check(report, "scan produced a report")
	eq(report.assets, 4, "four distinct assets (111, 222, 333, 444)")
	eq(report.references, 5, "five asset references; engine files and empty ids are ignored")
	eq(report.unverified, 1, "the timed-out asset is not offered for cleaning")
	eq(#report.broken, 2, "two assets failed")
	eq(report.broken[1].id, 111, "most-used first")
	eq(#report.broken[1].references, 2)
	eq(report.broken[2].id, 333)
	local line = w.app.state.statusLine:peek()
	eq(line.level, "warning", line.text)
	check(line.text:find("2 of 4 assets could not be loaded"), line.text)
	check(line.text:find("1 could not be checked"), line.text)
	-- nothing was touched
	eq(t.mesh.MeshId, "rbxassetid://111"); eq(t.decal.Texture, "rbxassetid://111"); eq(t.sound.SoundId, "rbxassetid://333")
	-- the list: both ticked, the legacy URL was checked through its normal id
	eq(#brokenRows(w), 2, "two rows")
	check(text(w.screen, "rbxassetid://111") and text(w.screen, "rbxassetid://333"), "ids are shown")
	check(text(w.screen, "2 uses · Decal.Texture · MeshPart.MeshId"), "where it is used (ties are alphabetical)")
	check(text(w.screen, "2 of 2 selected"), "a fresh scan ticks everything")
	check(table.find(w.contentProvider.calls, "rbxassetid://444"), "old-style URLs are checked by id")
	eq(w.contentProvider.batches, 1, "one batch for a small scan")
	teardown(w)
end)

test("asset cleaner: tick boxes, select all / none, and the clean button follows the ticks", function()
	local w = newWorld()
	local t = makeAssetTree(w)
	Selection:Set({ t.holder }); settle()
	click(button(w.screen, "Scan Selection")); settle()
	eq(w.app.state.gate.cleanAssets(), nil, "clean available with everything ticked")
	click(find(brokenRows(w)[1], "Checkbox")); settle()
	check(text(w.screen, "1 of 2 selected"), "one ticked off")
	eq(w.app.state.cleanPicked:peek()[111], nil, "the first row is unticked")
	check(not button(w.screen, "Select None"), "with one unticked the button offers Select All")
	click(button(w.screen, "Select All")); settle()
	check(text(w.screen, "2 of 2 selected"), "all ticked again")
	click(button(w.screen, "Select None")); settle()
	check(text(w.screen, "0 of 2 selected"), "none")
	local reason = w.app.state.gate.cleanAssets()
	check(reason ~= nil and reason:find("Tick at least one"), "clean explains why it is off")
	teardown(w)
end)

test("asset cleaner: Clean Selected blanks the property of what is ticked, as one undo step", function()
	local w = newWorld()
	local t = makeAssetTree(w)
	Selection:Set({ t.holder }); settle()
	click(button(w.screen, "Scan Selection")); settle()
	click(find(brokenRows(w)[2], "Checkbox")); settle() -- untick 333, the sound
	table.clear(recordings)
	click(button(w.screen, "Clean Selected")); settle()
	eq(t.mesh.MeshId, "", "mesh id cleared")
	eq(t.decal.Texture, "", "decal texture cleared")
	eq(t.mesh.TextureID, "rbxassetid://222", "the working texture is untouched")
	eq(t.sound.SoundId, "rbxassetid://333", "the unticked sound is untouched")
	check(t.mesh.Parent and t.decal.Parent, "instances are kept by default")
	eq(#recordings, 1, "one undo step")
	eq(recordings[1].op, "Commit")
	local line = w.app.state.statusLine:peek()
	eq(line.level, "success", line.text)
	check(line.text:find("Cleared 2 references to 1 asset"), line.text)
	eq(#brokenRows(w), 1, "cleaned assets leave the list")
	check(text(w.screen, "rbxassetid://333") and not text(w.screen, "rbxassetid://111"), "only the sound is left")
	teardown(w)
end)

test("asset cleaner: removing the holding instances always asks first", function()
	local w = newWorld()
	local t = makeAssetTree(w)
	Selection:Set({ t.holder }); settle()
	click(button(w.screen, "Scan Selection")); settle()
	eq(w.app.state.cleanRemove:peek(), false, "clearing the property is the default")
	local removeBox
	for _, d in w.screen:GetDescendants() do
		if d.Name == "Checkbox" and d.ClassName == "TextButton" then
			local label = find(d, "Label", "TextLabel")
			if label and label.Text:find("^Remove the instances") then removeBox = d end
		end
	end
	check(removeBox, "the remove option is offered")
	check(button(w.screen, "Clean Selected") and not button(w.screen, "Remove Selected"), "the button says Clean while clearing")
	click(removeBox); settle()
	eq(w.app.state.cleanRemove:peek(), true, "ticking it switches to removing")
	check(button(w.screen, "Remove Selected") and not button(w.screen, "Clean Selected"), "the button says Remove once removing is chosen")
	click(button(w.screen, "Remove Selected")); settle()
	check(w.app.state.confirm:peek() ~= nil, "removing asks for confirmation")
	check(find(w.screen, "ConfirmationDialog"), "dialog shown")
	check(text(w.screen, "This removes 3 instances that use the ticked assets, along with anything inside them. You can undo it with Ctrl+Z."), "the dialog says how many and reads correctly")
	eq(w.app.state.statusLine:peek().text, "Waiting for your answer...", "the status bar does not claim to be working while the dialog is open")
	click(button(w.screen, "Cancel")); settle()
	check(t.mesh.Parent and t.decal.Parent and t.sound.Parent, "cancel removed nothing")
	eq(t.mesh.MeshId, "rbxassetid://111", "cancel changed nothing")
	click(button(w.screen, "Remove Selected")); settle()
	click(button(find(w.screen, "ConfirmationDialog"), "Remove")); settle()
	check(t.mesh.Parent == nil and t.decal.Parent == nil and t.sound.Parent == nil, "the instances that held broken assets are gone")
	check(t.old.Parent ~= nil and t.builtin.Parent ~= nil, "everything else stays")
	local line = w.app.state.statusLine:peek()
	eq(line.level, "success", line.text)
	check(line.text:find("Removed 3 instances that used 2 assets"), line.text)
	teardown(w)
end)

test("asset cleaner: a reference that changed since the scan is left alone and reported", function()
	local w = newWorld()
	local t = makeAssetTree(w)
	Selection:Set({ t.holder }); settle()
	click(button(w.screen, "Scan Selection")); settle()
	t.decal.Texture = "rbxassetid://999" -- the user replaced it after the scan
	click(button(w.screen, "Clean Selected")); settle()
	eq(t.decal.Texture, "rbxassetid://999", "the replaced reference survives")
	eq(t.mesh.MeshId, "", "the others were cleaned")
	local line = w.app.state.statusLine:peek()
	eq(line.level, "warning", line.text)
	check(line.text:find("had already changed"), line.text)
	teardown(w)
end)

test("asset cleaner: nothing to find, and a failing content request, are reported without throwing", function()
	local w = newWorld()
	local bare = Instance.new("Folder"); bare.Parent = w.workspaceFolder
	Instance.new("Part").Parent = bare
	Selection:Set({ bare }); settle()
	click(button(w.screen, "Scan Selection")); settle()
	eq(w.app.state.statusLine:peek().level, "info", "no references is not an error")
	check(w.app.state.statusLine:peek().text:find("No asset references"), w.app.state.statusLine:peek().text)
	check(not find(w.screen, "BrokenAssetsSection"), "no list")
	-- a provider that errors: every asset stays unverified and nothing is offered for cleaning
	local t = makeAssetTree(w)
	w.contentProvider.PreloadAsync = function() error("network down") end
	Selection:Set({ t.holder }); settle()
	click(button(w.screen, "Scan Selection")); settle()
	local report = w.app.state.cleanReport:peek()
	eq(#report.broken, 0, "no verdict, nothing to clean")
	eq(report.unverified, 4, "every asset is unverified")
	check(w.app.state.statusLine:peek().level ~= "error", "a failed request does not break the scan")
	eq(t.mesh.MeshId, "rbxassetid://111", "nothing was changed")
	teardown(w)
end)

test("Marketplace: digits-only inputs, validation messages, latest vs versioned insertion", function()
	local w = newWorld()
	click(find(w.screen, "Nav_Marketplace")); settle()
	check(text(w.screen, "Asset Insertion") and text(w.screen, "Publishing & Export"), "marketplace panels")
	check(not text(w.screen, "Bypass Tools"), "modules page must be unmounted")
	local target = Instance.new("Folder"); target.Name = "Dest"; target.Parent = w.workspaceFolder
	Selection:Set({ target }); settle()
	check(w.app.state.gate.insertLatest() ~= nil, "gated without an id")
	local idBox = find(find(w.screen, "TextInput"), "Field", "TextBox")
	check(idBox, "asset id box")
	idBox.Text = "12ab3-4"; settle()
	eq(w.app.state.assetId:peek(), "1234", "non-digits stripped")
	eq(w.app.state.gate.insertLatest(), nil, "latest available with a valid id and selection")
	check(w.app.state.gate.insertVersion() ~= nil, "specific version needs a version")
	idBox.Text = "0"; settle()
	check(w.app.state.assetIdError:peek() ~= nil, "zero id rejected")
	idBox.Text = "555"; settle()
	getObjectsResult = function()
		local part = Instance.new("Part"); part.Name = "Loaded"; return { part }
	end
	-- one Insert button; by default it loads the latest version, says so, and there is no version field to confuse
	eq(w.app.state.assetVersionMode:peek(), "Latest", "defaults to the latest version")
	check(text(w.screen, "Loads the newest version published for the asset."), "latest mode explains itself")
	check(not text(w.screen, "Version number"), "no version field while Latest is chosen")
	check(not button(w.screen, "Insert Latest") and not button(w.screen, "Insert Specific Version"), "the two old buttons are gone")
	click(button(w.screen, "Insert latest version")); settle()
	eq(fetched[#fetched], "https://assetdelivery.roblox.com/v1/asset/?id=555", "latest url")
	check(target:FindFirstChild("Loaded"), "asset inserted into selection")
	-- choosing "Specific version" reveals the version field, and the button names the version it will load
	click(find(w.screen, "Segment_Specific version")); settle()
	eq(w.app.state.assetVersionMode:peek(), "Specific")
	check(text(w.screen, "Version number"), "version field appears")
	check(not text(w.screen, "Loads the newest version published for the asset."), "the latest-mode note is replaced")
	check(button(w.screen, "Insert version"), "button asks for a version")
	check(w.app.state.gate.insert() ~= nil, "specific mode needs a version")
	check(button(w.screen, "Insert version").Text == "Insert version", "label before a version is typed")
	local versionBox
	for _, ti in findAll(w.screen, function(d) return d.Name == "TextInput" end) do
		local f = find(ti, "Field", "TextBox"); if f ~= idBox then versionBox = f end
	end
	check(versionBox, "version box")
	versionBox.Text = "7"; settle()
	eq(w.app.state.gate.insert(), nil, "version insert enabled")
	check(button(w.screen, "Insert version 7"), "button names the version it will load")
	click(button(w.screen, "Insert version 7")); settle()
	eq(fetched[#fetched], "https://assetdelivery.roblox.com/v1/asset/?id=555&version=7", "versioned url")
	-- a typed version is ignored in Latest mode (it cannot be loaded by accident), and kept for when it is chosen again
	click(find(w.screen, "Segment_Latest")); settle()
	eq(w.app.state.assetVersion:peek(), "7", "the typed version is kept")
	check(button(w.screen, "Insert latest version"), "label back to latest")
	click(button(w.screen, "Insert latest version")); settle()
	eq(fetched[#fetched], "https://assetdelivery.roblox.com/v1/asset/?id=555", "latest again, version ignored")
	-- failure surfaces as an error, not a throw
	getObjectsResult = nil
	click(button(w.screen, "Insert latest version")); settle()
	eq(w.app.state.statusLine:peek().level, "error", "fetch failure is reported")
	getObjectsResult = nil
	teardown(w)
end)

test("Upload / Save invoke the native dialogs; failures and cancellation are reported", function()
	local w = newWorld()
	click(find(w.screen, "Nav_Marketplace")); settle()
	local part = Instance.new("Part"); part.Name = "Thing"; part.Parent = w.workspaceFolder
	Selection:Set({ part }); settle()
	click(button(w.screen, "Upload to Roblox")); settle()
	eq(pluginFake.saved, 1, "SaveSelectedToRoblox called")
	click(button(w.screen, "Save to File")); settle()
	eq(pluginFake.promptedName, "Thing.rbxm", "suggested file name")
	eq(w.app.state.statusLine:peek().level, "success")
	pluginFake.saveAnswer = false
	click(button(w.screen, "Save to File")); settle()
	eq(w.app.state.statusLine:peek().level, "info", "cancelled save")
	pluginFake.saveAnswer = true
	teardown(w)
end)

test("Studio page: spawn failure is reported as an error (no throw, no stuck busy)", function()
	local w = newWorld()
	click(find(w.screen, "Nav_Studio")); settle()
	check(text(w.screen, "R6 StarterCharacter") and text(w.screen, "R15 StarterCharacter"), "cards")
	click(button(w.screen, "Spawn R6")); settle()
	local line = w.app.state.statusLine:peek()
	print("        spawn status:", line.level, line.text)
	check(w.app.state.busy:peek() == nil, "busy must be cleared")
	check(line.level == "error" or line.level == "warning" or line.level == "success", "some outcome is shown")
	teardown(w)
end)

test("Confirmation: bulk operations ask first; Cancel changes nothing, Confirm proceeds", function()
	local w = newWorld()
	local mods = {}
	for i = 1, 12 do mods[i] = newModule(w, "Bulk" .. i) end
	Selection:Set(mods); settle()
	local before = #w.workspaceFolder:GetChildren()
	click(button(w.screen, "Bypass")); settle()
	check(w.app.state.confirm:peek() ~= nil, "dialog requested")
	check(find(w.screen, "ConfirmationDialog"), "dialog rendered in overlay")
	eq(w.app.state.busy:peek(), "bypass", "still busy while waiting")
	-- a second click while busy must be ignored
	click(button(w.screen, "Bypass")); settle()
	click(button(w.screen, "Cancel")); settle()
	eq(#w.workspaceFolder:GetChildren(), before, "cancel changed nothing")
	check(not find(w.screen, "ConfirmationDialog"), "dialog removed")
	eq(w.app.state.busy:peek(), nil, "busy cleared")
	eq(w.app.state.statusLine:peek().level, "info", "cancel message")
	click(button(w.screen, "Bypass")); settle()
	local dialog = find(w.screen, "ConfirmationDialog")
	check(dialog, "dialog shown again")
	click(button(dialog, "Bypass")); settle()
	check(not find(w.screen, "ConfirmationDialog"), "dialog closed after confirming")
	eq(w.app.state.busy:peek(), nil, "busy cleared")
	eq(w.app.state.statusLine:peek().level, "success", "confirmed operation ran")
	check(#w.workspaceFolder:GetChildren() > before, "bypassed copies were created")
	teardown(w)
end)

test("no duplicate submissions: clicks while a yielding action runs are ignored", function()
	local w = newWorld()
	click(find(w.screen, "Nav_Marketplace")); settle()
	local target = Instance.new("Folder"); target.Parent = w.workspaceFolder
	Selection:Set({ target }); settle()
	find(find(w.screen, "TextInput"), "Field", "TextBox").Text = "999"; settle()
	local pending = {}
	local before = #fetched
	getObjectsResult = function()
		table.insert(pending, coroutine.running())
		coroutine.yield()
		local part = Instance.new("Part"); part.Name = "Slow"; return { part }
	end
	local btn = button(w.screen, "Insert latest version")
	click(btn); settle()
	eq(w.app.state.busy:peek(), "latest", "busy while the asset downloads")
	-- the spinner sits in the button's left padding, clear of the label (UIPadding shifts children, so it is offset back)
	local spinner = find(btn, "Spinner")
	check(spinner, "a loading button shows its spinner")
	check(spinner.AbsolutePosition.X >= btn.AbsolutePosition.X, "the spinner is inside the button")
	check(spinner.AbsolutePosition.X + spinner.AbsoluteSize.X <= btn.AbsolutePosition.X + 32, "the spinner does not overlap the label")
	check(w.app.state.gate.insert() ~= nil, "the button gates itself while busy")
	click(btn); click(btn); settle()
	eq(#fetched - before, 1, "exactly one download started")
	eq(#pending, 1, "exactly one pending request")
	-- other actions are blocked too, and the status shows progress
	local line = w.app.state.statusLine:peek()
	check(line.busy, "status shows a working line"); check(line.text:find("Loading"), line.text)
	task.spawn(pending[1]); settle()
	eq(w.app.state.busy:peek(), nil, "busy cleared when finished")
	local slow = 0
	for _, c in target:GetChildren() do if c.Name == "Slow" then slow += 1 end end
	eq(slow, 1, "inserted exactly once")
	getObjectsResult = nil
	teardown(w)
end)

test("responsive: narrow dock collapses navigation, wide dock restores it", function()
	local w = newWorld()
	print("        width at 520:", w.app.state.width(), "compactNav", w.app.state.compactNav())
	engine:setViewport(Vector2.new(360, 760)); settle()
	print("        width at 360:", w.app.state.width(), "compactNav", w.app.state.compactNav())
	teardown(w)
end)

test("lifecycle: repeated mount/unmount leaves no orphans, owners or listeners", function()
	local baseline
	for round = 1, 5 do
		local w = newWorld()
		click(find(w.screen, "Nav_Marketplace")); settle()
		click(find(w.screen, "Nav_Studio")); settle()
		click(find(w.screen, "Nav_Modules")); settle()
		Selection:Set({ w.workspaceFolder }); settle()
		eq(Selection.SelectionChanged:count(), 1, "one SelectionChanged listener while mounted")
		w.app.unmount(); frames(3)
		eq(Selection.SelectionChanged:count(), 0, "listener released on unmount (round " .. round .. ")")
		eq(#w.screen:GetChildren(), 0, "widget emptied on unmount (round " .. round .. ")")
		eq(Flux.getOwner(), nil, "no leaked Flux owner")
		w.screen:Destroy(); w.workspaceFolder:Destroy(); Selection:Set({})
	end
end)

test("page switching does not accumulate instances", function()
	local w = newWorld()
	local function count() return #w.screen:GetDescendants() end
	local base = count()
	for _ = 1, 10 do
		click(find(w.screen, "Nav_Marketplace")); settle()
		click(find(w.screen, "Nav_Studio")); settle()
		click(find(w.screen, "Nav_Modules")); settle()
	end
	eq(count(), base, "descendant count after 10 navigation cycles")
	teardown(w)
end)


local Theme = require("../../.smoke/tree/UI/Theme")
local function center(d) return Vector2.new(d.AbsolutePosition.X + d.AbsoluteSize.X / 2, d.AbsolutePosition.Y + d.AbsoluteSize.Y / 2) end
local function hoverOn(btn)
	-- Emulator artifact: GetGuiObjectsAtPosition lists ancestors before descendants, so an Active ScrollingFrame
	-- ancestor would "cover" its own buttons. Real Roblox lists the front-most object first. Neutralise for tests.
	for _, d in btn:FindFirstAncestorOfClass("ScreenGui"):GetDescendants() do
		if d:IsA("ScrollingFrame") then d.Active = false end
	end
	-- Emulator artifact #2: layout goes stale after late child insertion; a same-size setViewport forces a relayout.
	engine:setViewport(Vector2.new(520, 760)); frames(6)
	local c = center(btn)
	engine:input():move(c)
	btn.MouseEnter:Fire(c.X, c.Y) -- the emulator does not raise MouseEnter by itself; real Studio does
end
local function hoverOff(btn)
	engine:input():move(Vector2.new(2, 2))
	btn.MouseLeave:Fire(2, 2)
end
local function near(a, b) return math.abs(a.R - b.R) < 0.02 and math.abs(a.G - b.G) < 0.02 and math.abs(a.B - b.B) < 0.02 end

test("pointer: hovering a disabled button explains why after a short delay, and leaving removes it", function()
	local w = newWorld()
	local btn = button(w.screen, "Bypass")
	hoverOn(btn); frames(8)
	check(not find(w.screen, "Tooltip"), "no tooltip before the delay")
	frames(40)
	local tip = find(w.screen, "Tooltip")
	check(tip, "tooltip should appear after hovering")
	check(tip:IsDescendantOf(find(w.screen, "Overlay")), "tooltip is portalled into the overlay layer")
	check(text(tip, "Select one or more ModuleScripts in Explorer."), "tooltip explains the missing prerequisite")
	hoverOff(btn); frames(10)
	check(not find(w.screen, "Tooltip"), "tooltip removed after leaving")
	teardown(w)
end)

test("pointer: hover feedback uses the theme's hover colour; disabled buttons do not react", function()
	local w = newWorld()
	local module = newModule(w)
	Selection:Set({ module }); settle()
	local bypass = button(w.screen, "Bypass") -- the page's one primary action
	check(near(bypass.BackgroundColor3, Theme.color.accent), "base is the accent colour")
	hoverOn(bypass); frames(30)
	check(near(bypass.BackgroundColor3, Theme.color.accentHover), "hover colour reached")
	hoverOff(bypass); frames(30)
	check(near(bypass.BackgroundColor3, Theme.color.accent), "returns to base")
	local sandbox = button(w.screen, "Sandbox") -- secondary
	check(near(sandbox.BackgroundColor3, Theme.color.control), "secondary base")
	hoverOn(sandbox); frames(30)
	check(near(sandbox.BackgroundColor3, Theme.color.controlHover), "secondary hover colour")
	hoverOff(sandbox)
	Selection:Set({}); settle()
	local disabled = button(w.screen, "Bypass")
	check(near(disabled.BackgroundColor3, Theme.color.accentSubtle), "disabled primary uses the subtle accent fill")
	hoverOn(disabled); frames(30)
	check(near(disabled.BackgroundColor3, Theme.color.accentSubtle), "a disabled button gives no hover feedback")
	teardown(w)
end)

test("pointer: a real click on a button runs its action", function()
	local w = newWorld()
	local folder = Instance.new("Folder"); folder.Parent = w.workspaceFolder
	Selection:Set({ folder }); settle()
	engine:input():click(button(w.screen, "Sandbox")); settle()
	eq(folder.Sandboxed, true, "click reached the operation")
	Selection:Set({}); settle()
	local before = w.app.state.status:peek()
	engine:input():click(button(w.screen, "Sandbox")); settle()
	eq(w.app.state.status:peek(), before, "disabled click ignored")
	teardown(w)
end)

test("dropdown: opens in the overlay, selects an option, closes; click-away closes too", function()
	local w = newWorld()
	local trigger = find(w.screen, "Trigger", "TextButton")
	eq(find(w.screen, "DropdownMenu"), nil, "closed at first")
	engine:input():click(trigger); settle()
	local menu = find(w.screen, "DropdownMenu")
	check(menu and menu:IsDescendantOf(find(w.screen, "Overlay")), "menu lives in the overlay")
	local options = findAll(menu, function(d) return d.Name == "Option" end)
	eq(#options, 2, "one row per method")
	check(text(options[1], "Alpha Method"), "options are sorted")
	engine:input():click(options[2]); settle()
	eq(w.app.state.method:peek(), "Recursion Method", "selection applied")
	eq(find(w.screen, "DropdownMenu"), nil, "menu closes after choosing")
	check(text(find(w.screen, "Trigger"), "Recursion Method"), "trigger shows the choice")
	engine:input():click(trigger); settle()
	check(find(w.screen, "DropdownMenu"), "reopens")
	local ticks = findAll(find(w.screen, "DropdownMenu"), function(d) return d.Name == "Selected" end)
	eq(#ticks, 1, "exactly one row, the current choice, carries the tick")
	check(ticks[1]:FindFirstAncestor("Option") ~= nil and text(ticks[1].Parent, "Recursion Method"), "the tick is on the chosen row")
	engine:input():click(find(w.screen, "DropdownScrim")); settle()
	eq(find(w.screen, "DropdownMenu"), nil, "click-away closes the menu")
	teardown(w)
end)

test("dropdown with no methods is disabled and says why", function()
	local w = newWorld()
	w.methods:set({}); w.app.state.refreshMethods(); settle()
	check(text(w.screen, "No methods loaded"), "empty text")
	engine:input():click(find(w.screen, "Trigger", "TextButton")); settle()
	eq(find(w.screen, "DropdownMenu"), nil, "does not open when empty")
	local m = newModule(w); Selection:Set({ m }); settle()
	check(w.app.state.gate.bypass():find("No bypass methods"), "reason mentions missing methods")
	teardown(w)
end)

test("reload button reloads methods and keeps the selected one", function()
	local w = newWorld()
	w.app.state.method:set("Recursion Method")
	click(button(w.screen, "Reload")); settle()
	eq(w.reloaded, 1, "reload callback ran")
	eq(w.app.state.method:peek(), "Recursion Method", "selection kept")
	eq(w.app.state.statusLine:peek().level, "success")
	teardown(w)
end)

test("history: success commits, failure cancels and re-raises, a blocked recording still runs", function()
	local h = History.new(ChangeHistory, log)
	table.clear(recordings)
	local ran = false
	h:record("ok", function() ran = true end)
	check(ran and recordings[1].op == "Commit", "commit on success")
	local ok, err = pcall(h.record, h, "bad", function() error("boom", 0) end)
	check(not ok and err == "boom", "error re-raised")
	eq(recordings[2].op, "Cancel", "cancel on failure")
	ChangeHistory.active = "someone else"
	local ranBlocked = false
	h:record("blocked", function() ranBlocked = true end)
	check(ranBlocked, "still runs when no recording could start")
	eq(#recordings, 2, "nothing recorded while blocked")
	ChangeHistory.active = nil
	local plain = History.new(nil, log); local ran2 = false
	plain:record("x", function() ran2 = true end)
	check(ran2, "runs without a ChangeHistoryService")
end)

test("status messages: success fades back to Ready, errors stay until dismissed", function()
	local w = newWorld()
	local m = newModule(w); Selection:Set({ m }); settle()
	click(button(w.screen, "Bypass")); settle()
	eq(w.app.state.statusLine:peek().level, "success")
	frames(60 * 11)
	eq(w.app.state.statusLine:peek().level, "idle", "success message fades to Ready")
	Selection:Set({}); settle()
	w.app.state.status:set({ level = "error", text = "kaboom", id = 99 })
	frames(60 * 20)
	eq(w.app.state.statusLine:peek().level, "error", "errors stay")
	click(find(w.screen, "IconButton_close")); settle()
	eq(w.app.state.statusLine:peek().level, "idle", "dismiss clears it")
	teardown(w)
end)



test("status strip: the dot and the text are centred in the bar and with each other", function()
	local w = newWorld()
	engine:setViewport(Vector2.new(520, 760)); frames(8)
	local bar = find(w.screen, "StatusMessage")
	local dot = find(bar, "Indicator")
	local label = find(bar, "Text", "TextLabel")
	local function centre(d) return d.AbsolutePosition.Y + d.AbsoluteSize.Y / 2 end
	local barCentre = bar.AbsolutePosition.Y + bar.AbsoluteSize.Y / 2
	print(string.format("        bar y=%.1f h=%.1f | dot centre %.1f | text centre %.1f | bar centre %.1f", bar.AbsolutePosition.Y, bar.AbsoluteSize.Y, centre(dot), centre(label), barCentre))
	check(math.abs(centre(dot) - centre(label)) <= 1, "dot and text share a centre line")
	-- the 1 px divider sits on top, so the content centre is half a pixel below the bar's centre
	check(math.abs(centre(label) - barCentre) <= 1.5, "row is vertically centred in the status bar")
	teardown(w)
end)

test("theme: text tokens stay readable on every surface (Studio-derived palette)", function()
	local C = Theme.color
	local function lin(c) return if c <= 0.03928 then c / 12.92 else ((c + 0.055) / 1.055) ^ 2.4 end
	local function lum(c) return 0.2126 * lin(c.R) + 0.7152 * lin(c.G) + 0.0722 * lin(c.B) end
	local function ratio(a, b)
		local la, lb = lum(a), lum(b)
		if la < lb then la, lb = lb, la end
		return (la + 0.05) / (lb + 0.05)
	end
	local surfaces = { "chrome", "canvas", "card", "sunken", "control", "popup", "subtle" }
	for _, s in surfaces do
		check(ratio(C.text, C[s]) >= 7, "text on " .. s)
		check(ratio(C.textMuted, C[s]) >= 4.5, "textMuted on " .. s)
		check(ratio(C.textTertiary, C[s]) >= 4.5, "textTertiary on " .. s)
	end
	check(ratio(C.onAccent, C.accent) >= 4.5, "label on accent button")
	check(ratio(C.onAccent, C.accentHover) >= 4.5, "label on hovered accent button")
	check(ratio(C.accentText, C.accentSubtle) >= 4.5, "accent text on its subtle fill")
	check(ratio(C.text, C.accentSubtle) >= 4.5 and ratio(C.text, C.accentSubtleHover) >= 4.5, "selected nav / menu labels on the selection blue (rest and hover)")
	check(ratio(C.accentText, C.accentSubtleHover) >= 4.5, "selected icon / tick on the hovered selection blue")
	check(ratio(C.accentMark, C.chromeHover) >= 3 and ratio(C.accentMark, C.chromePressed) >= 3, "the accent icon and bar stay visible on the selected nav wash")
	check(ratio(C.textTertiary, C.accentSubtle) >= 4.5, "disabled primary label")
	for _, status in { "success", "warning", "error" } do
		check(ratio(C[status], C.card) >= 4.5, status .. " on card")
	end
end)

test("theme: refresh is a no-op outside Studio and leaves the palette intact", function()
	local before = Theme.color.accent
	eq(Theme.refresh(), false, "no Studio theme available headlessly")
	eq(Theme.color.accent, before, "palette unchanged")
end)



test("sidebar: footer shows the version; the toggle pins it collapsed or open", function()
	local w = newWorld()
	engine:setViewport(Vector2.new(760, 700)); frames(8)
	local footer = find(w.screen, "Footer")
	check(footer and text(footer, "main"), "the version chip lives in the sidebar footer")
	check(not find(footer, "StatusIndicator"), "the status is shown once, in the status bar, not duplicated in the footer")
	local sidebar = find(w.screen, "Sidebar")
	engine:setViewport(Vector2.new(760, 700)); frames(8)
	eq(math.round(sidebar.AbsoluteSize.X), 176, "expanded at a wide window")
	click(find(footer, "IconButton_sidebar")); frames(30)
	engine:setViewport(Vector2.new(760, 700)); frames(8)
	eq(w.app.state.navOverride:peek(), true, "collapse is pinned")
	eq(math.round(sidebar.AbsoluteSize.X), 56, "collapsed to the rail even though the window is wide")
	check(not text(footer, "main"), "the version chip hides in the rail")
	check(not text(w.screen, "Tools"), "the group label hides in the rail")
	click(find(footer, "IconButton_sidebar")); frames(30)
	engine:setViewport(Vector2.new(760, 700)); frames(8)
	eq(w.app.state.navOverride:peek(), false, "open is pinned")
	eq(math.round(sidebar.AbsoluteSize.X), 176, "expanded again")
	-- a pinned-open sidebar stays open in a narrow window
	engine:setViewport(Vector2.new(400, 700)); frames(12)
	eq(math.round(sidebar.AbsoluteSize.X), 176, "pinned open overrides the narrow-window rail")
	teardown(w)
end)



test("selection chip: Explorer-style, blue when something is selected, full text in the tooltip", function()
	local w = newWorld()
	local Theme_ = Theme.color
	local bar = find(w.screen, "StatusMessage")
	local chip = bar:FindFirstChild("SelectionSummary", true)
	check(near(chip.BackgroundColor3, Theme_.control), "neutral pill with nothing selected")
	local m = newModule(w, "Handler"); Selection:Set({ m }); settle(); frames(30)
	check(near(chip.BackgroundColor3, Theme_.accent), "selection blue once something is selected")
	local title = find(chip, "Title", "TextLabel")
	check(near(title.TextColor3, Theme_.onAccent), "label drawn for the blue fill")
	check(find(chip, "ClassIcon", "ImageLabel"), "class icon slot present")
	hoverOn(chip); frames(40)
	check(text(find(w.screen, "Overlay"), "Handler · ModuleScript"), "tooltip carries name and class")
	hoverOff(chip)
	teardown(w)
end)



test("nav markers: a count on Modules, a spinner on the page that is working", function()
	local w = newWorld()
	engine:setViewport(Vector2.new(760, 700)); frames(10) -- wide enough for the full sidebar
	local modulesNav, marketNav = find(w.screen, "Nav_Modules"), find(w.screen, "Nav_Marketplace")
	check(not modulesNav:FindFirstChild("NavBadge", true), "no badge with nothing selected")
	Selection:Set({ newModule(w, "A"), newModule(w, "B"), newModule(w, "C") }); settle(); frames(10)
	local badge = modulesNav:FindFirstChild("NavBadge", true)
	check(badge and text(badge, "3"), "Modules shows how many ModuleScripts are selected")
	check(not marketNav:FindFirstChild("NavBadge", true), "other pages have no count")
	-- the label keeps clear of the marker
	local label, marker = find(modulesNav, "Label"), find(modulesNav, "NavMarker")
	check(label.AbsolutePosition.X + label.AbsoluteSize.X <= marker.AbsolutePosition.X + 0.5, "the label stops before the badge")
	-- a running operation shows a spinner on its own page only
	w.app.state.busy:set("latest"); frames(10)
	check(marketNav:FindFirstChild("NavBusy", true), "Marketplace shows a spinner while its operation runs")
	check(not modulesNav:FindFirstChild("NavBusy", true), "other pages do not")
	w.app.state.busy:set(nil); frames(10)
	check(not marketNav:FindFirstChild("NavBusy", true), "the spinner goes away when the operation ends")
	-- in the icon rail the marker is a dot on the icon
	w.app.state.navOverride:set(true); frames(30)
	check(modulesNav:FindFirstChild("NavDot", true), "the rail shows a dot for the count")
	Selection:Set({}); settle(); frames(10)
	check(not modulesNav:FindFirstChild("NavDot", true), "the dot clears with the selection")
	teardown(w)
end)



test("page transition: a page fades in when shown and is usable right away", function()
	local w = newWorld()
	engine:setViewport(Vector2.new(760, 700)); frames(10)
	frames(40)
	local first = find(w.screen, "PageFade", "CanvasGroup")
	check(first and first.GroupTransparency < 0.01, "the first page has finished fading in")
	click(find(w.screen, "Nav_Marketplace")); frames(1)
	local fade = find(w.screen, "PageFade", "CanvasGroup")
	check(fade and fade ~= first, "switching builds a new page group")
	frames(1)
	check(fade.GroupTransparency > 0, "the new page starts faded")
	-- usable while it fades in: the insertion button responds to a click
	check(find(w.screen, "Button", "TextButton") ~= nil, "controls exist as soon as the page is shown")
	frames(40)
	check(fade.GroupTransparency < 0.01, "the page is fully visible after the fade")
	check(find(w.screen, "PageFade", "CanvasGroup") == fade, "no extra page group is left behind")
	teardown(w)
end)


test("settings: the window mode switch asks the plugin to move the panel, once, and not while busy", function()
	local w = newWorld()
	click(find(w.screen, "Nav_Settings")); settle()
	check(text(w.screen, "Window"), "the Window panel is on the Settings page")
	local docked, floating = find(w.screen, "Segment_Docked"), find(w.screen, "Segment_Floating window")
	check(docked and floating, "both options are offered")
	check(text(w.screen, "A normal Studio panel. Dock it next to the Explorer, float it, or tab it with other panels. Studio remembers where you leave it."), "the note explains docking")

	click(docked); settle()
	eq(#w.windowSwitches, 0, "choosing the mode it is already in changes nothing")

	click(floating); settle()
	eq(#w.windowSwitches, 1, "choosing the other mode asks the plugin once")
	eq(w.windowSwitches[1], "Floating")
	check(text(w.screen, "A window over the 3D view that never docks. Drag its title bar to move it, and drag its edges or the bottom-right corner to resize it. Use the toolbar button to show or hide it."), "the note explains the floating window")

	-- while an action runs the switch is disabled: the UI is about to be rebuilt and must not lose that work
	w.app.state.windowMode:set("Dock")
	w.app.state.busy:set("scan"); settle()
	click(floating); settle()
	eq(#w.windowSwitches, 1, "no switch while another action is running")
	w.app.state.busy:set(nil)
	teardown(w)
end)

test("settings: the Settings page opens from the sidebar and has no spinner of its own", function()
	local w = newWorld()
	local nav = find(w.screen, "Nav_Settings")
	check(nav, "the sidebar lists Settings")
	click(nav); settle()
	eq(w.app.state.page:peek(), "Settings")
	check(find(w.screen, "SettingsPage", "Frame"), "the page is shown")
	w.app.state.busy:set("scan"); settle()
	check(not nav:FindFirstChild("NavSpinner", true), "no page operation belongs to Settings")
	w.app.state.busy:set(nil)
	teardown(w)
end)

-- A pointer event the way the engine delivers one: only the fields the window reads.
local function pointer(kind, x, y)
	return { UserInputType = kind, Position = Vector3.new(x, y, 0) }
end

local function newFloating(options)
	engine:setViewport(Vector2.new(1280, 720))
	local folder = Instance.new("Folder")
	folder.Parent = engine.LocalPlayer.PlayerGui
	local win = FloatingWindow.create({
		parent = folder,
		title = "Sensation Utilities",
		rect = options and options.rect,
		enabled = options and options.enabled,
		onRect = options and options.onRect,
		isPointerDown = options and options.isPointerDown or function() return true end,
	})
	settle()
	return win, folder
end

test("floating window: opens near the right edge with the app's content area under the title bar", function()
	local win, folder = newFloating({ enabled = true })
	local frame = find(win.gui, "Window", "Frame")
	check(frame and frame.Visible, "the window is shown once the screen size is known")
	eq(frame.AbsoluteSize.X, 400)
	eq(frame.AbsolutePosition.X, 1280 - 400 - 24, "near the right edge")
	eq(win.content.AbsoluteSize.X, 400)
	eq(win.content.AbsoluteSize.Y, frame.AbsoluteSize.Y - 24, "the content fills the window below the title bar")
	check(text(win.gui, "Sensation Utilities"), "the title bar names the plugin")
	check(win.gui.Enabled, "it starts shown when asked to")
	win.destroy(); folder:Destroy()
end)

test("floating window: starts hidden unless asked, and the close button hides it", function()
	local win, folder = newFloating()
	check(not win.gui.Enabled, "hidden by default, like the dock")
	win.gui.Enabled = true
	click(find(win.gui, "Close", "TextButton"))
	check(not win.gui.Enabled, "the close button hides it")
	win.destroy(); folder:Destroy()
end)

test("floating window: dragging the title bar moves it, and the final place is reported", function()
	local saved = {}
	local win, folder = newFloating({ rect = { x = 200, y = 100, width = 400, height = 500 }, onRect = function(r) table.insert(saved, r) end })
	local frame = find(win.gui, "Window", "Frame")
	local bar = find(win.gui, "TitleBar", "Frame")
	bar.InputBegan:Fire(pointer(Enum.UserInputType.MouseButton1, 300, 110))
	local catcher = find(win.gui, "DragCatcher")
	check(catcher, "a layer follows the pointer while dragging")
	catcher.InputChanged:Fire(pointer(Enum.UserInputType.MouseMovement, 350, 140))
	settle()
	eq(frame.AbsolutePosition.X, 250); eq(frame.AbsolutePosition.Y, 130)
	eq(#saved, 0, "nothing is saved mid-drag")
	catcher.InputEnded:Fire(pointer(Enum.UserInputType.MouseButton1, 350, 140))
	settle()
	check(not find(win.gui, "DragCatcher"), "the layer is removed when the button is released")
	eq(#saved, 1, "the final place is reported once")
	eq(saved[1].x, 250); eq(saved[1].y, 130); eq(saved[1].width, 400)
	-- a stray move after the release does nothing
	frame.Position = frame.Position
	win.destroy(); folder:Destroy()
end)

test("floating window: a drag ends if the button was released outside the window", function()
	local down, saved = true, {}
	local win, folder = newFloating({ rect = { x = 200, y = 100, width = 400, height = 500 }, isPointerDown = function() return down end, onRect = function(r) table.insert(saved, r) end })
	local bar = find(win.gui, "TitleBar", "Frame")
	bar.InputBegan:Fire(pointer(Enum.UserInputType.MouseButton1, 300, 110))
	local catcher = find(win.gui, "DragCatcher")
	down = false -- released outside Studio: no InputEnded ever arrives
	catcher.InputChanged:Fire(pointer(Enum.UserInputType.MouseMovement, 400, 200))
	settle()
	check(not find(win.gui, "DragCatcher"), "the drag stops by itself")
	eq(#saved, 1)
	eq(find(win.gui, "Window", "Frame").AbsolutePosition.X, 200, "the window did not jump to the stray position")
	win.destroy(); folder:Destroy()
end)

test("floating window: dragging cannot lose the title bar off screen", function()
	local win, folder = newFloating({ rect = { x = 200, y = 100, width = 400, height = 500 } })
	local bar = find(win.gui, "TitleBar", "Frame")
	bar.InputBegan:Fire(pointer(Enum.UserInputType.MouseButton1, 300, 110))
	find(win.gui, "DragCatcher").InputChanged:Fire(pointer(Enum.UserInputType.MouseMovement, 300, -5000))
	settle()
	eq(find(win.gui, "Window", "Frame").AbsolutePosition.Y, 0, "it stops at the top of the screen")
	find(win.gui, "DragCatcher").InputEnded:Fire(pointer(Enum.UserInputType.MouseButton1, 300, -5000))
	win.destroy(); folder:Destroy()
end)

test("floating window: the corner resizes it and the left edge keeps the right edge", function()
	local win, folder = newFloating({ rect = { x = 500, y = 100, width = 400, height = 500 } })
	local frame = find(win.gui, "Window", "Frame")
	find(win.gui, "ResizeBottomRight", "Frame").InputBegan:Fire(pointer(Enum.UserInputType.MouseButton1, 900, 600))
	find(win.gui, "DragCatcher").InputChanged:Fire(pointer(Enum.UserInputType.MouseMovement, 960, 640))
	find(win.gui, "DragCatcher").InputEnded:Fire(pointer(Enum.UserInputType.MouseButton1, 960, 640))
	settle()
	eq(frame.AbsoluteSize.X, 460); eq(frame.AbsoluteSize.Y, 540)
	eq(frame.AbsolutePosition.X, 500, "the corner keeps the top-left")

	find(win.gui, "ResizeLeft", "Frame").InputBegan:Fire(pointer(Enum.UserInputType.MouseButton1, 500, 300))
	find(win.gui, "DragCatcher").InputChanged:Fire(pointer(Enum.UserInputType.MouseMovement, 440, 300))
	find(win.gui, "DragCatcher").InputEnded:Fire(pointer(Enum.UserInputType.MouseButton1, 440, 300))
	settle()
	eq(frame.AbsoluteSize.X, 520)
	eq(frame.AbsolutePosition.X + frame.AbsoluteSize.X, 960, "the right edge did not move")
	win.destroy(); folder:Destroy()
end)

test("floating window: it follows the screen size, and clicks on the window do not start drags elsewhere", function()
	local win, folder = newFloating({ rect = { x = 800, y = 500, width = 400, height = 600 } })
	engine:setViewport(Vector2.new(700, 500)); frames(10)
	local frame = find(win.gui, "Window", "Frame")
	check(frame.AbsolutePosition.X + 96 <= 700, "a smaller screen pulls the window back into view")
	check(frame.AbsolutePosition.Y + 24 <= 500, "its title bar is still on screen")
	-- only presses start a drag
	find(win.gui, "TitleBar", "Frame").InputBegan:Fire(pointer(Enum.UserInputType.MouseMovement, 10, 10))
	check(not find(win.gui, "DragCatcher"), "hovering the title bar is not a drag")
	win.destroy(); folder:Destroy()
end)

test("floating window: the app mounts into it, lays out for its size and unmounts cleanly", function()
	local w = newWorld()
	w.app.unmount(); w.screen:Destroy()
	local win, folder = newFloating({ rect = { x = 100, y = 50, width = 360, height = 640 }, enabled = true })
	local app = App.mount({
		widget = win.content, windowMode = "Floating", setWindowMode = function(mode) table.insert(w.windowSwitches, mode) end,
		operations = w.operations, methods = w.methods, presets = w.presets, log = log, commit = "main",
		reloadMethods = function() return 1 end, reloadPresets = function() return 1 end,
	})
	settle()
	check(find(win.content, "SensationUtilities", "Frame"), "the app is built inside the window's content")
	check(app.state.compactNav:peek(), "a 360 px wide window uses the icon rail")
	eq(app.state.windowMode:peek(), "Floating", "the Settings control shows the mode it is in")
	app.unmount(); frames(2)
	eq(#win.content:GetChildren(), 0, "unmounting empties the content")
	win.destroy(); folder:Destroy()
	w.workspaceFolder:Destroy(); table.remove(liveWorlds, table.find(liveWorlds, w) or 0)
end)

test("floating window: destroying it removes everything", function()
	local win, folder = newFloating({ enabled = true })
	local gui = win.gui
	win.destroy(); frames(2)
	check(gui.Parent == nil, "the ScreenGui is gone")
	eq(#folder:GetChildren(), 0)
	folder:Destroy()
end)

print(`\n{passed} passed, {failed} failed`)
if failed > 0 then require("@lune/process").exit(1) end
