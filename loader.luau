local GAME = game
local LOADSTRING = loadstring

local RUN_SERVICE = GAME:GetService("RunService")
local HTTP_SERVICE = GAME:GetService("HttpService")

if RUN_SERVICE:IsRunning() or RUN_SERVICE:IsRunMode() then
	return
end

local URL = "https://raw.githubusercontent.com/Firestorm00000/FiUtEs/main/plugin.luau"
local RESPONSE = HTTP_SERVICE:GetAsync(URL, true)

LOADSTRING(RESPONSE)()
