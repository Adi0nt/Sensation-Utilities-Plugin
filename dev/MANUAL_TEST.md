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

- [ ] The sidebar footer shows the version, and its sidebar-toggle button collapses the sidebar to the icon rail and opens it again (the choice sticks while you resize); in the rail only the button shows. The footer and the status bar are the same height, so their top lines run level across the bottom of the window, and the status (dot and message) appears once, in the status bar.
- [ ] Nav markers: select a few ModuleScripts and the Modules item shows their count (a dot on the icon in the rail); start an operation (e.g. Reload, or Marketplace "Latest") and that page's nav item shows a spinner until it finishes.
- [ ] There is no top bar: the sidebar and the page start right under Studio's title bar. The selection is an Explorer-style chip at the far right of the status bar: the same class icon Explorer shows plus the name, on the selection blue (a neutral pill saying "No selection" when nothing is selected). It updates as you click in Explorer, hovering it shows `name · class`, and a long name truncates with an ellipsis without squeezing the status message. The icon matches Explorer's for several classes (Script, Part, Folder, ModuleScript).
- [ ] The panel's colours match Studio's own panels (Explorer, Properties) in the current theme.
- [ ] Switch Studio's theme (File > Studio Settings > Studio > Theme): the panel rebuilds in the new colours without errors, keeps the page you were on, and everything is readable in both dark and light.
- [ ] The "Ready" text and its dot are vertically centred in the status bar, and level with each other.

- [ ] Fonts look crisp; nothing smaller than the helper text; disabled text is dimmer but readable.
- [ ] Switching pages fades the new page in (about 0.2 s) with no jump in layout or scroll position, and focus rings on inputs at the page edge are not clipped during or after the fade.
- [ ] Hover and press on buttons, nav items, dropdown rows: short colour change, never laggy.
- [ ] Hover a **disabled** button for ~0.5 s: a tooltip explains why. It is not clipped by the scroll area.
- [ ] Dropdown menu opens under the trigger (flips above near the bottom), scrolls if long, closes on pick or click-away.
- [ ] Typing in the Asset ID field: letters are stripped, error text appears for `0`, Enter triggers the Insert button.
- [ ] Selecting/deselecting/renaming things in Explorer updates the selection bar immediately.

## 3. Modules

- [ ] Method dropdown lists methods alphabetically; **Reload** keeps your choice.
- [ ] **Bypass** (Insert) on a ModuleScript: bypassed copy appears beside it and becomes the selection.
- [ ] **Bypass** (Append): a `MainModule` appears wrapping the original.
- [ ] **Unbypass** on a bypassed module extracts the original; on a plain one it warns it was copied as-is.
- [ ] **Sandbox** / **Unsandbox** on a model: descendants change too (check `Sandboxed` / `Capabilities`).
- [ ] **Clean Unloaded Sounds** on a Sound with a broken/private id clears `SoundId` and the panel shows the count.
- [ ] **Scan Selection** on a model with some broken asset ids (a MeshPart, a Decal, a Sound): the broken ones are listed with where they are used, working ones are not, and nothing has changed yet. The status line says how many could not be loaded and how many could not be checked.
- [ ] Untick one asset, press **Clean Selected**: only the ticked ones lose their id, they leave the list, and **Ctrl+Z** brings them back in one step.
- [ ] Tick "Remove the instances instead of clearing the property": the button becomes **Remove Selected**, a confirmation names how many instances (and the status bar says it is waiting for you); Cancel changes nothing, Remove deletes them, and Ctrl+Z restores them.
- [ ] Scan something that only uses assets you own and can load: nothing is listed. (A plugin cannot ask Roblox whether *other* people can load an asset, only whether Studio can.)
- [ ] **Insert Preset** (Advanced and Basic) creates `MainModule` with the expected source. Edit a script in `presets.rbxm` (or push a new one), press **Reload** in Module Presets: the list and description update without restarting Studio.
- [ ] Select 11+ ModuleScripts and press Bypass: a confirmation appears; Cancel changes nothing.
- [ ] **Ctrl+Z** after each of the above undoes it in one step (this is the unverified `ChangeHistoryService` part).

## 4. Marketplace

- [ ] With Version set to Latest, the single button reads "Insert latest version", no version field shows, and it inserts the asset into every selected object; a bad ID shows an error, not a stuck spinner.
- [ ] Choosing Specific version shows a version field and the button reads "Insert version N" as you type; a blank/0 version keeps it disabled, and switching back to Latest ignores the typed number.
- [ ] While downloading, buttons show a spinner and a second click does nothing.
- [ ] **Upload to Roblox** opens Studio's upload dialog; **Save to File** opens the save dialog and reports saved/cancelled.

## 5. Studio

- [ ] **Spawn R6** and **Spawn R15** create `StarterPlayer.StarterCharacter`; spawning again asks before adding a second.
- [ ] If the avatar service fails (try offline), the panel shows an error instead of throwing.

## 6. Window mode (docked or floating)

- [ ] **Settings** is the last item in the sidebar. Its Window control shows **Docked** selected, with a note about docking.
- [ ] Pick **Floating window**: the dock widget closes and a window opens over the 3D view in the same moment (it stays open if the panel was open), on the Settings page you were on. The note now describes the floating window.
- [ ] The floating window has a title bar with the name and a close button. Drag the title bar to move it; drag the left edge, the bottom edge or the bottom-right corner to resize it (it stops at about 320 x 400 and at the screen). The sidebar collapses to the icon rail when it is narrow, as in the dock.
- [ ] Drag it mostly off the screen: the title bar and part of the window stay reachable. Release the mouse button outside the Studio window mid-drag: the window does not stay stuck to the cursor.
- [ ] The toolbar button shows and hides the floating window and lights up while it is open; the close button hides it and un-highlights the button.
- [ ] Restart Studio: the plugin opens in floating mode, in the same place and size, open or closed as you left it. No dock widget is created or shown.
- [ ] Switch Studio's theme while the window is open: its title bar and the panel both follow it, and the window stays where it was.
- [ ] Press a button that takes a moment (Marketplace insert, or Reload): while it runs the Window control is disabled.
- [ ] Pick **Docked** again: the floating window disappears, the dock widget returns where Studio last had it, and the page is kept.
- [ ] Disable then enable the plugin while floating: one window, no leftovers in CoreGui.

## 7. Unload / reload

- [ ] Disable then enable the plugin (Plugins > Manage Plugins): no duplicate toolbar buttons or panels, no errors.
- [ ] Run Play / Run mode: the plugin does not load; return to edit mode and it is back.

## Teardown

Delete `SensationDev.lua` from the Plugins folder and move `Plugin.rbxmx` back.
