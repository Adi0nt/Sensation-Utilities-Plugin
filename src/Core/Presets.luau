--!strict
--- Module presets. The sources are byte-for-byte the ones the previous plugin shipped.

local Common = require("./Common")
local Result = require("./Result")
local Types = require("./Types")

local Presets = {}

Presets.names = { "Advanced Module", "Basic Module" } :: { string }

Presets.descriptions = {
	["Advanced Module"] = "Clones the children of service-named folders (StarterGui, StarterPack, StarterCharacterScripts, ...) into the matching container of the named player.",
	["Basic Module"] = "Clones every child into the named player's PlayerGui.",
} :: { [string]: string }

local basicModuleSource = [[return function(...)
	const args = table.pack(...)
	const player: Player? = game:QueryDescendants(`>Players>Player#{args[1]}`)[1]
	if not player then
		return
	end
	const playerGui: PlayerGui? = player:FindFirstChildOfClass("PlayerGui")
	if not playerGui then
		return
	end
	for index: number, value: Instance in script:GetChildren() do
		value:Clone().Parent = playerGui
	end
end]]

local advancedModuleSource = [[const starterPlayer = game:GetService("StarterPlayer")
const starterPack = game:GetService("StarterPack")
const starterGui = game:GetService("StarterGui")
const players = game:GetService("Players")
const starterCharacterScripts = starterPlayer:QueryDescendants(">StarterCharacterScripts")[1]
const starterPlayerScripts = starterPlayer:QueryDescendants(">StarterPlayerScripts")[1]

const function getService(serviceName: string)
    local service = nil
    if serviceName == "StarterCharacterScripts" or serviceName == "StarterPlayerScripts" then
        service = game:QueryDescendants(serviceName)[1]
    else
        service = game:QueryDescendants(">"..serviceName)[1]
    end
    return service
end

return function(name: string)
    const player: Player = players:QueryDescendants(`>Player#{name}`)[1]
    if not player then
        return
    end
    for _, value in script:GetChildren() do
        local service = getService(value.Name)
        if typeof(service) ~= "Instance" then
            warn("Service not found: " .. value.Name, 1)
            continue
        end
        if service == starterPack then
            service = player:FindFirstChildWhichIsA("Backpack")
        elseif service == starterGui then
            service = player:FindFirstChildWhichIsA("PlayerGui")
        elseif service == starterPlayerScripts then
            service = player:FindFirstChildWhichIsA("PlayerGui")
        elseif service == starterCharacterScripts then
            service = player.Character or player.CharacterAdded:Wait()
        end
        if not service then
            warn("Service not found: " .. value.Name, 2)
            continue
        end
        for _, instance in value:GetChildren() do
            if not service:FindFirstChild(instance.Name) then
                instance:Clone().Parent = service
            end
        end
    end
end]]

local sources: { [string]: string } = {
	["Advanced Module"] = advancedModuleSource,
	["Basic Module"] = basicModuleSource,
}

--- The preset's source, or the previous implementation's placeholder for an unknown name.
function Presets.source(name: string): string
	return sources[name] or "-- Invalid Preset"
end

--- Creates a `MainModule` ModuleScript with the chosen preset inside every selected instance.
function Presets.insert(env: Types.Env, presetName: Types.PresetName): Types.Result
	local selected = Common.selected(env)
	if #selected == 0 then
		env.log.info("Nothing is selected to insert the preset into. Skipping...")
		return Result.skipped("Nothing is selected to insert the preset into.")
	end

	local source = Presets.source(presetName)
	env.history:record(`Sensation: Insert {presetName}`, function()
		for _, value: Instance in selected do
			Common.create(env, "ModuleScript", {
				Parent = value,
				Name = "MainModule",
				Source = source,
			})
		end
	end)

	env.log.info(`Inserted {presetName} into {#selected} object(s).`)
	return Result.success(`Inserted {presetName} into {#selected} {if #selected == 1 then "object" else "objects"}.`, #selected)
end


return Presets
