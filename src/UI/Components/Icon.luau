--!strict
--- Small 16 px glyphs drawn from rounded frames. Drawing them (instead of loading image assets) means the UI makes
--- no network requests for decoration and the glyphs follow the theme colours exactly.

local Flux = require("../../Flux")

export type Kind = "modules" | "market" | "studio" | "chevron" | "close" | "check" | "commit" | "sidebar"

local new = Flux.new

local SIZE = 16

type Color = Flux.Reactive<Color3>

local function block(x: number, y: number, width: number, height: number, radius: number, color: Color): Frame
	return new "Frame" {
		Position = UDim2.fromOffset(x, y),
		Size = UDim2.fromOffset(width, height),
		BackgroundColor3 = color,
		Flux.corner(radius),
	}
end

--- A line segment, centred on (x, y) and rotated.
local function bar(x: number, y: number, length: number, thickness: number, rotation: number, color: Color): Frame
	return new "Frame" {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(x, y),
		Size = UDim2.fromOffset(length, thickness),
		Rotation = rotation,
		BackgroundColor3 = color,
		Flux.corner(thickness / 2),
	}
end

local STROKE = 1.25

--- An outlined rounded box. The box is given as the OUTER edge of the line (x, y, width, height), the way the glyph is
--- designed on the 16 px grid; the frame itself is inset by the line width because the stroke is drawn outside it.
local function outline(x: number, y: number, width: number, height: number, corner: any, color: Color): Frame
	return new "Frame" {
		Position = UDim2.fromOffset(x + STROKE, y + STROKE),
		Size = UDim2.fromOffset(width - STROKE * 2, height - STROKE * 2),
		BackgroundTransparency = 1,
		Flux.corner(corner),
		new "UIStroke" {
			Thickness = STROKE,
			Color = color,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		},
	}
end

-- Line glyphs, like Caelum's: 1.25 px outlines on a 16 px grid.
local drawings: { [Kind]: (color: Color) -> { Instance } } = {
	-- A 2x2 grid of outlined tiles.
	modules = function(color)
		return {
			outline(1, 1, 6.5, 6.5, 2, color),
			outline(8.5, 1, 6.5, 6.5, 2, color),
			outline(1, 8.5, 6.5, 6.5, 2, color),
			outline(8.5, 8.5, 6.5, 6.5, 2, color),
		}
	end,
	-- A storefront: outlined awning and shop front, with a small door.
	market = function(color)
		return {
			outline(1, 1.5, 14, 4.5, 1.5, color),
			outline(2.5, 6.5, 11, 8, 1.5, color),
			block(6.75, 10.5, 2.5, 4, 1, color),
		}
	end,
	-- A character bust: outlined head and shoulders.
	studio = function(color)
		return {
			outline(4.75, 0.75, 6.5, 6.5, 3.25, color),
			outline(2, 9, 12, 6.25, { topLeft = 4, topRight = 4, bottomLeft = 1.5, bottomRight = 1.5 }, color),
		}
	end,
	-- A commit: a ring on a line.
	commit = function(color)
		return {
			bar(3.25, 8, 4.5, STROKE, 0, color),
			bar(12.75, 8, 4.5, STROKE, 0, color),
			outline(4.75, 4.75, 6.5, 6.5, 3.25, color),
		}
	end,
	-- A window with its left pane marked: the sidebar toggle.
	sidebar = function(color)
		return {
			outline(1, 2.5, 14, 11, 2.5, color),
			block(5.4, 3.75, STROKE, 8.5, 0.6, color),
		}
	end,
	-- A downward chevron.
	chevron = function(color)
		return {
			bar(5.4, 7.6, 7.2, 1.6, 45, color),
			bar(10.6, 7.6, 7.2, 1.6, -45, color),
		}
	end,
	-- A tick.
	check = function(color)
		return {
			bar(5.1, 9.9, 5.6, 1.7, 45, color),
			bar(9.8, 8.1, 9.4, 1.7, -45, color),
		}
	end,
	close = function(color)
		return {
			bar(8, 8, 12, 1.6, 45, color),
			bar(8, 8, 12, 1.6, -45, color),
		}
	end,
}

--- A 16x16 icon. `color` may be static or reactive.
local function Icon(kind: Kind, color: Color): Frame
	return new "Frame" {
		Name = `Icon_{kind}`,
		Size = UDim2.fromOffset(SIZE, SIZE),
		BackgroundTransparency = 1,
		drawings[kind](color),
	}
end

return Icon
