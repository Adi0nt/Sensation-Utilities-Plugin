--!strict
--- Modules: bypass tools, sandboxing, the asset cleaner and module presets.

local Flux = require("../../Flux")
local Button = require("../Components/Button")
local Controller = require("./Controller")
local Dropdown = require("../Components/Dropdown")
local Form = require("../Components/Form")
local Panel = require("../Components/Panel")
local Presets = require("../../Core/Presets")
local SectionHeader = require("../Components/SectionHeader")
local SegmentedControl = require("../Components/SegmentedControl")
local Theme = require("../Theme")
local Types = require("../../Core/Types")

local new = Flux.new
local Note, ButtonRow = Form.Note, Form.ButtonRow

local MODE_DESCRIPTIONS: { [Types.BypassMode]: string } = {
	Insert = "Places a copy of each module next to the original, with the bypass method inside it.",
	Append = "Creates a new MainModule next to each module that loads a copy of it through the bypass method.",
}

local function ModulesPage(controller: Controller.Controller): Frame
	local state, actions = controller.state, controller.actions

	local isBusy = function(): boolean
		return state.busy() ~= nil
	end
	local function isRunning(key: string): () -> boolean
		return function()
			return state.busy() == key
		end
	end

	local methodOptions = Flux.computed(function(): { Dropdown.Option }
		local options: { Dropdown.Option } = {}
		for _, name in state.methodNames() do
			table.insert(options, { value = name, label = name })
		end
		return options
	end)

	-- Bypass Tools -----------------------------------------------------------------------------------------------
	local bypass = Panel({
		title = "Bypass Tools",
		description = "Wrap the selected ModuleScripts with a bypass method, or extract the originals again.",
		children = {
			new "Frame" {
				Name = "MethodRow",
				Size = UDim2.fromScale(1, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				Flux.list({ direction = "x", gap = Theme.space.sm, align = "end" }),

				new "Frame" {
					Size = UDim2.fromScale(0, 0),
					AutomaticSize = Enum.AutomaticSize.Y,
					BackgroundTransparency = 1,
					Flux.flex(),
					Dropdown({
						label = "Method",
						options = methodOptions,
						value = state.method,
						emptyText = "No methods loaded",
						disabled = isBusy,
					}),
				},

				Button({
					label = "Reload",
					variant = "ghost",
					onClick = actions.reloadMethods,
					loading = isRunning("reload"),
					disabled = function()
						return state.gate.reloadMethods() ~= nil
					end,
					tooltip = function(): string?
						return state.gate.reloadMethods() or "Download the bypass methods again."
					end,
				}),
			},

			SegmentedControl({
				label = "Mode",
				options = {
					{ value = "Insert" :: Types.BypassMode, label = "Insert" },
					{ value = "Append" :: Types.BypassMode, label = "Append" },
				},
				value = state.mode,
				disabled = isBusy,
			}),

			Note(function()
				return MODE_DESCRIPTIONS[state.mode()]
			end),

			ButtonRow({
				Button({
					label = "Bypass",
					variant = "primary",
					onClick = actions.bypass,
					loading = isRunning("bypass"),
					disabled = function()
						return state.gate.bypass() ~= nil
					end,
					tooltip = state.gate.bypass,
				}),
				Button({
					label = "Unbypass",
					variant = "secondary",
					onClick = actions.unbypass,
					loading = isRunning("unbypass"),
					disabled = function()
						return state.gate.unbypass() ~= nil
					end,
					tooltip = state.gate.unbypass,
				}),
			}),
		},
	})

	-- Sandbox Controls -------------------------------------------------------------------------------------------
	local sandbox = Panel({
		title = "Sandbox Controls",
		description = "Toggle SecurityCapabilities and sandboxing flags. The selected objects and all of their descendants are affected.",
		children = {
			ButtonRow({
				Button({
					label = "Sandbox",
					variant = "secondary",
					onClick = actions.sandbox,
					loading = isRunning("sandbox"),
					disabled = function()
						return state.gate.sandbox() ~= nil
					end,
					tooltip = state.gate.sandbox,
				}),
				Button({
					label = "Unsandbox",
					variant = "secondary",
					onClick = actions.unsandbox,
					loading = isRunning("unsandbox"),
					disabled = function()
						return state.gate.unsandbox() ~= nil
					end,
					tooltip = state.gate.unsandbox,
				}),
			}),
		},
	})

	-- Asset Cleaner ----------------------------------------------------------------------------------------------
	local cleaner = Panel({
		title = "Asset Cleaner",
		description = "Clears the SoundId of sounds that have not loaded (broken or private audio). Select sounds, or models that contain them. Sounds that are still loading are cleared too, so let valid audio load first.",
		children = {
			ButtonRow({
				Button({
					label = "Clean Selected Sounds",
					variant = "secondary",
					onClick = actions.cleanSounds,
					loading = isRunning("clean"),
					disabled = function()
						return state.gate.cleanSounds() ~= nil
					end,
					tooltip = state.gate.cleanSounds,
				}),
			}),
			Flux.show(state.cleanerResult, function(value: () -> any)
				return Note(function()
					return `Last run: {value()}`
				end)
			end),
		},
	})

	-- Module Presets ---------------------------------------------------------------------------------------------
	local presetOptions: { SegmentedControl.Option<Types.PresetName> } = {}
	for _, name in Presets.names do
		table.insert(presetOptions, { value = name :: Types.PresetName, label = name })
	end

	local presets = Panel({
		title = "Module Presets",
		description = "Create a ready-made MainModule inside every selected object.",
		children = {
			SegmentedControl({
				label = "Preset",
				options = presetOptions,
				value = state.preset,
				disabled = isBusy,
			}),
			Note(function()
				return Presets.descriptions[state.preset()] or ""
			end),
			ButtonRow({
				Button({
					label = "Insert Preset",
					variant = "secondary",
					onClick = actions.insertPreset,
					loading = isRunning("preset"),
					disabled = function()
						return state.gate.insertPreset() ~= nil
					end,
					tooltip = state.gate.insertPreset,
				}),
			}),
		},
	})

	return new "Frame" {
		Name = "ModulesPage",
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Flux.list({ gap = Theme.space.md }),

		SectionHeader({
			level = "page",
			title = "Modules",
			description = "Bypass, sandbox and prepare ModuleScripts for the objects selected in Explorer.",
		}),
		bypass,
		sandbox,
		cleaner,
		presets,
	}
end

return ModulesPage
