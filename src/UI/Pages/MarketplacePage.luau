--!strict
--- Marketplace: insert an asset (one Insert button; the Version control picks the latest or a specific version)
--- and publish / export the selection.

local Flux = require("../../Flux")
local Button = require("../Components/Button")
local Controller = require("./Controller")
local Form = require("../Components/Form")
local Panel = require("../Components/Panel")
local SectionHeader = require("../Components/SectionHeader")
local SegmentedControl = require("../Components/SegmentedControl")
local SelectionSummary = require("../Components/SelectionSummary")
local State = require("../State")
local TextInput = require("../Components/TextInput")
local Theme = require("../Theme")
local Validation = require("../../Core/Validation")

local new = Flux.new
local Note, ButtonRow = Form.Note, Form.ButtonRow

local function MarketplacePage(controller: Controller.Controller): Frame
	local state, actions = controller.state, controller.actions

	local function isRunning(key: string): () -> boolean
		return function()
			return state.busy() == key
		end
	end
	local isBusy = function(): boolean
		return state.busy() ~= nil
	end

	-- The button names exactly what will be loaded, so there is nothing to guess.
	local function insertLabel(): string
		if state.assetVersionMode() ~= "Specific" then
			return "Insert latest version"
		end
		local version = Validation.parseVersion(state.assetVersion())
		return if version ~= nil then `Insert version {version}` else "Insert version"
	end

	local insertion = Panel({
		title = "Asset Insertion",
		description = "Insert an asset from Roblox into every selected object.",
		children = {
			TextInput.NumberInput({
				label = "Asset ID",
				placeholder = "e.g. 1234567890",
				value = state.assetId,
				error = state.assetIdError,
				helper = "The number from the asset's URL.",
				disabled = isBusy,
				onSubmit = function()
					if state.gate.insert() == nil then
						actions.insert()
					end
				end,
			}),

			-- One choice, one button: which version to load is picked here, and the button says what it will do.
			SegmentedControl({
				label = "Version",
				options = {
					{ value = "Latest" :: State.VersionMode, label = "Latest" },
					{ value = "Specific" :: State.VersionMode, label = "Specific version" },
				},
				value = state.assetVersionMode,
				disabled = isBusy,
			}),
			Flux.show(function()
				return state.assetVersionMode() == "Specific"
			end, function()
				return TextInput.NumberInput({
					label = "Version number",
					placeholder = "e.g. 12",
					value = state.assetVersion,
					error = state.assetVersionError,
					helper = "A whole number, starting at 1.",
					disabled = isBusy,
					onSubmit = function()
						if state.gate.insert() == nil then
							actions.insert()
						end
					end,
				})
			end, function()
				return Note("Loads the newest version published for the asset.")
			end),

			ButtonRow({
				Button({
					label = insertLabel,
					fill = state.stackCards,
					variant = "primary",
					onClick = actions.insert,
					loading = function()
						return state.busy() == "latest" or state.busy() == "version"
					end,
					disabled = function()
						return state.gate.insert() ~= nil
					end,
					tooltip = state.gate.insert,
				}),
			}),
		},
	})

	local publishing = Panel({
		title = "Publishing & Export",
		description = "Upload the selection to Roblox, or save it as a .rbxm file.",
		children = {
			SelectionSummary({ summary = state.summary, variant = "inline", caption = "Target" }),
			ButtonRow({
				Button({
					label = "Upload to Roblox",
					variant = "secondary",
					onClick = actions.upload,
					loading = isRunning("upload"),
					disabled = function()
						return state.gate.upload() ~= nil
					end,
					tooltip = state.gate.upload,
				}),
				Button({
					label = "Save to File",
					variant = "secondary",
					onClick = actions.save,
					loading = isRunning("save"),
					disabled = function()
						return state.gate.save() ~= nil
					end,
					tooltip = state.gate.save,
				}),
			}),
			Note("Both open Studio's own dialogs. An upload to Roblox cannot be undone from here."),
		},
	})

	return new "Frame" {
		Name = "MarketplacePage",
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Flux.list({ gap = Theme.space.md }),

		SectionHeader({
			level = "page",
			title = "Marketplace",
			description = "Insert Roblox assets into your selection, or publish and export it.",
		}),
		insertion,
		publishing,
	}
end

return MarketplacePage
