--!strict
local players = game:GetService("Players")
local starterPlayer = game:GetService("StarterPlayer")
local selection = game:GetService("Selection")
local serializationService = game:GetService("SerializationService")
local httpService = game:GetService("HttpService")

local toolbar = plugin:CreateToolbar("Sensation")

local packages = {}
local methods = {}
local method: string = "Single Method"
local mode: "Insert" | "Append" = "Insert"

local cryo
local rawLib
local maid
local task
local reGui

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

local function appendAsync(moduleScript: ModuleScript)
	local container = methods[method] :: Folder?
	assert(typeof(container) == "Instance", "Invalid method.")
	println(`Appended {moduleScript.Name}`)
	
	return selection:Set({
		createAsync("ModuleScript", {
			Parent = moduleScript.Parent,
			Name = "MainModule",
			Source = 'local moduleScript=script:FindFirstChildWhichIsA("ModuleScript",true)\nmoduleScript.Parent=nil\nscript:ClearAllChildren()\nmoduleScript.Parent=script\nreturn require(moduleScript)',
		}, { cloneAsync(container:GetChildren()[1], nil, { moduleScript:Clone() }) }),
	})
end

local function insertAsync(moduleScript: ModuleScript)
	local container = methods[method] :: Folder?
	assert(typeof(container) == "Instance", "Invalid method.")
	println(`Inserted {moduleScript.Name}`)
	
	return selection:Set({
		cloneAsync(moduleScript:Clone(), {
			Parent = moduleScript.Parent
		}, container:GetChildren())
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
	for _, value in _methods do
		methods[value.Name] = value
	end
	println("Loaded methods.")
else
	warnln("Critical Error: Methods failed to load.")
end

cryo = require(packages.Cryo)
rawLib = require(packages.RawLib)
maid = require(packages.Maid)
task = require(packages.Task)
reGui = require(packages.ReGui)(plugin)

maid = maid.new()
instance_newindex = rawLib.instance_newindex

local hue = 208 / 360

local accent = {
	Light = Color3.fromHSV(hue, 204 / 255, 250 / 255),
	Dark = Color3.fromHSV(hue, 214 / 255, 188 / 255),
	ExtraDark = Color3.fromHSV(hue, 213 / 255, 120 / 255),
	White = Color3.fromRGB(240, 240, 240),
	Gray = Color3.fromRGB(175, 175, 175),
	Black = Color3.fromRGB(24, 24, 24),
	Yellow = Color3.fromRGB(230, 180, 0),
	Orange = Color3.fromRGB(230, 150, 0),
	Green = Color3.fromRGB(130, 188, 91),
	Red = Color3.fromRGB(255, 69, 69),
}

reGui:DefineTheme("Sensation", {
	AnimationTweenInfo = TweenInfo.new(0.08),
	TextSize = 13,
	Text = accent.White,
	TextDisabled = accent.Gray,
	ErrorText = accent.Red,

	FrameBg = accent.Dark,
	FrameBgTransparency = 0.4,
	FrameBgActive = accent.Light,
	FrameBgTransparencyActive = 0.4,
	FrameRounding = UDim.new(0, 2),

	SliderGrab = accent.Light,
	ButtonsBg = accent.Light,
	CollapsingHeaderBg = accent.Light,
	CollapsingHeaderText = accent.White,
	CheckMark = accent.Light,
	ResizeGrab = accent.Light,
	HeaderBg = accent.Gray,
	HeaderBgTransparency = 0.7,
	HistogramBar = accent.Yellow,
	ProgressBar = accent.Yellow,
	RegionBg = accent.Dark,
	RegionBgTransparency = 0.1,
	Separator = accent.Gray,
	SeparatorTransparency = 0.5,
	ConsoleLineNumbers = accent.White,
	LabelPaddingTop = UDim.new(0, 0),
	LabelPaddingBottom = UDim.new(0, 0),
	MenuBar = accent.ExtraDark,
	MenuBarTransparency = 0.1,
	PopupCanvas = accent.Black,

	TabTextPaddingTop = UDim.new(0, 3),
	TabTextPaddingBottom = UDim.new(0, 8),
	TabText = accent.Gray,
	TabBg = accent.Dark,
	TabTextActive = accent.White,
	TabBgActive = accent.Light,
	TabsBarBg = Color3.fromRGB(36, 36, 36),
	TabsBarBgTransparency = 1,
	TabPagePadding = UDim.new(0, 8),

	ModalWindowDimBg = Color3.fromRGB(230, 230, 230),
	ModalWindowDimTweenInfo = TweenInfo.new(0.2),

	WindowBg = accent.Black,
	WindowBgTransparency = 0.05,

	Border = accent.Gray,
	BorderTransparency = 0.8,
	BorderTransparencyActive = 0.5,

	Title = accent.White,
	TitleAlign = Enum.TextXAlignment.Left,
	TitleBarBg = accent.Black,
	TitleBarTransparency = 0,
	TitleActive = accent.White,
	TitleBarBgActive = accent.Dark,
	TitleBarTransparencyActive = 0.05,
	TitleBarBgCollapsed = Color3.fromRGB(0, 0, 0),
	TitleBarTransparencyCollapsed = 0.6,
})

local window = reGui:TabsWindow({
	Title = "Sensation Utilities",
	Theme = "Sensation",
	Size = UDim2.new(0, 400, 0, 300),
	NoScroll = true,
	Visible = false,
	NoClose = true,
}):Center()

window:SetVisible(false)

local moduleTab = window:CreateTab({
	Name = "Module",
})

local bypassHeader = moduleTab:CollapsingHeader({ Title = "Bypass" })

bypassHeader:Combo({
	Label = "Bypass method",
	Selected = "Single Method",
	GetItems = function()
		return methods
	end,
	Callback = function(self, item: string)
		method = item
	end,
})

bypassHeader:Combo({
	Label = "Bypass mode",
	Selected = "Insert",
	Items = { "Insert", "Append" },
	Callback = function(self, item: string)
		if item == "Insert" or item == "Append" then
			mode = item
		end
	end,
})

bypassHeader:Button({
	Text = "Bypass",
	Callback = function()
		local selected = selection:Get()
		if #selected == 0 then
			return println("Nothing is selected to bypass. Skipping...")
		end

        if mode == "Insert" then
            for _, value in selected do
                if value:IsA("ModuleScript") then
                    insertAsync(value)
                end
            end
        elseif mode == "Append" then
            for _, value in selected do
			    if value:IsA("ModuleScript") then
			    	appendAsync(value)
			    end
		    end
        end
	end,
})

bypassHeader:Button({
	Text = "Unbypass",
	Callback = function()
		local selected = selection:Get()
		if #selected == 0 then
			return println("Nothing is selected to unbypass. Skipping...")
		end
		
		for _, value in selected do
			if value:IsA("ModuleScript") then
				extractAsync(value)
			end
		end
	end,
})

local sandboxHeader = moduleTab:CollapsingHeader({ Title = "Sandbox" })

sandboxHeader:Button({
	Text = "Sandbox",
	Callback = function()
		local selected = selection:Get()
		if #selected == 0 then
			return println("Nothing is selected to sandbox. Skipping...")
		end
		
		for _, value: Instance in selected do
            if value.Sandboxed then
                value.Capabilities = value.Capabilities:Remove(Enum.SecurityCapability.CapabilityControl, Enum.SecurityCapability.LoadOwnedAsset, Enum.SecurityCapability.LoadString, Enum.SecurityCapability.LoadUnownedAsset)
                value.Sandboxed = true
            end
            for _, object: Instance in value:QueryDescendants("[Sandboxed = true]") do
                object.Capabilities = object.Capabilities:Remove(Enum.SecurityCapability.CapabilityControl, Enum.SecurityCapability.LoadOwnedAsset, Enum.SecurityCapability.LoadString, Enum.SecurityCapability.LoadUnownedAsset)
                object.Sandboxed = true
            end
		end
	end,
})

sandboxHeader:Button({
	Text = "Unsandbox",
	Callback = function()
		local selected = selection:Get()
		if #selected == 0 then
			return println("Nothing is selected to unsandbox. Skipping...")
		end
		
		for _, value: Instance in selected do
            if value.Sandboxed then
                value.Capabilities = value.Capabilities:Add(Enum.SecurityCapability.CapabilityControl, Enum.SecurityCapability.LoadOwnedAsset, Enum.SecurityCapability.LoadString, Enum.SecurityCapability.LoadUnownedAsset)
                value.Sandboxed = false
            end
            for _, object: Instance in value:QueryDescendants("[Sandboxed = true]") do
                object.Capabilities = object.Capabilities:Add(Enum.SecurityCapability.CapabilityControl, Enum.SecurityCapability.LoadOwnedAsset, Enum.SecurityCapability.LoadString, Enum.SecurityCapability.LoadUnownedAsset)
                object.Sandboxed = false
            end
		end
	end,
})

local contentHeader = moduleTab:CollapsingHeader({ Title = "Content" })

contentHeader:Button({
	Text = "Remove Private AssetIds",
	Callback = function()
		local selected = selection:Get()
		if #selected == 0 then
			return println("Nothing is selected to remove. Skipping...")
		end
		
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
	end,
})

local presetHeader = moduleTab:CollapsingHeader({ Title = "Preset" })

local preset = "Advanced Module"

bypassHeader:Combo({
	Label = "Presets",
	Selected = "Advanced Module",
	Items = { "Advanced Module", "Basic Module" },
	Callback = function(self, item: string)
		preset = item
	end,
})

presetHeader:Button({
	Text = "Insert Preset",
	Callback = function()
		local selected = selection:Get()
		if #selected == 0 then
			return println("Nothing is selected to insert the preset into. Skipping...")
		end

		local source = if preset == "Advanced Module" then advancedModuleSource elseif preset == "Basic Module" then basicModuleSource else "-- Invalid Preset"
		
		for _, value: Instance in selected do
            createAsync("ModuleScript", {
                Parent = value,
                Name = "MainModule",
                Source = source,
            })
		end
	end,
})

local marketplaceTab = window:CreateTab({
	Name = "Marketplace",
})

local assetsHeader = marketplaceTab:CollapsingHeader({ Title = "Assets" })

local assetId = 1234567890

assetsHeader:InputInt({
    Label = "AssetId",
    Value = 1234567890,
    Callback = function(self, int: number)
       assetId = int
    end,
})

assetsHeader:Button({
    Text = "Insert",
    Callback = function()
        local selected = selection:Get()
		if #selected == 0 then
			return println("Nothing is selected to insert the asset into. Skipping...")
		end
		
		for _, value: Instance in selected do
            for _, object in game:GetObjects(Content.fromAssetId(assetId).Uri) do
                object.Parent = value
            end
		end
    end,
})

local studioTab = window:CreateTab({
	Name = "Studio",
})

local studioHeader = studioTab:CollapsingHeader({ Title = "Utilities" })

studioHeader:Button({
	Text = "R6 StarterCharacter",
	Callback = function()
		local humanoidDescription: HumanoidDescription = players:GetHumanoidDescriptionFromUserIdAsync(4907137312)
			or Instance.new("HumanoidDescription")
		local model: Model = players:CreateHumanoidModelFromDescriptionAsync(humanoidDescription, Enum.HumanoidRigType.R6)
		model:PivotTo(CFrame.new(workspace.InsertPoint))
		model.Name = "StarterCharacter"
		model.Parent = starterPlayer
	end,
})

studioHeader:Button({
	Text = "R15 StarterCharacter",
	Callback = function()
		local humanoidDescription: HumanoidDescription = players:GetHumanoidDescriptionFromUserIdAsync(4907137312)
			or Instance.new("HumanoidDescription")
		local model: Model = players:CreateHumanoidModelFromDescriptionAsync(humanoidDescription, Enum.HumanoidRigType.R15)
		model:PivotTo(CFrame.new(workspace.InsertPoint))
		model.Name = "StarterCharacter"
		model.Parent = starterPlayer
	end,
})

maid:Add(button.Click:Connect(function()
	window:ToggleVisibility()
end))

plugin.Unloading:Connect(function()
	println("Closing plugin...")
	window:Close()
	maid:Destroy()
	println("Closed plugin.")
end)

println("Loaded.")