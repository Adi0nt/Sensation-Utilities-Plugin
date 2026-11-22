--!strict
--- Sandbox / Unsandbox. The capability logic is ported unchanged from the previous plugin.

local Common = require("./Common")
local Result = require("./Result")
local Types = require("./Types")

local minCapabilities = SecurityCapabilities.new()

local Sandbox = {}

local function plural(count: number, word: string): string
	return if count == 1 then word else word .. "s"
end

local function objectsLabel(count: number, descendants: number): string
	if descendants > 0 then
		return `{count} {plural(count, "object")} and {descendants} {plural(descendants, "descendant")}`
	end
	return `{count} {plural(count, "object")}`
end

--- Number of instances an operation on `instances` touches (the instances plus all of their descendants).
function Sandbox.affectedCount(instances: { Instance }): number
	return #instances + Common.countDescendants(instances)
end

function Sandbox.sandbox(env: Types.Env): Types.Result
	local selected = Common.selected(env)
	if #selected == 0 then
		env.log.info("Nothing is selected to sandbox. Skipping...")
		return Result.skipped("Nothing is selected to sandbox.")
	end

	local newIndex = env.newIndex
	local descendants = 0
	env.history:record("Sensation: Sandbox", function()
		for _, value: Instance in selected do
			pcall(newIndex, value, "Capabilities", minCapabilities)
			pcall(newIndex, value, "Sandboxed", true)
			for _, object: Instance in value:GetDescendants() do
				descendants += 1
				pcall(newIndex, object, "Capabilities", minCapabilities)
				pcall(newIndex, object, "Sandboxed", true)
			end
		end
	end)

	env.log.info(`Sandboxed {#selected} object(s).`)
	return Result.success(`Sandboxed {objectsLabel(#selected, descendants)}.`, #selected + descendants)
end

function Sandbox.unsandbox(env: Types.Env): Types.Result
	local selected = Common.selected(env)
	if #selected == 0 then
		env.log.info("Nothing is selected to unsandbox. Skipping...")
		return Result.skipped("Nothing is selected to unsandbox.")
	end

	local newIndex = env.newIndex
	local descendants = 0
	env.history:record("Sensation: Unsandbox", function()
		for _, value: Instance in selected do
			for _, securityCapability in Enum.SecurityCapability:GetEnumItems() do
				pcall(newIndex, value, "Capabilities", value.Capabilities:Add(securityCapability))
			end
			pcall(newIndex, value, "Sandboxed", false)
			for _, object: Instance in value:GetDescendants() do
				descendants += 1
				for _, securityCapability in Enum.SecurityCapability:GetEnumItems() do
					pcall(newIndex, object, "Capabilities", value.Capabilities:Add(securityCapability))
				end
				pcall(newIndex, object, "Sandboxed", false)
			end
		end
	end)

	env.log.info(`Unsandboxed {#selected} object(s).`)
	return Result.success(`Unsandboxed {objectsLabel(#selected, descendants)}.`, #selected + descendants)
end

return Sandbox
