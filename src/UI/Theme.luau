--!strict
--- The single source of truth for colours, type, spacing and motion. Nothing else in the UI hardcodes these.
---
--- Colours come from the user's own Studio theme (`settings().Studio.Theme` and `Enum.StudioStyleGuideColor`), so the
--- panel matches Studio whatever theme is active. Surfaces, lines and hover states are derived from Studio's colours
--- (never hardcoded), so light themes work too. When Studio is not available (headless tests) the values Studio's dark
--- theme reports are used instead.
---
--- The structure follows Caelum's design system. Layering, back to front:
---   chrome   title bar and sidebar (one plane, no divider between them)
---   canvas   the content layer, inset with a rounded top-left corner
---   card     panels and cards on the canvas
---   sunken   inputs
---   control  button fills and the raised (selected) segment
--- The accent is reserved for primary actions, selection, focus and links.
---
--- `Theme.color` is one table that `Theme.refresh()` rewrites in place. After a Studio theme change, call it and
--- rebuild the UI: components read their colours when they are built.

export type Colors = {
	-- Surfaces
	chrome: Color3,
	canvas: Color3,
	card: Color3,
	cardHover: Color3,
	subtle: Color3,
	sunken: Color3,
	popup: Color3,
	-- Controls
	control: Color3,
	controlHover: Color3,
	controlPressed: Color3,
	controlDisabled: Color3,
	chromeHover: Color3,
	chromePressed: Color3,
	-- Lines
	border: Color3,
	borderSubtle: Color3,
	borderStrong: Color3,
	contentBorder: Color3,
	-- Text
	text: Color3,
	textMuted: Color3,
	textTertiary: Color3,
	-- Accent
	accent: Color3,
	accentHover: Color3,
	accentPressed: Color3,
	accentSubtle: Color3,
	accentText: Color3,
	onAccent: Color3,
	-- Status
	success: Color3,
	successSubtle: Color3,
	warning: Color3,
	warningSubtle: Color3,
	error: Color3,
	errorSubtle: Color3,
	neutral: Color3,
	scrim: Color3,
}

--- Reads one Studio style-guide colour: `get("MainText", "Hover")`.
type Getter = (name: string, modifier: string?) -> Color3

local function hex(value: string): Color3
	local r = tonumber(string.sub(value, 1, 2), 16) :: number
	local g = tonumber(string.sub(value, 3, 4), 16) :: number
	local b = tonumber(string.sub(value, 5, 6), 16) :: number
	return Color3.fromRGB(r, g, b)
end

local function mix(a: Color3, b: Color3, t: number): Color3
	return a:Lerp(b, t)
end

-- Studio's colours ---------------------------------------------------------------------------------------------

--- What Studio's dark theme reports for the entries we use (read from a live Studio; "Default" unless noted).
local DARK_FALLBACK: { [string]: string } = {
	MainBackground = "191A1F",
	Titlebar = "202227",
	Light = "353741",
	InputFieldBackground = "282931",
	Button = "353741",
	["Button.Pressed"] = "272930",
	MainText = "BCBEC8",
	["MainText.Hover"] = "FFFFFF",
	SubText = "BCBEC8",
	DimmedText = "6A6F81",
	InfoText = "8FB4FF",
	ErrorText = "E75750",
	WarningText = "F57630",
	DialogMainButton = "335FFF",
	["DialogMainButton.Hover"] = "528BFF",
	["DialogMainButton.Pressed"] = "002DD6",
	DialogMainButtonText = "FFFFFF",
	["Item.Selected"] = "13235D",
}

local function fallbackGetter(name: string, modifier: string?): Color3
	local key = if modifier ~= nil and DARK_FALLBACK[`{name}.{modifier}`] ~= nil then `{name}.{modifier}` else name
	return hex(DARK_FALLBACK[key] or "FF00FF") -- magenta: a missing entry is obvious
end

--- A getter backed by the live Studio theme, or `nil` outside Studio.
local function studioGetter(): Getter?
	local ok, theme = pcall(function()
		return (settings() :: any).Studio.Theme
	end)
	if not ok or theme == nil then
		return nil
	end
	return function(name: string, modifier: string?): Color3
		-- Names are our own constants from the table above, so the string lookups on the enums are safe.
		local color = (Enum.StudioStyleGuideColor :: any)[name]
		local mod = if modifier ~= nil
			then (Enum.StudioStyleGuideModifier :: any)[modifier]
			else Enum.StudioStyleGuideModifier.Default
		return theme:GetColor(color, mod)
	end
end

--- Derives every token from Studio's colours.
local function build(get: Getter): Colors
	local canvas = get("MainBackground")
	local chrome = get("Titlebar")
	local card = chrome
	local text = get("MainText", "Hover") -- Studio's emphasis colour: white in dark themes
	local subText = get("SubText")
	local lift = get("MainText") -- washes and lines move toward this, which lightens dark themes and darkens light ones

	local control = get("Button")
	local accent = get("DialogMainButton")
	local isDark = (canvas.R + canvas.G + canvas.B) < 1.5

	local success = if isDark then hex("5CC98F") else hex("1A7F4B")
	local warning = get("WarningText")
	-- Studio's error red is 4.45:1 on a card, a hair under AA for inline messages; nudge it toward the text colour.
	local danger = mix(get("ErrorText"), text, 0.1)

	return {
		chrome = chrome,
		canvas = canvas,
		card = card,
		cardHover = mix(card, lift, 0.05),
		subtle = mix(card, canvas, 0.5),
		sunken = get("InputFieldBackground"), -- Studio's own text-field background
		popup = mix(card, get("Light"), 0.5),

		control = control,
		controlHover = mix(control, lift, 0.08),
		controlPressed = get("Button", "Pressed"),
		controlDisabled = mix(card, control, 0.6),
		chromeHover = mix(chrome, lift, 0.07),
		chromePressed = mix(chrome, lift, 0.11),

		border = mix(card, lift, 0.14),
		borderSubtle = mix(card, lift, 0.08),
		borderStrong = mix(card, lift, 0.24),
		contentBorder = mix(chrome, lift, 0.1),

		text = text,
		textMuted = subText,
		textTertiary = mix(get("DimmedText"), subText, 0.65),

		accent = accent,
		-- Studio's hover blue is lighter than white labels can sit on at AA; take a fifth of the way there.
		accentHover = mix(accent, get("DialogMainButton", "Hover"), 0.2),
		accentPressed = get("DialogMainButton", "Pressed"),
		accentSubtle = get("Item", "Selected"), -- Studio's selection colour
		accentText = get("InfoText"),
		onAccent = get("DialogMainButtonText"),

		success = success,
		successSubtle = mix(card, success, 0.14),
		warning = warning,
		warningSubtle = mix(card, warning, 0.14),
		error = danger,
		errorSubtle = mix(card, danger, 0.14),
		neutral = get("DimmedText"),
		scrim = Color3.new(0, 0, 0),
	}
end

local Theme = {}

Theme.color = build(studioGetter() or fallbackGetter)

--- Re-reads the current Studio theme into `Theme.color` (in place). Returns false outside Studio.
function Theme.refresh(): boolean
	local get = studioGetter()
	if get == nil then
		return false
	end
	local fresh: any = build(get)
	local colors: any = Theme.color
	for key, value in fresh do
		colors[key] = value
	end
	return true
end

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
