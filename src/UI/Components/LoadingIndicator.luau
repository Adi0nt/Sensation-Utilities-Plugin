--!strict
--- A small spinner: a ring whose stroke gradient rotates. It only animates while mounted (it is created inside a
--- `Flux.show` branch), so an idle plugin runs no per-frame work.

local Flux = require("../../Flux")
local Theme = require("../Theme")

local new = Flux.new

export type Props = {
	color: Flux.Reactive<Color3>?,
	size: number?,
}

local ARC = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 0),
	NumberSequenceKeypoint.new(0.62, 0),
	NumberSequenceKeypoint.new(0.63, 1),
	NumberSequenceKeypoint.new(1, 1),
})

local TURNS_PER_SECOND = 1.3

local function LoadingIndicator(props: Props?): Frame
	local color = if props and props.color then props.color else Theme.color.textMuted
	local size = if props and props.size then props.size else 14
	local angle = Flux.signal(0)

	Flux.cleanup(Flux.Clock.connect("Heartbeat", function(dt: number)
		angle:set((angle:peek() + dt * 360 * TURNS_PER_SECOND) % 360)
	end))

	return new "Frame" {
		Name = "LoadingIndicator",
		Size = UDim2.fromOffset(size, size),
		BackgroundTransparency = 1,
		Flux.corner(UDim.new(0.5, 0)),
		new "UIStroke" {
			Thickness = 2,
			Color = color,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			new "UIGradient" {
				Transparency = ARC,
				Rotation = angle,
			},
		},
	}
end

return LoadingIndicator
