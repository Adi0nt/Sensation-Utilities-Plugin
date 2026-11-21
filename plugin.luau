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

local hue = 208 / 360
local accentLight = Color3.fromHSV(hue, 204 / 255, 250 / 255)
local accentDark = Color3.fromHSV(hue, 214 / 255, 188 / 255)

Iris.UpdateGlobalConfig({
	TitleBgActiveColor = accentDark,
	FrameBgColor = accentDark,
	FrameBgActiveColor = accentLight,
	ButtonColor = accentLight,
	ButtonHoveredColor = accentLight,
	ButtonActiveColor = accentDark,
	HeaderColor = accentLight,
	HeaderHoveredColor = accentLight,
	HeaderActiveColor = accentDark,
	TabActiveColor = accentLight,
})

local windowSize = Iris.State(Vector2.new(420, 320))
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
						Iris.Combo({ "Bypass method" }, { index = methodState })
						do
							for methodName in methods do
								Iris.Selectable({ methodName, methodName }, { index = methodState })
							end
						end
						Iris.End()
					elseif methodCount == 1 and activeMethod then
						Iris.Text({ `Method: {activeMethod.Name}` })
					else
						Iris.TextDisabled({ "No methods loaded" })
					end

					Iris.Combo({ "Bypass mode" }, { index = modeState })
					do
						Iris.Selectable({ "Insert", "Insert" }, { index = modeState })
						Iris.Selectable({ "Append", "Append" }, { index = modeState })
					end
					Iris.End()

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

				Iris.CollapsingHeader({ "Sandbox" })
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
						end
					end
				end
				Iris.End()

				Iris.CollapsingHeader({ "Content" })
				do
					if Iris.Button({ "Remove Private AssetIds" }).clicked() then
						local selected = selection:Get()
						if #selected == 0 then
							println("Nothing is selected to remove. Skipping...")
						else
							for _, value: Instance in selected do
								if value:IsA("Sound") then
									if value.TimeLength == 0 and value.IsLoaded == false then
										value.SoundId = ""
									end
								end
								for _, object: Sound in value:QueryDescendants("Sound[TimeLength = 0][IsLoaded = false]") do
									object.SoundId = ""
								end
							end
						end
					end
				end
				Iris.End()

				Iris.CollapsingHeader({ "Preset" })
				do
					Iris.Combo({ "Presets" }, { index = presetState })
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
						end
					end
				end
				Iris.End()
			end
			Iris.End()

			Iris.Tab({ "Marketplace" })
			do
				Iris.CollapsingHeader({ "Assets" })
				do
					Iris.InputNum({ "Id", 1, 0, nil, "%d" }, { number = assetIdState })
					Iris.InputNum({ "Version", 1, 0, nil, "%d" }, { number = assetVersionState })

					if Iris.Button({ "Insert" }).clicked() then
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
								println(`Inserted asset {id} (v{version}) into selection.`)
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
								println(`Inserted latest version of asset {id} into selection.`)
							else
								warnln(`Failed to fetch asset {id}: {tostring(objects)}`)
							end
						end
					end
				end
				Iris.End()
			end
			Iris.End()

			Iris.Tab({ "Studio" })
			do
				Iris.CollapsingHeader({ "Utilities" })
				do
					if Iris.Button({ "R6 StarterCharacter" }).clicked() then
						local humanoidDescription: HumanoidDescription = players:GetHumanoidDescriptionFromUserIdAsync(4907137312)
							or Instance.new("HumanoidDescription")
						local model: Model = players:CreateHumanoidModelFromDescriptionAsync(humanoidDescription, Enum.HumanoidRigType.R6)
						model:PivotTo(CFrame.new(workspace.InsertPoint))
						model.Name = "StarterCharacter"
						model.Parent = starterPlayer
					end

					if Iris.Button({ "R15 StarterCharacter" }).clicked() then
						local humanoidDescription: HumanoidDescription = players:GetHumanoidDescriptionFromUserIdAsync(4907137312)
							or Instance.new("HumanoidDescription")
						local model: Model = players:CreateHumanoidModelFromDescriptionAsync(humanoidDescription, Enum.HumanoidRigType.R15)
						model:PivotTo(CFrame.new(workspace.InsertPoint))
						model.Name = "StarterCharacter"
						model.Parent = starterPlayer
					end
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
