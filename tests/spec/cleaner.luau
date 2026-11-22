--!nocheck
local Cleaner = require("../../src/Core/Cleaner")

local function eq(actual: any, expected: any, label: string?)
	if actual ~= expected then
		error(`{label or "value"}: expected {tostring(expected)}, got {tostring(actual)}`, 2)
	end
end

return {
	name = "Cleaner (asset references)",
	run = function(test)
		test("assetId reads rbxassetid:// references", function()
			eq(Cleaner.assetId("rbxassetid://123456"), 123456)
			eq(Cleaner.assetId("RBXASSETID://77"), 77, "case does not matter")
			eq(Cleaner.assetId("rbxassetid://9120386436"), 9120386436, "ids beyond 32 bits")
		end)

		test("assetId reads the older asset URLs", function()
			eq(Cleaner.assetId("http://www.roblox.com/asset/?id=555"), 555)
			eq(Cleaner.assetId("https://www.roblox.com/asset/?id=556&version=2"), 556)
			eq(Cleaner.assetId("http://www.roblox.com/asset?id=557"), 557)
			eq(Cleaner.assetId("https://assetdelivery.roblox.com/v1/asset/?id=558"), 558)
		end)

		test("assetId ignores everything that is not a Roblox asset", function()
			eq(Cleaner.assetId(""), nil, "empty")
			eq(Cleaner.assetId("rbxasset://textures/face.png"), nil, "engine file")
			eq(Cleaner.assetId("rbxthumb://type=Asset&id=1&w=150&h=150"), nil, "thumbnail")
			eq(Cleaner.assetId("rbxassetid://"), nil, "no id")
			eq(Cleaner.assetId("rbxassetid://abc"), nil, "not a number")
			eq(Cleaner.assetId("rbxassetid://0"), nil, "zero is not an asset")
			eq(Cleaner.assetId("http://example.com/asset/?id=5"), nil, "other hosts")
		end)
	end,
}
