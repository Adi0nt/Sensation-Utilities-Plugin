--!strict
--- A title with an optional one-line description. `level = "page"` is the large page title; the default is a
--- section heading inside a panel.

local Flux = require("../../Flux")
local Theme = require("../Theme")

local new = Flux.new
local C = Theme.color

export type Props = {
	title: Flux.Reactive<string>,
	description: Flux.Reactive<string>?,
	level: ("page" | "section")?,
}

local function SectionHeader(props: Props): Frame
	local isPage = props.level == "page"
	local titleStyle = if isPage then Theme.text.title else Theme.text.heading
	local descriptionStyle = if isPage then Theme.text.body else Theme.text.helper

	local children: { Instance } = {
		new "TextLabel" {
			Name = "Title",
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			Text = props.title,
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = C.text,
			FontFace = titleStyle.face,
			TextSize = titleStyle.size,
		},
	}
	if props.description then
		table.insert(
			children,
			new "TextLabel" {
				Name = "Description",
				Size = UDim2.fromScale(1, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				Text = props.description,
				TextWrapped = true,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextColor3 = C.textMuted,
				FontFace = descriptionStyle.face,
				TextSize = descriptionStyle.size,
			}
		)
	end

	local header = new "Frame" {
		Name = "SectionHeader",
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Flux.list({ gap = Theme.space.xs }),
		children,
	}
	if isPage then
		-- A little air between the page title block and the first card.
		Flux.edit(header) { Flux.padding({ bottom = Theme.space.xs }) }
	end
	return header
end

return SectionHeader
