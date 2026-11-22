--!nocheck
local Validation = require("../../src/Core/Validation")

local function eq(actual: any, expected: any, label: string?)
	if actual ~= expected then
		error(`{label or "value"}: expected {tostring(expected)}, got {tostring(actual)}`, 2)
	end
end

return {
	name = "Validation",
	run = function(test)
		test("accepts a plain asset id", function()
			local id, err = Validation.parseAssetId("1234567890")
			eq(id, 1234567890)
			eq(err, nil)
		end)

		test("trims whitespace around an asset id", function()
			eq((Validation.parseAssetId("  42  ")), 42)
		end)

		test("rejects an empty asset id", function()
			local id, err = Validation.parseAssetId("   ")
			eq(id, nil)
			eq(err, "Enter an asset ID.")
		end)

		test("rejects letters, signs and decimals in an asset id", function()
			for _, text in { "abc", "12a", "-5", "1.5", "1e5", "rbxassetid://1", "0x10" } do
				local id, err = Validation.parseAssetId(text)
				eq(id, nil, text)
				eq(err, "Asset IDs contain digits only.", text)
			end
		end)

		test("rejects zero and absurdly long asset ids", function()
			eq(select(2, Validation.parseAssetId("0")), "Asset IDs start at 1.")
			eq(select(2, Validation.parseAssetId("00")), "Asset IDs start at 1.")
			eq(select(2, Validation.parseAssetId(string.rep("9", 17))), "That asset ID is too long.")
		end)

		test("keeps a 16 digit id exact", function()
			eq((Validation.parseAssetId("9007199254740991")), 9007199254740991)
		end)

		test("a blank version is valid and means latest", function()
			local version, err = Validation.parseVersion("")
			eq(version, nil)
			eq(err, nil)
			version, err = Validation.parseVersion("   ")
			eq(version, nil)
			eq(err, nil)
		end)

		test("accepts a positive version", function()
			eq((Validation.parseVersion("7")), 7)
			eq((Validation.parseVersion(" 12 ")), 12)
		end)

		test("rejects non-numeric, zero and oversized versions", function()
			eq(select(2, Validation.parseVersion("v2")), "Versions are whole numbers.")
			eq(select(2, Validation.parseVersion("1.5")), "Versions are whole numbers.")
			eq(select(2, Validation.parseVersion("0")), "Versions start at 1.")
			eq(select(2, Validation.parseVersion("1234567890")), "That version number is too long.")
		end)

		test("digitsOnly strips everything that is not a digit", function()
			eq(Validation.digitsOnly("a1b2-3 4.5"), "12345")
			eq(Validation.digitsOnly("abc"), "")
		end)

		test("asset urls match the previous implementation exactly", function()
			eq(Validation.assetUrl(123), "https://assetdelivery.roblox.com/v1/asset/?id=123")
			eq(Validation.assetUrl(123, 4), "https://assetdelivery.roblox.com/v1/asset/?id=123&version=4")
			eq(
				Validation.assetUrl(1234567890123456),
				"https://assetdelivery.roblox.com/v1/asset/?id=1234567890123456"
			)
		end)
	end,
}
