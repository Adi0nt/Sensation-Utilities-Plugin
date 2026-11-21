--!strict
--- A compact square button that shows only an icon (dismiss, close, ...).

local Flux = require("../../Flux")
local Icon = require("./Icon")
local Theme = require("../Theme")
local Tooltip = require("./Tooltip")

local new = Flux.new
local C = Theme.color

export type Props = {
	icon: Icon.Kind,
	onClick: () -> (),
	--- What the button does. Shown as a tooltip.
	label: string,
	disabled: Flux.Reactive<boolean>?,
}

local SIZE = 24

local function IconButton(props: Props): TextButton
	local button = new "TextButton" {
		Name = `IconButton_{props.icon}`,
		Size = UDim2.fromOffset(SIZE, SIZE),
		Text = "",
		Flux.corner(Theme.radius.sm),
	}

	local hovered = Flux.Interact.hover(button)
	local pressed = Flux.Interact.press(button)
	local isDisabled = Flux.computed(function()
		return Flux.read(props.disabled) == true
	end)

	local fillColor = Flux.tween(function()
		return if pressed() then C.controlPressed else C.controlHover
	end, Theme.tween.fast)
	-- Quiet at rest: a wash appears only on hover or press.
	local fillTransparency = Flux.tween(function()
		return if not isDisabled() and (hovered() or pressed()) then 0 else 1
	end, Theme.tween.fast)

	local glyphColor = Flux.computed(function()
		if isDisabled() then
			return C.textTertiary
		elseif hovered() then
			return C.text
		end
		return C.textMuted
	end)

	Flux.edit(button) {
		BackgroundColor3 = fillColor,
		BackgroundTransparency = fillTransparency,
		Activated = function()
			if not isDisabled() then
				props.onClick()
			end
		end,

		new "Frame" {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(16, 16),
			BackgroundTransparency = 1,
			Icon(props.icon, glyphColor),
		},
	}

	Tooltip.attach(button, props.label, hovered)
	return button
end

return IconButton
