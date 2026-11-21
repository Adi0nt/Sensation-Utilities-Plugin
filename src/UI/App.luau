--!strict
--- The application shell: header, navigation sidebar, selection bar, scrolling page area, status strip and the
--- overlay layer. `mount` builds it inside a Flux root scope, so `unmount` tears down every instance, connection
--- and timer it created.

local Flux = require("../Flux")
local Actions = require("./Actions")
local ConfirmationDialog = require("./Components/ConfirmationDialog")
local Context = require("./Context")
local Controller = require("./Pages/Controller")
local Icon = require("./Components/Icon")
local IconButton = require("./Components/IconButton")
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

-- The footer and the status bar share one height, so their top hairlines run level across the bottom of the window.
local BAR_HEIGHT = 40

--- The bottom of the sidebar: the version and a toggle that collapses the sidebar to the icon rail or opens it again.
--- (What the plugin is doing is shown once, in the status bar.) In the rail only the toggle shows, centred.
local function SidebarFooter(controller: Controller.Controller): Frame
	local state, actions = controller.state, controller.actions

	return new "Frame" {
		Name = "Footer",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, BAR_HEIGHT),
		BackgroundTransparency = 1,

		-- Hairline across the top, level with the status bar's.
		new "Frame" {
			Name = "Divider",
			Size = UDim2.new(1, 0, 0, 1),
			BackgroundColor3 = C.borderSubtle,
		},

		new "Frame" {
			Name = "Row",
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Flux.padding({ x = Theme.space.sm }),
			Flux.list({
				direction = "x",
				align = "center",
				justify = function()
					return if state.compactNav() then "center" else "between"
				end,
			}),

			-- The version, lined up with the nav icons and labels above it (hidden in the rail). Quiet text, no box.
			Flux.show(function()
				return not state.compactNav()
			end, function()
				return new "Frame" {
					Name = "VersionSlot",
					Size = UDim2.fromScale(0, 0),
					AutomaticSize = Enum.AutomaticSize.XY,
					BackgroundTransparency = 1,
					Flux.padding({ left = Theme.space.md }),
					Flux.list({ direction = "x", gap = Theme.space.md, align = "center" }),

					Icon("commit", C.textTertiary),
					new "TextLabel" {
						Name = "Version",
						Size = UDim2.fromOffset(0, 20),
						AutomaticSize = Enum.AutomaticSize.X,
						BackgroundTransparency = 1,
						Text = state.commit,
						TextColor3 = C.textMuted,
						FontFace = Theme.text.mono.face,
						TextSize = Theme.text.mono.size,
					},
				}
			end),

			IconButton({
				icon = "sidebar",
				label = function()
					return if state.compactNav() then "Expand sidebar" else "Collapse sidebar"
				end,
				onClick = actions.toggleNav,
			}),
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
				Size = UDim2.new(1, 0, 0, 28),
				BackgroundTransparency = 1,
				Text = "Tools",
				TextXAlignment = Enum.TextXAlignment.Left,
				TextColor3 = C.textTertiary,
				FontFace = Theme.text.group.face,
				TextSize = Theme.text.group.size,
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
			Flux.list({ gap = 2 }),
			items,
		},

		SidebarFooter(controller),
	}
end

-- A page fades in when it is shown, so switching pages (and the build of a tall page) does not pop. The page sits in a
-- CanvasGroup, which clips to its own bounds, so the group carries a small bleed of padding for focus rings and other
-- strokes that reach just outside a control; the surrounding page padding is reduced by the same amount.
local BLEED = 4
local FADE_FROM = 0.97 -- not quite 1: a fully transparent group would also be treated as hidden by hit-testing

local function FadeIn(build: () -> GuiObject): CanvasGroup
	local shown = Flux.signal(false)
	local group = new "CanvasGroup" {
		Name = "PageFade",
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		GroupTransparency = Flux.tween(function()
			return if shown() then 0 else FADE_FROM
		end, Theme.tween.slow),
		Flux.padding(BLEED),
		build(),
	}
	-- Flip on the next step, so the first frame is drawn faded and then eases in.
	task.defer(function()
		shown:set(true)
	end)
	return group
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
			Flux.padding({ x = Theme.size.pagePadding - BLEED, top = Theme.space.lg - BLEED, bottom = Theme.space.xl - BLEED }),

			-- Pages stop growing instead of stretching controls across a wide dock.
			new "Frame" {
				Name = "Column",
				Size = UDim2.fromScale(1, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				Flux.sizeConstraint({ maxWidth = Theme.size.maxContent + BLEED * 2 }),

				Flux.switch(state.page)({
					Modules = function(): GuiObject
						return FadeIn(function()
							return ModulesPage(controller)
						end)
					end,
					Marketplace = function(): GuiObject
						return FadeIn(function()
							return MarketplacePage(controller)
						end)
					end,
					Studio = function(): GuiObject
						return FadeIn(function()
							return StudioPage(controller)
						end)
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
