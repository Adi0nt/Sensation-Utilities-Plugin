local GAME = game
local LOADSTRING = loadstring

local RUN_SERVICE = GAME:GetService("RunService")
local HTTP_SERVICE = GAME:GetService("HttpService")

if RUN_SERVICE:IsRunning() or RUN_SERVICE:IsRunMode() then
	return
end

local URL = "https://raw.githubusercontent.com/Adi0nt/Sensation-Utilities-Plugin/refs/heads/main/plugin.luau"
local RESPONSE = HTTP_SERVICE:GetAsync(URL, true)

LOADSTRING(RESPONSE)()
