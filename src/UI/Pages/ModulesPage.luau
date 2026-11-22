--!strict
--- Modules: bypass tools, sandboxing, the asset cleaner and module presets.

local Flux = require("../../Flux")
local Button = require("../Components/Button")
local Controller = require("./Controller")
local Checkbox = require("../Components/Checkbox")
local Dropdown = require("../Components/Dropdown")
local Form = require("../Components/Form")
local Format = require("../../Core/Format")
local Panel = require("../Components/Panel")
local SectionHeader = require("../Components/SectionHeader")
local SegmentedControl = require("../Components/SegmentedControl")
local Theme = require("../Theme")
local Types = require("../../Core/Types")

local new = Flux.new
local C = Theme.color
local Note, ButtonRow = Form.Note, Form.ButtonRow

-- A row in the broken-asset list is a fixed height (two short lines), so the list can size itself to its rows.
local BROKEN_ROW_HEIGHT = 48
local BROKEN_LIST_MAX_HEIGHT = 192

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
					variant = "secondary",
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
	local function scanSummary(): string
		local report = state.cleanReport()
		if report == nil then
			return ""
		end
		local parts = {
			`{report.scanned} {if report.scanned == 1 then "object" else "objects"} scanned`,
			`{report.assets} {if report.assets == 1 then "asset" else "assets"}`,
			`{#report.broken} could not be loaded`,
		}
		if report.unverified > 0 then
			table.insert(parts, `{report.unverified} not checked`)
		end
		return table.concat(parts, " · ")
	end

	--- One broken asset: a tick box, the id, and where it is used.
	local function BrokenAssetRow(item: Flux.Node<Types.BrokenAsset>): Frame
		local id = item:peek().id
		return new "Frame" {
			Name = "BrokenAsset",
			Size = UDim2.new(1, 0, 0, BROKEN_ROW_HEIGHT),
			BackgroundTransparency = 1,
			Flux.padding({ x = Theme.space.sm, y = 6 }),

			Checkbox({
				checked = function()
					return state.cleanPicked()[id] == true
				end,
				onToggle = function()
					actions.toggleAsset(id)
				end,
				disabled = isBusy,
				content = new "Frame" {
					Size = UDim2.fromScale(0, 0),
					AutomaticSize = Enum.AutomaticSize.Y,
					BackgroundTransparency = 1,
					Flux.flex(),
					Flux.list({ gap = 2 }),

					new "TextLabel" {
						Name = "AssetId",
						Size = UDim2.new(1, 0, 0, 16),
						BackgroundTransparency = 1,
						Text = function()
							return item().content
						end,
						TextXAlignment = Enum.TextXAlignment.Left,
						TextTruncate = Enum.TextTruncate.AtEnd,
						TextColor3 = C.text,
						FontFace = Theme.text.mono.face,
						TextSize = Theme.text.mono.size,
					},
					new "TextLabel" {
						Name = "AssetUses",
						Size = UDim2.new(1, 0, 0, 14),
						BackgroundTransparency = 1,
						Text = function()
							local asset = item()
							local uses: { Format.Use } = {}
							for _, reference in asset.references do
								table.insert(uses, { className = reference.instance.ClassName, property = reference.property })
							end
							local count = #asset.references
							return `{count} {if count == 1 then "use" else "uses"} · {Format.assetUses(uses)}`
						end,
						TextXAlignment = Enum.TextXAlignment.Left,
						TextTruncate = Enum.TextTruncate.AtEnd,
						TextColor3 = C.textTertiary,
						FontFace = Theme.text.helper.face,
						TextSize = Theme.text.helper.size,
					},
				},
			}),
		}
	end

	local brokenList = new "ScrollingFrame" {
		Name = "BrokenAssets",
		Size = function()
			local rows = #state.cleanBroken()
			return UDim2.new(1, 0, 0, math.min(rows * BROKEN_ROW_HEIGHT, BROKEN_LIST_MAX_HEIGHT) + 2)
		end,
		BackgroundColor3 = C.sunken,
		BorderSizePixel = 0,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 4,
		ScrollBarImageColor3 = C.border,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		Flux.corner(Theme.radius.sm),
		Flux.stroke({ thickness = 1, color = C.border }),
		Flux.list({ gap = 0 }),

		Flux.forKey(state.cleanBroken, function(asset: Types.BrokenAsset)
			return asset.id
		end, function(_, item: Flux.Node<Types.BrokenAsset>)
			return BrokenAssetRow(item)
		end),
	}

	local cleaner = Panel({
		title = "Asset Cleaner",
		description = "Scan the selection for assets Studio cannot load (meshes, textures, sounds, animations...), then clear them.",
		children = {
			ButtonRow({
				Button({
					label = "Scan Selection",
					variant = "secondary",
					onClick = actions.scanAssets,
					loading = isRunning("scan"),
					disabled = function()
						return state.gate.scanAssets() ~= nil
					end,
					tooltip = state.gate.scanAssets,
				}),
				Button({
					label = "Clean Unloaded Sounds",
					variant = "ghost",
					onClick = actions.cleanSounds,
					loading = isRunning("clean"),
					disabled = function()
						return state.gate.cleanSounds() ~= nil
					end,
					tooltip = function(): string?
						return state.gate.cleanSounds()
							or "Clears the SoundId of selected sounds that report as not loaded. Sounds still loading are cleared too."
					end,
				}),
			}),

			Flux.show(state.cleanReport, function()
				return Note(scanSummary)
			end),

			-- The broken assets, with what to do about them.
			Flux.show(function()
				return #state.cleanBroken() > 0
			end, function()
				return new "Frame" {
					Name = "BrokenAssetsSection",
					Size = UDim2.fromScale(1, 0),
					AutomaticSize = Enum.AutomaticSize.Y,
					BackgroundTransparency = 1,
					Flux.list({ gap = Theme.space.sm }),

					new "Frame" {
						Name = "PickRow",
						Size = UDim2.fromScale(1, 0),
						AutomaticSize = Enum.AutomaticSize.Y,
						BackgroundTransparency = 1,
						Flux.list({ direction = "x", gap = Theme.space.sm, align = "center", justify = "between" }),

						new "TextLabel" {
							Name = "PickedCount",
							Size = UDim2.fromScale(0, 0),
							AutomaticSize = Enum.AutomaticSize.Y,
							BackgroundTransparency = 1,
							Text = function()
								return `{state.cleanPickedCount()} of {#state.cleanBroken()} selected`
							end,
							TextXAlignment = Enum.TextXAlignment.Left,
							TextTruncate = Enum.TextTruncate.AtEnd,
							TextColor3 = C.textMuted,
							FontFace = Theme.text.label.face,
							TextSize = Theme.text.label.size,
							Flux.flex(),
						},
						Button({
							label = function()
								return if state.cleanPickedCount() == #state.cleanBroken() then "Select None" else "Select All"
							end,
							variant = "ghost",
							onClick = function()
								actions.setAllAssets(state.cleanPickedCount() ~= #state.cleanBroken())
							end,
							disabled = isBusy,
						}),
					},

					brokenList,

					Checkbox({
						checked = state.cleanRemove,
						onToggle = function()
							state.cleanRemove:set(not state.cleanRemove:peek())
						end,
						label = "Remove the instances instead of clearing the property",
						disabled = isBusy,
					}),

					ButtonRow({
						Button({
							-- The button names what it will do, so removing is never a surprise.
							label = function()
								return if state.cleanRemove() then "Remove Selected" else "Clean Selected"
							end,
							variant = "primary",
							onClick = actions.cleanAssets,
							loading = isRunning("cleanAssets"),
							disabled = function()
								return state.gate.cleanAssets() ~= nil
							end,
							tooltip = state.gate.cleanAssets,
						}),
					}),
				}
			end),

			Flux.show(state.cleanerResult, function(value: () -> any)
				return Note(function()
					return `Last run: {value()}`
				end)
			end),
		},
	})

	-- Module Presets ---------------------------------------------------------------------------------------------
	local presetOptions = Flux.computed(function(): { Dropdown.Option }
		local options: { Dropdown.Option } = {}
		for _, name in state.presetNames() do
			table.insert(options, { value = name, label = name })
		end
		return options
	end)

	local presets = Panel({
		title = "Module Presets",
		description = "Create a ready-made MainModule inside every selected object.",
		children = {
			new "Frame" {
				Name = "PresetRow",
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
						label = "Preset",
						options = presetOptions,
						value = state.preset,
						emptyText = "No presets loaded",
						disabled = isBusy,
					}),
				},

				Button({
					label = "Reload",
					variant = "secondary",
					onClick = actions.reloadPresets,
					loading = isRunning("reloadPresets"),
					disabled = function()
						return state.gate.reloadPresets() ~= nil
					end,
					tooltip = function(): string?
						return state.gate.reloadPresets() or "Download presets.rbxm again."
					end,
				}),
			},
			Note(state.presetDescription),
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
