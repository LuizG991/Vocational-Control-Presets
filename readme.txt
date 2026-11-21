Vocational Control Presets v1.0.0  -  Dragon's Dogma 2 (REFramework script)

WHAT IT DOES
  Save a gamepad control preset for each vocation. When you change vocation the mod applies that
  vocation's preset on its own. A vocation without a preset always gets the game's default layout
  back, whatever a previous preset changed.
  The Warfarer follows the vocation of the weapon in hand, so swapping weapons swaps presets
  (turn off with "Warfarer follows the weapon's vocation").

REQUIREMENTS
  REFramework for Dragon's Dogma 2 (dinput8.dll in the game folder).

INSTALL
  Fluffy Mod Manager: drag this zip onto Fluffy Mod Manager (Dragon's Dogma 2 selected), then enable the mod.
  Manual: copy reframework/autorun/VocationalControlPresets.lua into <game folder>/reframework/autorun/

  Upgrading from "JobControlPresets" (test versions): remove JobControlPresets.lua from
  reframework/autorun/ first. Your presets are carried over automatically from
  reframework/data/JobControlPresets/config.json the first time this version runs.

USING IT (REFramework menu > Script Generated UI > VocationalControlPresets)
  1. Presets > pick a vocation in "Vocation to edit" and tick "Use a preset for this vocation".
  2. Choose a button for any control. "(game default: X)" is the normal binding of that control.
     The list at the top holds the linked controls (Vocation Action, Sheathe/Draw/Cancel, attacks,
     Jump, Grab, Interact, Switch Weapon Skill and Weapon Skills 1-5). "All other controls" holds
     everything else in the binding table (Dash, pawn commands, lock-on, ...).
  3. Tick "Show modifier (Shift) options" to also choose whether a control needs the Shift button
     (the Switch Weapon Skill button, LB by default).
  4. A [!] line appears when a changed control shares its button with another control.
  Changes apply right away and are saved automatically. "Apply now", "Restore game defaults" and
  "Save settings" are also available.

  Controls the mod cannot remap (analog sticks, button chords such as "LB + Y B") are shown read-only.
  "Fill with game defaults" copies the default layout into the preset as a starting point.

GAME DEFAULTS
  The default layout of the game's Button Mapping screen is built into the mod. Controls that have
  no built-in default (SkillAdditional, lock-on, ...) use the values captured the first time the mod
  ran. If you change those in the game's own menu, press "Recapture other defaults" with no preset active.

SETTINGS
  Enabled                          Master switch. Turning it off restores the game defaults.
  Apply automatically when the vocation changes
  Warfarer follows the weapon's vocation
  Settle frames                    The vocation must stay the same this many frames before the preset is applied.
  Live bindings (debug)            Shows the game's binding table (action = modifier + button), for bug reports.
  Presets and settings are kept in reframework/data/VocationalControlPresets/config.json.
  Presets can also be edited there; extra linked controls can be added under "extra_groups":
    "extra_groups": [ { "name": "My control", "actions": ["ActionNameA", "ActionNameB"] } ]

COMPATIBILITY
  Do not use it together with the "Apply automatically on startup" option of Classic Aim Controls:
  both rewrite the same binding table. To get the same layout, make a preset for the Archer and
  Magick Archer with Vocation Action = LT, Sheathe/Draw/Cancel = RB, Light Attack = RT, Grab = X.

UNINSTALL
  Disable the mod in Fluffy Mod Manager, or delete reframework/autorun/VocationalControlPresets.lua.
