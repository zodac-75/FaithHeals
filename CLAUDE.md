# Working on FaithHeals

A HealBot-style healing addon for **WoW Forever** (the Midnight/Retail client, game version
1.60.1): party and raid bars, click-casting, mouse-over casting for a 12-button MMO mouse,
themes, layout options and test bars. README.md has the overview.

## How the owner wants it

- **Handover for new sessions**: `Z:\FaithHeals\Claude\CLAUDE.md` (Swedish) has where everything
  lives, the workflow and **the current state**; `Z:\FaithHeals\Claude\Starta-ny-session.txt` is the
  text he pastes into a new chat. **Update the "Läge just nu" section there after every change, test
  and release.**
- **Jennie's suggestions**: she writes them in `Z:\FaithHeals\Jennie\TIll Claude.txt` (Claude reads
  it and may add to it, but never removes her text); Claude answers in `Från Claude.txt` (only Claude writes there) (newest on top, Swedish, a status per item) and asks him before
  building anything. Details in the handover file.
- **Unreleased work goes on the `dev` branch** (push it so it survives between sessions; only `main`
  releases). Merge to `main` with the CHANGELOG bump when he says go.

- He writes Swedish or English: answer in the same language.
- **Test on his PC before pushing.** Build, run the checks, install the changed files on his PC
  (when the chat is linked to it) and tell him what to test. Commit and push only after he says
  it works / gives the go-ahead. Gather several fixes into one release instead of many small ones.
  Without a linked PC, ask before pushing. Repo notes like this file can be pushed right away.
- **Install on his PC**: `D:\Blizzard\World of Warcraft\_forever_\Interface\AddOns\FaithHeals\`,
  copying from the build output (`python3 tools/build.py` makes `dist/FaithHeals/`). New files
  (a new .lua or .xml, or a changed .toc) need a full game restart; changed files only `/reload`.
  Tell him which.
- **Releases**: every release bumps the first line of `CHANGELOG.md` ("# FaithHeals 0.1.1") and
  adds the notes under it. Pushing to `main` then releases it (see below). Only the newest
  section goes to CurseForge and GitHub.
- **Release zips on his NAS** (when the PC is linked and `Z:\` is connected): after each release put
  `FaithHeals-<version>.zip` (same folders as the CurseForge package; `python3 tools/build.py --zip DIR`)
  in `Z:\FaithHeals\Releases\`. Also keep `Z:\FaithHeals\FaithHeals\` as the latest unpacked addon.
  Logos, icons and screenshots live in `Z:\FaithHeals\Bilder\`.
- **Never** paste or ask for the CurseForge API token. It lives only in the repo secret `CF_API_KEY`
  (he adds it himself in Settings > Secrets and variables > Actions).
- **Check the upload** after a push:
  `gh api 'repos/zodac-75/FaithHeals/actions/runs?per_page=1'` then
  `gh run view <id> -R zodac-75/FaithHeals --log | grep Uploading` (`gh run list` doesn't work here).
- **CurseForge description**: `docs/curseforge.html`. Update it when a real feature lands (not for
  small fixes), in the built-in browser where he is logged in
  (authors.curseforge.com/#/projects/1805340/description). The editor is TinyMCE:
  `tinymce.activeEditor.setContent(html)` without the final ".", type the "." with a real
  keystroke, then click Save and check "Changes saved successfully". Wait until the editor content
  starts with `<h2>FaithHeals</h2>` before editing (the page is an SPA and keeps the old text for
  a moment). If logged out, tell him; don't log in.
- Screenshots on CurseForge are real ones from the game that he takes himself. Never use
  AI-generated images as screenshots.
- **Jennie** (plays/tests it) needs **health %** and **incoming heals** on the bars: never break them.
  Testers can get builds from `Z:\FaithHeals\Jennie\` (FaithHeals.zip + Installera.txt in Swedish).
- **The settings window must stay simple and easy to understand**: one toggle per thing, short
  labels, at most 1-2 lines of help text per section.
- **Writing files to his PC/NAS** (`device_commit_files`): sending the same staged path again can
  write an OLD copy (new mtime, old size). Copy the files to a new folder each time
  (e.g. `outputs/push-<time>/`) and check the sizes with `device_list_dir` afterwards.

## Layout

```
FaithHeals/            the addon (copy this folder into Interface\AddOns)
  FaithHeals.toc         "## Version: @project-version@" is filled in by the build
  Core.lua               saved settings, click-casting and keybinds, hover bindings, slash commands
  Frames.lua             unit bars, themes, range, layout, move/resize
  Config.lua             the /fh window (Spells, Look & layout and Bars & text tabs), minimap button
  Spells.lua             reads the spellbook (spell list and ranks for the Spells tab)
  Test.lua               test bars (fake group members)
  Template.xml           the secure unit button template
  Media/                 Icon.tga, Logo.tga
