# FaithHeals

HealBot-style healing frames for **WoW Forever**: party and raid bars, click-casting, 12-button MMO mouse support and themes.

CurseForge: [FaithHeals](https://www.curseforge.com/wow/addons/faithheals) (project 1805340)

## Features

- Party and raid frames that appear automatically, with their own size for Solo, Party and Raid 10/20/25/40
- Click-casting: pick a spell from your spellbook (or Target, Set focus, Assist, Unit menu, Trade) and press the mouse button or key you want, with Alt/Ctrl/Shift combinations; "Max" rank or a fixed rank
- Built for 12-button MMO mice: thumb buttons and the wheel cast on the bar under your cursor, and keep their normal job everywhere else
- Hover a bar to see what every button casts with the modifier you are holding
- Health %, incoming heals, target highlight, range fade, raid markers
- Tanks on top of the frame, marked MT / OT, and a small icon on healers
- Icons with one toggle each: your HoTs, buffs, debuffs (all or dispellable), each with its own max and size
- Four themes, plus font, text size, colours, outline, shadow, background and fill direction
- Test bars (`/fh test 20`) to set up look and layout without a group
- Drag to move, drag the corner to resize, mouse wheel to scale

## Use

Type `/fh`. On the **Spells** tab press New, pick a spell, then "Bind a button" and press it.
**Look & layout** and **Bars & text** set how the bars look. Press Save & Apply.
Ships with a Restoration Druid setup, but works for any healer.

| Command | What it does |
|---|---|
| `/fh` | Open the settings |
| `/fh test 20` | Show test bars |
| `/fh unlock` / `/fh lock` | Move and resize the frames |
| `/fh scale 1.2` | Scale everything |
| `/fh debug`, `/fh binds` | What FaithHeals sees, and what each binding does |
| `/fh clicks`, `/fh heals`, `/fh auras` | Print what each click does / what the game reports about incoming heals / about buffs and debuffs |
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

Beta. Tested in the game, but not everything in combat yet. Please report problems as issues (`/fh debug` helps).

Licensed under GPL-3.0.
