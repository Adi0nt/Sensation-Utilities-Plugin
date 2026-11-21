--!strict
--- Hover tooltips. They are portalled into the overlay layer, so they are never clipped by scrolling panels, and
--- they only exist while visible. Used mainly to explain why a control is disabled.

local Flux = require("../../Flux")
local Context = require("../Context")
local Theme = require("../Theme")

local new = Flux.new

local SHOW_DELAY = 0.45
local GAP = 6

local Tooltip = {}

--- Attaches a tooltip to `target`. `text` may be reactive; `nil` or an empty string disables it.
--- Pass the target's existing `hovered` node to avoid creating a second hover tracker.
function Tooltip.attach(target: GuiObject, text: Flux.Reactive<string?>, hovered: Flux.Node<boolean>?)
	local overlay = Context.overlay()
	local isHovered = hovered or Flux.Interact.hover(target)
	local visible = Flux.signal(false)

	Flux.effect(function()
		local content = Flux.read(text)
		if isHovered() and content ~= nil and content ~= "" then
			local timer = Flux.Clock.delay(SHOW_DELAY, function()
				visible:set(true)
			end)
			Flux.cleanup(function()
				Flux.Clock.cancel(timer)
				visible:set(false)
			end)
		else
			visible:set(false)
		end
	end)

	local targetPosition = Flux.property(target, "AbsolutePosition")
	local targetSize = Flux.property(target, "AbsoluteSize")
	local overlayPosition = Flux.property(overlay, "AbsolutePosition")
	local overlaySize = Flux.property(overlay, "AbsoluteSize")

	-- Anchor to the target's left edge, or its right edge when the target sits in the right half of the window.
	local alignRight = Flux.computed(function()
		local centre = targetPosition().X + targetSize().X / 2 - overlayPosition().X
		return centre > overlaySize().X / 2
	end)

	Flux.edit(target) {
		Flux.show(visible, function()
			return Flux.portal(overlay, {
				new "Frame" {
					Name = "Tooltip",
					AutomaticSize = Enum.AutomaticSize.XY,
					Size = UDim2.fromOffset(0, 0),
					AnchorPoint = function()
						return Vector2.new(if alignRight() then 1 else 0, 0)
					end,
					Position = function()
						local x = if alignRight() then targetPosition().X + targetSize().X else targetPosition().X
						local y = targetPosition().Y + targetSize().Y + GAP
						return UDim2.fromOffset(x - overlayPosition().X, y - overlayPosition().Y)
					end,
					BackgroundColor3 = Theme.color.input,
					ZIndex = 50,
					Flux.corner(Theme.radius.sm),
					Flux.stroke({ thickness = 1, color = Theme.color.border }),
					Flux.padding({ x = 10, y = 6 }),
					Flux.sizeConstraint({ maxWidth = 240 }),

					new "TextLabel" {
						AutomaticSize = Enum.AutomaticSize.XY,
						Size = UDim2.fromOffset(0, 0),
						BackgroundTransparency = 1,
						Text = function()
							return Flux.read(text) or ""
						end,
						TextWrapped = true,
						TextXAlignment = Enum.TextXAlignment.Left,
						TextColor3 = Theme.color.text,
						FontFace = Theme.text.helper.face,
						TextSize = Theme.text.helper.size,
						ZIndex = 51,
					},
				},
			})
		end),
	}
end

return Tooltip
