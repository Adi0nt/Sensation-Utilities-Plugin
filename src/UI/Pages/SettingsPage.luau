--!strict
--- Settings: where the panel lives. It is a dock widget by default; the floating window is the old CoreGui setup, a
--- movable window over the viewport that never docks. The choice is remembered between sessions.

local Flux = require("../../Flux")
local Controller = require("./Controller")
local Form = require("../Components/Form")
local Panel = require("../Components/Panel")
local SectionHeader = require("../Components/SectionHeader")
local SegmentedControl = require("../Components/SegmentedControl")
local State = require("../State")
local Theme = require("../Theme")

local new = Flux.new
local Note = Form.Note

local OPTIONS: { SegmentedControl.Option<State.WindowMode> } = {
	{ value = "Dock", label = "Docked" },
	{ value = "Floating", label = "Floating window" },
}

local function SettingsPage(controller: Controller.Controller): Frame
	local state, actions = controller.state, controller.actions

	return new "Frame" {
		Name = "SettingsPage",
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Flux.list({ gap = Theme.space.md }),

		SectionHeader({
			level = "page",
			title = "Settings",
			description = "How Sensation Utilities appears in Studio.",
		}),

		Panel({
			title = "Window",
			description = "Choose where the panel opens. Your choice is remembered.",
			icon = "settings",
			children = {
				SegmentedControl({
					options = OPTIONS,
					value = state.windowMode,
					onChange = actions.setWindowMode,
					disabled = function()
						return state.gate.windowMode() ~= nil
					end,
				}),
				Note(function()
					if state.windowMode() == "Floating" then
						return "A window over the 3D view that never docks. Drag its title bar to move it, and drag its edges or the bottom-right corner to resize it. Use the toolbar button to show or hide it."
					end
					return "A normal Studio panel. Dock it next to the Explorer, float it, or tab it with other panels. Studio remembers where you leave it."
				end),
			},
		}),
	}
end

return SettingsPage
