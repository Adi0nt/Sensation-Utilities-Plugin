--!strict
--- Asset cleaner.
---
--- `scan` looks through the selection for asset references (meshes, textures, images, sounds, animations, ...) and
--- asks Studio's `ContentProvider` to load each distinct asset. The ones that fail (private, deleted, or not
--- available to this account) are reported, never changed. `clean` then clears them: it blanks the property that
--- holds the id, or, when asked, removes the instance that holds it. Both are protected per write so one failure
--- cannot abort the run, and a clean is one undo step.
---
--- `cleanSounds` is the older, narrower tool: it clears `SoundId` on sounds that report as not loaded.

local Common = require("./Common")
local Result = require("./Result")
local Types = require("./Types")

local Cleaner = {}

-- Which properties hold an asset id, by exact class name. Exact names (not `IsA`) keep the scan to one table lookup
-- per instance, which matters when the selection is a whole map.
local ASSET_PROPERTIES: { [string]: { string } } = {
	MeshPart = { "MeshId", "TextureID" },
	SpecialMesh = { "MeshId", "TextureId" },
	CharacterMesh = { "MeshId", "BaseTextureId", "OverlayTextureId" },
	Decal = { "Texture" },
	Texture = { "Texture" },
	ImageLabel = { "Image" },
	ImageButton = { "Image", "HoverImage", "PressedImage" },
	ImageHandleAdornment = { "Image" },
	Sound = { "SoundId" },
	Animation = { "AnimationId" },
	Sky = { "SkyboxBk", "SkyboxDn", "SkyboxFt", "SkyboxLf", "SkyboxRt", "SkyboxUp", "MoonTextureId", "SunTextureId" },
	ParticleEmitter = { "Texture" },
	Beam = { "Texture" },
	Trail = { "Texture" },
	Shirt = { "ShirtTemplate" },
	Pants = { "PantsTemplate" },
	ShirtGraphic = { "Graphic" },
	Tool = { "TextureId" },
	SurfaceAppearance = { "ColorMap", "MetalnessMap", "NormalMap", "RoughnessMap" },
	MaterialVariant = { "ColorMap", "MetalnessMap", "NormalMap", "RoughnessMap" },
	VideoFrame = { "Video" },
}

--- Asset ids are checked in batches, so a large scan can report progress.
local BATCH_SIZE = 100

--- The numeric id inside an asset reference, or nil for anything that is not a Roblox asset (empty, `rbxasset://`
--- engine files, thumbnails, ...). Handles `rbxassetid://123` and the older `...asset/?id=123` URLs.
function Cleaner.assetId(content: string): number?
	local lowered = string.lower(content)
	local id = string.match(lowered, "^rbxassetid://(%d+)")
		or string.match(lowered, "^https?://[%w%.%-]*roblox%.com/asset/?%?[^#]*id=(%d+)")
		or string.match(lowered, "^https?://assetdelivery%.roblox%.com/[^?]*%?[^#]*id=(%d+)")
	local number = if id then tonumber(id) else nil
	if number == nil or number <= 0 then
		return nil
	end
	return number
end

local function contentOf(id: number): string
	return `rbxassetid://{id}`
end

--- Every asset reference inside `roots` (and their descendants), grouped by asset id, plus how many instances were
--- looked at and how many references there are in total.
function Cleaner.collect(roots: { Instance }): ({ [number]: { Types.AssetReference } }, number, number)
	local byId: { [number]: { Types.AssetReference } } = {}
	local scanned, references = 0, 0

	local function look(instance: Instance)
		scanned += 1
		local properties = ASSET_PROPERTIES[instance.ClassName]
		if properties == nil then
			return
		end
		for _, property in properties do
			local ok, value = pcall(function()
				return (instance :: any)[property]
			end)
			if ok and type(value) == "string" and value ~= "" then
				local id = Cleaner.assetId(value)
				if id ~= nil then
					local list = byId[id]
					if list == nil then
						list = {}
						byId[id] = list
					end
					table.insert(list, { instance = instance, property = property })
					references += 1
				end
			end
		end
	end

	-- Overlapping selections (a model and one of its parts) must not be counted twice.
	local seen: { [Instance]: boolean } = {}
	for _, root in roots do
		if not seen[root] then
			seen[root] = true
			look(root)
		end
		for _, descendant in root:GetDescendants() do
			if not seen[descendant] then
				seen[descendant] = true
				look(descendant)
			end
		end
	end

	return byId, scanned, references
end

local function isFailure(status: any): boolean
	return status == Enum.AssetFetchStatus.Failure
end

local function isSuccess(status: any): boolean
	return status == Enum.AssetFetchStatus.Success
end

