--!strict
--- The floating window: the old CoreGui setup, for people who do not want a dock widget. A ScreenGui in CoreGui holds
--- one movable, resizable window; the app is mounted into `content`, the way it is mounted into a DockWidgetPluginGui.
---
--- The window is chrome only (title bar, close button, resize handles). Where it may sit is decided by
--- `Core/Placement`, which is unit-tested; this file turns pointer input into those calls.

local Flux = require("../Flux")
local Placement = require("../Core/Placement")
local Theme = require("./Theme")

local new = Flux.new
local C = Theme.color

export type Options = {
	--- Where the ScreenGui goes (CoreGui in the plugin).
	parent: Instance,
	title: string,
	--- Where the window was last left. `nil` opens it near the right edge.
	rect: Placement.Rect?,
	--- Whether the window starts shown.
	enabled: boolean?,
	--- Called when a move or resize ends, with the final rectangle (to be saved).
	onRect: ((Placement.Rect) -> ())?,
	--- Whether the mouse button is still held. A drag ends when it is not, so a button released outside Studio does not
	--- leave the window stuck to the cursor. Defaults to UserInputService.
	isPointerDown: (() -> boolean)?,
}

export type Window = {
	--- The ScreenGui. `Enabled` shows and hides the window.
	gui: ScreenGui,
	--- Where the app is mounted.
	content: Frame,
	--- The current placement (`nil` until the screen size is known).
	rect: () -> Placement.Rect?,
	destroy: () -> (),
}

local TITLE_HEIGHT = Placement.TITLE_HEIGHT
local HANDLE = 5 -- thickness of the resize strips
local CORNER = 14 -- size of the corner grips
local TITLE_FONT = Font.fromEnum(Enum.Font.SourceSans)
local TITLE_SIZE = 14
local RADIUS = 3 -- the window's corners: a slight rounding, below the theme's smallest radius step (4)

local function defaultPointerDown(): boolean
	local ok, down = pcall(function()
		return game:GetService("UserInputService"):IsMouseButtonPressed(Enum.UserInputType.MouseButton1)
	end)
	return not ok or down == true
end

local function isPress(input: InputObject): boolean
	return input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch
end

local function isMove(input: InputObject): boolean
	return input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch
end

