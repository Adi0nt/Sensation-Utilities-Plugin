--!strict
local players = game:GetService("Players")
local starterPlayer = game:GetService("StarterPlayer")
local selection = game:GetService("Selection")
local serializationService = game:GetService("SerializationService")
local httpService = game:GetService("HttpService")
local coreGui = game:GetService("CoreGui")

local toolbar = plugin:CreateToolbar("Sensation")

local packages = {}
local methods = {}
local mode: "Insert" | "Append" = "Insert"
local methodState: any = nil

local rawLib
local maid
local task
local Iris

local instance_newindex

const basicModuleSource = [[return function(...)
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

const advancedModuleSource = [[const starterPlayer = game:GetService("StarterPlayer")
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

local function println(output: string)
	print(`[Sensation Utilities]: {output}`)
end

local function warnln(output: string)
	warn(`[Sensation Utilities]: {output}`)
end

local function applyPropertiesAndChildren(instance: Instance, properties: { [string]: any }?, children: { Instance }?)
	if properties then
		local parent = nil
		for property, value in properties do
			if property:lower() == "parent" then
				parent = value
				continue
			end
			pcall(instance_newindex, instance, property, value)
		end
		if parent then
			pcall(instance_newindex, instance, "Parent", parent)
		end
	end
	if children then
		for _, child in children do
			pcall(instance_newindex, child, "Parent", instance)
		end
	end
	return instance
end

local function createAsync(className: string, properties: { [string]: any }?, children: { Instance }?)
	local class = Instance.new(className)
	return applyPropertiesAndChildren(class, properties, children)
end

local function cloneAsync(clone: Instance, properties: { [string]: any }?, children: { Instance }?)
	local class = clone:Clone()
	return applyPropertiesAndChildren(class, properties, children)
end

local function getAsync(url: string, maxRetries: number?): string?
	local retries = maxRetries or 5
	local attempts = 0
	local success, body = false, nil
	
	repeat
		success, body = pcall(httpService.GetAsync, httpService, url)
		if success then
			return body
		end
		
		attempts += 1
		if attempts <= retries then
			println(`Buffering... (Attempt {attempts}/{retries})`)
			task.wait(1)
		end
	until success or attempts > retries
	
	warnln(`Failed to fetch URL after {retries} attempts.`)
	return nil
end

local function deserializeInstancesAsync(...): { Instance }
	return select(2, pcall(serializationService.DeserializeInstancesAsync, serializationService, ...))
end

local function getActiveMethod(): Instance?
	if methodState and methodState.value ~= "" and methods[methodState.value] then
		return methods[methodState.value]
	end
	local firstName, firstInstance = next(methods)
	if firstName and firstInstance then
		if methodState then
			methodState:set(firstName)
		end
		return firstInstance
	end
	return nil
end

local function appendAsync(moduleScript: ModuleScript)
	local container = getActiveMethod()
	if not container then
		return warnln("No bypass method available. Ensure methods.rbxm is loaded.")
	end
	println(`Appended {moduleScript.Name} using {container.Name}`)
	
	return selection:Set({
		createAsync("ModuleScript", {
			Parent = moduleScript.Parent,
			Name = "MainModule",
			Source = 'local moduleScript=script:FindFirstChildWhichIsA("ModuleScript",true)\nmoduleScript.Parent=nil\nscript:ClearAllChildren()\nmoduleScript.Parent=script\nreturn require(moduleScript)',
		}, { 
			cloneAsync(container:GetChildren()[1], nil, { moduleScript:Clone() }) 
		}),
	})
end

local function insertAsync(moduleScript: ModuleScript)
	local container = getActiveMethod()
	if not container then
		return warnln("No bypass method available. Ensure methods.rbxm is loaded.")
	end
	println(`Inserted {moduleScript.Name} using {container.Name}`)

	local children = container:GetChildren()
	for index, child in children do
		children[index] = child:Clone()
	end
	
	return selection:Set({
		cloneAsync(moduleScript:Clone(), {
			Parent = moduleScript.Parent
		}, children)
	})
end

local function extractAsync(moduleScript: ModuleScript)
	local originalModule = moduleScript:FindFirstChildWhichIsA("ModuleScript", true)
	if not originalModule then
		println(`Extracted {moduleScript.Name} from itself.`)
		return selection:Set({ cloneAsync(moduleScript, { Parent = moduleScript.Parent }) })
	end
	println(`Extracted {originalModule.Name} from {moduleScript.Name}`)
	return selection:Set({ cloneAsync(originalModule, { Parent = moduleScript.Parent }) })
end

local button = toolbar:CreateButton("Sensation Utilities", "Toggles the built-in interface.", Content.fromAssetId(16517502292).Uri)

println("Loading packages...")
local packageUrl = "https://github.com/Adi0nt/Sensation-Utilities-Plugin/raw/refs/heads/main/packages.rbxm"
local packageResponse = getAsync(packageUrl)
if packageResponse then
	local responseBuffer = buffer.fromstring(packageResponse)
	local _packages = deserializeInstancesAsync(responseBuffer)
	for _, value in _packages do
		packages[value.Name] = value
	end
	println("Loaded packages.")
else
	warnln("Critical Error: Packages failed to load.")
end

println("Loading methods...")
local methodsUrl = "https://github.com/Adi0nt/Sensation-Utilities-Plugin/raw/refs/heads/main/methods.rbxm"
local methodsResponse = getAsync(methodsUrl)
if methodsResponse then
	local responseBuffer = buffer.fromstring(methodsResponse)
	local _methods = deserializeInstancesAsync(responseBuffer)
	table.clear(methods)
	for _, value in _methods do
		methods[value.Name] = value
	end
	println(`Loaded {#_methods} method(s).`)
	if methodState and not methods[methodState.value] then
		local firstMethod = next(methods)
		if firstMethod then
			methodState:set(firstMethod)
		end
	end
else
	warnln("Critical Error: Methods failed to load.")
end

println("Loading Iris...")
local irisModule: ModuleScript? = packages.Iris
if not irisModule then
	local irisUrl = "https://github.com/Adi0nt/Sensation-Utilities-Plugin/raw/refs/heads/main/Iris.rbxm"
	local irisResponse = getAsync(irisUrl)
	if irisResponse then
		local responseBuffer = buffer.fromstring(irisResponse)
		local _iris = deserializeInstancesAsync(responseBuffer)
		irisModule = _iris[1] :: ModuleScript?
	end
	if not irisModule then
		local fallbackUrl = "https://github.com/SirMallard/Iris/releases/download/v2.5.1/Iris.rbxm"
		local fallbackResponse = getAsync(fallbackUrl)
		if fallbackResponse then
			local responseBuffer = buffer.fromstring(fallbackResponse)
			local _iris = deserializeInstancesAsync(responseBuffer)
			irisModule = _iris[1] :: ModuleScript?
		end
	end
end

assert(irisModule, "Critical Error: Iris failed to load.")
println("Loaded Iris.")
local irisLib = require(irisModule)

rawLib = require(packages.RawLib)
maid = require(packages.Maid)
task = require(packages.Task)

maid = maid.new()
instance_newindex = rawLib.instance_newindex

Iris = irisLib.Init(coreGui)
;(Iris :: any).TextDisabled = function(args: { string })
	local text = args[1] or ""
	Iris.Text({ text, false, Color3.fromRGB(150, 150, 150) })
end

local function textDisabled(text: string)
	Iris.Text({ text, false, Color3.fromRGB(150, 150, 150) })
end

local hue = 208 / 360
local accentLight = Color3.fromHSV(hue, 204 / 255, 250 / 255)
local accentDark = Color3.fromHSV(hue, 214 / 255, 188 / 255)

Iris.UpdateGlobalConfig({
	ItemSpacing = Vector2.new(8, 6),
	ItemInnerSpacing = Vector2.new(6, 4),
	FramePadding = Vector2.new(6, 4),

	TitleBgColor = Color3.fromRGB(18, 22, 28),
	TitleBgActiveColor = accentDark,
	WindowBgColor = Color3.fromRGB(22, 25, 32),
	WindowBgTransparency = 0.02,

	FrameBgColor = Color3.fromRGB(30, 36, 46),
	FrameBgHoveredColor = Color3.fromRGB(38, 48, 62),
	FrameBgActiveColor = accentDark,

	ButtonColor = Color3.fromRGB(42, 68, 102),
	ButtonHoveredColor = Color3.fromRGB(56, 92, 138),
	ButtonActiveColor = accentLight,

	HeaderColor = Color3.fromRGB(35, 45, 60),
	HeaderHoveredColor = Color3.fromRGB(48, 64, 86),
	HeaderActiveColor = accentDark,

	TabColor = Color3.fromRGB(26, 33, 44),
	TabHoveredColor = Color3.fromRGB(42, 58, 80),
	TabActiveColor = Color3.fromRGB(46, 76, 116),

	SeparatorColor = Color3.fromRGB(55, 65, 80),
	BorderColor = Color3.fromRGB(60, 72, 90),
})

local windowSize = Iris.State(Vector2.new(460, 420))
local isWindowVisible = Iris.State(false)

methodState = Iris.State("")
getActiveMethod()
local modeState = Iris.State("Insert")
local presetState = Iris.State("Advanced Module")
local assetIdState = Iris.State(1234567890)
local assetVersionState = Iris.State(0)

const minCapabilities = SecurityCapabilities.new()

Iris:Connect(function()
	if not isWindowVisible.value then
		return
	end

	mode = modeState.value

	Iris.Window({ "Sensation Utilities", false, false, false, false }, { size = windowSize, isOpened = isWindowVisible })
	do
		local currentSelection = selection:Get()
		local selCount = #currentSelection
		Iris.SameLine()
		do
			if selCount == 0 then
				textDisabled("Selection: None (select objects in Explorer)")
			elseif selCount == 1 then
				Iris.Text({ `Selection: "{currentSelection[1].Name}" [{currentSelection[1].ClassName}]` })
			else
				Iris.Text({ `Selection: {selCount} objects ("{currentSelection[1].Name}", ...)` })
			end
		end
		Iris.End()

		Iris.Separator()

		Iris.TabBar()
		do
			Iris.Tab({ "Module" })
			do
				Iris.CollapsingHeader({ "Bypass" })
				do
					local activeMethod = getActiveMethod()
					local methodCount = 0
					for _ in methods do
						methodCount += 1
					end

					if methodCount > 1 then
						Iris.Combo({ "Method" }, { index = methodState })
						do
							for methodName in methods do
								Iris.Selectable({ methodName, methodName }, { index = methodState })
							end
						end
						Iris.End()
					elseif methodCount == 1 and activeMethod then
						Iris.Text({ `Method: {activeMethod.Name}` })
					else
						textDisabled("No methods loaded")
					end

					Iris.Combo({ "Mode" }, { index = modeState })
					do
						Iris.Selectable({ "Insert", "Insert" }, { index = modeState })
						Iris.Selectable({ "Append", "Append" }, { index = modeState })
					end
					Iris.End()

					Iris.SameLine()
					do
						if Iris.Button({ "Bypass" }).clicked() then
							local selected = selection:Get()
							if #selected == 0 then
								println("Nothing is selected to bypass. Skipping...")
							else
								if modeState.value == "Insert" then
									for _, value in selected do
										if value:IsA("ModuleScript") then
											insertAsync(value)
										end
									end
								elseif modeState.value == "Append" then
									for _, value in selected do
										if value:IsA("ModuleScript") then
											appendAsync(value)
										end
									end
								end
							end
						end

						if Iris.Button({ "Unbypass" }).clicked() then
							local selected = selection:Get()
							if #selected == 0 then
								println("Nothing is selected to unbypass. Skipping...")
							else
								for _, value in selected do
									if value:IsA("ModuleScript") then
										extractAsync(value)
									end
								end
							end
						end
					end
					Iris.End()
				end
				Iris.End()

				Iris.CollapsingHeader({ "Sandbox" })
				do
					textDisabled("Toggle SecurityCapabilities and sandboxing flags")
					Iris.SameLine()
					do
						if Iris.Button({ "Sandbox" }).clicked() then
							local selected = selection:Get()
							if #selected == 0 then
								println("Nothing is selected to sandbox. Skipping...")
							else
								for _, value: Instance in selected do
									pcall(instance_newindex, value, "Capabilities", minCapabilities)
									pcall(instance_newindex, value, "Sandboxed", true)
									for _, object: Instance in value:GetDescendants() do
										pcall(instance_newindex, object, "Capabilities", minCapabilities)
										pcall(instance_newindex, object, "Sandboxed", true)
									end
								end
								println(`Sandboxed {#selected} object(s).`)
							end
						end

						if Iris.Button({ "Unsandbox" }).clicked() then
							local selected = selection:Get()
							if #selected == 0 then
								println("Nothing is selected to unsandbox. Skipping...")
							else
								for _, value: Instance in selected do
									for _, securityCapability in Enum.SecurityCapability:GetEnumItems() do
										pcall(instance_newindex, value, "Capabilities", value.Capabilities:Add(securityCapability))
									end
									pcall(instance_newindex, value, "Sandboxed", false)
									for _, object: Instance in value:GetDescendants() do
										for _, securityCapability in Enum.SecurityCapability:GetEnumItems() do
											pcall(instance_newindex, object, "Capabilities", value.Capabilities:Add(securityCapability))
										end
										pcall(instance_newindex, object, "Sandboxed", false)
									end
								end
								println(`Unsandboxed {#selected} object(s).`)
							end
						end
					end
					Iris.End()
				end
				Iris.End()

				Iris.CollapsingHeader({ "Cleaners" })
				do
					textDisabled("Clear broken or private SoundId references on unloaded sounds")
					if Iris.Button({ "Remove Private AssetIds" }).clicked() then
						local selected = selection:Get()
						if #selected == 0 then
							println("Nothing is selected to clean. Skipping...")
						else
							local cleaned = 0
							for _, value: Instance in selected do
								if value:IsA("Sound") then
									if value.TimeLength == 0 and value.IsLoaded == false then
										value.SoundId = ""
										cleaned += 1
									end
								end
								for _, object: Sound in value:QueryDescendants("Sound[TimeLength = 0][IsLoaded = false]") do
									object.SoundId = ""
									cleaned += 1
								end
							end
							println(`Cleaned {cleaned} sound instance(s).`)
						end
					end
				end
				Iris.End()

				Iris.CollapsingHeader({ "Presets" })
				do
					Iris.Combo({ "Preset" }, { index = presetState })
					do
						Iris.Selectable({ "Advanced Module", "Advanced Module" }, { index = presetState })
						Iris.Selectable({ "Basic Module", "Basic Module" }, { index = presetState })
					end
					Iris.End()

					if Iris.Button({ "Insert Preset" }).clicked() then
						local selected = selection:Get()
						if #selected == 0 then
							println("Nothing is selected to insert the preset into. Skipping...")
						else
							local source = if presetState.value == "Advanced Module"
								then advancedModuleSource
								elseif presetState.value == "Basic Module" then basicModuleSource
								else "-- Invalid Preset"

							for _, value: Instance in selected do
								createAsync("ModuleScript", {
									Parent = value,
									Name = "MainModule",
									Source = source,
								})
							end
							println(`Inserted {presetState.value} into {#selected} object(s).`)
						end
					end
				end
				Iris.End()
			end
			Iris.End()

			Iris.Tab({ "Marketplace" })
			do
				Iris.CollapsingHeader({ "Insert Asset" })
				do
					Iris.InputNum({ "Asset ID", 1, 0, nil, "%d" }, { number = assetIdState })
					Iris.InputNum({ "Version", 1, 0, nil, "%d" }, { number = assetVersionState })

					Iris.SameLine()
					do
						if Iris.Button({ "Insert Version" }).clicked() then
							local selected = selection:Get()
							if #selected == 0 then
								println("Nothing is selected to insert the asset into. Skipping...")
							else
								local id = math.floor(assetIdState.value)
								local version = math.floor(assetVersionState.value)
								local success, objects = pcall(game.GetObjects, game, `https://assetdelivery.roblox.com/v1/asset/?id={id}&version={version}`)
								if success and objects then
									for _, value: Instance in selected do
										for _, object in objects do
											object:Clone().Parent = value
										end
									end
									println(`Inserted asset {id} (v{version}) into {#selected} object(s).`)
								else
									warnln(`Failed to fetch asset {id}: {tostring(objects)}`)
								end
							end
						end

						if Iris.Button({ "Insert Latest" }).clicked() then
							local selected = selection:Get()
							if #selected == 0 then
								println("Nothing is selected to insert the asset into. Skipping...")
							else
								local id = math.floor(assetIdState.value)
								local success, objects = pcall(game.GetObjects, game, `https://assetdelivery.roblox.com/v1/asset/?id={id}`)
								if success and objects then
									for _, value: Instance in selected do
										for _, object in objects do
											object:Clone().Parent = value
										end
									end
									println(`Inserted latest version of asset {id} into {#selected} object(s).`)
								else
									warnln(`Failed to fetch asset {id}: {tostring(objects)}`)
								end
							end
						end
					end
					Iris.End()
				end
				Iris.End()

				Iris.CollapsingHeader({ "Upload & Export" })
				do
					textDisabled("Publish or save selected models & assets")

					local selected = selection:Get()
					if #selected == 0 then
						textDisabled("Target: No selection")
					elseif #selected == 1 then
						Iris.Text({ `Target: "{selected[1].Name}" ({selected[1].ClassName})` })
					else
						Iris.Text({ `Target: {#selected} objects ("{selected[1].Name}", ...)` })
					end

					Iris.SameLine()
					do
						if Iris.Button({ "Upload to Roblox" }).clicked() then
							local currentSelected = selection:Get()
							if #currentSelected == 0 then
								println("Nothing is selected to upload. Select an object in Explorer first.")
							else
								local success, err = pcall(function()
									plugin:SaveSelectedToRoblox()
								end)
								if success then
									println(`Opened Roblox upload prompt for "{currentSelected[1].Name}".`)
								else
									warnln(`Failed to open upload prompt: {tostring(err)}`)
								end
							end
						end

						if Iris.Button({ "Save to File (.rbxm)" }).clicked() then
							local currentSelected = selection:Get()
							if #currentSelected == 0 then
								println("Nothing is selected to save. Select an object in Explorer first.")
							else
								local suggestedName = currentSelected[1].Name .. ".rbxm"
								local success, err = pcall(function()
									plugin:PromptSaveSelection(suggestedName)
								end)
								if success then
									println(`Opened file save prompt for "{currentSelected[1].Name}".`)
								else
									warnln(`Failed to open save prompt: {tostring(err)}`)
								end
							end
						end
					end
					Iris.End()
				end
				Iris.End()
			end
			Iris.End()

			Iris.Tab({ "Studio" })
			do
				Iris.CollapsingHeader({ "Character Spawners" })
				do
					textDisabled("Spawn rigged StarterCharacter model into StarterPlayer")
					Iris.SameLine()
					do
						if Iris.Button({ "Spawn R6" }).clicked() then
							local humanoidDescription: HumanoidDescription = players:GetHumanoidDescriptionFromUserIdAsync(4907137312)
								or Instance.new("HumanoidDescription")
							local model: Model = players:CreateHumanoidModelFromDescriptionAsync(humanoidDescription, Enum.HumanoidRigType.R6)
							model:PivotTo(CFrame.new(workspace.InsertPoint))
							model.Name = "StarterCharacter"
							model.Parent = starterPlayer
							println("Spawned R6 StarterCharacter.")
						end

						if Iris.Button({ "Spawn R15" }).clicked() then
							local humanoidDescription: HumanoidDescription = players:GetHumanoidDescriptionFromUserIdAsync(4907137312)
								or Instance.new("HumanoidDescription")
							local model: Model = players:CreateHumanoidModelFromDescriptionAsync(humanoidDescription, Enum.HumanoidRigType.R15)
							model:PivotTo(CFrame.new(workspace.InsertPoint))
							model.Name = "StarterCharacter"
							model.Parent = starterPlayer
							println("Spawned R15 StarterCharacter.")
						end
					end
					Iris.End()
				end
				Iris.End()
			end
			Iris.End()
		end
		Iris.End()
	end
	Iris.End()
end)

maid:Add(button.Click:Connect(function()
	isWindowVisible:set(not isWindowVisible.value)
end))

plugin.Unloading:Connect(function()
	println("Closing plugin...")
	Iris.Shutdown()
	maid:Destroy()
	println("Closed plugin.")
end)

println("Loaded.")
