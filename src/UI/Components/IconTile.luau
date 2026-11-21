--!strict
--- A 32 px tile that anchors a card or row (Caelum's `icon-tile`). `accent` tints it with the subtle accent.

local Flux = require("../../Flux")
local Icon = require("./Icon")
local Theme = require("../Theme")

local new = Flux.new
local C = Theme.color

local function IconTile(icon: Icon.Kind, accent: boolean?): Frame
	local tile = new "Frame" {
		Name = "IconTile",
		Size = UDim2.fromOffset(Theme.size.tile, Theme.size.tile),
		BackgroundColor3 = if accent then C.accentSubtle else C.subtle,
		Flux.corner(Theme.radius.md),

		new "Frame" {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(Theme.size.icon, Theme.size.icon),
			BackgroundTransparency = 1,
			Icon(icon, if accent then C.accentText else C.textMuted),
		},
	}
	if not accent then
		Flux.edit(tile) { Flux.stroke({ thickness = 1, color = C.border }) }
	end
	return tile
end

return IconTile
