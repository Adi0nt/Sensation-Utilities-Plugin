--!strict
--- Undo support through ChangeHistoryService.
---
--- Operations that change the DataModel (bypass, sandbox, presets, insertion, ...) are wrapped in one recording so
--- Studio can undo them as a single step. This is best effort and never blocks an operation: if a recording cannot
--- start (another recording is active, solo playtest, API missing) the operation just runs without an undo step.
--- Operations that leave Studio (upload, save to file) are not recorded because Roblox cannot reverse them.

local Types = require("./Types")

local History = {}
History.__index = History

type Self = {
	service: ChangeHistoryService?,
	log: Types.Log,
}

function History.new(service: ChangeHistoryService?, log: Types.Log): Types.History
	return setmetatable({ service = service, log = log } :: Self, History) :: any
end

local function begin(service: ChangeHistoryService, name: string): string?
	local ok, id = pcall(function()
		return (service :: any):TryBeginRecording(name, name)
	end)
	if ok and type(id) == "string" then
		return id
	end
	return nil
end

--- Runs `fn` as one undo step. If `fn` throws, the recording is cancelled (reverting partial changes) and the error
--- is re-raised so the caller can report it.
function History.record(self: Self, name: string, fn: () -> ())
	local service = self.service
	if service == nil then
		fn()
		return
	end

	local recording = begin(service, name)
	local ok, err = pcall(fn :: () -> any)

	if recording ~= nil then
		local operation = if ok then Enum.FinishRecordingOperation.Commit else Enum.FinishRecordingOperation.Cancel
		local finished, finishError = pcall(function()
			(service :: any):FinishRecording(recording, operation)
		end)
		if not finished then
			self.log.warn(`Could not finish the undo recording for "{name}": {tostring(finishError)}`)
		end
	end

	if not ok then
		error(err, 0)
	end
end

return History
