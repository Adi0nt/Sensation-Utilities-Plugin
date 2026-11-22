--!strict
--- The same class icon Explorer shows for an instance, from `StudioService:GetClassIcon`. The icons are textures that
--- ship with Studio (no network request) and follow the active Studio theme. Outside Studio, or for a class Studio
--- does not know, the icon is simply hidden and takes no space.

local Flux = require("../../Flux")

local new = Flux.new

type Icon = { Image: string, ImageRectOffset: Vector2, ImageRectSize: Vector2 }

local SIZE = 16

-- Class name -> icon, or `false` once we know there is none. Icons depend on the Studio theme, so the cache is
-- dropped by `ClassIcon.clearCache()` (the UI is rebuilt on a theme change anyway, which makes a new module state).
local cache: { [string]: Icon | false } = {}

local function lookup(className: string): Icon?
	local cached = cache[className]
	if cached ~= nil then
		return cached or nil
	end
	local ok, icon = pcall(function()
		return (game:GetService("StudioService") :: any):GetClassIcon(className)
	end)
	if ok and type(icon) == "table" and icon.Image ~= nil then
		cache[className] = icon :: Icon
		return icon :: Icon
	end
	cache[className] = false
	return nil
end

local ClassIcon = {}

function ClassIcon.clearCache()
	table.clear(cache)
end

--- A 16 px icon for `className` (static or reactive). `nil` hides it.
function ClassIcon.new(className: Flux.Reactive<string?>): ImageLabel
	local icon = Flux.computed(function(): Icon?
		local name = Flux.read(className)
		return if name ~= nil then lookup(name) else nil
	end)

	return new "ImageLabel" {
		Name = "ClassIcon",
		Size = UDim2.fromOffset(SIZE, SIZE),
		BackgroundTransparency = 1,
		Visible = function()
			return icon() ~= nil
		end,
		Image = function()
			local current = icon()
			return if current then current.Image else ""
		end,
		ImageRectOffset = function()
			local current = icon()
			return if current then current.ImageRectOffset else Vector2.zero
		end,
		ImageRectSize = function()
			local current = icon()
			return if current then current.ImageRectSize else Vector2.zero
		end,
	}
end

return ClassIcon
