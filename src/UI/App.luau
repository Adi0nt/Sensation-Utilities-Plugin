--!strict
--- The application shell: header, navigation sidebar, selection bar, scrolling page area, status strip and the
--- overlay layer. `mount` builds it inside a Flux root scope, so `unmount` tears down every instance, connection
--- and timer it created.

local Flux = require("../Flux")
local Actions = require("./Actions")
local ConfirmationDialog = require("./Components/ConfirmationDialog")
local Context = require("./Context")
local Controller = require("./Pages/Controller")
local IconButton = require("./Components/IconButton")
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

-- `owns` says whether a running operation (by its busy key) belongs to the page, so its nav item can show a spinner.
local function keys(list: { string }): (string) -> boolean
	local set: { [string]: boolean } = {}
	for _, key in list do
		set[key] = true
	end
	return function(key: string): boolean
		return set[key] == true
	end
end

local NAV: { { page: State.Page, label: string, icon: "modules" | "market" | "studio", owns: (string) -> boolean } } = {
	{
		page = "Modules",
		label = "Modules",
		icon = "modules",
		owns = keys({ "bypass", "unbypass", "sandbox", "unsandbox", "clean", "preset", "reload" }),
	},
	{ page = "Marketplace", label = "Marketplace", icon = "market", owns = keys({ "latest", "version", "upload", "save" }) },
	{
		page = "Studio",
		label = "Studio",
		icon = "studio",
		owns = function(key: string): boolean
			return string.sub(key, 1, 5) == "spawn"
		end,
	},
}

-- The nav icons and the footer dot centre on the icon rail's centre line (half of its width).
local RAIL_CENTRE = Theme.size.sidebarCompact / 2

--- The bottom of the sidebar: what the plugin is doing (dot or spinner), the version, and a toggle that collapses the
--- sidebar to the icon rail or opens it again. In the rail only the dot and the toggle show, stacked.
local function SidebarFooter(controller: Controller.Controller): Frame
	local state, actions = controller.state, controller.actions

	local isBusy = Flux.computed(function()
		return state.busy() ~= nil
	end)
	local indicatorColor = Flux.tween(function()
		return Theme.levelColor(state.statusLine().level)
	end, Theme.tween.base)

	return new "Frame" {
		Name = "Footer",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,

		-- Hairline above the footer, inset like the nav items.
		new "Frame" {
			Name = "Divider",
			Position = UDim2.fromOffset(Theme.space.sm, 0),
			Size = UDim2.new(1, -Theme.space.sm * 2, 0, 1),
			BackgroundColor3 = C.border,
		},

		new "Frame" {
			Name = "Row",
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			Flux.padding({ x = Theme.space.sm, y = Theme.space.sm }),
			Flux.list({
				direction = function()
					return if state.compactNav() then "y" else "x"
				end,
				gap = Theme.space.sm,
				align = "center",
				justify = "between",
			}),

			-- Status dot / spinner, and the version chip when there is room for it.
			new "Frame" {
				Name = "Status",
				Size = UDim2.fromScale(0, 0),
				AutomaticSize = Enum.AutomaticSize.XY,
				BackgroundTransparency = 1,
				-- Puts the 14 px indicator's centre on the rail's centre line (the row already has 8 px of padding).
				Flux.padding({ x = RAIL_CENTRE - 7 - Theme.space.sm }),
				Flux.list({ direction = "x", gap = 8, align = "center" }),

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

				Flux.show(function()
					return not state.compactNav()
				end, function()
					return new "TextLabel" {
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
					}
				end),
			},

			IconButton({
				icon = "chevron",
				label = function()
					return if state.compactNav() then "Expand sidebar" else "Collapse sidebar"
				end,
				-- A down chevron turned to point where the sidebar will go: left to collapse, right to expand.
				rotation = function()
					return if state.compactNav() then -90 else 90
				end,
				onClick = actions.toggleNav,
			}),
		},
	}
end

local function Sidebar(controller: Controller.Controller): Frame
	local state, actions = controller.state, controller.actions

	local items: { any } = {}
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
				-- Modules shows how many ModuleScripts the selection covers; any page shows a spinner while it works.
				badge = if entry.page == "Modules"
					then function(): string?
						local count = state.moduleCount()
						return if count <= 0 then nil elseif count > 99 then "99+" else tostring(count)
					end
					else nil,
				busy = function()
					local key = state.busy()
					return key ~= nil and entry.owns(key)
				end,
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
			Flux.padding({ x = Theme.space.sm, top = Theme.space.md, bottom = Theme.space.sm }),
			Flux.list({ gap = Theme.space.xs }),
			items,
		},

		SidebarFooter(controller),
	}
end

-- Scrolling content fades out over the last pixels before an edge instead of being sliced through mid-line.
local FADE_TOP = 12
local FADE_BOTTOM = 24

--- A strip of the canvas colour that goes from clear to solid, pinned to the top or bottom of the page viewport.
local function EdgeFade(name: string, atBottom: boolean, height: number): Frame
	return new "Frame" {
		Name = name,
		AnchorPoint = Vector2.new(0, if atBottom then 1 else 0),
		-- Inset by the content layer's 1 px border so the strip never paints over it.
		Position = UDim2.new(0, 1, if atBottom then 1 else 0, if atBottom then 0 else 1),
		Size = UDim2.new(1, -2, 0, height),
		BackgroundColor3 = C.canvas,
		BorderSizePixel = 0,
		ZIndex = 2,
		-- The top strip sits in the content layer's rounded top-left corner, so it follows the curve (radius minus the border).
		Flux.corner({
			topLeft = if atBottom then 0 else Theme.radius.md - 1,
			topRight = 0,
			bottomLeft = 0,
			bottomRight = 0,
		}),
		new "UIGradient" {
			Rotation = 90,
			Transparency = if atBottom
				then NumberSequence.new(1, 0) -- clear at the top of the strip, solid against the bar
				else NumberSequence.new(0, 1),
		},
	}
end

local function PageArea(controller: Controller.Controller): Frame
	local state = controller.state

	local scroller = new "ScrollingFrame" {
		Name = "Pages",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = C.borderStrong,

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

	return new "Frame" {
		Name = "PageArea",
		Size = UDim2.fromScale(1, 0),
		BackgroundTransparency = 1,
		Flux.flex(),

		scroller,
		EdgeFade("FadeTop", false, FADE_TOP),
		EdgeFade("FadeBottom", true, FADE_BOTTOM),
	}
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
					-- A little room under Studio's title bar, so the content layer's top border and rounded corner are
					-- fully inside the widget instead of half-clipped by its edge.
					Flux.padding({ top = Theme.space.xs }),
					Flux.list({ gap = 0 }),


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

							PageArea(controller),
							StatusMessage({
								line = state.statusLine,
								onDismiss = actions.dismissStatus,
								-- Bottom-right corner. Capped to under half the bar so a long message keeps its room.
								trailing = SelectionSummary({
									summary = state.summary,
									variant = "chip",
									maxWidth = function()
										local bar = state.width() - (if state.compactNav() then Theme.size.sidebarCompact else Theme.size.sidebar)
										return if bar > 0 then math.clamp(bar * 0.45, 96, 320) else 320
									end,
								}),
							}),
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
