--!strict
--- Small 16 px glyphs drawn from rounded frames. Drawing them (instead of loading image assets) means the UI makes
--- no network requests for decoration and the glyphs follow the theme colours exactly.

local Flux = require("../../Flux")

export type Kind = "modules" | "market" | "studio" | "chevron" | "close"

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

local drawings: { [Kind]: (color: Color) -> { Instance } } = {
	-- A 2x2 grid of blocks.
	modules = function(color)
		return {
			block(1, 1, 6, 6, 2, color),
			block(9, 1, 6, 6, 2, color),
			block(1, 9, 6, 6, 2, color),
			block(9, 9, 6, 6, 2, color),
		}
	end,
	-- A storefront: filled awning, outlined shop front, filled door.
	market = function(color)
		return {
			block(1, 1.5, 14, 4.5, 1.5, color),
			new "Frame" {
				Position = UDim2.fromOffset(3.25, 7.75),
				Size = UDim2.fromOffset(9.5, 6.5),
				BackgroundTransparency = 1,
				Flux.corner(1),
				new "UIStroke" {
					Thickness = 1.5,
					Color = color,
					ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				},
			},
			block(6.75, 10.25, 2.5, 4.5, 1, color),
		}
	end,
	-- A character bust: head and shoulders.
	studio = function(color)
		return {
			block(4.5, 0.5, 7, 7, 3.5, color),
			block(1.5, 9, 13, 6.5, 3.5, color),
		}
	end,
	-- A downward chevron.
	chevron = function(color)
		return {
			bar(5.4, 7.6, 7.2, 1.6, 45, color),
			bar(10.6, 7.6, 7.2, 1.6, -45, color),
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
