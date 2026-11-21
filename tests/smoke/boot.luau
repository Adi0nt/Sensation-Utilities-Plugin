--!nocheck
-- Boots the sert headless engine + real Flux, then exposes the Roblox globals the plugin modules expect.
local sert = require("@sert")
require("@sert/engine/datatypes").installGlobals()
local HeadlessClock = require("../../.smoke/tree/Flux/Clock")
local Compat = require("../../.smoke/tree/Flux/Compat")
local engine = sert.env.new({
	isClient = true, isStudio = true, strict = true,
	host = { clock = HeadlessClock.now, spawn = Compat.task.spawn, defer = HeadlessClock.defer,
		delay = HeadlessClock.delay, wait = HeadlessClock.wait, cancel = HeadlessClock.cancel },
})
for _, key in {"typeof","Color3","UDim","UDim2","Vector2","Vector3","CFrame","Rect","NumberRange","Font","TweenInfo","Enum","ColorSequence","ColorSequenceKeypoint","NumberSequence","NumberSequenceKeypoint"} do
	Compat[key] = sert.env[key]
end
Compat.Instance = engine.Instance
Compat.services = engine.services
local function bridge()
	HeadlessClock.connect("Heartbeat", function(dt) engine:step(dt) end)
end
bridge()
local Flux = require("../../.smoke/tree/Flux")

-- Globals for the plugin's own modules (set after Flux loaded so Flux keeps its headless paths).
local env0 = getfenv(0)
env0.game = engine.game
env0.workspace = engine.workspace
env0.Instance = engine.Instance
env0.task = Compat.task
env0.typeof = sert.env.typeof
if env0.SecurityCapabilities == nil then
	env0.SecurityCapabilities = { new = function() return { Add = function(self) return self end } end }
end

return {
	sert = sert, engine = engine, Flux = Flux, Compat = Compat, Clock = Flux.Clock, bridge = bridge,
}
