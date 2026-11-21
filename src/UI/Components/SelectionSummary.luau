--!strict
--- Shows what is selected in Explorer. `chip` is the compact one-line pill at the right of the top bar; `inline` is the
--- two-line version inside a panel (the publishing target). Driven by a summary node, so both update on selection
--- changes without rebuilding anything.

local Flux = require("../../Flux")
local Format = require("../../Core/Format")
local Theme = require("../Theme")

local new = Flux.new
local C = Theme.color

export type Props = {
	summary: Flux.Reactive<Format.Summary>,
	variant: ("chip" | "inline")?,
	--- Small caption above the name (inline only), e.g. "Target".
	caption: string?,
	--- Widest the chip may get, so long names truncate instead of pushing into the logo (chip only).
	maxWidth: Flux.Reactive<number>?,
}

local TITLE_HEIGHT = 18
local DETAIL_HEIGHT = 16
local CAPTION_HEIGHT = 14

local CHIP_HEIGHT = 24
local CHIP_PADDING = 10
local CHIP_GAP = 8
local DOT = 8
local CHIP_DEFAULT_MAX = 320

--- The compact one-line pill: `● name · class`.
local function Chip(props: Props): Frame
	local hasSelection = Flux.computed(function()
		return Flux.read(props.summary).kind ~= "none"
	end)
	local function chipMax(): number
		return Flux.read(props.maxWidth) or CHIP_DEFAULT_MAX
	end

	return new "Frame" {
		Name = "SelectionSummary",
		Size = UDim2.fromOffset(0, CHIP_HEIGHT),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = C.control,
		Flux.corner(Theme.radius.sm),
		Flux.padding({ x = CHIP_PADDING }),
		Flux.list({ direction = "x", gap = CHIP_GAP, align = "center" }),
		Flux.sizeConstraint({ maxWidth = chipMax }),

		-- Indicator dot: accent when something is selected.
		new "Frame" {
			Name = "Dot",
			Size = UDim2.fromOffset(DOT, DOT),
			BackgroundColor3 = Flux.tween(function()
				return if hasSelection() then C.accent else C.neutral
			end, Theme.tween.base),
			Flux.corner(UDim.new(0.5, 0)),
		},

		new "TextLabel" {
			Name = "Title",
			Size = UDim2.fromOffset(0, CHIP_HEIGHT),
			AutomaticSize = Enum.AutomaticSize.X,
			BackgroundTransparency = 1,
			Text = function()
				return Format.oneLine(Flux.read(props.summary))
			end,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			TextColor3 = function()
				return if hasSelection() then C.text else C.textMuted
			end,
			FontFace = Theme.text.label.face,
			TextSize = Theme.text.label.size,
			-- The chip's maximum minus its padding, dot and gap.
			Flux.sizeConstraint({
				maxWidth = function()
					return chipMax() - CHIP_PADDING * 2 - DOT - CHIP_GAP
				end,
			}),
		},
	}
end

--- The two-line version inside a panel.
local function Inline(props: Props): Frame
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

	local verticalPadding = 10
	local contentHeight = TITLE_HEIGHT + DETAIL_HEIGHT + 1 + (if props.caption then CAPTION_HEIGHT + 1 else 0)

	return new "Frame" {
		Name = "SelectionSummary",
		Size = UDim2.new(1, 0, 0, contentHeight + verticalPadding * 2),
		BackgroundColor3 = C.sunken,
		Flux.corner(Theme.radius.sm),
		Flux.stroke({ thickness = 1, color = C.border }),
		Flux.padding({ x = 12, y = verticalPadding }),

		-- Selection indicator dot: accent when something is selected.
		new "Frame" {
			Name = "Dot",
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 0, 0.5, 0),
			Size = UDim2.fromOffset(DOT, DOT),
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
end

local function SelectionSummary(props: Props): Frame
	if props.variant == "chip" then
		return Chip(props)
	end
	return Inline(props)
end

return SelectionSummary
