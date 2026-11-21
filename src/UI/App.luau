--!strict
--- The application shell: header, navigation sidebar, selection bar, scrolling page area, status strip and the
--- overlay layer. `mount` builds it inside a Flux root scope, so `unmount` tears down every instance, connection
--- and timer it created.

local Flux = require("../Flux")
local Actions = require("./Actions")
local ConfirmationDialog = require("./Components/ConfirmationDialog")
local Context = require("./Context")
local Controller = require("./Pages/Controller")
local LoadingIndicator = require("./Components/LoadingIndicator")
local MarketplacePage = require("./Pages/MarketplacePage")
local ModulesPage = require("./Pages/ModulesPage")
local Operations = require("../Core/Operations")
local SelectionSummary = require("./Components/SelectionSummary")
local SidebarItem = require("./Components/SidebarItem")
local State = require("./State")
local StatusMessage = require("./Components/StatusMessage")
local StudioPage = require("./Pages/StudioPage")
local Theme = require("./Theme")
local Types = require("../Core/Types")

local new = Flux.new
local C = Theme.color

export type Config = {
	widget: DockWidgetPluginGui,
	operations: Operations.Operations,
	methods: Types.MethodStore,
	log: Types.Log,
	--- The commit / version label shown in the header (updated later through `state.commit`).
	commit: string,
	--- Re-downloads the bypass methods. Yields. Returns the method count, or `nil, reason`.
	reloadMethods: () -> (number?, string?),
}

export type App = {
	state: State.State,
	unmount: () -> (),
}

local NAV: { { page: State.Page, label: string, icon: "modules" | "market" | "studio" } } = {
	{ page = "Modules", label = "Modules", icon = "modules" },
	{ page = "Marketplace", label = "Marketplace", icon = "market" },
	{ page = "Studio", label = "Studio", icon = "studio" },
}

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

local function Header(state: State.State): Frame
	local isBusy = Flux.computed(function()
		return state.busy() ~= nil
	end)
	local indicatorColor = Flux.tween(function()
		return levelColor(state.statusLine().level)
	end, Theme.tween.base)

	return new "Frame" {
		Name = "Header",
		Size = UDim2.new(1, 0, 0, Theme.size.header),
		BackgroundColor3 = C.chrome,

		new "Frame" {
			Name = "Content",
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Flux.padding({ x = Theme.space.lg }),
			Flux.list({ direction = "x", gap = 10, align = "center", justify = "between" }),

			-- Brand
			new "Frame" {
				Name = "Brand",
				Size = UDim2.fromScale(0, 1),
				AutomaticSize = Enum.AutomaticSize.X,
				BackgroundTransparency = 1,
				Flux.list({ direction = "x", gap = 10, align = "center" }),

				new "Frame" {
					Name = "Mark",
					Size = UDim2.fromOffset(24, 24),
					BackgroundColor3 = C.accent,
					Flux.corner(Theme.radius.sm),
					new "TextLabel" {
						Size = UDim2.fromScale(1, 1),
						BackgroundTransparency = 1,
						Text = "S",
						TextColor3 = C.onAccent,
						FontFace = Theme.text.heading.face,
						TextSize = Theme.text.heading.size,
					},
				},
				new "TextLabel" {
					Name = "Title",
					Size = UDim2.fromScale(0, 1),
					AutomaticSize = Enum.AutomaticSize.X,
					BackgroundTransparency = 1,
					Text = "Sensation Utilities",
					TextColor3 = C.text,
					FontFace = Theme.text.heading.face,
					TextSize = Theme.text.heading.size,
				},
			},

			-- Status dot / spinner and version chip
			new "Frame" {
				Name = "Meta",
				Size = UDim2.fromScale(0, 1),
				AutomaticSize = Enum.AutomaticSize.X,
				BackgroundTransparency = 1,
				Flux.list({ direction = "x", gap = 10, align = "center" }),

				new "Frame" {
					Name = "StatusIndicator",
					Size = UDim2.fromOffset(14, 14),
					BackgroundTransparency = 1,
					Flux.show(isBusy, function()
						return LoadingIndicator({ color = C.accent, size = 14 })
					end, function()
						return new "Frame" {
							AnchorPoint = Vector2.new(0.5, 0.5),
							Position = UDim2.fromScale(0.5, 0.5),
							Size = UDim2.fromOffset(8, 8),
							BackgroundColor3 = indicatorColor,
							Flux.corner(UDim.new(0.5, 0)),
						}
					end),
				},

				new "TextLabel" {
					Name = "Version",
					Size = UDim2.fromOffset(0, 22),
					AutomaticSize = Enum.AutomaticSize.X,
					BackgroundColor3 = C.control,
					Text = state.commit,
					TextColor3 = C.textTertiary,
					FontFace = Theme.text.mono.face,
					TextSize = Theme.text.mono.size,
					Flux.corner(Theme.radius.sm),
					Flux.padding({ x = 8 }),
				},
			},
		},
	}
end

