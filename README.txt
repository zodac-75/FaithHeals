FaithHeals - HealBot-style healing frames (WoW Forever / Midnight client)

INSTALL
  1. Copy the folder "FaithHeals" into the Interface\AddOns folder of the Forever install
     (Battle.net > choose Forever > gear icon > Show in Explorer).
  2. At the character screen click AddOns and tick FaithHeals. If it says "out of date",
     tick "Load out of date AddOns".

COMMANDS
  /fh            open the Spells window
  /fh unlock     move / resize the frames, /fh lock when done
  /fh scale 1.2  scale everything
  /fh reset      back to defaults

SPELLS (works like HealBot's Spells tab)
  Pick a button in the list on the left, then type a spell for each combination:
  Click, Shift, Ctrl, Alt, Ctrl+Shift, Alt+Shift, Alt+Ctrl.

  Buttons: Left, Right, Middle, Button 4, Button 5, Wheel up, Wheel down,
           and Thumb 1-12 (the twelve side buttons of an MMO mouse).

  Special words instead of a spell:  target   focus   menu

  THUMB BUTTONS: the addon needs to know which key each side button sends.
  Default is 1 2 3 4 5 6 7 8 9 0 - =  (what most 12-button mice send).
  If a button sends something else: select "Thumb N", click the box after
  "This button sends:", and press that side button.

  The thumb buttons and the wheel only cast while the mouse is over one of the
  frames. Everywhere else they do what they normally do (action bars, zoom).
  Tick "Thumb buttons cast on my target when not over a frame" if you want them
  to heal your current target when the mouse is somewhere else.

  Hover a frame to see what every button casts. Hold Shift/Ctrl/Alt to see that set.

THEMES
  Click the Theme button in /fh, then Save & Apply:
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
  Your own HoTs with timers, a purple border for a debuff you can dispel,
  a white border on your target, faded when out of range.

Settings can't be changed in combat. Spell names must match the spellbook exactly.
