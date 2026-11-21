# Sensation Utilities Plugin

A comprehensive Roblox Studio utility plugin featuring module bypass tools, sandboxing, asset inspection and insertion, and character rigging utilities — powered by an immediate-mode [Iris](https://github.com/SirMallard/Iris) interface.

---

## Features

- **Module Utilities:**
  - **Dynamic Bypass:** Automatically detects and loads available bypass methods from `methods.rbxm` without needing code changes. Supports both **Insert** and **Append** modes as well as clean **Unbypass** extraction.
  - **Sandboxing:** Toggle custom `SecurityCapabilities` and sandboxing flags across selected instances and their descendants.
  - **Asset Cleaner:** Remove broken or private `SoundId` references from unloaded sounds with a single click.
  - **Preset Inserter:** Quickly insert predefined `MainModule` presets (`Advanced Module` or `Basic Module`).

- **Marketplace Utilities:**
  - **Asset Inserter:** Load and parent any Roblox asset directly into selected instances by **Asset ID** and **Version**.
  - **Insert Latest:** Instantly fetch and insert the latest available version of an asset into your selection with safe multi-selection cloning.

- **Studio Utilities:**
  - **StarterCharacter Spawners:** One-click spawn for standard R6 and R15 `StarterCharacter` models placed in `StarterPlayer`.

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

---

### Method 2: Roblox Marketplace

Install directly from the [Roblox Creator Store](https://create.roblox.com/store/asset/74082080143456).

---

## Troubleshooting

* **No plugin icon in the Plugins tab:**
  * Ensure the file was placed in the correct `Plugins` folder and restart all open Roblox Studio instances.
* **HTTP / GetAsync Errors:**
  * Ensure your network permits connections to GitHub and Roblox Studio has internet access enabled.
* **Require / Loading Errors:**
  * Ensure you are using the official [Plugin.rbxmx](https://github.com/Adi0nt/Sensation-Utilities-Plugin/releases/latest/download/Plugin.rbxmx) loader.
