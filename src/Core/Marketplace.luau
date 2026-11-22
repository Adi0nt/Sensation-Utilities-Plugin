--!strict
--- Marketplace utilities: insert an asset (latest or a specific version) and the native upload / save dialogs.

local Common = require("./Common")
local Result = require("./Result")
local Types = require("./Types")
local Validation = require("./Validation")

local Marketplace = {}

--- Fetches an asset and clones its contents into every selected instance. Yields while the asset downloads.
--- `idText` / `versionText` are the raw field contents; a blank version means "latest".
function Marketplace.insertAsset(env: Types.Env, idText: string, versionText: string?, latest: boolean): Types.Result
	local id, idError = Validation.parseAssetId(idText)
	if id == nil then
		return Result.skipped(idError or "Enter a valid asset ID.")
	end

	local version: number? = nil
	if not latest then
		local parsed, versionError = Validation.parseVersion(versionText or "")
		if parsed == nil then
			return Result.skipped(versionError or "Enter a version number, or switch to Latest.")
		end
		version = parsed
	end

	local selected = Common.selected(env)
	if #selected == 0 then
		env.log.info("Nothing is selected to insert the asset into. Skipping...")
		return Result.skipped("Nothing is selected to insert the asset into.")
	end

	local url = Validation.assetUrl(id, version)
	local success, objects: any = pcall(game.GetObjects, game, url)
	if not success or objects == nil then
		env.log.warn(`Failed to fetch asset {id}: {tostring(objects)}`)
		return Result.failure(`Could not load asset {id}. {tostring(objects)}`)
	end

	local inserted, failed = 0, 0
	env.history:record(`Sensation: Insert asset {id}`, function()
		for _, value: Instance in selected do
			for _, object in objects :: { Instance } do
				local ok = pcall(function()
					object:Clone().Parent = value
				end)
				if ok then
					inserted += 1
				else
					failed += 1
				end
			end
		end
	end)
	for _, object in objects :: { Instance } do
		object:Destroy()
	end

	local label = if version ~= nil then `asset {id} (v{version})` else `the latest version of asset {id}`
	local where = `{#selected} {if #selected == 1 then "object" else "objects"}`
	env.log.info(`Inserted {label} into {#selected} object(s).`)
	if failed > 0 then
		return Result.warning(`Inserted {label} into {where}, but {failed} insertion(s) failed.`, inserted)
	end
	return Result.success(`Inserted {label} into {where}.`, inserted)
end

--- Opens Studio's native "upload to Roblox" prompt for the selection. Roblox cannot undo an upload.
function Marketplace.uploadSelection(env: Types.Env): Types.Result
	local selected = Common.selected(env)
	if #selected == 0 then
		env.log.info("Nothing is selected to upload. Select an object in Explorer first.")
		return Result.skipped("Nothing is selected to upload. Select an object in Explorer first.")
	end

	local success, err = pcall(function()
		env.plugin:SaveSelectedToRoblox()
	end)
	if not success then
		env.log.warn(`Failed to open upload prompt: {tostring(err)}`)
		return Result.failure(`Could not open the upload prompt. {tostring(err)}`)
	end
	env.log.info(`Opened Roblox upload prompt for "{selected[1].Name}".`)
	return Result.info(`Opened the Roblox upload prompt for "{selected[1].Name}".`)
end

--- Opens Studio's native "save to file" prompt (.rbxm) for the selection. Yields until the dialog is closed.
function Marketplace.saveSelection(env: Types.Env): Types.Result
	local selected = Common.selected(env)
	if #selected == 0 then
		env.log.info("Nothing is selected to save. Select an object in Explorer first.")
		return Result.skipped("Nothing is selected to save. Select an object in Explorer first.")
	end

	local suggestedName = selected[1].Name .. ".rbxm"
	local plugin: any = env.plugin
	local success, saved = pcall(function()
		-- PromptSaveSelection is deprecated in favour of the yielding PromptSaveSelectionAsync.
		local hasAsync, asyncMethod = pcall(function()
			return plugin.PromptSaveSelectionAsync
		end)
		if hasAsync and asyncMethod ~= nil then
			return plugin:PromptSaveSelectionAsync(suggestedName)
		end
		return plugin:PromptSaveSelection(suggestedName)
	end)
	if not success then
		env.log.warn(`Failed to open save prompt: {tostring(saved)}`)
		return Result.failure(`Could not open the save prompt. {tostring(saved)}`)
	end
	if saved == false then
		env.log.info(`Save prompt for "{selected[1].Name}" was closed without saving.`)
		return Result.info("Save cancelled.")
	end
	env.log.info(`Opened file save prompt for "{selected[1].Name}".`)
	return Result.success(`Saved "{selected[1].Name}" as {suggestedName}.`)
end

return Marketplace
