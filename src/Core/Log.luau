--!strict
--- Output-window logging. Keeps the plugin's existing `[Sensation Utilities]: ...` format.

local Types = require("./Types")

local PREFIX = "[Sensation Utilities]: "

local Log = {}

function Log.info(message: string)
	print(PREFIX .. message)
end

function Log.warn(message: string)
	warn(PREFIX .. message)
end

return Log :: Types.Log
