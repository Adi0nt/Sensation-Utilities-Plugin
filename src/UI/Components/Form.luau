--!strict
--- Small layout pieces shared by the pages.

local Flux = require("../../Flux")
local Theme = require("../Theme")

local new = Flux.new

local Form = {}

--- A muted helper paragraph.
function Form.Note(text: Flux.Reactive<string>): TextLabel
	return new "TextLabel" {
		Name = "Note",
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Text = text,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Theme.color.textTertiary,
		FontFace = Theme.text.helper.face,
		TextSize = Theme.text.helper.size,
	}
end

--- A row of buttons that wraps onto a second line in a narrow dock.
function Form.ButtonRow(buttons: { Instance }): Frame
	return new "Frame" {
		Name = "Buttons",
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Flux.list({ direction = "x", gap = Theme.space.sm, wraps = true }),
		buttons,
	}
end

return Form
