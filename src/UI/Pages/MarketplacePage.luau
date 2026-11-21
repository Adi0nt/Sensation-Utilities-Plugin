--!strict
--- Marketplace: insert an asset (latest or a specific version) and publish / export the selection.

local Flux = require("../../Flux")
local Button = require("../Components/Button")
local Controller = require("./Controller")
local Form = require("../Components/Form")
local Panel = require("../Components/Panel")
local SectionHeader = require("../Components/SectionHeader")
local SelectionSummary = require("../Components/SelectionSummary")
local TextInput = require("../Components/TextInput")
local Theme = require("../Theme")

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
					if state.gate.insertLatest() == nil then
						actions.insertLatest()
					end
				end,
			}),
			TextInput.NumberInput({
				label = "Version (optional)",
				placeholder = "Latest",
				value = state.assetVersion,
				error = state.assetVersionError,
				helper = "Leave empty to use the latest version.",
				disabled = isBusy,
			}),
			ButtonRow({
				Button({
					label = "Insert Latest",
					variant = "primary",
					onClick = actions.insertLatest,
					loading = isRunning("latest"),
					disabled = function()
						return state.gate.insertLatest() ~= nil
					end,
					tooltip = state.gate.insertLatest,
				}),
				Button({
					label = "Insert Specific Version",
					variant = "secondary",
					onClick = actions.insertVersion,
					loading = isRunning("version"),
					disabled = function()
						return state.gate.insertVersion() ~= nil
					end,
					tooltip = state.gate.insertVersion,
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
