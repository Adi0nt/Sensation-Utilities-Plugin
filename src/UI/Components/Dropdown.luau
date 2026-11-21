--!strict
--- A select control. The menu is portalled into the overlay layer (so scrolling panels never clip it), opens under
--- the trigger or flips above it when there is no room, and closes on selection or a click anywhere outside.

local Flux = require("../../Flux")
local Context = require("../Context")
local Icon = require("./Icon")
local Theme = require("../Theme")

local new = Flux.new
local C = Theme.color

export type Option = { value: string, label: string }

export type Props = {
	options: Flux.Reactive<{ Option }>,
	value: Flux.State<string>,
	label: string?,
	--- Shown when nothing is selected.
	placeholder: string?,
	--- Shown (and the control is disabled) when there are no options.
	emptyText: string?,
	disabled: Flux.Reactive<boolean>?,
}

local FIELD_HEIGHT = Theme.size.control
local ROW_HEIGHT = 30
local MENU_PADDING = 4
local MENU_MAX_HEIGHT = 200
local MENU_GAP = 4
local EDGE = 8 -- keep the menu this far from the window edge

local function Dropdown(props: Props): Frame
	local overlay = Context.overlay()
	local open = Flux.signal(false)

	local options = Flux.computed(function(): { Option }
		return Flux.read(props.options)
	end)
	local isEmpty = Flux.computed(function()
		return #options() == 0
	end)
	local blocked = Flux.computed(function()
		return Flux.read(props.disabled) == true or isEmpty()
	end)

	-- Never leave a menu open on a control that just became unavailable.
	Flux.effect(function()
		if blocked() then
			open:set(false)
		end
	end)

	local selectedLabel = Flux.computed(function(): string?
		local current = props.value()
		for _, option in options() do
			if option.value == current then
				return option.label
			end
		end
		return nil
	end)

	local trigger = new "TextButton" {
		Name = "Trigger",
		Size = UDim2.new(1, 0, 0, FIELD_HEIGHT),
		Text = "",
		Flux.corner(Theme.radius.sm),
	}

	local hovered = Flux.Interact.hover(trigger)

	local glyphColor = Flux.computed(function()
		return if blocked() then C.textTertiary else C.textMuted
	end)

	Flux.edit(trigger) {
		-- A select is an input: a sunken well whose outline reacts.
		BackgroundColor3 = function()
			return if blocked() then C.subtle else C.sunken
		end,

		Activated = function()
			if not blocked() then
				open:set(not open:peek())
			end
		end,

		Flux.stroke({
			thickness = 1,
			color = Flux.tween(function()
				if blocked() then
					return C.borderSubtle
				elseif open() then
					return C.accent
				elseif hovered() then
					return C.borderStrong
				end
				return C.border
			end, Theme.tween.fast),
		}),

		new "TextLabel" {
			Name = "Value",
			Position = UDim2.fromOffset(12, 0),
			Size = UDim2.new(1, -40, 1, 0),
			BackgroundTransparency = 1,
			Text = function()
				if isEmpty() then
					return props.emptyText or "Nothing available"
				end
				return selectedLabel() or props.placeholder or "Select..."
			end,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			TextColor3 = function()
				if blocked() or selectedLabel() == nil then
					return C.textTertiary
				end
				return C.text
			end,
			FontFace = Theme.text.body.face,
			TextSize = Theme.text.body.size,
		},

		Flux.edit(Icon("chevron", glyphColor)) {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -10, 0.5, 0),
			Rotation = Flux.tween(function()
				return if open() then 180 else 0
			end, Theme.tween.base),
		},
	}

	-- Menu geometry, in overlay coordinates. It flips above the trigger when it would run off the bottom.
	local triggerPosition = Flux.property(trigger, "AbsolutePosition")
	local triggerSize = Flux.property(trigger, "AbsoluteSize")
	local overlayPosition = Flux.property(overlay, "AbsolutePosition")
	local overlaySize = Flux.property(overlay, "AbsoluteSize")

	local menuHeight = Flux.computed(function()
		return math.min(#options() * ROW_HEIGHT + MENU_PADDING * 2, MENU_MAX_HEIGHT)
	end)
	local opensUp = Flux.computed(function()
		local top = triggerPosition().Y - overlayPosition().Y
		local below = top + triggerSize().Y + MENU_GAP + menuHeight()
		return below > overlaySize().Y - EDGE and top - MENU_GAP - menuHeight() >= EDGE
	end)

	Flux.edit(trigger) {
		Flux.show(open, function()
			return Flux.portal(overlay, {
				-- Click-away layer.
				new "TextButton" {
					Name = "DropdownScrim",
					Size = UDim2.fromScale(1, 1),
					BackgroundTransparency = 1,
					Text = "",
					ZIndex = 40,
					Activated = function()
						open:set(false)
					end,
				},

				new "Frame" {
					Name = "DropdownMenu",
					Size = function()
						return UDim2.fromOffset(triggerSize().X, menuHeight())
					end,
					Position = function()
						local x = triggerPosition().X - overlayPosition().X
						local top = triggerPosition().Y - overlayPosition().Y
						local y = if opensUp() then top - MENU_GAP - menuHeight() else top + triggerSize().Y + MENU_GAP
						return UDim2.fromOffset(x, y)
					end,
					BackgroundColor3 = C.popup,
					ZIndex = 41,
					Flux.corner(Theme.radius.md),
					Flux.stroke({ thickness = 1, color = C.borderStrong }),

					new "ScrollingFrame" {
						Size = UDim2.fromScale(1, 1),
						BackgroundTransparency = 1,
						CanvasSize = UDim2.new(),
						AutomaticCanvasSize = Enum.AutomaticSize.Y,
						ScrollBarThickness = 4,
						ScrollBarImageColor3 = C.border,
						ScrollingDirection = Enum.ScrollingDirection.Y,
						Flux.padding(MENU_PADDING),
						Flux.list({ gap = 0 }),

						Flux.forIndex(options, function(_, option: Flux.Node<Option>)
							local row = new "TextButton" {
								Name = "Option",
								Size = UDim2.new(1, 0, 0, ROW_HEIGHT),
								Text = "",
								Flux.corner(Theme.radius.sm),
							}
							local rowHovered = Flux.Interact.hover(row)
							local isSelected = Flux.computed(function()
								return props.value() == option().value
							end)

							return Flux.edit(row) {
								BackgroundColor3 = Flux.tween(function()
									if isSelected() then
										return C.accentSubtle
									elseif rowHovered() then
										return C.controlHover
									end
									return C.popup
								end, Theme.tween.fast),

								Activated = function()
									local chosen = option:peek()
									props.value:set(chosen.value)
									open:set(false)
								end,

								new "TextLabel" {
									Position = UDim2.fromOffset(10, 0),
									Size = UDim2.new(1, -20, 1, 0),
									BackgroundTransparency = 1,
									Text = function()
										return option().label
									end,
									TextXAlignment = Enum.TextXAlignment.Left,
									TextTruncate = Enum.TextTruncate.AtEnd,
									TextColor3 = function()
										return if isSelected() then C.accentText else C.text
									end,
									FontFace = Theme.text.body.face,
									TextSize = Theme.text.body.size,
								},
							}
						end),
					},
				},
			})
		end),
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
	table.insert(children, trigger)

	return new "Frame" {
		Name = "Dropdown",
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Flux.list({ gap = 6 }),
		children,
	}
end

return Dropdown
