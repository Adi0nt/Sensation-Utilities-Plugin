--!strict
--- The single source of truth for colours, type, spacing and motion. Nothing else in the UI hardcodes these.
--- Pure data (no Flux), so it is also usable from tests.

local function hex(value: string): Color3
	local r = tonumber(string.sub(value, 1, 2), 16) :: number
	local g = tonumber(string.sub(value, 3, 4), 16) :: number
	local b = tonumber(string.sub(value, 5, 6), 16) :: number
	return Color3.fromRGB(r, g, b)
end

local function mix(a: Color3, b: Color3, t: number): Color3
	return a:Lerp(b, t)
end

-- Base palette -------------------------------------------------------------------------------------------------

local bg = hex("101318") -- main background
local sidebar = hex("151A21")
local surface = hex("1B212B") -- elevated surfaces (panels)
local input = hex("222A35") -- input backgrounds and secondary buttons
local border = hex("303A48")
local text = hex("F1F4F8")
local textMuted = hex("99A5B5")
local accent = hex("598EFF")
local success = hex("4FC79B")
local warning = hex("E9B665")
local errorColor = hex("EF717B")

-- Text drawn on top of an accent fill. Dark for contrast: white on #598EFF is only about 3:1, this is above 5:1.
local onAccent = hex("0B1220")

local black = Color3.new(0, 0, 0)

local Theme = {}

Theme.color = {
	bg = bg,
	sidebar = sidebar,
	surface = surface,
	input = input,
	border = border,
	text = text,
	textMuted = textMuted,
	accent = accent,
	success = success,
	warning = warning,
	error = errorColor,
	onAccent = onAccent,

	-- Derived: interaction states
	surfaceHover = mix(surface, text, 0.05),
	inputHover = mix(input, text, 0.06),
	inputPressed = mix(input, black, 0.18),
	borderHover = mix(border, textMuted, 0.4),
	accentHover = mix(accent, Color3.new(1, 1, 1), 0.14),
	accentPressed = mix(accent, black, 0.12),
	accentSubtle = mix(surface, accent, 0.18), -- selected navigation / segmented option background
	accentBorder = mix(surface, accent, 0.55),

	-- Derived: disabled
	disabledBg = mix(surface, input, 0.55),
	textDisabled = mix(textMuted, bg, 0.28), -- about 3.6:1 on disabled surfaces: clearly dimmer than muted, still readable
	placeholder = mix(textMuted, input, 0.25), -- about 3.9:1 on input backgrounds

	-- Derived: feedback backgrounds
	successSubtle = mix(surface, success, 0.12),
	warningSubtle = mix(surface, warning, 0.12),
	errorSubtle = mix(surface, errorColor, 0.12),

	scrim = black,
}

--- Status level -> accent colour.
Theme.levelColor = {
	success = success,
	info = accent,
	warning = warning,
	error = errorColor,
}

-- Typography ---------------------------------------------------------------------------------------------------
-- Builder Sans is Roblox's own UI font. Nothing here is smaller than 12 px.

export type TextStyle = { face: Font, size: number }

local function style(font: Enum.Font, size: number): TextStyle
	return { face = Font.fromEnum(font), size = size }
end

Theme.text = {
	title = style(Enum.Font.BuilderSansBold, 18),
	heading = style(Enum.Font.BuilderSansBold, 15),
	body = style(Enum.Font.BuilderSans, 14),
	label = style(Enum.Font.BuilderSansMedium, 13),
	helper = style(Enum.Font.BuilderSans, 12),
	mono = style(Enum.Font.RobotoMono, 12),
}

-- Spacing & shape ----------------------------------------------------------------------------------------------
-- An 8 px grid (with a 4 px half-step for tight pairs).

Theme.space = {
	xs = 4,
	sm = 8,
	md = 16,
	lg = 24,
	xl = 32,
}

Theme.radius = {
	sm = 6,
	md = 8,
	lg = 10,
}

Theme.size = {
	control = 32, -- buttons, inputs, dropdown triggers
	header = 48,
	sidebar = 160,
	sidebarCompact = 56,
	sidebarItem = 36,
	icon = 16,
	maxContent = 640, -- pages stop growing at this width instead of stretching controls across a wide dock
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
	compactNav = 540, -- window width below which the sidebar collapses to icons (keeps the content column roomy)
	stackCards = 400, -- content column width below which the R6/R15 cards stack instead of sitting side by side
}

return Theme
