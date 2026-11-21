--!strict
--- A navigation entry: icon and label, filled with the selection blue when active. It can carry a live marker: a count
--- badge, or a spinner while one of its page's operations runs. In `compact` mode only the icon shows (the marker
--- becomes a small dot or spinner on its corner) and the label moves to a tooltip.

local Flux = require("../../Flux")
local Icon = require("./Icon")
local LoadingIndicator = require("./LoadingIndicator")
local Theme = require("../Theme")
local Tooltip = require("./Tooltip")

local new = Flux.new
local C = Theme.color

export type Props = {
	label: string,
	icon: Icon.Kind,
	selected: Flux.Reactive<boolean>,
	compact: Flux.Reactive<boolean>,
	--- A short count for the page ("3"); nil shows nothing.
	badge: Flux.Reactive<string?>?,
	--- True while an operation on this page is running; shows a spinner (it takes precedence over the badge).
	busy: Flux.Reactive<boolean>?,
	onClick: () -> (),
}

local MARKER_RESERVE = 24 -- extra label room kept free for the marker when there is one
local MARKER_HEIGHT = 18

local function SidebarItem(props: Props): TextButton
	local isSelected = Flux.computed(function()
		return Flux.read(props.selected) == true
	end)
	local isCompact = Flux.computed(function()
		return Flux.read(props.compact) == true
	end)

	local item = new "TextButton" {
		Name = `Nav_{props.label}`,
		Size = UDim2.new(1, 0, 0, Theme.size.sidebarItem),
		Text = "",
		Flux.corner(Theme.radius.md),
	}

	local hovered = Flux.Interact.hover(item)

	local badgeText = Flux.computed(function(): string?
		return Flux.read(props.badge)
	end)
	local isBusy = Flux.computed(function()
		return Flux.read(props.busy) == true
	end)
	local hasMarker = Flux.computed(function()
		return isBusy() or badgeText() ~= nil
	end)

	-- The current page is Studio's selection blue with a light-blue icon and a white label; the others are quiet.
	local glyphColor = Flux.computed(function()
		if isSelected() then
			return C.accentText
		elseif hovered() then
			return C.text
		end
		return C.textMuted
	end)
	local labelColor = Flux.computed(function()
		return if isSelected() or hovered() then C.text else C.textMuted
	end)

	Flux.edit(item) {
		BackgroundColor3 = Flux.tween(function()
			if isSelected() and hovered() then
				return C.accentSubtleHover
			elseif isSelected() then
				return C.accentSubtle
			elseif hovered() then
				return C.controlHover
			end
			return C.chrome
		end, Theme.tween.fast),

		Activated = function()
			props.onClick()
		end,

		-- Icon: pinned left, or centred when compact.
		new "Frame" {
			Name = "IconSlot",
			AnchorPoint = function()
				return Vector2.new(if isCompact() then 0.5 else 0, 0.5)
			end,
			Position = function()
				return if isCompact() then UDim2.fromScale(0.5, 0.5) else UDim2.new(0, 12, 0.5, 0)
			end,
			Size = UDim2.fromOffset(Theme.size.icon, Theme.size.icon),
			BackgroundTransparency = 1,
			Icon(props.icon, glyphColor),
		},

		Flux.show(function()
			return not isCompact()
		end, function()
			return new "TextLabel" {
				Name = "Label",
				Position = UDim2.fromOffset(40, 0),
				Size = function()
					return UDim2.new(1, -(48 + (if hasMarker() then MARKER_RESERVE else 0)), 1, 0)
				end,
				BackgroundTransparency = 1,
				Text = props.label,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextTruncate = Enum.TextTruncate.AtEnd,
				TextColor3 = labelColor,
				-- The current page is Medium weight, the others Regular (Caelum).
				FontFace = function()
					return if isSelected() then Theme.text.label.face else Theme.text.body.face
				end,
				TextSize = Theme.text.label.size,
			}
		end),

		-- Live marker, expanded: a count pill, or a spinner while the page is working.
		Flux.show(function()
			return hasMarker() and not isCompact()
		end, function()
			return new "Frame" {
				Name = "NavMarker",
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -8, 0.5, 0),
				Size = UDim2.fromOffset(0, MARKER_HEIGHT),
				AutomaticSize = Enum.AutomaticSize.X,
				BackgroundTransparency = 1,
				Flux.list({ direction = "x", align = "center", justify = "center" }),

				Flux.show(isBusy, function()
					return new "Frame" {
						Name = "NavBusy",
						Size = UDim2.fromOffset(MARKER_HEIGHT, MARKER_HEIGHT),
						BackgroundTransparency = 1,
						LoadingIndicator({ color = C.accentText, size = 14 }),
					}
				end, function()
					return new "Frame" {
						Name = "NavBadge",
						Size = UDim2.fromOffset(0, MARKER_HEIGHT),
						AutomaticSize = Enum.AutomaticSize.X,
						BackgroundColor3 = C.accent,
						Flux.corner(UDim.new(0.5, 0)),
						Flux.padding({ x = 6 }),
						new "TextLabel" {
							Size = UDim2.fromOffset(0, MARKER_HEIGHT),
							AutomaticSize = Enum.AutomaticSize.X,
							BackgroundTransparency = 1,
							Text = function()
								return badgeText() or ""
							end,
							TextColor3 = C.onAccent,
							FontFace = Theme.text.overline.face,
							TextSize = Theme.text.overline.size,
						},
					}
				end),
			}
		end),

		-- Live marker, in the icon rail: a dot (count) or a small spinner on the icon's top-right corner.
		Flux.show(function()
			return hasMarker() and isCompact()
		end, function()
			return new "Frame" {
				Name = "NavMarkerCompact",
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.new(0.5, 10, 0.5, -9),
				Size = UDim2.fromOffset(10, 10),
				BackgroundTransparency = 1,
				Flux.show(isBusy, function()
					return LoadingIndicator({ color = C.accentText, size = 10 })
				end, function()
					return new "Frame" {
						Name = "NavDot",
						Size = UDim2.fromScale(1, 1),
						BackgroundColor3 = C.accent,
						Flux.corner(UDim.new(0.5, 0)),
					}
				end),
			}
		end),
	}

	Tooltip.attach(item, function(): string?
		return if isCompact() then props.label else nil
	end, hovered)

	return item
end

return SidebarItem
