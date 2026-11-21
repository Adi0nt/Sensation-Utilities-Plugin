--!strict
--- Studio: spawn an R6 or R15 StarterCharacter. The two options sit side by side when there is room and stack in a
--- narrow dock.

local Flux = require("../../Flux")
local Button = require("../Components/Button")
local Controller = require("./Controller")
local Panel = require("../Components/Panel")
local SectionHeader = require("../Components/SectionHeader")
local Theme = require("../Theme")
local Types = require("../../Core/Types")

local new = Flux.new

local CARD_GAP = Theme.space.md

local RIGS: { { rig: Types.RigType, description: string } } = {
	{
		rig = "R6",
		description = "The classic six-part rig.",
	},
	{
		rig = "R15",
		description = "The modern fifteen-part rig with jointed limbs.",
	},
}

local function StudioPage(controller: Controller.Controller): Frame
	local state, actions = controller.state, controller.actions

	local cardSize = Flux.computed(function(): UDim2
		if state.stackCards() then
			return UDim2.fromScale(1, 0)
		end
		return UDim2.new(0.5, -CARD_GAP / 2, 0, 0)
	end)

	local cards: { Instance } = {}
	for _, entry in RIGS do
		local rig = entry.rig
		table.insert(
			cards,
			Panel({
				title = `{rig} StarterCharacter`,
				description = entry.description,
				icon = "studio",
				size = cardSize,
				children = {
					Button({
						label = `Spawn {rig}`,
						variant = "primary",
						fill = true,
						onClick = function()
							actions.spawn(rig)
						end,
						loading = function()
							return state.busy() == `spawn{rig}`
						end,
						disabled = function()
							return state.gate.spawn() ~= nil
						end,
						tooltip = state.gate.spawn,
					}),
				},
			})
		)
	end

	return new "Frame" {
		Name = "StudioPage",
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Flux.list({ gap = Theme.space.md }),

		SectionHeader({
			level = "page",
			title = "Studio",
			description = "Set up the StarterCharacter that every player spawns with. Rigs are placed in StarterPlayer.",
		}),

		new "Frame" {
			Name = "Cards",
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			Flux.list({ direction = "x", gap = CARD_GAP, wraps = true, lineAlign = "start" }),
			cards,
		},
	}
end

return StudioPage
