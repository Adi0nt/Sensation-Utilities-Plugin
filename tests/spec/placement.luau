--!nocheck
local Placement = require("../../src/Core/Placement")

local function eq(actual: any, expected: any, label: string?)
	if actual ~= expected then
		error(`{label or "value"}: expected {tostring(expected)}, got {tostring(actual)}`, 2)
	end
end

local function rect(x: number, y: number, width: number, height: number)
	return { x = x, y = y, width = width, height = height }
end

local SCREEN = { x = 1280, y = 720 }

return {
	name = "Placement (floating window)",
	run = function(test)
		test("a new window opens near the right edge, below the top, at its default size", function()
			local placed = Placement.initial(SCREEN)
			eq(placed.width, 400)
			eq(placed.height, 720 - Placement.MARGIN * 3, "no taller than the room between its top and bottom margins")
			eq(placed.x, 1280 - 400 - Placement.MARGIN)
			eq(placed.y, Placement.MARGIN * 2)
		end)

		test("a tall screen gets the full default height", function()
			eq(Placement.initial({ x = 1920, y = 1200 }).height, 680)
		end)

		test("a tiny screen still gets a usable window", function()
			local placed = Placement.initial({ x = 300, y = 300 })
			eq(placed.width, Placement.MIN_WIDTH)
			eq(placed.height, Placement.MIN_HEIGHT)
		end)

		test("moving shifts the window", function()
			local moved = Placement.move(rect(100, 100, 400, 500), 30, -20, SCREEN)
			eq(moved.x, 130)
			eq(moved.y, 80)
			eq(moved.width, 400)
			eq(moved.height, 500)
		end)

		test("the title bar can never leave the screen", function()
			local up = Placement.move(rect(100, 100, 400, 500), 0, -500, SCREEN)
			eq(up.y, 0, "not above the top")
			local down = Placement.move(rect(100, 100, 400, 500), 0, 5000, SCREEN)
			eq(down.y, SCREEN.y - Placement.TITLE_HEIGHT, "its title bar stays visible at the bottom")
		end)

		test("part of the window always stays on screen horizontally", function()
			local left = Placement.move(rect(100, 100, 400, 500), -5000, 0, SCREEN)
			eq(left.x, Placement.KEEP_VISIBLE - 400, "the right edge keeps a grabbable strip")
			local right = Placement.move(rect(100, 100, 400, 500), 5000, 0, SCREEN)
			eq(right.x, SCREEN.x - Placement.KEEP_VISIBLE, "the left edge keeps a grabbable strip")
		end)

		test("fitting shrinks a window that no longer fits a smaller screen", function()
			local fitted = Placement.fit(rect(900, 500, 800, 900), { x = 600, y = 500 })
			eq(fitted.width, 600)
			eq(fitted.height, 500)
			eq(fitted.x, 600 - Placement.KEEP_VISIBLE)
			eq(fitted.y, 500 - Placement.TITLE_HEIGHT)
		end)

		test("a window is never smaller than the interface can lay out", function()
			local fitted = Placement.fit(rect(0, 0, 100, 100), SCREEN)
			eq(fitted.width, Placement.MIN_WIDTH)
			eq(fitted.height, Placement.MIN_HEIGHT)
		end)

		test("dragging the bottom-right corner grows the window and keeps its corner", function()
			local resized = Placement.resize(rect(100, 100, 400, 500), { right = true, bottom = true }, 60, 40, SCREEN)
			eq(resized.x, 100)
			eq(resized.y, 100)
			eq(resized.width, 460)
			eq(resized.height, 540)
		end)

		test("dragging the left edge keeps the right edge where it was", function()
			local resized = Placement.resize(rect(500, 100, 400, 500), { left = true }, -80, 0, SCREEN)
			eq(resized.width, 480)
			eq(resized.x, 420)
			eq(resized.x + resized.width, 900)
		end)

		test("shrinking from the left stops at the minimum width, with the right edge still in place", function()
			local resized = Placement.resize(rect(500, 100, 400, 500), { left = true }, 300, 0, SCREEN)
			eq(resized.width, Placement.MIN_WIDTH)
			eq(resized.x + resized.width, 900)
		end)

		test("resizing cannot go below the minimum or past the screen", function()
			local small = Placement.resize(rect(100, 100, 400, 500), { right = true, bottom = true }, -999, -999, SCREEN)
			eq(small.width, Placement.MIN_WIDTH)
			eq(small.height, Placement.MIN_HEIGHT)
			local big = Placement.resize(rect(100, 100, 400, 500), { right = true, bottom = true }, 9999, 9999, SCREEN)
			eq(big.width, SCREEN.x)
			eq(big.height, SCREEN.y)
		end)

		test("a saved rectangle is read back, and damaged ones are rejected", function()
			local saved = { x = 10, y = 20, width = 420, height = 600 }
			local read = Placement.decode(saved)
			eq(read.x, 10)
			eq(read.height, 600)
			eq(Placement.decode(nil), nil, "nothing saved")
			eq(Placement.decode("rect"), nil, "wrong type")
			eq(Placement.decode({ x = 1, y = 2, width = 420 }), nil, "missing a field")
			eq(Placement.decode({ x = 0 / 0, y = 2, width = 420, height = 600 }), nil, "not a number")
			eq(Placement.decode({ x = 1, y = 2, width = 10, height = 10 }), nil, "too small to use")
		end)
	end,
}
