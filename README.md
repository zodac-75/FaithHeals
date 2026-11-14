# FaithHeals

HealBot-style healing frames for **WoW Forever**: party and raid bars, click-casting, 12-button MMO mouse support and themes.

CurseForge: [FaithHeals](https://www.curseforge.com/wow/addons/faithheals) (project 1805340)

## Features

- Party and raid frames that appear automatically
- Click-casting like HealBot's Spells tab: bind spells to Left, Right, Middle, Button 4/5 and the mouse wheel, with seven modifier combinations each
- Built for 12-button MMO mice: all twelve thumb buttons can cast on the bar under your cursor, and keep their normal action-bar job everywhere else
- Hover a bar to see what every button casts with the modifier you are holding
- Your own HoTs with timers, dispellable-debuff border, target highlight and range fade
- Four themes, or pick bar colour, name colour and texture yourself
- Layout: columns or rows, sort by group, role or name, bars per column, spacing
- Test bars (`/fh test 20`) to set up look and layout without a group
- Drag to move, drag the corner to resize, mouse wheel to scale

## Use

Type `/fh`, pick a button on the left and type a spell name for each combination. Ships with a Restoration Druid setup, but works for any healer.

| Command | What it does |
|---|---|
| `/fh` | Open the settings |
| `/fh test 20` | Show test bars |
| `/fh unlock` / `/fh lock` | Move and resize the frames |
| `/fh scale 1.2` | Scale everything |
| `/fh reset` | Back to defaults |

## Build and release

```
python3 tools/build.py              # builds dist/FaithHeals/
python3 tools/build.py --zip DIR    # also writes FaithHeals-<version>.zip
python3 tools/check.py dist/FaithHeals
```

Copy `dist/FaithHeals` into `Interface\AddOns`. To release, bump the first line of `CHANGELOG.md`
(`# FaithHeals 0.1.1`) and push to `main`: GitHub Actions packages it with the
[BigWigs packager](https://github.com/BigWigsMods/packager), uploads it to CurseForge and makes a
GitHub release. A version with `beta` or `alpha` in it becomes a beta/alpha file. Needs the
repository secret `CF_API_KEY`.

## Status

Early version, not yet tested in the game. Please report Lua errors as issues.

Licensed under GPL-3.0.
