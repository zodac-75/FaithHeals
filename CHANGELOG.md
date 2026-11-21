# FaithHeals 0.3.4-beta

### New
- **Follow** as a bar action (Spells tab > Actions): bind it to a click or a key, and it follows the group member under the mouse.

# FaithHeals 0.3.3-beta

### Fixed
- **Incoming heals** rewritten. In WoW Forever the game hides incoming-heal amounts from addons, so FaithHeals now asks the game's own heal prediction calculator, which also stops the green bar at full health. Errors here can no longer stop the health bar from updating.

### Debug
- `/fh heals` now shows which method is used, the last error and whether the green bar is shown, for every bar and every heal. If incoming heals still don't show for you, please post its output.

# FaithHeals 0.3.2-beta

### New
- **Tanks on top:** players with the tank role come first in the frame (party and raid), marked **MT** / **OT** left of the name. Main Tank / Main Assist set by the raid leader decide MT / OT; otherwise the first tank is MT. Toggle: Look & layout > "Tanks on top, marked MT / OT".
- **Healer icon:** a small icon on healers in your group. Toggle: Bars & text > "Show a healer icon on healers".
- The test bars (`/fh test 20`) show both.

### Fixed
- Dragging the frames when combat started gave an "action blocked" error. A drag still going is now finished just before combat starts.

### Note
- With tanks on top, a raid is not also sorted by raid group (the frame can only group by one thing). Turn "Tanks on top" off to sort by raid group again.

Incoming heals in combat are still being looked at: `/fh heals` output helps.

# FaithHeals 0.3.1-beta

### Fixed
- HoT, buff and debuff icons could stop updating in combat. Aura values that the game hides in combat are now checked before they are used, and icons fall back to reading the auras one by one.
- Errors while updating the icons are caught and shown by `/fh debug` instead of stopping the icons.

### New
- `/fh auras` shows what the game reports about buffs and debuffs, in and out of combat. Please include it when you report icon problems.

Incoming heals in combat are still being looked at: `/fh heals` output helps.

# FaithHeals 0.3.0-beta

First beta. A new Spells tab, many new look options, and click-casting fixes.

### Spells tab
- **Your bindings list:** pick a spell from your spellbook (or Target, Set focus, Assist, Unit menu, Trade), then press the mouse button or key you want, with Alt, Ctrl and Shift combinations.
- **Ranks:** "Max" always casts your highest rank, or pick a fixed rank.
- **Any key works:** the 12 thumb buttons of an MMO mouse and the wheel cast on the bar under the mouse and keep their normal job everywhere else.
- Option: keys cast on your target when the mouse isn't over a bar.

### On the bars
- **Health %** on every bar size, coloured white, like the name, yellow, or by health (green to red).
- **Incoming heals** as a light green bar right after the health.
- **Icons, one toggle each**, on every bar in the group (your own too): **My HoTs** (only your HoTs, no more Arcane Intellect there), **Buffs**, **Debuffs** (all, or only ones you can dispel). Each with its own max (1-4) and size (50-200%).
- Purple border when you can dispel a debuff (on/off), raid markers (skull, star ...).

### Look & layout
- New **Bars & text** tab: font, text size, outline, text shadow, name colour, length and position, background colour, fill direction (left to right by default, like Blizzard).
- **A size per group size:** Solo, Party, Raid 10, 20, 25 and 40 each have their own bar width, height and columns, and the bars switch by themselves.
- Minimap button (left-click: settings, right-click: lock).
- Test bars show all of the above without a group: `/fh test 20`.

### Fixed
- **Target / Set focus / Assist** did nothing: they now run as `/target` on the bar you click.
- Mouse clicks on the bars could be ignored.
- Settings were not saved when closing the window with the X.

### Commands
`/fh`, `/fh test 20`, `/fh unlock`, `/fh debug`, `/fh binds`, `/fh clicks` (what each click does), `/fh heals` (what the game reports about incoming heals).

Settings from 0.1.0-alpha are moved over automatically. Not everything is tested in combat yet: please report problems (`/fh debug` helps).

# FaithHeals 0.1.0-alpha

- **First test version.** HealBot-style party and raid frames for healers.
- **Click-casting like HealBot's Spells tab.** Put a spell, `target`, `focus` or `menu` on Left, Right, Middle, Button 4, Button 5 and the mouse wheel, with seven modifier combinations each (Click, Shift, Ctrl, Alt, Ctrl+Shift, Alt+Shift, Alt+Ctrl).
- **Built for 12-button MMO mice.** All twelve thumb buttons can cast on the bar under the mouse, and keep their normal action-bar job everywhere else. Choose which key each thumb button sends in the settings.
- **Hover a bar to see what every button casts**, for the modifier you are holding.
- **On the bars:** class or health colours, your own HoTs with timers, a border for a debuff you can dispel, a border on your target, and fading for players out of range.
- **Look and layout:** four themes, bar colour, name colour, texture, health %, bar size and scale; columns or rows, sorted by group, role or name; bars per column; spacing.
- **Test bars:** `/fh test 20` shows fake group members so you can set up the look and layout without a group.
- Drag to move and resize the frames with `/fh unlock`. `/fh` opens the settings.
- Ships with a Restoration Druid setup, and works for any healer.
- Not tested in the game yet: please report errors.
