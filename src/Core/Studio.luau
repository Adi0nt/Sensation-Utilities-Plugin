--!strict
--- Studio utilities: spawn a StarterCharacter rig into StarterPlayer (same user id / placement as before).

local Result = require("./Result")
local Types = require("./Types")

local players = game:GetService("Players")
local starterPlayer = game:GetService("StarterPlayer")

--- The user whose avatar the previous plugin used as the HumanoidDescription source.
local DESCRIPTION_USER_ID = 4907137312

local Studio = {}

--- True when StarterPlayer already contains a `StarterCharacter` (Roblox only uses one).
function Studio.hasStarterCharacter(): boolean
	return starterPlayer:FindFirstChild("StarterCharacter") ~= nil
end

--- Builds an R6 or R15 StarterCharacter model and parents it to StarterPlayer. Yields (avatar APIs hit the network).
function Studio.spawnCharacter(env: Types.Env, rigType: Types.RigType): Types.Result
	local rig = if rigType == "R6" then Enum.HumanoidRigType.R6 else Enum.HumanoidRigType.R15

	local usedDefaultDescription = false
	local descriptionOk, description: any = pcall(players.GetHumanoidDescriptionFromUserIdAsync, players, DESCRIPTION_USER_ID)
	if not descriptionOk or description == nil then
		env.log.warn(`Could not load the avatar description ({tostring(description)}). Using a default one.`)
		description = Instance.new("HumanoidDescription")
		usedDefaultDescription = true
	end

	local modelOk, model: any = pcall(players.CreateHumanoidModelFromDescriptionAsync, players, description, rig)
	if not modelOk or model == nil then
		env.log.warn(`Failed to create the {rigType} rig: {tostring(model)}`)
		return Result.failure(`Could not create the {rigType} rig. {tostring(model)}`)
	end

	local placed, placeError = pcall(function()
		env.history:record(`Sensation: Spawn {rigType} StarterCharacter`, function()
			model:PivotTo(CFrame.new(workspace.InsertPoint))
			model.Name = "StarterCharacter"
			model.Parent = starterPlayer
		end)
	end)
	if not placed then
		(model :: Instance):Destroy()
		env.log.warn(`Failed to place the {rigType} StarterCharacter: {tostring(placeError)}`)
		return Result.failure(`Could not place the {rigType} StarterCharacter. {tostring(placeError)}`)
	end

	env.log.info(`Spawned {rigType} StarterCharacter.`)
	if usedDefaultDescription then
		return Result.warning(`Spawned an {rigType} StarterCharacter with a default avatar (the avatar lookup failed).`)
	end
	return Result.success(`Spawned an {rigType} StarterCharacter in StarterPlayer.`)
end

return Studio
