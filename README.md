# Vocational Control Presets
**Language:** English · [Português (Brasil)](README.pt-BR.md)

[![Version](https://img.shields.io/badge/version-1.0.0-blue.svg)](CHANGELOG.md)
[![Game](https://img.shields.io/badge/game-Dragon's%20Dogma%202-red.svg)](#requirements)
[![REFramework](https://img.shields.io/badge/tool-REFramework-orange.svg)](https://github.com/praydog/REFramework)
[![Nexus](https://camo.githubusercontent.com/1b13470b273fd814146a809ba9e00a631ba31d8a1d3ff94ec60f2e553f36e2ec/68747470733a2f2f696d672e736869656c64732e696f2f656e64706f696e743f75726c3d6874747073253341253246253246676973742e67697468756275736572636f6e74656e742e636f6d2532467261646a333037253246653961383037333165653233366363363766623030623639386537353230316525324672617725324635323330303734646662316136306662613931376131323332663933383266613563666563356462253246656e64706f696e742e6a736f6e)](https://www.nexusmods.com/dragonsdogma2/mods/2667?tab=description)

![Vocational Control Presets cover](/cover.png)

## Summary

Vocational Control Presets is a Dragon's Dogma 2 Lua mod for REFramework. It saves a gamepad button preset for each vocation and automatically applies the matching preset when the player changes vocation.

## Features

- Save a separate gamepad preset for every supported vocation.
- Apply presets automatically after the vocation becomes stable for several frames.
- Restore the game's default layout for a vocation that has no preset.
- Make Warfarer follow the weapon in hand, or disable that behavior.
- Edit all remappable game controls, including the Shift modifier and Weapon Skills 1–5.
- Display `[!]` when changed controls use the same button as another control.
- Show analog controls and unsupported button combinations as read-only.
- Fill a preset with the game's default layout.
- Apply and save changes immediately.
- Automatically migrate presets from the old JobControlPresets test name.

## Supported vocations

| Vocation |
|---|
| Fighter |
| Archer |
| Mage |
| Thief |
| Warrior |
| Sorcerer |
| Mystic Spearhand |
| Magick Archer |
| Trickster |
| Warfarer |

## Requirements

- Dragon's Dogma 2 (PC)
- REFramework for Dragon's Dogma 2 (`dinput8.dll` in the game folder)

## Installation

### Fluffy Mod Manager

1. Download the `VocationalControlPresets_<tag>.zip` release archive.
2. Drag the ZIP into Fluffy Mod Manager with Dragon's Dogma 2 selected.
3. Enable the mod.

The ZIP keeps `VocationalControlPresets/` as the installation root.

### Manual installation

Copy `reframework/autorun/VocationalControlPresets.lua` to:

```text
<game folder>/reframework/autorun/
