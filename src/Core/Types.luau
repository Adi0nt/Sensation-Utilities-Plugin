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
--- A preset is whatever `presets.rbxm` contains, so its name is free text.
export type PresetName = string
export type RigType = "R6" | "R15"

--- Where operations get their side-effecting dependencies from. Everything is injected so the UI never has to
--- reach into globals and the operations stay testable.
export type Env = {
	plugin: Plugin,
	selection: Selection,
	history: History,
	log: Log,
	methods: MethodStore,
	--- The module presets loaded from `presets.rbxm`.
	presets: PresetStore,
	--- `ContentProvider`: the private-asset scan asks it which asset references fail to load.
	contentProvider: ContentLoader,
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

--- One place that holds an asset id: this property of this instance.
export type AssetReference = { instance: Instance, property: string }

--- An asset the scan could not load, with everything in the selection that refers to it.
export type BrokenAsset = {
	--- The id as the engine was asked for it ("rbxassetid://123").
	content: string,
	id: number,
	references: { AssetReference },
}

--- What a private-asset scan found. `broken` is ordered most-used first.
export type ScanReport = {
	broken: { BrokenAsset },
	--- Instances looked at (the selection and everything below it).
	scanned: number,
	--- Asset references found in them, and how many distinct assets those are.
	references: number,
	assets: number,
	--- Assets that never gave a verdict (the request timed out), so they are not offered for cleaning.
	unverified: number,
}

--- A loaded preset: the source of the `MainModule` it creates and a one-line description for the UI.
export type Preset = { source: string, description: string }

export type PresetStore = {
	set: (self: PresetStore, presets: { [string]: Preset }) -> (),
	names: (self: PresetStore) -> { string },
	has: (self: PresetStore, name: string) -> boolean,
	source: (self: PresetStore, name: string) -> string?,
	description: (self: PresetStore, name: string) -> string,
}

--- The one `ContentProvider` method the scan uses (a plain type so tests can pass a fake).
export type ContentLoader = {
	PreloadAsync: (self: any, contentIdList: { any }, callback: ((contentId: string, status: any) -> ())?) -> (),
}

return {}
