--!strict
--- Buttons. States: default, hover, pressed, disabled, loading. Colour changes are a short tween; the control is
--- usable immediately and never waits for an animation.

local Flux = require("../../Flux")
local LoadingIndicator = require("./LoadingIndicator")
local Theme = require("../Theme")
local Tooltip = require("./Tooltip")

local new = Flux.new
local C = Theme.color

export type Variant = "primary" | "secondary" | "ghost"

export type Props = {
	label: Flux.Reactive<string>,
	onClick: () -> (),
	variant: Variant?,
	--- Disabled buttons ignore clicks, ignore hover/press feedback and use the disabled palette.
	disabled: Flux.Reactive<boolean>?,
	--- Shows a spinner and ignores clicks (but keeps the normal colours).
	loading: Flux.Reactive<boolean>?,
	--- Hover text; typically the reason a control is disabled.
	tooltip: Flux.Reactive<string?>?,
	--- Stretch to the parent's width instead of hugging the label.
	fill: boolean?,
}

type Palette = {
	base: Color3,
	hover: Color3,
	pressed: Color3,
	text: Color3,
	border: Color3,
	borderHover: Color3,
}

local palettes: { [Variant]: Palette } = {
	primary = {
		base = C.accent,
		hover = C.accentHover,
		pressed = C.accentPressed,
		text = C.onAccent,
		border = C.accent,
		borderHover = C.accentHover,
	},
	secondary = {
		base = C.input,
		hover = C.inputHover,
		pressed = C.inputPressed,
		text = C.text,
		border = C.border,
		borderHover = C.borderHover,
	},
	ghost = {
		base = C.surface,
		hover = C.input,
		pressed = C.inputPressed,
		text = C.textMuted,
		border = C.surface,
		borderHover = C.border,
	},
}

local function Button(props: Props): TextButton
	local variant: Variant = props.variant or "secondary"
	local palette = palettes[variant]
	local isDisabled = Flux.computed(function()
		return Flux.read(props.disabled) == true
	end)
	local isLoading = Flux.computed(function()
		return Flux.read(props.loading) == true
	end)

	local button = new "TextButton" {
		Name = "Button",
		Size = if props.fill then UDim2.new(1, 0, 0, Theme.size.control) else UDim2.fromOffset(0, Theme.size.control),
		AutomaticSize = if props.fill then Enum.AutomaticSize.None else Enum.AutomaticSize.X,
		Text = props.label,
		FontFace = Theme.text.label.face,
		TextSize = Theme.text.label.size,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Flux.corner(Theme.radius.md),
		Flux.sizeConstraint({ minWidth = 72 }),
	}

	local hovered = Flux.Interact.hover(button)
	local pressed = Flux.Interact.press(button)
	local active = Flux.computed(function()
		return not isDisabled()
	end)

	local fillColor = Flux.tween(function()
		if isDisabled() then
			return C.disabledBg
		elseif pressed() then
			return palette.pressed
		elseif hovered() then
			return palette.hover
		end
		return palette.base
	end, Theme.tween.fast)

	local strokeColor = Flux.tween(function()
		if isDisabled() then
			return C.border
		elseif hovered() or pressed() then
			return palette.borderHover
		end
		return palette.border
	end, Theme.tween.fast)

	local textColor = Flux.computed(function()
		return if isDisabled() then C.textDisabled else palette.text
	end)

	Flux.edit(button) {
		BackgroundColor3 = fillColor,
		TextColor3 = textColor,

		Activated = function()
			if active() and not isLoading() then
				props.onClick()
			end
		end,

		-- Room for the spinner on the left while loading.
		Flux.padding(function()
			return { left = if isLoading() then 32 else 16, right = 16 }
		end),
		Flux.stroke({ thickness = 1, color = strokeColor }),

		Flux.show(isLoading, function()
			return new "Frame" {
				Name = "Spinner",
				AnchorPoint = Vector2.new(0, 0.5),
				Position = UDim2.new(0, 10, 0.5, 0),
				Size = UDim2.fromOffset(14, 14),
				BackgroundTransparency = 1,
				LoadingIndicator({ color = textColor, size = 14 }),
			}
		end),
	}

	if props.tooltip then
		Tooltip.attach(button, props.tooltip, hovered)
	end

	return button
end

return Button
