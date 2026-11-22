--!strict
--- A row of mutually exclusive options (e.g. Insert / Append). One option is always selected.

local Flux = require("../../Flux")
local Theme = require("../Theme")

local new = Flux.new
local C = Theme.color

export type Option<T> = { value: T, label: string }

export type Props<T> = {
	options: { Option<T> },
	value: Flux.State<T>,
	label: string?,
	disabled: Flux.Reactive<boolean>?,
}

local HEIGHT = Theme.size.control

local function Segment<T>(option: Option<T>, props: Props<T>): TextButton
	local isDisabled = Flux.computed(function()
		return Flux.read(props.disabled) == true
	end)
	local isSelected = Flux.computed(function()
		return props.value() == option.value
	end)

	local segment = new "TextButton" {
		Name = `Segment_{option.label}`,
		Size = UDim2.new(0, 0, 1, 0),
		Text = option.label,
		FontFace = Theme.text.label.face,
		TextSize = Theme.text.label.size,
		Flux.corner(Theme.radius.xs),
		Flux.flex(),
	}

	local hovered = Flux.Interact.hover(segment)

	Flux.edit(segment) {
		BackgroundColor3 = Flux.tween(function()
			-- Caelum: the selected segment is raised on Control; hover is a quiet wash. Never the same fill.
			if isSelected() then
				return C.control
			elseif hovered() and not isDisabled() then
				return C.card
			end
			return C.sunken
		end, Theme.tween.fast),

		TextColor3 = function()
			if isDisabled() then
				return C.textTertiary
			elseif isSelected() then
				return C.text
			elseif hovered() then
				return C.text
			end
			return C.textMuted
		end,

		Activated = function()
			if not isDisabled() then
				props.value:set(option.value)
			end
		end,

		Flux.stroke({
			thickness = 1,
			color = Flux.tween(function()
				return if isSelected() then C.borderStrong else C.sunken
			end, Theme.tween.fast),
		}),
	}

	return segment
end

local function SegmentedControl<T>(props: Props<T>): Frame
	local segments: { Instance } = {}
	for _, option in props.options do
		table.insert(segments, Segment(option, props))
	end

	local track = new "Frame" {
		Name = "Track",
		Size = UDim2.new(1, 0, 0, HEIGHT),
		BackgroundColor3 = C.sunken,
		Flux.corner(Theme.radius.sm),
		Flux.stroke({ thickness = 1, color = C.border }),
		Flux.padding(2),
		Flux.list({ direction = "x", gap = 2 }),
		segments,
	}

	local children: { Instance } = {}
	if props.label then
		table.insert(
			children,
			new "TextLabel" {
				Name = "Label",
				Size = UDim2.fromScale(1, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				Text = props.label,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextColor3 = C.text,
				FontFace = Theme.text.label.face,
				TextSize = Theme.text.label.size,
			}
		)
	end
	table.insert(children, track)

	return new "Frame" {
		Name = "SegmentedControl",
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Flux.list({ gap = 6 }),
		children,
	}
end

return SegmentedControl
