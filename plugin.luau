local players = game:GetService("Players")
local starterPlayer = game:GetService("StarterPlayer")
local selection = game:GetService("Selection")
local serverStorage = game:GetService("ServerStorage")
local serializationService = game:GetService("SerializationService")
local httpService = game:GetService("HttpService")

local packages = {}
local methods = {}
local method = "Adiont's Method"

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
		task.Wait(1)
	end
	return body
end

local function deserializeInstancesAsync(...): { Instance }
	return select(2, pcall(serializationService.DeserializeInstancesAsync, serializationService, ...))
end

local function bypassAsync(moduleScript: ModuleScript)
	local container: Folder? = methods[method]
	assert(typeof(container) == "Instance", "Invalid method.")
	selection:Set({
		createAsync("ModuleScript", {
			Parent = serverStorage,
			Name = "MainModule",
			Source = 'local moduleScript=script:FindFirstChildWhichIsA("ModuleScript",true)\nmoduleScript.Parent=nil\nscript:ClearAllChildren()\nmoduleScript.Parent=script\nreturn require(moduleScript)',
		}, { cloneAsync(container:GetChildren()[1], nil, { moduleScript:Clone() }) }),
	})
end

local toolbar = plugin:CreateToolbar("Sensation")
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

local cryo = require(packages.Cryo)
local rawLib = require(packages.RawLib)
local maid = require(packages.Maid)
local task = require(packages.Task)
local reGui = require(packages.ReGui)(plugin)

local maid = maid.new()
local instance_newindex = rawLib.instance_newindex

local window = reGui
	:TabsWindow({
		Title = "Sensation Utilities",
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

tab:Button({
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