CHANGELOG.md           release notes; the first line is the version
tools/build.py         builds dist/FaithHeals/ and fills in the version (--zip DIR makes the zip)
tools/check.py         .toc files exist, XML valid, Lua parses (luac), no old names
tools/release.py       builds, checks and releases a new version (used by GitHub Actions)
docs/curseforge.html   the CurseForge description
```

## Release flow

Push to `main`. If the version in the first line of `CHANGELOG.md` has no `FaithHeals-<version>`
tag yet, `.github/workflows/release.yml` builds and checks the addon, packages it with the
BigWigs packager (branch v2, `-g 1.60.1`), uploads it to CurseForge (project 1805340, from
`## X-Curse-Project-ID` in the .toc) and makes a GitHub release with the same zip. A version with
"beta" or "alpha" in it is a beta/alpha file on CurseForge. Without a bump, nothing is released.

## WoW Forever gotchas

- **Secret values**: in combat the game can give addons "secret" values (health, auras, range).
  Never compare or do maths on one; pass it straight to a widget (`StatusBar:SetValue`,
  `SetFormattedText`) or test it with `issecretvalue` first. Wrap risky API calls in `pcall`.
- **Combat lockdown**: bars are secure frames made by `SecureGroupHeaderTemplate`. Anything that
  changes their size, position, attributes or bindings only runs out of combat (`ApplyAll` waits
  for `PLAYER_REGEN_ENABLED`).
- **Taint**: never parent our frames to Blizzard frames and never call ShowUIPanel/HideUIPanel or
  toggle Blizzard panels from addon code.
- The thumb buttons and the wheel are bound with `SetBindingClick` from a secure header while the
  mouse is over a bar, so they only act on bars and keep their normal job elsewhere.
- **Clicks**: secure buttons (bars, fallback keys) must use `RegisterForClicks("AnyUp", "AnyDown")`.
  With only one direction, mouse clicks were ignored in Forever. Insecure post-click code
  (`BarPostClick`, e.g. Trade) only acts when `down` is false.
- **Target / focus / assist** run as macros: a secure pre-click (`ON_CLICK` in Core.lua, wrapped on
  OnClick) writes `"/target " .. unit` into the right `macrotext` attribute before every click.
  The plain secure `type = "target"` did nothing in Forever. Don't change it back.
- **HoT icons** = your own auras filtered by `JH.IsHot` (known HoT names, or 60 s or less, cached per
  auraInstanceID because names/durations can be secret in combat). Everything else is a buff.
- **Settings migrations**: `db.version` in `InitDB` (Core.lua). Bump it and migrate when a setting
  changes shape. Every `db.look` key must be in both `JH.defaults.look` and `DEFAULT_LOOK` (Frames.lua).
- **Debug commands**: `/fh debug`, `/fh binds`, `/fh clicks` (what each click does, which unit, the
  target afterwards), `/fh heals` (incoming-heal API, events and values).
- **Open (0.3.0-beta)**: incoming heals may not show in combat. Ask for `/fh heals` output; if
  `UnitGetIncomingHeals`/`UNIT_HEAL_PREDICTION` don't work in Forever, estimate own heals or use
  LibHealComm-style addon messages.
- Older note: not tested in the game as of 0.1.0-alpha. The parts that depend on new Midnight APIs
  (health-colour curve, `UnitHealthPercent`, `SetAlphaFromBoolean`, aura duration objects) are
  guarded and fall back quietly; if one doesn't work in the game, fix that first.
