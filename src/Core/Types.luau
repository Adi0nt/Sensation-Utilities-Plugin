--!strict
--- Shared types for the utility layer. Nothing in `Core` depends on the UI framework.

export type Level = "success" | "info" | "warning" | "error"

--- The outcome of a utility operation. The UI shows `message` in the status area, `Core` also writes it to Output.
export type Result = {
	ok: boolean,
	level: Level,
	message: string,
	count: number?,
}

export type BypassMode = "Insert" | "Append"
export type PresetName = "Advanced Module" | "Basic Module"
export type RigType = "R6" | "R15"

--- Where operations get their side-effecting dependencies from. Everything is injected so the UI never has to
--- reach into globals and the operations stay testable.
export type Env = {
	plugin: Plugin,
	selection: Selection,
	history: History,
	log: Log,
	methods: MethodStore,
	--- Raw `Instance.__newindex` (from the RawLib package). Used for property writes that must bypass protections.
	newIndex: (instance: Instance, property: string, value: any) -> (),
}

export type Log = {
	info: (message: string) -> (),
	warn: (message: string) -> (),
}

export type History = {
	--- Runs `fn` inside one Studio undo step (best effort). Re-raises if `fn` throws, after cancelling the recording.
	record: (self: History, name: string, fn: () -> ()) -> (),
}

export type MethodStore = {
	set: (self: MethodStore, containers: { [string]: Instance }) -> (),
	names: (self: MethodStore) -> { string },
	get: (self: MethodStore, name: string) -> Instance?,
	resolve: (self: MethodStore, name: string?) -> (string?, Instance?),
}

return {}
