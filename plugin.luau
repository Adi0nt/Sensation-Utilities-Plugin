local players = game:GetService("Players")
local starterPlayer = game:GetService("StarterPlayer")
local selection = game:GetService("Selection")
local serverStorage = game:GetService("ServerStorage")
local serializationService = game:GetService("SerializationService")
local httpService = game:GetService("HttpService")

local toolbar = plugin:CreateToolbar("Sensation")

local packages = {}
local methods = {}
local method = "Adiont's Method"

local cryo
local rawLib
local maid
local task
local reGui

local instance_newindex

local function println(output: string)
	print("[Sensation Utilities]: " .. output)
end

--[[
Creates a new Instance with properties and children.
]]
local function createAsync(className: string, properties: { string: any }?, children: { Instance }?)
	local class = Instance.new(className)
	if properties then
		local parent = nil
		for property, value in properties do
			if property == "Parent" or property == "parent" then
				parent = value
				continue
			end
			pcall(instance_newindex, class, property, value)
		end
		if parent then
			pcall(instance_newindex, class, "Parent", parent)
		end
	end
	if children then
		for _, child in children do
			pcall(instance_newindex, child, "Parent", class)
		end
	end
	return class
end

--[[
Clones a Instance with properties and children.
]]
local function cloneAsync(clone: Instance, properties: { string: any }?, children: { Instance }?)
	local class = clone:Clone()
	if properties then
		local parent = nil
		for property, value in properties do
			if property == "Parent" or property == "parent" then
				parent = value
				continue
			end
			pcall(instance_newindex, class, property, value)
		end
		if parent then
			pcall(instance_newindex, class, "Parent", parent)
		end
	end
	if children then
		for _, child in children do
			pcall(instance_newindex, child, "Parent", class)
		end
	end
	return class
end

local function getAsync(...): string
	local success, body = pcall(httpService.GetAsync, httpService, ...)
	while not success do
		success, body = pcall(httpService.GetAsync, httpService, ...)
		if success then
			break
		end
		task.wait(1 / 3)
		println("Buffering.")
		task.wait(1 / 3)
		println("Buffering..")
		task.wait(1 / 3)
		println("Buffering...")
	end
	return body
end

local function deserializeInstancesAsync(...): { Instance }
	return select(2, pcall(serializationService.DeserializeInstancesAsync, serializationService, ...))
end

local function bypassAsync(moduleScript: ModuleScript)
	local container: Folder? = methods[method]
	assert(typeof(container) == "Instance", "Invalid method.")
	println(`Bypassed {moduleScript}`)
	return selection:Set({
		createAsync("ModuleScript", {
			Parent = moduleScript.Parent,
			Name = "MainModule",
			Source = 'local moduleScript=script:FindFirstChildWhichIsA("ModuleScript",true)\nmoduleScript.Parent=nil\nscript:ClearAllChildren()\nmoduleScript.Parent=script\nreturn require(moduleScript)',
		}, { cloneAsync(container:GetChildren()[1], nil, { moduleScript:Clone() }) }),
	})
end

local function extractAsync(moduleScript: ModuleScript)
	local originalModule = moduleScript:FindFirstChildWhichIsA("ModuleScript", true)
	if not originalModule then
		println(`Extracted {moduleScript} from {moduleScript}`)
		return selection:Set({ cloneAsync(moduleScript, { Parent = moduleScript.Parent }) })
	end
	println(`Extracted {originalModule} from {moduleScript}`)
	return selection:Set({ cloneAsync(originalModule, { Parent = moduleScript.Parent }) })
end

local selected

local button =
	toolbar:CreateButton("Sensation Utilities", "Toggles the built-in interface.", Content.fromAssetId(16517502292).Uri)

println("Loading packages...")
local url = "https://github.com/Adi0nt/Sensation-Utilities-Plugin/raw/refs/heads/main/packages.rbxm"
local response = getAsync(url)
local responseBuffer = buffer.fromstring(response)
local _packages = deserializeInstancesAsync(responseBuffer)
for index, value in _packages do
	packages[value.Name] = value
end
println("Loaded packages.")

println("Loading methods...")
local url = "https://github.com/Adi0nt/Sensation-Utilities-Plugin/raw/refs/heads/main/methods.rbxm"
local response = getAsync(url)
local responseBuffer = buffer.fromstring(response)
local _methods = deserializeInstancesAsync(responseBuffer)
for index, value in _methods do
	methods[value.Name] = value
