--!strict
--- A navigation entry: icon, label and an accent indicator when active. In `compact` mode only the icon shows and
--- the label moves to a tooltip.

local Flux = require("../../Flux")
local Icon = require("./Icon")
local Theme = require("../Theme")
local Tooltip = require("./Tooltip")

local new = Flux.new
local C = Theme.color

export type Props = {
	label: string,
	icon: Icon.Kind,
	selected: Flux.Reactive<boolean>,
	compact: Flux.Reactive<boolean>,
	onClick: () -> (),
}

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

	local glyphColor = Flux.computed(function()
		if isSelected() then
			return C.accent
		elseif hovered() then
			return C.text
		end
		return C.textMuted
	end)

	Flux.edit(item) {
		BackgroundColor3 = Flux.tween(function()
			if isSelected() then
				return C.accentSubtle
			elseif hovered() then
				return C.surface
			end
			return C.sidebar
		end, Theme.tween.fast),

		Activated = function()
			props.onClick()
		end,

		-- Active indicator on the left edge.
		new "Frame" {
			Name = "Indicator",
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 0, 0.5, 0),
			Size = Flux.tween(function()
				return if isSelected() then UDim2.fromOffset(3, 18) else UDim2.fromOffset(3, 0)
			end, Theme.tween.base),
			BackgroundColor3 = C.accent,
			Flux.corner(2),
		},

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
				Size = UDim2.new(1, -48, 1, 0),
				BackgroundTransparency = 1,
				Text = props.label,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextTruncate = Enum.TextTruncate.AtEnd,
				TextColor3 = function()
					return if isSelected() then C.text else glyphColor()
				end,
				FontFace = Theme.text.label.face,
				TextSize = Theme.text.label.size + 1,
			}
		end),
	}

	Tooltip.attach(item, function(): string?
		return if isCompact() then props.label else nil
	end, hovered)

	return item
end

return SidebarItem
