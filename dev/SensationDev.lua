-- Development loader. Copy this file into your Studio Plugins folder (Plugins tab > Plugins Folder) while testing a
-- local checkout, and TEMPORARILY move the installed Plugin.rbxmx out of that folder so only one copy loads.
-- Start the server first, from the repository root:  python -m http.server 8000
-- Studio needs Game Settings > Security > Allow HTTP Requests enabled (or the same plugin permission prompt accepted).

local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")

if RunService:IsRunning() or RunService:IsRunMode() then
	return
end

shared.SensationDevBase = "http://localhost:8000/"

local source = HttpService:GetAsync(shared.SensationDevBase .. "plugin.luau?t=" .. os.time(), true)
loadstring(source)()