end
println("Loaded methods.")

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
	--TextFont = Enum.Font.SourceSans,
	TextSize = 13,
	Text = accent.White,
	TextDisabled = accent.Gray,
	ErrorText = accent.Red,

	FrameBg = accent.Dark,
	FrameBgTransparency = 0.4,
	FrameBgActive = accent.Light,
	FrameBgTransparencyActive = 0.4,
	FrameRounding = UDim.new(0, 2),

	--// Elements
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

	--// TabSelector
	TabTextPaddingTop = UDim.new(0, 3),
	TabTextPaddingBottom = UDim.new(0, 8),
	TabText = accent.Gray,
	TabBg = accent.Dark,
	TabTextActive = accent.White,
	TabBgActive = accent.Light,
	TabsBarBg = Color3.fromRGB(36, 36, 36),
	TabsBarBgTransparency = 1,
	TabPagePadding = UDim.new(0, 8),

	--// Window
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

local window = reGui
	:TabsWindow({
		Title = "Sensation Utilities",
		Theme = "Sensation",
		Size = UDim2.new(0, 400, 0, 300),
		NoScroll = true,
		Visible = false,
		NoClose = true,
	})
	:Center()
window:SetVisible(false)

local tab = window:CreateTab({
	Name = "Marketplace",
})

local header = tab:CollapsingHeader({ Title = "Marketplace Bypasses" })

header:Combo({
	Label = "Bypass method",
	Selected = "Adiont's Method",
	GetItems = function()
		return methods
	end,
	Callback = function(self, item: string)
		method = item
	end,
})

local bypassModel = true

header:Button({
	Text = "Bypass",
	Callback = function()
		if bypassModel then
			local modalWindow = header:PopupModal({
				Title = "Bypass?",
			}) --> Canvas
			local names = cryo.List.map(selected, function(value, key: number)
				return value.Name, key
			end)
			modalWindow:Label({
				Text = `Are you sure you want to bypass \{{table.concat(names, ", ")}\}?\nThis operation will cause some lag!`,
				TextWrapped = true,
			})
			modalWindow:Separator()
			local checkbox = modalWindow:Checkbox({
				Value = false,
				Label = "Don't ask me next time",
			})

			local Row = modalWindow:Row({
				Expanded = true,
			}) --> Canvas
			Row:Button({
				Text = "Okay",
				Callback = function()
					modalWindow:ClosePopup()
					if checkbox.Value then
						bypassModel = false
					end
					for index, value in selected do
						if not value:IsA("ModuleScript") then
							continue
						end
						bypassAsync(value)
					end
				end,
			})
			Row:Button({
				Text = "Cancel",
				Callback = function()
					modalWindow:ClosePopup()
				end,
			})
		else
			for index, value in selected do
				if not value:IsA("ModuleScript") then
					continue
				end
				bypassAsync(value)
			end
		end
	end,
})

local header = tab:CollapsingHeader({ Title = "Marketplace Utilities" })

header:Button({
	Text = "Extract Original Module From Bypass",
	Callback = function()
		for index, value in selected do
			if not value:IsA("ModuleScript") then
				continue
			end
			extractAsync(value)
		end
	end,
})

local header = tab:CollapsingHeader({ Title = "Marketplace Fixes" })

header:Button({
	Text = "Fix Private Audios",
	Callback = function()
		for _, value: Instance in selected do
			for _, object: Sound in value:QueryDescendants("Sound") do
				if object.TimeLength == 0 and object.IsLoaded == false then
					object.SoundId = ""
				end
			end
		end
	end,
})

local tab = window:CreateTab({
	Name = "Studio",
})

local header = tab:CollapsingHeader({ Title = "Studio Utilities" })

header:Button({
	Text = "Insert R6 StarterCharacter",
	Callback = function()
		local humanoidDescription: HumanoidDescription = players:GetHumanoidDescriptionFromUserId(4907137312)
			or Instance.new("HumanoidDescription")
		local model: Model = players:CreateHumanoidModelFromDescription(humanoidDescription, Enum.HumanoidRigType.R6)
		model:PivotTo(CFrame.new(workspace.InsertPoint))
		model.Name = "StarterCharacter"
		model.Parent = starterPlayer
	end,
})

maid:Add(selection.SelectionChanged:Connect(function()
	selected = selection:Get()
end))

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
