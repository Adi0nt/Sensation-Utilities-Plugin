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
	fill: Flux.Reactive<boolean>?,
}

-- Left padding while loading: the spinner's 14 px plus its margin, so the label never moves under it.
local SPINNER_PADDING = 32

type Palette = {
	base: Color3,
	hover: Color3,
	pressed: Color3,
	text: Color3,
	border: Color3,
	borderHover: Color3,
	disabledBase: Color3,
	disabledText: Color3,
	disabledBorder: Color3,
}

-- Same interaction model for every variant: rest, hover, pressed, disabled.
local function palettes(): { [Variant]: Palette }
	return {
		primary = {
			base = C.accent,
			hover = C.accentHover,
			pressed = C.accentPressed,
			text = C.onAccent,
			border = C.accent,
			borderHover = C.accentHover,
			-- Caelum: a disabled primary drops to the subtle accent fill.
			disabledBase = C.accentSubtle,
			disabledText = C.textTertiary,
			disabledBorder = C.accentSubtle,
		},
		secondary = {
			base = C.control,
			hover = C.controlHover,
			pressed = C.controlPressed,
			text = C.text,
			border = C.border,
			borderHover = C.borderStrong,
			disabledBase = C.controlDisabled,
			disabledText = C.textTertiary,
			disabledBorder = C.borderSubtle,
		},
		ghost = {
			base = C.card,
			hover = C.cardHover,
			pressed = C.control,
			text = C.textMuted,
			border = C.card,
			borderHover = C.card,
			disabledBase = C.card,
			disabledText = C.textTertiary,
			disabledBorder = C.card,
		},
	}
end

local function Button(props: Props): TextButton
	local variant: Variant = props.variant or "secondary"
	local palette = palettes()[variant]
	local isDisabled = Flux.computed(function()
		return Flux.read(props.disabled) == true
	end)
	local isLoading = Flux.computed(function()
		return Flux.read(props.loading) == true
	end)

	local button = new "TextButton" {
		Name = "Button",
		Size = function()
			return if Flux.read(props.fill) == true
				then UDim2.new(1, 0, 0, Theme.size.control)
				else UDim2.fromOffset(0, Theme.size.control)
		end,
		AutomaticSize = function()
			return if Flux.read(props.fill) == true then Enum.AutomaticSize.None else Enum.AutomaticSize.X
		end,
		Text = props.label,
		FontFace = Theme.text.label.face,
		TextSize = Theme.text.label.size,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Flux.corner(Theme.radius.sm),
		Flux.sizeConstraint({ minWidth = 72 }),
	}

	local hovered = Flux.Interact.hover(button)
	local pressed = Flux.Interact.press(button)
	local active = Flux.computed(function()
		return not isDisabled()
	end)

	local fillColor = Flux.tween(function()
		if isDisabled() then
			return palette.disabledBase
		elseif pressed() then
			return palette.pressed
		elseif hovered() then
			return palette.hover
		end
		return palette.base
	end, Theme.tween.fast)

	local strokeColor = Flux.tween(function()
		if isDisabled() then
			return palette.disabledBorder
		elseif hovered() or pressed() then
			return palette.borderHover
		end
		return palette.border
	end, Theme.tween.fast)

	local textColor = Flux.computed(function()
		return if isDisabled() then palette.disabledText else palette.text
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
			return { left = if isLoading() then SPINNER_PADDING else 16, right = 16 }
		end),
		Flux.stroke({ thickness = 1, color = strokeColor }),

		Flux.show(isLoading, function()
			return new "Frame" {
				Name = "Spinner",
				AnchorPoint = Vector2.new(0, 0.5),
				-- UIPadding moves children too, so the spinner is offset back to sit in the padding, 10 px from the edge.
				Position = UDim2.new(0, 10 - SPINNER_PADDING, 0.5, 0),
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
