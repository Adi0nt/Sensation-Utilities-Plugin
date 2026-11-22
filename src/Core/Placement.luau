--!strict
--- Where the floating window sits on screen. Plain numbers only (no engine types), so the rules are unit-tested.
---
--- A window may be dragged partly off screen, but never so far that its title bar cannot be grabbed again, and it never
--- grows past the screen or shrinks below a size the interface can lay out in.

export type Rect = { x: number, y: number, width: number, height: number }
export type Size = { x: number, y: number }
--- Which edges a resize handle moves.
export type Edges = { left: boolean?, right: boolean?, bottom: boolean? }

local Placement = {}

Placement.MIN_WIDTH = 320
Placement.MIN_HEIGHT = 400
Placement.DEFAULT_WIDTH = 400
Placement.DEFAULT_HEIGHT = 680
--- Height of the title bar: the part that must stay on screen so the window can always be moved back.
Placement.TITLE_HEIGHT = 24 -- with the 4 px the app leaves under it, the content starts where a docked panel's does
--- At least this much of the window's width stays on screen.
Placement.KEEP_VISIBLE = 96
--- Space left around a new window.
Placement.MARGIN = 24

local function finite(value: any): boolean
	return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end

local function round(value: number): number
	return math.floor(value + 0.5)
end

--- Keeps `rect` usable on a screen of `screen` pixels.
function Placement.fit(rect: Rect, screen: Size): Rect
	local width = math.clamp(rect.width, Placement.MIN_WIDTH, math.max(Placement.MIN_WIDTH, screen.x))
	local height = math.clamp(rect.height, Placement.MIN_HEIGHT, math.max(Placement.MIN_HEIGHT, screen.y))
	local keep = math.min(Placement.KEEP_VISIBLE, width)
	return {
		x = round(math.clamp(rect.x, keep - width, math.max(keep - width, screen.x - keep))),
		y = round(math.clamp(rect.y, 0, math.max(0, screen.y - Placement.TITLE_HEIGHT))),
		width = round(width),
		height = round(height),
	}
end

--- The first placement: near the right edge, below the top bar, and no taller than the screen.
function Placement.initial(screen: Size): Rect
	local width = Placement.DEFAULT_WIDTH
	local top = Placement.MARGIN * 2 -- clear of Studio's top bar
	local height = math.min(Placement.DEFAULT_HEIGHT, screen.y - top - Placement.MARGIN)
	return Placement.fit({
		x = screen.x - width - Placement.MARGIN,
		y = top,
		width = width,
		height = height,
	}, screen)
end

--- `start` moved by (dx, dy).
function Placement.move(start: Rect, dx: number, dy: number, screen: Size): Rect
	return Placement.fit({ x = start.x + dx, y = start.y + dy, width = start.width, height = start.height }, screen)
end

--- `start` resized by dragging the given edges by (dx, dy). A left edge keeps the right edge where it was.
function Placement.resize(start: Rect, edges: Edges, dx: number, dy: number, screen: Size): Rect
	local x, width, height = start.x, start.width, start.height
	local right = start.x + start.width

	if edges.right then
		width = start.width + dx
	elseif edges.left then
		width = start.width - dx
	end
	if edges.bottom then
		height = start.height + dy
	end

	local maxWidth = math.max(Placement.MIN_WIDTH, screen.x)
	width = math.clamp(width, Placement.MIN_WIDTH, maxWidth)
	height = math.clamp(height, Placement.MIN_HEIGHT, math.max(Placement.MIN_HEIGHT, screen.y))
	if edges.left and not edges.right then
		x = right - width
	end

	return Placement.fit({ x = x, y = start.y, width = width, height = height }, screen)
end

--- Reads a rectangle saved in the plugin settings. `nil` when it is missing or damaged.
function Placement.decode(saved: any): Rect?
	if type(saved) ~= "table" then
		return nil
	end
	local x, y, width, height = saved.x, saved.y, saved.width, saved.height
	if not (finite(x) and finite(y) and finite(width) and finite(height)) then
		return nil
	end
	if width < Placement.MIN_WIDTH or height < Placement.MIN_HEIGHT then
		return nil
	end
	return { x = x, y = y, width = width, height = height }
end

return Placement
