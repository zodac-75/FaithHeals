# FaithHeals

HealBot-style healing frames for WoW Forever and Midnight: party and raid bars, click-casting, 12-button MMO mouse support and themes.

## Features

- Party and raid frames, sorted by group, that appear automatically
- Click-casting: bind spells to Left, Right, Middle, Button 4/5 and the mouse wheel
- Built for 12-button MMO mice: all twelve thumb buttons can cast on the bar under your cursor, and keep their normal action-bar job everywhere else
- Seven modifier combinations per button (Click, Shift, Ctrl, Alt, Ctrl+Shift, Alt+Shift, Alt+Ctrl)
- Tooltip showing what every button casts with the modifier you are holding
- Your own HoTs with timers, dispellable-debuff border, target highlight and range fade
- Four themes (Classic HealBot, Class colours, Slim class, Dark), or pick bar colour, name colour and texture yourself
- Layout options: columns or rows, sort by group, role or name, bars per column, spacing
- Light on the CPU: per-unit events, event-driven range, throttled aura updates
- Drag to move, drag the corner to resize, mouse wheel to scale; text and icons scale with the bars

## Install

Copy this folder into `Interface\AddOns\FaithHeals` of your WoW Forever (or Retail) install.

## Use

Type `/fh`, pick a button on the left and type a spell name for each combination.
Ships with a Restoration Druid setup, but works for any healer. See `README.txt` for details.

| Command | What it does |
|---|---|
| `/fh` | Open the Spells window |
| `/fh test 20` | Show test bars to set up look and layout without a group |
| `/fh unlock` / `/fh lock` | Move and resize the frames |
| `/fh scale 1.2` | Scale everything |
| `/fh reset` | Back to defaults |

## Status

Early version, not yet tested in game. Please report Lua errors (BugSack helps) as issues.
