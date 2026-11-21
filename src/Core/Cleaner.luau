--!strict
--- Asset cleaner: clears `SoundId` on sounds that never loaded (broken or private assets). Same selection rules
--- as the previous plugin; each write is now protected so one failure cannot abort the run.

local Common = require("./Common")
local Result = require("./Result")
local Types = require("./Types")

local Cleaner = {}

local function clear(sound: Sound): boolean
	return (pcall(function()
		sound.SoundId = ""
	end))
end

function Cleaner.cleanSounds(env: Types.Env): Types.Result
	local selected = Common.selected(env)
	if #selected == 0 then
		env.log.info("Nothing is selected to clean. Skipping...")
		return Result.skipped("Nothing is selected to clean.")
	end

	local cleaned, failed = 0, 0
	env.history:record("Sensation: Clean sounds", function()
		for _, value: Instance in selected do
			if value:IsA("Sound") then
				if value.TimeLength == 0 and value.IsLoaded == false then
					if clear(value) then
						cleaned += 1
					else
						failed += 1
					end
				end
			end
			for _, object in value:QueryDescendants("Sound[TimeLength = 0][IsLoaded = false]") do
				if clear(object :: Sound) then
					cleaned += 1
				else
					failed += 1
				end
			end
		end
	end)

	env.log.info(`Cleaned {cleaned} sound instance(s).`)
	local noun = if cleaned == 1 then "sound" else "sounds"
	if failed > 0 then
		return Result.warning(`Cleaned {cleaned} {noun}; {failed} could not be changed.`, cleaned)
	end
	if cleaned == 0 then
		return Result.info("No unloaded sounds found in the selection.", 0)
	end
	return Result.success(`Cleaned {cleaned} {noun}.`, cleaned)
end

return Cleaner
