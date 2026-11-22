--!strict
--- A checkbox row: a small box and either a text label or any content (the broken-asset rows use two lines). The whole
--- row is the click target. Checked is the accent with a tick; hover brightens the box border; disabled ignores clicks.

local Flux = require("../../Flux")
local Icon = require("./Icon")
local Theme = require("../Theme")

local new = Flux.new
local C = Theme.color

export type Props = {
	checked: Flux.Reactive<boolean>,
	onToggle: () -> (),
	--- A plain text label. Use `content` instead for anything richer.
	label: Flux.Reactive<string>?,
	content: Instance?,
	disabled: Flux.Reactive<boolean>?,
}

local BOX = 16

local function Checkbox(props: Props): TextButton
	local isChecked = Flux.computed(function()
		return Flux.read(props.checked) == true
	end)
	local isDisabled = Flux.computed(function()
		return Flux.read(props.disabled) == true
	end)

	local row = new "TextButton" {
		Name = "Checkbox",
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Text = "",
		Flux.list({ direction = "x", gap = Theme.space.sm, align = "start" }),
	}
	local hovered = Flux.Interact.hover(row)

	local box = new "Frame" {
		Name = "Box",
		Size = UDim2.fromOffset(BOX, BOX),
		BackgroundColor3 = Flux.tween(function()
			if isDisabled() then
				return C.controlDisabled
			elseif isChecked() then
				return C.accent
			elseif hovered() then
				return C.controlHover
			end
			return C.sunken
		end, Theme.tween.fast),
		Flux.corner(Theme.radius.xs),
		Flux.stroke({
			thickness = 1,
			color = Flux.tween(function()
				if isChecked() and not isDisabled() then
					return C.accent
				end
				return if hovered() and not isDisabled() then C.borderStrong else C.border
			end, Theme.tween.fast),
		}),

		Flux.show(isChecked, function()
			return new "Frame" {
				Name = "Tick",
				Size = UDim2.fromOffset(Theme.size.icon, Theme.size.icon),
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				BackgroundTransparency = 1,
				Icon("check", C.onAccent),
			}
		end),
	}

	local content: Instance
	if props.content then
		content = props.content
	else
		content = new "TextLabel" {
			Name = "Label",
			Size = UDim2.fromScale(0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			Text = props.label or "",
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = function()
				return if isDisabled() then C.textTertiary else C.text
			end,
			FontFace = Theme.text.body.face,
			TextSize = Theme.text.body.size,
			Flux.flex(),
		}
	end

	Flux.edit(row) {
		Activated = function()
			if not isDisabled() then
				props.onToggle()
			end
		end,
		box,
		content,
	}
	return row
end

return Checkbox
