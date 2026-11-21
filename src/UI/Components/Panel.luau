--!strict
--- A bordered surface that groups related controls under a heading. Panels are never nested.

local Flux = require("../../Flux")
local SectionHeader = require("./SectionHeader")
local Theme = require("../Theme")

local new = Flux.new
local C = Theme.color

export type Props = {
	title: string,
	description: Flux.Reactive<string>?,
	children: Flux.Children,
	--- Defaults to the parent's full width.
	size: Flux.Reactive<UDim2>?,
}

local function Panel(props: Props): Frame
	return new "Frame" {
		Name = `Panel_{props.title}`,
		Size = props.size or UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = C.surface,
		Flux.corner(Theme.radius.lg),
		Flux.stroke({ thickness = 1, color = C.border }),
		Flux.padding(Theme.space.md),
		Flux.list({ gap = 12 }),

		SectionHeader({ title = props.title, description = props.description }),
		props.children,
	}
end

return Panel
