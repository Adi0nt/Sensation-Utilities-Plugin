# Sensation Utilities Plugin

A Roblox Studio utility plugin for module bypassing, sandboxing, asset insertion and publishing, and StarterCharacter
rigging. The interface is a dockable panel built with the [Flux](https://github.com/kohltastrophe/flux) reactive UI
library.

---

## Features

- **Modules**
  - **Bypass Tools:** pick a bypass method (discovered dynamically from `methods.rbxm`), choose **Insert** or
    **Append**, then **Bypass** or **Unbypass** the selected ModuleScripts. **Reload** fetches the methods again and
    keeps your selected method if it still exists.
  - **Sandbox Controls:** sandbox or unsandbox the selection *and all of its descendants*.
  - **Asset Cleaner:** clears the `SoundId` of unloaded (broken or private) sounds and reports how many it cleaned.
  - **Module Presets:** insert an `Advanced Module` or `Basic Module` `MainModule` into every selected object.
- **Marketplace**
  - **Asset Insertion:** insert an asset by ID into every selected object, either the **latest** version or a
    **specific version**. Inputs are validated before anything is requested.
  - **Publishing & Export:** **Upload to Roblox** and **Save to File (.rbxm)** open Studio's native dialogs for the
    current selection.
- **Studio**
  - **StarterCharacter spawners:** spawn an **R6** or **R15** rig into `StarterPlayer`.

### Using the interface

- Open or close the panel with the **Sensation Utilities** toolbar button. It is a normal Studio dock widget: dock it,
  float it, resize it, hide it and reopen it. Studio remembers where you left it.
- **Navigation** (Modules, Marketplace, Studio) is a sidebar that collapses to icons in a narrow dock.
- The **selection bar** under the header always shows what is selected in Explorer and updates as it changes.
- Every action reports its outcome in the **status strip** at the bottom. Success and info messages fade back to
  *Ready*; warnings and errors stay until you dismiss them. Output-window logging is unchanged.
- Buttons are disabled until what they need exists (a selection, a ModuleScript, a valid asset ID, loaded methods).
  Hover a disabled button to see why.
- Only one action runs at a time, so a slow download cannot be submitted twice.
- Operations that would touch many instances (more than 10 ModuleScripts or targets, or more than 250 instances
  including descendants) ask for confirmation first.
- Each scene change is wrapped in one `ChangeHistoryService` recording (best effort: if Studio cannot start a
  recording the operation still runs), so it should undo as a single step. Uploading and saving to a file leave
  Studio and cannot be undone from here.

> **Behaviour notes.** An asset *version* must be 1 or higher (the old version 0 field default is gone; use **Insert
> Latest** instead). If `StarterPlayer` already contains a `StarterCharacter`, you are asked before a second one is
> added. The cleaner clears sounds that report as not loaded, so let valid audio load first.

---

## Installation

### Method 1: Local Plugin (Recommended & Auto-Updating)

The local plugin automatically fetches the latest updates on Studio startup.

1. **Download the Plugin:**
   * Download [**Plugin.rbxmx**](https://github.com/Adi0nt/Sensation-Utilities-Plugin/releases/latest/download/Plugin.rbxmx) from the latest release (or [loader.luau](https://raw.githubusercontent.com/Adi0nt/Sensation-Utilities-Plugin/main/loader.luau)).
2. **Open the Plugins Folder:**
   * In **Roblox Studio**, navigate to the **Plugins** tab on the top ribbon.
   * Click **Plugins Folder** (folder icon).
3. **Install:**
   * Move the downloaded `Plugin.rbxmx` (or `loader.luau`) into the opened folder.
4. **Restart:**
   * Restart Roblox Studio. You will see the **Sensation Utilities** button in your plugins toolbar.

#### Default Plugin Folder Locations:
* **Windows:** `%LocalAppData%\Roblox\Plugins`
* **macOS:** `~/Documents/Roblox/Plugins`
* **Linux (Wine / Vinegar):** `~/.var/app/io.github.vinegar_hq.Vinegar/data/vinegar/prefixes/studio/drive_c/users/$USER/AppData/Local/Roblox/Plugins`

The installation process is unchanged by the Flux rewrite: the loader still downloads `plugin.luau` from this
repository on every start.

---

### Method 2: Roblox Marketplace

Install directly from the [Roblox Creator Store](https://create.roblox.com/store/asset/74082080143456).

---

## How it works

```
Plugin.rbxmx / loader.luau   tiny loader, unchanged
        │  downloads on every Studio start
        ▼
plugin.luau                  plugin LIFECYCLE only: toolbar button, dock widget, downloads, mount / unmount
        │  downloads
        ├── packages.rbxm    Maid, RawLib (and some unused extras)
        ├── methods.rbxm     the bypass methods
        └── ui.rbxm          Flux + the application (built from src/ and vendor/, see below)
```

`ui.rbxm` is a [Rojo](https://rojo.space) build of:

| Path | Layer | Responsibility |
| --- | --- | --- |
| `src/Core` | **Utility operations** | The bypass, sandbox, cleaner, preset, asset and rig logic. No GUI or UI framework. Every operation returns a result `{ ok, level, message }`. Dependencies (plugin, selection, undo history, method store, raw property writes) are injected. |
| `src/UI/Theme.luau` | **Theme** | Every colour, font size, spacing, radius and motion value. Nothing else hardcodes them. The values follow Caelum's design system (dark theme, Blue accent): chrome, canvas and card surfaces, a 4-pt spacing scale and a 13/14/20 type scale. |
| `src/UI/Components` | **Components** | Button, IconButton, TextInput / NumberInput, Dropdown, SegmentedControl, SectionHeader, Panel, Tooltip, StatusMessage, ConfirmationDialog, SelectionSummary, SidebarItem, LoadingIndicator and the drawn icons. |
| `src/UI/State.luau` | **UI state** | One signal per value (page, selection, method, mode, inputs, status, busy, confirmation) plus computed values: derived selection summary, validation errors, and a *gate* per action that says why it is unavailable. |
| `src/UI/Actions.luau` | **Glue** | Runs an operation: refuses duplicates, shows progress, asks for confirmation, catches errors, reports the result. |
| `src/UI/Pages`, `src/UI/App.luau` | **Pages and shell** | Layout only. |
| `vendor/flux` | **Dependency** | Flux **v0.5.2**, an unmodified copy of upstream `src/`, pinned and bundled (see [`vendor/flux/README.md`](vendor/flux/README.md)). MIT, license kept in `vendor/flux/LICENSE.md` and inside `ui.rbxm`. |

The whole UI is created inside one `Flux.mount` scope. Unloading the plugin destroys that scope, which tears down every
instance, connection, timer and reaction it owns.

---

## Development

Tools: [Rojo](https://rojo.space) (build), [Lune](https://lune-org.github.io/docs) (tests), and optionally
[luau-lsp](https://github.com/JohnnyMorganz/luau-lsp) (type checking).

**Rebuild `ui.rbxm`** after changing anything in `src/` or `vendor/`, and commit it together with `plugin.luau` (the
live plugin always downloads both from `main`):

```powershell
rojo build default.project.json -o ui.rbxm
```

**Pure-logic tests** (validation, formatting, method ordering, preset sources unchanged from the previous plugin):

```powershell
lune run tests/run
```

**Headless UI tests.** These mount the real `App`, the real `Core` operations and the real Flux on
[`sert`](https://github.com/kohltastrophe/sert), the headless Roblox-engine emulator Flux's own tests use. They click
buttons, hover, open dropdowns, check gating, confirmation, duplicate-submission protection, undo recording, status
fading and clean unmounting, then measure the layout at dock sizes from 320 px to 1400 px.

```powershell
lune run tests/smoke/prepare   # once, and after editing src/: mirrors the tree, downloads sert (SHA-256 verified)
lune run tests/smoke/app
lune run tests/smoke/layout
```

**Type checking** needs the new Luau type solver because Flux uses newer syntax:

```powershell
rojo sourcemap default.project.json -o sourcemap.json
luau-lsp analyze --flag:LuauSolverV2=true --definitions=globalTypes.d.luau --sourcemap=sourcemap.json --base-luaurc=.luaurc src plugin.luau
```

(`globalTypes.d.luau` is the Roblox API definition file from the luau-lsp repository.)

**Updating Flux:** replace `vendor/flux/src` with the new upstream `src/` and update `vendor/flux/README.md`, run the
tests, rebuild `ui.rbxm`.

> `plugin.luau` loads `packages.rbxm`, `methods.rbxm` and `ui.rbxm` from the `main` branch on GitHub. To try a branch,
> temporarily change `RAW_MAIN` / `RAW_FRESH` at the top of `plugin.luau`.

---

## Troubleshooting

* **No plugin icon in the Plugins tab:**
  * Ensure the file was placed in the correct `Plugins` folder and restart all open Roblox Studio instances.
* **HTTP / GetAsync Errors:**
  * Ensure your network permits connections to GitHub and Roblox Studio has internet access enabled (the plugin needs
    `HttpService` access to download its packages).
* **The panel opens but Bypass is disabled / "No bypass methods are loaded":**
  * The methods download failed. Check your connection and press **Reload** in *Bypass Tools*.
* **Require / Loading Errors:**
  * Ensure you are using the official [Plugin.rbxmx](https://github.com/Adi0nt/Sensation-Utilities-Plugin/releases/latest/download/Plugin.rbxmx) loader.

---

## License and credits

Sensation Utilities is MIT licensed, see [`LICENSE`](LICENSE).

The interface uses [Flux](https://github.com/kohltastrophe/flux) by Kohl, MIT licensed
([`vendor/flux/LICENSE.md`](vendor/flux/LICENSE.md)). Headless tests use
[sert](https://github.com/kohltastrophe/sert), also by Kohl, downloaded on demand and not redistributed here.