local function Sidebar(controller: Controller.Controller): Frame
	local state, actions = controller.state, controller.actions

	-- A titled group, like Caelum's sidebar sections; the label hides in the icon rail.
	local items: { any } = {
		Flux.show(function()
			return not state.compactNav()
		end, function()
			return new "TextLabel" {
				Name = "GroupLabel",
				Size = UDim2.new(1, 0, 0, 24),
				BackgroundTransparency = 1,
				Text = "Tools",
				TextXAlignment = Enum.TextXAlignment.Left,
				TextColor3 = C.textTertiary,
				FontFace = Theme.text.overline.face,
				TextSize = Theme.text.overline.size,
				Flux.padding({ left = Theme.space.md }),
			}
		end),
	}
	for _, entry in NAV do
		table.insert(
			items,
			SidebarItem({
				label = entry.label,
				icon = entry.icon,
				selected = function()
					return state.page() == entry.page
				end,
				compact = state.compactNav,
				onClick = function()
					actions.navigate(entry.page)
				end,
			})
		)
	end

	return new "Frame" {
		Name = "Sidebar",
		Size = Flux.tween(function()
			return UDim2.new(0, if state.compactNav() then Theme.size.sidebarCompact else Theme.size.sidebar, 1, 0)
		end, Theme.tween.base),
		BackgroundColor3 = C.chrome,
		ClipsDescendants = true,

		new "Frame" {
			Name = "Items",
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Flux.padding(Theme.space.sm),
			Flux.list({ gap = Theme.space.xs }),
			items,
		},
	}
end

local function PageArea(controller: Controller.Controller): ScrollingFrame
	local state = controller.state

	local scroller = new "ScrollingFrame" {
		Name = "Pages",
		Size = UDim2.fromScale(1, 0),
		BackgroundTransparency = 1,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = C.borderStrong,
		Flux.flex(),

		new "Frame" {
			Name = "Content",
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			Flux.padding({ x = Theme.size.pagePadding, top = Theme.space.lg, bottom = Theme.space.xl }),

			-- Pages stop growing instead of stretching controls across a wide dock.
			new "Frame" {
				Name = "Column",
				Size = UDim2.fromScale(1, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				Flux.sizeConstraint({ maxWidth = Theme.size.maxContent }),

				Flux.switch(state.page)({
					Modules = function(): GuiObject
						return ModulesPage(controller)
					end,
					Marketplace = function(): GuiObject
						return MarketplacePage(controller)
					end,
					Studio = function(): GuiObject
						return StudioPage(controller)
					end,
				}),
			},
		},
	}

	-- A new page starts at the top.
	Flux.effect(function()
		state.page()
		scroller.CanvasPosition = Vector2.zero
	end)

	return scroller
end

--- Builds the UI into `config.widget`. Call `unmount` to remove it again.
local function mount(config: Config): App
	local mountedState: State.State? = nil

	local unmount = Flux.mount(function()
		-- The overlay layer exists before anything that portals into it.
		local overlay = new "Frame" {
			Name = "Overlay",
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			ZIndex = 100,
		}

		return Context.services:provide({ overlay = overlay }, function()
			local state = State.new({
				selection = config.operations.env.selection,
				operations = config.operations,
				methods = config.methods,
				widget = config.widget,
				commit = config.commit,
			})
			local actions = Actions.new(state, {
				operations = config.operations,
				log = config.log,
				reloadMethods = config.reloadMethods,
			})
			local controller: Controller.Controller = { state = state, actions = actions }
			mountedState = state

			return new "Frame" {
				Name = "SensationUtilities",
				Size = UDim2.fromScale(1, 1),
				BackgroundColor3 = C.chrome,
				ClipsDescendants = true,

				new "Frame" {
					Name = "Shell",
					Size = UDim2.fromScale(1, 1),
					BackgroundTransparency = 1,
					Flux.list({ gap = 0 }),

					Header(state),

					new "Frame" {
						Name = "Body",
						Size = UDim2.fromScale(1, 0),
						BackgroundTransparency = 1,
						Flux.flex(),
						Flux.list({ direction = "x", gap = 0 }),

						Sidebar(controller),

						-- The content layer: Caelum insets it on the chrome with one rounded top-left corner and a 1 px edge.
						new "Frame" {
							Name = "Main",
							Size = UDim2.fromScale(0, 1),
							BackgroundColor3 = C.canvas,
							Flux.corner({
								topLeft = Theme.radius.md,
								topRight = 0,
								bottomLeft = 0,
								bottomRight = 0,
							}),
							Flux.stroke({ thickness = 1, color = C.contentBorder }),
							Flux.flex(),
							Flux.list({ gap = 0 }),

							SelectionSummary({ summary = state.summary, variant = "bar" }),
							new "Frame" {
								Name = "SelectionDivider",
								Size = UDim2.new(1, 0, 0, 1),
								BackgroundColor3 = C.borderSubtle,
							},
							PageArea(controller),
							StatusMessage({ line = state.statusLine, onDismiss = actions.dismissStatus }),
						},
					},
				},

				ConfirmationDialog({ request = state.confirm }),
				overlay,
			}
		end)
	end, config.widget)

	local state = mountedState
	assert(state, "Sensation UI failed to build its state")
	return { state = state, unmount = unmount }
end

return {
	mount = mount,
}
