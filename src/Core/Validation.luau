--!strict
--- Pure input validation. No Roblox APIs, so it is unit-testable under Lune.

local Validation = {}

local MAX_ASSET_ID_DIGITS = 16 -- Roblox ids stay well below 2^53 (about 9.007e15, 16 digits)
local MAX_VERSION_DIGITS = 9

local function trim(text: string): string
	return (string.match(text, "^%s*(.-)%s*$")) :: string
end

--- Strips everything that is not a decimal digit.
function Validation.digitsOnly(text: string): string
	return (string.gsub(text, "%D", ""))
end

--- Validates an asset id field. Returns `(id, nil)` or `(nil, errorMessage)`.
function Validation.parseAssetId(text: string): (number?, string?)
	local trimmed = trim(text)
	if trimmed == "" then
		return nil, "Enter an asset ID."
	end
	if not string.match(trimmed, "^%d+$") then
		return nil, "Asset IDs contain digits only."
	end
	if #trimmed > MAX_ASSET_ID_DIGITS then
		return nil, "That asset ID is too long."
	end
	local id = tonumber(trimmed) :: number
	if id < 1 then
		return nil, "Asset IDs start at 1."
	end
	return id, nil
end

--- Validates the optional version field. A blank field is valid and means "latest" (`(nil, nil)`).
--- Returns `(version, nil)`, `(nil, nil)` for blank, or `(nil, errorMessage)`.
function Validation.parseVersion(text: string): (number?, string?)
	local trimmed = trim(text)
	if trimmed == "" then
		return nil, nil
	end
	if not string.match(trimmed, "^%d+$") then
		return nil, "Versions are whole numbers."
	end
	if #trimmed > MAX_VERSION_DIGITS then
		return nil, "That version number is too long."
	end
	local version = tonumber(trimmed) :: number
	if version < 1 then
		return nil, "Versions start at 1."
	end
	return version, nil
end

--- The asset delivery URL used by the previous implementation (`GetObjects`).
function Validation.assetUrl(id: number, version: number?): string
	local base = string.format("https://assetdelivery.roblox.com/v1/asset/?id=%d", id)
	if version ~= nil then
		return base .. string.format("&version=%d", version)
	end
	return base
end

return Validation