--- Finds the asset references in the selection that Studio cannot load. Yields (it waits on the network).
--- `onProgress(done, total)` is called as batches of assets are checked. Returns a result for the status bar and, when
--- something was checked, the report the UI lists.
function Cleaner.scan(env: Types.Env, onProgress: ((done: number, total: number) -> ())?): (Types.Result, Types.ScanReport?)
	local selected = Common.selected(env)
	if #selected == 0 then
		env.log.info("Nothing is selected to scan. Skipping...")
		return Result.skipped("Select what to scan for broken assets."), nil
	end

	local byId, scanned, references = Cleaner.collect(selected)
	local ids: { number } = {}
	for id in byId do
		table.insert(ids, id)
	end
	table.sort(ids)

	local report: Types.ScanReport = { broken = {}, scanned = scanned, references = references, assets = #ids, unverified = 0 }
	if #ids == 0 then
		env.log.info(`Scanned {scanned} instance(s): no asset references.`)
		return Result.info(`No asset references found in the selection ({scanned} {if scanned == 1 then "object" else "objects"} checked).`, 0), report
	end

	local verdict: { [string]: any } = {}
	local done = 0
	for first = 1, #ids, BATCH_SIZE do
		local batch: { string } = {}
		for index = first, math.min(first + BATCH_SIZE - 1, #ids) do
			table.insert(batch, contentOf(ids[index]))
		end
		-- A failed request must not stop the scan: whatever it could not decide stays unverified.
		pcall(function()
			env.contentProvider:PreloadAsync(batch :: { any }, function(contentId: string, status: any)
				verdict[contentId] = status
			end)
		end)
		done += #batch
		if onProgress then
			onProgress(done, #ids)
		end
	end

	for _, id in ids do
		local content = contentOf(id)
		local status = verdict[content]
		if isFailure(status) then
			table.insert(report.broken, { content = content, id = id, references = byId[id] })
		elseif not isSuccess(status) then
			report.unverified += 1
		end
	end
	-- Most-used first, then by id so the order is stable.
	table.sort(report.broken, function(a: Types.BrokenAsset, b: Types.BrokenAsset)
		if #a.references ~= #b.references then
			return #a.references > #b.references
		end
		return a.id < b.id
	end)

	env.log.info(`Scanned {scanned} instance(s): {#ids} asset(s), {#report.broken} could not be loaded.`)
	local checked = `{#ids} {if #ids == 1 then "asset" else "assets"}`
	if #report.broken == 0 then
		local note = if report.unverified > 0 then ` ({report.unverified} could not be checked)` else ""
		return Result.info(`All {checked} loaded.{note}`, 0), report
	end
	local message = `{#report.broken} of {checked} could not be loaded.`
	if report.unverified > 0 then
		message ..= ` {report.unverified} could not be checked.`
	end
	return Result.warning(message, #report.broken), report
end

--- Writes "" into the property, falling back to the raw setter for properties a plain assignment is refused on.
local function blank(env: Types.Env, reference: Types.AssetReference): boolean
	local instance, property = reference.instance, reference.property
	if pcall(function()
		(instance :: any)[property] = ""
	end) then
		return true
	end
	return (pcall(env.newIndex, instance, property, ""))
end

--- Whether the reference still holds the broken asset (the place may have changed since the scan).
local function stillHolds(reference: Types.AssetReference, id: number): boolean
	local ok, value = pcall(function()
		return (reference.instance :: any)[reference.property]
	end)
	return ok and type(value) == "string" and Cleaner.assetId(value) == id
end

--- Clears the chosen broken assets. By default each reference is blanked; with `removeInstances` the instance that
--- holds it is destroyed instead. References that changed since the scan are left alone.
function Cleaner.clean(env: Types.Env, broken: { Types.BrokenAsset }, removeInstances: boolean): Types.Result
	if #broken == 0 then
		return Result.skipped("Choose at least one asset to clean.")
	end

	local cleared, removed, failed, skipped = 0, 0, 0, 0
	local destroyed: { [Instance]: boolean } = {}
	env.history:record("Sensation: Clean private assets", function()
		for _, asset in broken do
			for _, reference in asset.references do
				if destroyed[reference.instance] then
					continue
				end
				if not stillHolds(reference, asset.id) then
					skipped += 1
					continue
				end
				if removeInstances then
					if pcall(function()
						reference.instance:Destroy()
					end) then
						destroyed[reference.instance] = true
						removed += 1
					else
						failed += 1
					end
				elseif blank(env, reference) then
					cleared += 1
				else
					failed += 1
				end
			end
		end
	end)

	local assets = `{#broken} {if #broken == 1 then "asset" else "assets"}`
	local what: string
	local count: number
	if removeInstances then
		count = removed
		what = `Removed {removed} {if removed == 1 then "instance" else "instances"} that used {assets}.`
	else
		count = cleared
		what = `Cleared {cleared} {if cleared == 1 then "reference" else "references"} to {assets}.`
	end
	env.log.info(what)

	local notes: { string } = {}
	if failed > 0 then
		table.insert(notes, `{failed} could not be changed`)
	end
	if skipped > 0 then
		table.insert(notes, `{skipped} had already changed`)
	end
	if #notes > 0 then
		return Result.warning(`{what} {table.concat(notes, ", ")}.`, count)
	end
	if count == 0 then
		return Result.info("Nothing needed cleaning.", 0)
	end
	return Result.success(what, count)
end

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
