--!strict
--- Single-line text field with label, helper text and an inline error. `NumberInput` is the digits-only variant used
--- for asset ids and versions. States: default, hover, focused, error, disabled.

local Flux = require("../../Flux")
local Theme = require("../Theme")
local Validation = require("../../Core/Validation")

local new = Flux.new
local C = Theme.color

export type Props = {
	value: Flux.State<string>,
	label: string?,
	placeholder: string?,
	--- Shown in red under the field and turns the border red.
	error: Flux.Reactive<string?>?,
	--- Shown in muted text under the field when there is no error.
	helper: Flux.Reactive<string?>?,
	disabled: Flux.Reactive<boolean>?,
	--- Applied to every edit; return the cleaned text (e.g. strip non-digits).
	sanitize: ((text: string) -> string)?,
	--- Called when Enter is pressed.
	onSubmit: (() -> ())?,
}

local FIELD_HEIGHT = Theme.size.control

local function TextInput(props: Props): Frame
	local isDisabled = Flux.computed(function()
		return Flux.read(props.disabled) == true
	end)

	local sanitize = props.sanitize
	if sanitize then
		Flux.effect(function()
			local current = props.value()
			local cleaned = sanitize(current)
			if cleaned ~= current then
				props.value:set(cleaned)
			end
		end)
	end

	local textBox = new "TextBox" {
		Name = "Field",
		Position = UDim2.fromOffset(12, 0),
		Size = UDim2.new(1, -24, 1, 0),
		BackgroundTransparency = 1,
		Text = Flux.model(props.value),
		PlaceholderText = props.placeholder or "",
		PlaceholderColor3 = C.textTertiary,
		ClearTextOnFocus = false,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		FontFace = Theme.text.body.face,
		TextSize = Theme.text.body.size,
		TextEditable = function()
			return not isDisabled()
		end,
		TextColor3 = function()
			return if isDisabled() then C.textTertiary else C.text
		end,
	}

	local focused = Flux.Interact.focused(textBox)
	local box = new "Frame" {
		Name = "Box",
		Size = UDim2.new(1, 0, 0, FIELD_HEIGHT),
		Flux.corner(Theme.radius.sm),
		textBox,
	}
	local hovered = Flux.Interact.hover(box, { within = true })

	local hasError = Flux.computed(function()
		local message = Flux.read(props.error)
		return message ~= nil and message ~= ""
	end)

	Flux.edit(box) {
		-- Inputs are sunken wells; only the outline reacts.
		BackgroundColor3 = function()
			return if isDisabled() then C.subtle else C.sunken
		end,

		Flux.stroke({
			-- Focus is a 2 px accent ring (the stroke sits outside the field, so nothing shifts).
			thickness = function()
				return if focused() and not hasError() and not isDisabled() then 2 else 1
			end,
			color = Flux.tween(function()
				if hasError() then
					return C.error
				elseif isDisabled() then
					return C.borderSubtle
				elseif focused() then
					return C.accent
				elseif hovered() then
					return C.borderStrong
				end
				return C.border
			end, Theme.tween.fast),
		}),
	}

	Flux.edit(textBox) {
		FocusLost = function(enterPressed: boolean)
			if enterPressed and props.onSubmit then
				props.onSubmit()
			end
		end,
	}

	local message = Flux.computed(function(): string?
		local errorText = Flux.read(props.error)
		if errorText ~= nil and errorText ~= "" then
			return errorText
		end
		return Flux.read(props.helper)
	end)

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
	table.insert(children, box)

	return new "Frame" {
		Name = "TextInput",
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Flux.list({ gap = 6 }),

		children,

		Flux.show(function()
			local text = message()
			return text ~= nil and text ~= ""
		end, function()
			return new "TextLabel" {
				Name = "Message",
				Size = UDim2.fromScale(1, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				Text = function()
					return message() or ""
				end,
				TextWrapped = true,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextColor3 = function()
					return if hasError() then C.error else C.textTertiary
				end,
				FontFace = Theme.text.helper.face,
				TextSize = Theme.text.helper.size,
			}
		end),
	}
end

--- Digits-only input (asset ids, versions). Typed or pasted non-digits are stripped.
local function NumberInput(props: Props): Frame
	local merged = table.clone(props)
	merged.sanitize = Validation.digitsOnly
	return TextInput(merged)
end

return {
	TextInput = TextInput,
	NumberInput = NumberInput,
}
