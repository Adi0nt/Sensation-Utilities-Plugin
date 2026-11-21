--!nocheck
-- Geometry checks on the real App across dock sizes and pages (emulator computes layout; a same-size setViewport
-- forces a full relayout, which works around the emulator's stale incremental layout after late child insertion).
local B = require("./boot")
local engine, Flux, Clock = B.engine, B.Flux, B.Clock
local Operations = require("../../.smoke/tree/Core/Operations")
local Methods = require("../../.smoke/tree/Core/Methods")
local App = require("../../.smoke/tree/UI/App")

local function sig() local s = {}; function s:Connect() return { Disconnect = function() end } end return s end
local selectionList = {}
local Selection = { SelectionChanged = sig(), Get = function() return selectionList end, Set = function() end }
local store = Methods.new()
for _, n in { "Recursion Method", "Alpha Method" } do
	local f = Instance.new("Folder"); f.Name = n; Instance.new("Script").Parent = f
	local all = {}; for _, name in store:names() do all[name] = store:get(name) end; all[n] = f; store:set(all)
end
local silent = { info = function() end, warn = function() end }
local ops = Operations.new({ plugin = {}, selection = Selection, history = { record = function(_, _, fn) fn() end }, log = silent, methods = store, newIndex = function(i, p, v) i[p] = v end })

local function relayout(vw, vh)
	for _ = 1, 20 do Clock.step(1 / 60) end Clock.drain()
	engine:setViewport(Vector2.new(vw, vh))
	for _ = 1, 20 do Clock.step(1 / 60) end Clock.drain()
end

local violations, checks = {}, 0
local function flag(ctx, msg) table.insert(violations, ctx .. ": " .. msg) end
local function rect(d) return d.AbsolutePosition.X, d.AbsolutePosition.Y, d.AbsoluteSize.X, d.AbsoluteSize.Y end

local function inside(d, ancestor) return d:IsDescendantOf(ancestor) end

local function verify(vw, vh, page, selectionKind)
	local ctx = string.format("[%dx%d %s%s]", vw, vh, page, selectionKind and (" sel=" .. selectionKind) or "")
	engine:setViewport(Vector2.new(vw, vh))
	local screen = Instance.new("ScreenGui"); screen.Parent = engine.LocalPlayer.PlayerGui
	selectionList = {}
	if selectionKind == "long" then
		local p = Instance.new("Part"); p.Name = "AVeryLongObjectNameThatKeepsGoingAndGoingAndGoing"; selectionList = { p }
	elseif selectionKind == "multi" then
		selectionList = { Instance.new("Part"), Instance.new("Script"), Instance.new("Model"), Instance.new("Folder") }
	end
	local app = App.mount({ widget = screen, operations = ops, methods = store, log = silent, commit = "d7ab719", reloadMethods = function() return 1 end })
	app.state.page:set(page)
	relayout(vw, vh)

	local function find(name) for _, d in screen:GetDescendants() do if d.Name == name then return d end end end
	local root = find("SensationUtilities")
	local header, sidebar, main, pages, status, summary, column =
		find("Header"), find("Sidebar"), find("Main"), find("Pages"), find("StatusMessage"), find("SelectionSummary"), find("Column")

	-- Shell geometry
	checks += 1
	local hx, hy, hw, hh = rect(header)
	if hh ~= 48 or hw ~= vw then flag(ctx, `header should be {vw}x48, got {hw}x{hh}`) end
	local sx, sy, sw, sh = rect(sidebar)
	local expectedSidebar = if vw < 540 then 56 else 160
	if math.abs(sw - expectedSidebar) > 1 then flag(ctx, `sidebar width {sw}, expected {expectedSidebar}`) end
	if math.abs(sh - (vh - 48)) > 1 then flag(ctx, `sidebar height {sh}, expected {vh - 48}`) end
	local mx, my, mw, mh = rect(main)
	if math.abs(mw - (vw - expectedSidebar)) > 1 then flag(ctx, `main width {mw}, expected {vw - expectedSidebar}`) end
	local stx, sty, stw, sth = rect(status)
	if math.abs((sty + sth) - vh) > 1 then flag(ctx, `status bar should end at the window bottom ({vh}), ends at {sty + sth}`) end
	local px, py, pw, ph = rect(pages)
	local sux, suy, suw, suh = rect(summary)
	if ph < 100 then flag(ctx, `page area is only {ph}px tall`) end
	if math.abs(py - (suy + suh)) > 1 then flag(ctx, `page area should start under the selection bar ({suy + suh}), starts at {py}`) end
	if math.abs((py + ph) - sty) > 1 then flag(ctx, `page area should end where the status bar starts ({sty}), ends at {py + ph}`) end

	-- Header contents fit: brand + meta within the header
	local brand, meta = find("Brand"), find("Meta")
	local bx, _, bw = rect(brand); local mex, _, mew = rect(meta)
	checks += 1
	if bx + bw > mex + 1 then flag(ctx, `header brand ({bx + bw}) overlaps the version/status area ({mex})`) end
	if mex + mew > vw + 0.5 then flag(ctx, `header meta runs past the window ({mex + mew} > {vw})`) end

	-- Content column: never wider than 640, never narrower than the window allows
	local cx, cy, cw, ch = rect(column)
	checks += 1
	if cw > 640.5 then flag(ctx, `content column is {cw}px wide (max 640)`) end
	if cx < px - 0.5 or cx + cw > px + pw + 0.5 then flag(ctx, "content column leaves the page area horizontally") end

	-- Every visible GuiObject in the page content must sit inside its parent horizontally (no clipping/overflow)
	local pageRoot = find(page .. "Page")
	for _, d in pageRoot:GetDescendants() do
		if d:IsA("GuiObject") and d.Visible then
			local p = d.Parent
			if p and p:IsA("GuiObject") and not p.Name:find("^Icon_") and not (d.Parent.Name:find("^Icon_")) and d.Name ~= "Spinner" and d.ClassName ~= "UIListLayout" then
				local dx, dy, dw, dh = rect(d); local ppx, ppy, ppw, pph = rect(p)
				checks += 1
				if dx < ppx - 1 or dx + dw > ppx + ppw + 1 then
					flag(ctx, `{d:GetFullName():match("[^.]+%.[^.]+$")} ({dx},{dw}) is outside its parent {p.Name} ({ppx},{ppw}) horizontally`)
				end
			end
		end
	end

	-- Sibling panels / rows in vertical lists must not overlap
	for _, container in pageRoot:GetDescendants() do
		local layout = container:IsA("GuiObject") and container:FindFirstChildOfClass("UIListLayout")
		if layout and layout.FillDirection == Enum.FillDirection.Vertical then
			local kids = {}
			for _, c in container:GetChildren() do if c:IsA("GuiObject") and c.Visible then table.insert(kids, c) end end
			table.sort(kids, function(a, b) return a.LayoutOrder < b.LayoutOrder end)
			for i = 2, #kids do
				local _, ay, _, ah = rect(kids[i - 1]); local _, by = rect(kids[i])
				checks += 1
				if by < ay + ah - 1 then flag(ctx, `{kids[i - 1].Name} overlaps {kids[i].Name} inside {container.Name} ({ay + ah} > {by})`) end
			end
		end
	end

	-- Buttons keep a consistent size
	for _, d in pageRoot:GetDescendants() do
		if d.ClassName == "TextButton" and d.Name == "Button" then
			local _, _, bw2, bh2 = rect(d)
			checks += 1
			if bh2 ~= 32 then flag(ctx, `button "{d.Text}" height {bh2} (expected 32)`) end
			if bw2 < 72 - 1 then flag(ctx, `button "{d.Text}" width {bw2} (min 72)`) end
			if bw2 > cw + 1 then flag(ctx, `button "{d.Text}" wider than the column`) end
		end
	end

	-- Studio cards: side by side only when there is room, otherwise stacked, never overlapping
	if page == "Studio" then
		local r6, r15 = find("Panel_R6 StarterCharacter"), find("Panel_R15 StarterCharacter")
		local x6, y6, w6, h6 = rect(r6); local x15, y15, w15, h15 = rect(r15)
		checks += 1
		local sideBySide = math.abs(y6 - y15) < 1
		local contentWidth = vw - expectedSidebar - 32
		if contentWidth < 400 and sideBySide then flag(ctx, "cards should stack when the content column is under 400px") end
		if contentWidth >= 400 and not sideBySide then flag(ctx, "cards should be side by side when there is room") end
		if sideBySide and (x6 + w6 > x15 + 1) then flag(ctx, "R6 and R15 cards overlap") end
		if not sideBySide and (y6 + h6 > y15 + 1) then flag(ctx, "stacked cards overlap") end
	end

	local report = {
		ctx = ctx, sidebar = sw, content = cw, pages = string.format("%dx%d", pw, ph),
		pageHeight = (function() local _, _, _, h = rect(pageRoot); return h end)(),
	}
	app.unmount(); screen:Destroy()
	return report
end

local sizes = { { 320, 400 }, { 360, 700 }, { 480, 700 }, { 539, 700 }, { 540, 700 }, { 591, 700 }, { 592, 700 }, { 900, 700 }, { 1400, 900 } }
for _, size in sizes do
	for _, page in { "Modules", "Marketplace", "Studio" } do
		local r = verify(size[1], size[2], page, nil)
		print(string.format("%-26s sidebar=%3d column=%3d pageArea=%-9s pageContentHeight=%d", r.ctx, r.sidebar, r.content, r.pages, r.pageHeight))
	end
end
for _, kind in { "long", "multi" } do
	for _, size in { { 320, 400 }, { 520, 760 } } do verify(size[1], size[2], "Modules", kind) end
end

print(`\n{checks} geometry checks, {#violations} violations`)
for _, v in violations do print("  VIOLATION " .. v) end
if #violations > 0 then require("@lune/process").exit(1) end