--- The close "X", drawn to match the one on Studio's own widget title bars (measured on a docked panel): 8 px across,
--- strokes about 1.5 px, in a soft grey (224 of 255 in the dark theme) rather than the full text colour. Studio's X has
--- faint pixels beside each stroke (edge smoothing). Rotated frames are not smoothed, so each stroke sits on a wider,
--- mostly transparent copy of itself that puts those faint pixels back (measured at about 25% of the stroke's strength).
local function crossGlyph(): { Instance }
	local color = C.text:Lerp(C.chrome, 0.14)
	local function stroke(rotation: number, length: number, thickness: number, transparency: number): Frame
		return new "Frame" {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(length, thickness),
			Rotation = rotation,
			BackgroundColor3 = color,
			BackgroundTransparency = transparency,
			Flux.corner(thickness / 2),
		}
	end
	return {
		stroke(45, 11, 3.4, 0.76),
		stroke(-45, 11, 3.4, 0.76),
		stroke(45, 10.5, 1.75, 0),
		stroke(-45, 10.5, 1.75, 0),
	}
end

local Window = {}

function Window.create(options: Options): Window
	local isPointerDown = options.isPointerDown or defaultPointerDown

	local screen: ScreenGui
	local frame: Frame
	local content: Frame
	local rect: Placement.Rect? = options.rect
	local dragging: GuiObject? = nil -- the catcher while a move or resize is in progress

	local function viewport(): Placement.Size?
		local size = screen.AbsoluteSize
		if size.X <= 0 or size.Y <= 0 then
			return nil
		end
		return { x = size.X, y = size.Y }
	end

	local function apply(placed: Placement.Rect)
		frame.Position = UDim2.fromOffset(placed.x, placed.y)
		frame.Size = UDim2.fromOffset(placed.width, placed.height)
	end

	--- (Re)places the window for the current screen size. Waits until the screen has been laid out.
	local function place()
		local size = viewport()
		if size == nil then
			return
		end
		local placed = if rect then Placement.fit(rect, size) else Placement.initial(size)
		rect = placed
		apply(placed)
		frame.Visible = true
	end

	--- Starts following the pointer. `change` turns the distance moved so far into the new rectangle.
	local function drag(input: InputObject, change: (start: Placement.Rect, dx: number, dy: number, size: Placement.Size) -> Placement.Rect)
		local start, size = rect, viewport()
		if dragging ~= nil or start == nil or size == nil or not isPress(input) then
			return
		end
		local origin = input.Position
		local byMouse = input.UserInputType ~= Enum.UserInputType.Touch

		-- Pointer events only reach the object under the pointer, so a transparent layer over the whole screen follows
		-- it wherever it goes for as long as the drag lasts.
		local catcher = Instance.new("TextButton")
		catcher.Name = "DragCatcher"
		catcher.Size = UDim2.fromScale(1, 1)
		catcher.BackgroundTransparency = 1
		catcher.Text = ""
		catcher.AutoButtonColor = false
		catcher.ZIndex = 1000
		catcher.Parent = screen
		dragging = catcher

		local function finish()
			if dragging ~= catcher then
				return
			end
			dragging = nil
			catcher:Destroy()
			if options.onRect and rect then
				options.onRect(rect)
			end
		end

		catcher.InputChanged:Connect(function(moved: InputObject)
			if not isMove(moved) then
				return
			end
			if byMouse and not isPointerDown() then
				finish()
				return
			end
			rect = change(start, moved.Position.X - origin.X, moved.Position.Y - origin.Y, viewport() or size)
			apply(rect :: Placement.Rect)
		end)
		catcher.InputEnded:Connect(function(ended: InputObject)
			if isPress(ended) then
				finish()
			end
		end)
	end

	local function Handle(name: string, edges: Placement.Edges, props: { [string]: any }, glyph: { Instance }?): Frame
		local handle = new "Frame" {
			Name = name,
			BackgroundTransparency = 1,
			Active = true, -- take the press, so it does not also reach the app underneath
			ZIndex = 10,
			InputBegan = function(input: InputObject)
				drag(input, function(start, dx, dy, size)
					return Placement.resize(start, edges, dx, dy, size)
				end)
			end,
			glyph,
		}
		for key, value in props do
			(handle :: any)[key] = value
		end
		return handle
	end

	local unmount = Flux.mount(function()
		screen = new "ScreenGui" {
			Name = "SensationUtilities_Floating",
			Enabled = options.enabled == true,
			IgnoreGuiInset = true,
			ResetOnSpawn = false,
			DisplayOrder = 10,
			ZIndexBehavior = Enum.ZIndexBehavior.Sibling,

			new "Frame" {
				Name = "Window",
				Visible = false, -- until the screen size is known
				BackgroundTransparency = 1,
				ZIndex = 1,

				-- A CanvasGroup clips everything inside it to its rounded corners (a plain frame cannot).
				new "CanvasGroup" {
					Name = "Body",
					Size = UDim2.fromScale(1, 1),
					BackgroundColor3 = C.chrome,
					Flux.corner(RADIUS),

					new "Frame" {
						Name = "TitleBar",
						Size = UDim2.new(1, 0, 0, TITLE_HEIGHT),
						BackgroundColor3 = C.chrome,
						Active = true,
						InputBegan = function(input: InputObject)
							drag(input, function(start, dx, dy, size)
								return Placement.move(start, dx, dy, size)
							end)
						end,

						-- Centred across the whole bar, like Studio's own widget title bar. The side padding keeps a long
						-- title clear of the close button.
						new "TextLabel" {
							Name = "Title",
							Size = UDim2.fromScale(1, 1),
							BackgroundTransparency = 1,
							Text = options.title,
							TextXAlignment = Enum.TextXAlignment.Center,
							TextTruncate = Enum.TextTruncate.AtEnd,
							-- Studio's normal text colour (#BCBEC8 in the dark theme), not the white emphasis colour: white reads heavier.
							TextColor3 = C.textMuted,
							-- Studio draws its widget titles in the Windows system font (a humanist sans). Source Sans at 14 is the
							-- closest Roblox font: measured in Studio it is 91 px wide for this title, the same as Studio's own, with
							-- the same capital height. (The interface's Builder Sans reads about 6% narrower at 13 and 5% wider at 14.)
							FontFace = TITLE_FONT,
							TextSize = TITLE_SIZE,
							Flux.padding({ x = 40 }),
						},
						(function(): TextButton
							local close = new "TextButton" {
								Name = "Close",
								AnchorPoint = Vector2.new(1, 0.5),
								Position = UDim2.new(1, -5, 0.5, 1), -- measured against Studio's own close button: 1 px lower and 1 px further right than centred
								Size = UDim2.fromOffset(20, 20),
								Text = "",
								Flux.corner(Theme.radius.sm),
							}
							local hovered = Flux.Interact.hover(close)
							Flux.edit(close) {
								BackgroundColor3 = C.controlHover,
								BackgroundTransparency = Flux.tween(function()
									return if hovered() then 0 else 1
								end, Theme.tween.fast),
								Activated = function()
									screen.Enabled = false
								end,
								crossGlyph(),
							}
							return close
						end)(),
					},

					new "Frame" {
						Name = "Content",
						Position = UDim2.fromOffset(0, TITLE_HEIGHT),
						Size = UDim2.new(1, 0, 1, -TITLE_HEIGHT),
						BackgroundTransparency = 1,
						ClipsDescendants = true,
					},
				},

				-- The border is drawn over the body: a stroke on the clipped group would be cut off.
				new "Frame" {
					Name = "Border",
					Size = UDim2.fromScale(1, 1),
					BackgroundTransparency = 1,
					ZIndex = 5,
					Flux.corner(RADIUS),
					Flux.stroke({ thickness = 1, color = C.borderStrong }),
				},

				Handle("ResizeLeft", { left = true }, {
					Size = UDim2.new(0, HANDLE, 1, -CORNER),
					Position = UDim2.fromOffset(0, TITLE_HEIGHT),
				}),
				Handle("ResizeBottom", { bottom = true }, {
					Size = UDim2.new(1, -CORNER * 2, 0, HANDLE),
					AnchorPoint = Vector2.new(0.5, 1),
					Position = UDim2.fromScale(0.5, 1),
				}),
				Handle("ResizeBottomLeft", { left = true, bottom = true }, {
					Size = UDim2.fromOffset(CORNER, CORNER),
					AnchorPoint = Vector2.new(0, 1),
					Position = UDim2.fromScale(0, 1),
				}),
				Handle("ResizeBottomRight", { right = true, bottom = true }, {
					Size = UDim2.fromOffset(CORNER, CORNER),
					AnchorPoint = Vector2.new(1, 1),
					Position = UDim2.fromScale(1, 1),
				}),
			},
		}
		return screen
	end, options.parent)

	frame = screen:FindFirstChild("Window") :: Frame
	content = frame:FindFirstChild("Content", true) :: Frame
	screen:GetPropertyChangedSignal("AbsoluteSize"):Connect(place)
	place()

	return {
		gui = screen,
		content = content,
		rect = function()
			return rect
		end,
		destroy = function()
			dragging = nil
			unmount()
		end,
	}
end

return Window
