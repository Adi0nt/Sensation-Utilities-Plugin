--!strict
--- Constructors for operation results (see `Types.Result`).

local Types = require("./Types")

local Result = {}

function Result.success(message: string, count: number?): Types.Result
	return { ok = true, level = "success", message = message, count = count }
end

function Result.info(message: string, count: number?): Types.Result
	return { ok = true, level = "info", message = message, count = count }
end

--- Nothing happened because a prerequisite is missing. Not an error, but the user should know.
function Result.skipped(message: string): Types.Result
	return { ok = false, level = "warning", message = message }
end

function Result.warning(message: string, count: number?): Types.Result
	return { ok = true, level = "warning", message = message, count = count }
end

function Result.failure(message: string): Types.Result
	return { ok = false, level = "error", message = message }
end

return Result
