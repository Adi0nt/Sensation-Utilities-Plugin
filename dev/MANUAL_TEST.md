# Manual Studio test checklist

These are the things the headless tests cannot prove. Tick each one, and note anything odd (a screenshot of the panel
at a narrow and a wide size helps most).

## Setup

1. In the repo root run `rojo build default.project.json -o ui.rbxm` (only if you changed `src/`).
2. Start a local server from the repo root: `python -m http.server 8000`
3. Move the installed `Plugin.rbxmx` out of the Plugins folder (temporarily), copy `dev/SensationDev.lua` in, and
   restart Studio (or reopen the place). Make sure HTTP requests are allowed.
4. Open a place that has a few ModuleScripts, Sounds and a Model in Workspace. Save a copy first.

## 1. Loading and docking

- [ ] Output shows `Loaded packages.`, `Loaded UI.`, `Loaded N method(s).`, `Loaded.` and **no red errors**.
      (A failure at `Loading UI...` most likely means string `require` of the downloaded modules does not resolve.)
- [ ] One **Sensation Utilities** toolbar button; clicking it opens/closes the panel and the button shows active/inactive.
- [ ] Closing the panel with its own X also un-highlights the button.
- [ ] Dock it left, right, bottom, as a tab; float it; resize it repeatedly. No clipped or overlapping controls.
- [ ] At ~320 px wide: sidebar is icons only, content scrolls, header does not overflow.
- [ ] At ~600 px+: sidebar shows labels; on the Studio page R6/R15 sit side by side; at 900 px+ content stops at ~720 px.
- [ ] Close and reopen the panel five times: no duplicate content, no errors.
- [ ] Restart Studio: the panel reopens where you left it.

## 2. Look and feel

- [ ] The panel's colours match Studio's own panels (Explorer, Properties) in the current theme.
- [ ] Switch Studio's theme (File > Studio Settings > Studio > Theme): the panel rebuilds in the new colours without errors, keeps the page you were on, and everything is readable in both dark and light.
- [ ] The "Ready" text and its dot are vertically centred in the status bar, and level with each other.

- [ ] Fonts look crisp; nothing smaller than the helper text; disabled text is dimmer but readable.
- [ ] Hover and press on buttons, nav items, dropdown rows: short colour change, never laggy.
- [ ] Hover a **disabled** button for ~0.5 s: a tooltip explains why. It is not clipped by the scroll area.
- [ ] Dropdown menu opens under the trigger (flips above near the bottom), scrolls if long, closes on pick or click-away.
- [ ] Typing in the Asset ID field: letters are stripped, error text appears for `0`, Enter triggers Insert Latest.
- [ ] Selecting/deselecting/renaming things in Explorer updates the selection bar immediately.

## 3. Modules

- [ ] Method dropdown lists methods alphabetically; **Reload** keeps your choice.
- [ ] **Bypass** (Insert) on a ModuleScript: bypassed copy appears beside it and becomes the selection.
- [ ] **Bypass** (Append): a `MainModule` appears wrapping the original.
- [ ] **Unbypass** on a bypassed module extracts the original; on a plain one it warns it was copied as-is.
- [ ] **Sandbox** / **Unsandbox** on a model: descendants change too (check `Sandboxed` / `Capabilities`).
- [ ] **Clean Selected Sounds** on a Sound with a broken/private id clears `SoundId` and the panel shows the count.
- [ ] **Insert Preset** (Advanced and Basic) creates `MainModule` with the expected source.
- [ ] Select 11+ ModuleScripts and press Bypass: a confirmation appears; Cancel changes nothing.
- [ ] **Ctrl+Z** after each of the above undoes it in one step (this is the unverified `ChangeHistoryService` part).

## 4. Marketplace

- [ ] Insert Latest with a valid asset ID inserts it into every selected object; a bad ID shows an error, not a stuck spinner.
- [ ] Insert Specific Version inserts that version; a blank/0 version keeps the button disabled.
- [ ] While downloading, buttons show a spinner and a second click does nothing.
- [ ] **Upload to Roblox** opens Studio's upload dialog; **Save to File** opens the save dialog and reports saved/cancelled.

## 5. Studio

- [ ] **Spawn R6** and **Spawn R15** create `StarterPlayer.StarterCharacter`; spawning again asks before adding a second.
- [ ] If the avatar service fails (try offline), the panel shows an error instead of throwing.

## 6. Unload / reload

- [ ] Disable then enable the plugin (Plugins > Manage Plugins): no duplicate toolbar buttons or panels, no errors.
- [ ] Run Play / Run mode: the plugin does not load; return to edit mode and it is back.

## Teardown

Delete `SensationDev.lua` from the Plugins folder and move `Plugin.rbxmx` back.
