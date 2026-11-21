--!strict
--- Shows what is selected in Explorer. `bar` is the always-visible strip under the header; `inline` is the same
--- information inside a panel (the publishing target). Driven by a summary node, so it updates on selection changes
--- without rebuilding anything.

local Flux = require("../../Flux")
local Format = require("../../Core/Format")
local Theme = require("../Theme")

local new = Flux.new
local C = Theme.color

export type Props = {
	summary: Flux.Reactive<Format.Summary>,
	variant: ("bar" | "inline")?,
	--- Small caption above the name, e.g. "Target".
	caption: string?,
}

local TITLE_HEIGHT = 18
local DETAIL_HEIGHT = 16
local CAPTION_HEIGHT = 14

local function SelectionSummary(props: Props): Frame
	local isBar = props.variant ~= "inline"

	local hasSelection = Flux.computed(function()
		return Flux.read(props.summary).kind ~= "none"
	end)

	local lines: { Instance } = {}
	if props.caption then
		table.insert(
			lines,
			new "TextLabel" {
				Name = "Caption",
				Size = UDim2.new(1, 0, 0, CAPTION_HEIGHT),
				BackgroundTransparency = 1,
				Text = props.caption,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextColor3 = C.textTertiary,
				FontFace = Theme.text.helper.face,
				TextSize = Theme.text.helper.size,
			}
		)
	end
	table.insert(
		lines,
		new "TextLabel" {
			Name = "Title",
			Size = UDim2.new(1, 0, 0, TITLE_HEIGHT),
			BackgroundTransparency = 1,
			Text = function()
				return Flux.read(props.summary).title
			end,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			TextColor3 = function()
				return if hasSelection() then C.text else C.textMuted
			end,
			FontFace = Theme.text.label.face,
			TextSize = Theme.text.label.size,
		}
	)
	table.insert(
		lines,
		new "TextLabel" {
			Name = "Detail",
			Size = UDim2.new(1, 0, 0, DETAIL_HEIGHT),
			BackgroundTransparency = 1,
			Text = function()
				return Flux.read(props.summary).detail
			end,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			TextColor3 = C.textTertiary,
			FontFace = Theme.text.helper.face,
			TextSize = Theme.text.helper.size,
		}
	)

	local verticalPadding = if isBar then 6 else 10
	local contentHeight = TITLE_HEIGHT + DETAIL_HEIGHT + 1 + (if props.caption then CAPTION_HEIGHT + 1 else 0)

	local root = new "Frame" {
		Name = "SelectionSummary",
		Size = UDim2.new(1, 0, 0, contentHeight + verticalPadding * 2),
		BackgroundColor3 = C.sunken,
		BackgroundTransparency = if isBar then 1 else 0,
		Flux.padding({ x = if isBar then Theme.size.pagePadding else 12, y = verticalPadding }),

		-- Selection indicator dot: accent when something is selected.
		new "Frame" {
			Name = "Dot",
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 0, 0.5, 0),
			Size = UDim2.fromOffset(8, 8),
			BackgroundColor3 = Flux.tween(function()
				return if hasSelection() then C.accent else C.neutral
			end, Theme.tween.base),
			Flux.corner(UDim.new(0.5, 0)),
		},

		new "Frame" {
			Name = "Text",
			Position = UDim2.fromOffset(18, 0),
			Size = UDim2.new(1, -18, 1, 0),
			BackgroundTransparency = 1,
			Flux.list({ gap = 1, justify = "center" }),
			lines,
		},
	}

	if not isBar then
		Flux.edit(root) {
			Flux.corner(Theme.radius.sm),
			Flux.stroke({ thickness = 1, color = C.border }),
		}
	end
	return root
end

return SelectionSummary
