--!strict
--- The single source of truth for colours, type, spacing and motion. Nothing else in the UI hardcodes these.
--- Pure data (no Flux), so it is also usable from tests.
---
--- The values follow Caelum's design system (Styles/Tokens.axaml and docs/DESIGN_SYSTEM.md), dark theme with the
--- Blue accent, so both tools read as one family. Layering, back to front:
---   chrome   title bar and sidebar (one plane, no divider between them)
---   canvas   the content layer, inset with a rounded top-left corner
---   card     panels and cards on the canvas
---   sunken   inputs and wells
---   control  button fills and the raised (selected) segment
--- The accent is reserved for primary actions, selection, focus and links.

local function hex(value: string): Color3
	local r = tonumber(string.sub(value, 1, 2), 16) :: number
	local g = tonumber(string.sub(value, 3, 4), 16) :: number
	local b = tonumber(string.sub(value, 5, 6), 16) :: number
	return Color3.fromRGB(r, g, b)
end

local function mix(a: Color3, b: Color3, t: number): Color3
	return a:Lerp(b, t)
end

local white = Color3.new(1, 1, 1)

local chrome = hex("1B1E20")
local card = hex("1C1F22")
local control = hex("25292C")

local Theme = {}

Theme.color = {
	-- Surfaces
	chrome = chrome,
	canvas = hex("151718"),
	card = card,
	cardHover = mix(card, white, 0.05), -- quiet controls sitting on a card
	subtle = hex("191C1E"), -- icon tiles, disabled fields
	sunken = hex("111314"),
	popup = hex("1F2326"), -- menus, tooltips, dialogs

	-- Controls
	control = control,
	controlHover = hex("2E3235"),
	controlPressed = hex("363A3E"),
	controlDisabled = mix(card, control, 0.6),

	-- Quiet washes on the chrome plane (Caelum's Chrome.Hover / Chrome.Pressed are 7% / 11% white)
	chromeHover = mix(chrome, white, 0.07),
	chromePressed = mix(chrome, white, 0.11),

	-- Lines
	border = hex("2C2F33"),
	borderSubtle = hex("23272A"),
	borderStrong = hex("3C4044"),
	contentBorder = hex("272B2E"), -- where the content layer meets the chrome

	-- Text
	text = hex("F0F2F3"),
	textMuted = hex("A7ABAE"), -- secondary: descriptions
	textTertiary = hex("969A9D"), -- metadata, helper text, placeholders, disabled

	-- Accent (Blue; neutrals above are Caelum's, tinted toward this hue at 70% saturation)
	accent = hex("7BB4E3"),
	accentHover = hex("96C7EE"),
	accentPressed = hex("62A0D6"),
	accentSubtle = hex("1E3345"),
	accentText = hex("A5D4FA"), -- accent-coloured text and icons on dark surfaces
	onAccent = hex("0F2230"), -- text drawn on an accent fill

	-- Status (independent of the accent)
	success = hex("5CC98F"),
	successSubtle = hex("173027"),
	warning = hex("E5A83B"),
	warningSubtle = hex("33291A"),
	error = hex("F26D6D"),
	errorSubtle = hex("3A1F22"),
	neutral = hex("717578"), -- inactive status dot

	scrim = Color3.new(0, 0, 0),
}

--- Status level -> accent colour.
Theme.levelColor = {
	success = Theme.color.success,
	info = Theme.color.accent,
	warning = Theme.color.warning,
	error = Theme.color.error,
}

-- Typography ---------------------------------------------------------------------------------------------------
-- One family and a short scale (Caelum: 11 / 12 / 13 / 14 / 20). Builder Sans is Roblox's own UI font; it has
-- Regular, Medium and Bold, so SemiBold maps to Bold. Nothing here is smaller than 11.

export type TextStyle = { face: Font, size: number }

local function style(font: Enum.Font, size: number): TextStyle
	return { face = Font.fromEnum(font), size = size }
end

Theme.text = {
	title = style(Enum.Font.BuilderSansBold, 20), -- page title
	heading = style(Enum.Font.BuilderSansBold, 14), -- section / panel heading
	cardTitle = style(Enum.Font.BuilderSansBold, 13),
	body = style(Enum.Font.BuilderSans, 13),
	label = style(Enum.Font.BuilderSansMedium, 13), -- input labels, buttons
	helper = style(Enum.Font.BuilderSans, 12), -- captions, helper text
	overline = style(Enum.Font.BuilderSansBold, 11), -- sidebar group labels
	mono = style(Enum.Font.RobotoMono, 12),
}

-- Spacing & shape ----------------------------------------------------------------------------------------------
-- One 4-pt scale: 2 / 4 / 8 / 12 / 16 / 24 / 32.

Theme.space = {
	xxs = 2,
	xs = 4,
	sm = 8,
	md = 12,
	lg = 16,
	xl = 24,
	xxl = 32,
}

-- Shape: 4 / 6 / 8 / 12. Nested shapes step down one rung (an 8 panel holds 6 controls which hold 4 chips).
Theme.radius = {
	xs = 4,
	sm = 6,
	md = 8,
	lg = 12,
}

Theme.size = {
	control = 32, -- buttons, inputs, dropdown triggers (Caelum's comfortable control is 36; a dock is tighter)
	header = 44, -- Caelum's top bar
	sidebar = 176,
	sidebarCompact = 56, -- Caelum's rail
	sidebarItem = 32, -- Caelum's nav item
	icon = 16,
	tile = 32, -- icon tile
	pagePadding = 20, -- Caelum compact page padding
	maxContent = 720, -- pages stop growing at this width instead of stretching controls across a wide dock
}

-- Motion -------------------------------------------------------------------------------------------------------
-- Short and restrained. Never waited on: controls are usable at once.

Theme.tween = {
	fast = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
	base = TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
	slow = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
}

--- Layout breakpoints, in widget pixels.
Theme.breakpoint = {
	compactNav = 540, -- window width below which the sidebar collapses to the icon rail
	stackCards = 400, -- content column width below which the R6/R15 cards stack instead of sitting side by side
}

return Theme
