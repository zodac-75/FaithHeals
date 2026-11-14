FaithHeals - HealBot-style healing frames (WoW Forever / Midnight client)

INSTALL
  1. Copy the folder "FaithHeals" into the Interface\AddOns folder of the Forever install
     (Battle.net > choose Forever > gear icon > Show in Explorer).
  2. At the character screen click AddOns and tick FaithHeals. If it says "out of date",
     tick "Load out of date AddOns".

COMMANDS
  /fh            open the Spells window
  /fh test 20    show 20 test bars (any number 1-40), /fh test again to hide
  /fh minimap    hide or show the minimap button (left-click: settings, right-click: lock)
  /fh debug      show what FaithHeals sees, for reporting problems
  /fh binds      list your bindings and what your own bar will do for each
  /fh clicks     print what every click on a bar does (to find binding problems)
  /fh heals      show what the game reports about incoming heals
  /fh auras      show what the game reports about buffs/debuffs (icons)
  /fh unlock     move / resize the frames, /fh lock when done
  /fh scale 1.2  scale everything
  /fh reset      back to defaults

SPELLS (first tab in /fh)
  1. Press New (or pick a binding in "Your bindings" to change it).
  2. In the list on the left, click a spell or an action:
       Target, Set focus, Assist, Unit menu, Trade.
     The list shows the spells in your spellbook. "Friendly only" hides attacks.
     A spell that isn't listed can be typed in the box under the list.
  3. Rank: "Max" always casts your highest rank (also after you train a new one).
     Click the Rank button to pick a lower rank instead.
  4. Click "Bind a button", then press the mouse button or key you want.
     Hold Alt, Ctrl or Shift while you press it to bind that combination,
     e.g. hold Alt and right-click = Alt + Right button.
  5. Save & Apply.

  Mouse buttons (left, right, middle, 4, 5) cast when you click a bar.
  Keys, the 12 thumb buttons of an MMO mouse and the wheel cast on the bar under
  the mouse, and do their normal job everywhere else (action bars, zoom).
  One button = one action: binding a button that is already used replaces the old one.
  Tick "Keys cast on my target when not over a bar" if you want keys to heal your
  target when the mouse is somewhere else.

  Hover a bar to see what every button casts. Hold Shift/Ctrl/Alt to see that set.
  If Alt+click casts on yourself, set Self Cast to None in the game options.

LOOK & LAYOUT (second tab in /fh)
  Look:   theme, bar colour (by health / class / dark), name colour, bar texture,
          health % (on every bar size), incoming heals,
          bar width / height / scale, how much out-of-range bars fade.
  Size:   Solo, Party, Raid 10, 20, 25 and 40 each have their own bar width, height and
          number of columns. Pick the group size, set the numbers (or turn on Test bars and
          drag the corner handle). The bars switch size by themselves with your group.
  Layout: columns or rows, sort by raid group / role / name, space between bars,
          show when solo, show yourself in the party.
  Nothing changes until you press Save & Apply.

BARS & TEXT (third tab in /fh)
  Text:   font, text size (Auto follows the bar height), outline, name length
          (cut long names), name position (centre / left), name colour
          (white / class / yellow / light grey / black), health % colour
          (white / same as name / by health / yellow), shadow behind the text.
  Bars:   background colour (dark / red / dark class colour), health fills
          left to right (default, like Blizzard's bars) or bottom to top,
          raid markers on the bars.
  Icons:  one toggle each, shown on every bar in the group (your own bar too):
            My HoTs        on/off, max 1-4, size 50-200% (only HoTs and short
                           effects you cast)
            Buffs          on/off, max 1-4, size 50-200% (all other buffs, also
                           your own long ones like Arcane Intellect)
            Debuffs        on/off, max 1-4, size 50-200%, all of them or only
                           ones you can dispel
            Purple border  on/off, when you can dispel a debuff
          Tall bars: HoTs bottom left, buffs bottom right, debuffs top right.
          Slim bars: HoTs and buffs on the right, debuffs on the left.

TEST BARS
  Look & layout tab > "Test bars" (or /fh test 20) shows fake group members so the
  look and layout can be set up without a party or raid. They show different health,
  HoTs, a dead and an offline player, a dispel border and out-of-range fading.
  They can't be clicked, and hide themselves when combat starts.

THEMES
  A theme is a preset for the Look settings. Click the Theme button, then Save & Apply:
    Classic HealBot - slim bars, green > yellow > red as health drops
    Class colours   - taller bars in class colour, with health %
    Slim class      - slim bars in class colour
    Dark            - dark bars, class-coloured names, red where health is missing
  Each theme suggests a bar size; change Width/Height or drag the corner handle.

MOVE AND RESIZE
  /fh unlock, then:
    drag the green bar            move
    drag the corner handle        make the bars wider / taller
    mouse wheel on bar or handle  scale everything
  Text and HoT icons grow and shrink with the bars.

ON THE BARS
  Health % (tick "Show health %"), incoming heals as a light green bar after the
  health, your own HoTs with timers, a purple border for a debuff you can dispel,
  a white border on your target, faded when out of range.

PERFORMANCE
  Each bar only listens to its own player, range changes come from the game itself
  (with a light check twice a second as backup), and bursts of buff changes are
  combined into one update. Nothing runs for hidden bars.

Settings can't be changed in combat. Spell names must match the spellbook exactly.
