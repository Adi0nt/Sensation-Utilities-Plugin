--!strict
--- The status strip at the bottom of the window: the outcome of the last action (success, info, warning, error),
--- a "working" line with a spinner while something runs, or a quiet "Ready".

local Flux = require("../../Flux")
local IconButton = require("./IconButton")
local LoadingIndicator = require("./LoadingIndicator")
local Theme = require("../Theme")

local new = Flux.new
local C = Theme.color

export type Line = {
	level: "success" | "info" | "warning" | "error" | "idle",
	text: string,
	--- Show a spinner instead of the level dot.
	busy: boolean,
	--- Show the dismiss button.
	dismissible: boolean,
}

export type Props = {
	line: Flux.Reactive<Line>,
	onDismiss: () -> (),
}

local MIN_HEIGHT = 40

local function levelColor(level: string): Color3
	if level == "success" then
		return C.success
	elseif level == "warning" then
		return C.warning
	elseif level == "error" then
		return C.error
	elseif level == "info" then
		return C.accent
	end
	return C.neutral
end

local function levelBackground(level: string): Color3
	if level == "success" then
		return C.successSubtle
	elseif level == "warning" then
		return C.warningSubtle
	elseif level == "error" then
		return C.errorSubtle
	end
	return C.canvas
end

local function StatusMessage(props: Props): Frame
	local line = Flux.computed(function(): Line
		return Flux.read(props.line)
	end)
	local level = Flux.computed(function()
		return line().level
	end)
	local isBusy = Flux.computed(function()
		return line().busy
	end)
	local accentColor = Flux.tween(function()
		return levelColor(level())
	end, Theme.tween.base)

	return new "Frame" {
		Name = "StatusMessage",
		Size = UDim2.new(1, 0, 0, MIN_HEIGHT),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Flux.tween(function()
			return levelBackground(level())
		end, Theme.tween.base),

		-- Top divider.
		new "Frame" {
			Name = "Divider",
			Size = UDim2.new(1, 0, 0, 1),
			BackgroundColor3 = C.borderSubtle,
		},

		new "Frame" {
			Name = "Content",
			-- A 40 px minimum (the bar grows for wrapped text); the row is centred vertically inside it.
			Size = UDim2.new(1, 0, 0, MIN_HEIGHT),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			Flux.padding({ x = Theme.size.pagePadding, y = 8 }),
			Flux.list({ direction = "x", gap = 10, align = "center" }),

			-- Dot or spinner.
			new "Frame" {
				Name = "Indicator",
				Size = UDim2.fromOffset(14, 14),
				BackgroundTransparency = 1,

				Flux.show(isBusy, function()
					return LoadingIndicator({ color = C.accent, size = 14 })
				end, function()
					return new "Frame" {
						AnchorPoint = Vector2.new(0.5, 0.5),
						Position = UDim2.fromScale(0.5, 0.5),
						Size = UDim2.fromOffset(8, 8),
						BackgroundColor3 = accentColor,
						Flux.corner(UDim.new(0.5, 0)),
					}
				end),
			},

			new "TextLabel" {
				Name = "Text",
				Size = UDim2.fromScale(0, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				Text = function()
					return line().text
				end,
				TextWrapped = true,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextColor3 = function()
					return if level() == "idle" then C.textMuted else C.text
				end,
				FontFace = Theme.text.body.face,
				TextSize = Theme.text.body.size,
				Flux.flex(),
			},

			Flux.show(function()
				return line().dismissible
			end, function()
				return IconButton({ icon = "close", label = "Dismiss", onClick = props.onDismiss })
			end),
		},
	}
end

return StatusMessage
