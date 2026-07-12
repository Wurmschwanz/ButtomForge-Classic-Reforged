ButtonForge Classic v0.3.21 Alpha

For Turtle WoW / Vanilla 1.12.

Basic commands:
/bf new       Create a new bar
/bf config    Toggle Configure Mode
/bf bg        Toggle active bar background
/bf bg all    Toggle all bar backgrounds
/bf cols 6    Set columns
/bf rows 2    Set rows
/bf scale 1.2 Set scale
/bf lock      Lock active bar
/bf unlock    Unlock active bar
/bf delete    Delete active bar
/bf reset     Reset settings

v0.3.21:
- Centralized visible UI strings in Locale.lua.
- English cleanup for bar controls and chat messages.

Stable base:
- Multiple bars, drag/drop, tooltips, stack counts, configure mode, minimap button.
- Right-click menu remains disabled; use minimap button and bar controls.


v0.4.9
- Fixed normal-mode drag & drop by showing temporary drop slots on bar hover.
- Blocked BUTTON1/BUTTON2 keybind assignment for safety.

Version 0.4.15 swap timing stability.


v0.4.15: Internal slot-to-slot dragging now swaps ButtonForge ActionSlot references instead of using PickupAction/PlaceAction.

0.4.19: Real per-character SavedVariables for bars, settings and keybinds.


0.4.24: Safe runtime keybindings. ButtonForge no longer calls SaveBindings(). Keybinds are stored in addon SavedVariables and applied at login only.
