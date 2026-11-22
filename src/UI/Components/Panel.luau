--!strict
--- A bordered card that groups related controls under a heading (Caelum's `panel`). Panels are never nested.
--- An optional icon tile anchors the heading, as on Caelum's tool cards.

local Flux = require("../../Flux")
local Icon = require("./Icon")
local IconTile = require("./IconTile")
local SectionHeader = require("./SectionHeader")
local Theme = require("../Theme")

local new = Flux.new
local C = Theme.color

export type Props = {
	title: string,
	description: Flux.Reactive<string>?,
	children: Flux.Children,
	icon: Icon.Kind?,
	--- Defaults to the parent's full width.
	size: Flux.Reactive<UDim2>?,
}

local function Panel(props: Props): Frame
	local header = SectionHeader({ title = props.title, description = props.description })

	local top: Instance = header
	if props.icon then
		top = new "Frame" {
			Name = "Heading",
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			Flux.list({ direction = "x", gap = Theme.space.md, align = "start" }),

			IconTile(props.icon),
			new "Frame" {
				Size = UDim2.fromScale(0, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				Flux.flex(),
				header,
			},
		}
	end

	return new "Frame" {
		Name = `Panel_{props.title}`,
		Size = props.size or UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = C.card,
		Flux.corner(Theme.radius.md),
		Flux.stroke({ thickness = 1, color = C.border }),
		Flux.padding(Theme.space.lg),
		Flux.list({ gap = Theme.space.md }),

		top,
		props.children,
	}
end

return Panel
