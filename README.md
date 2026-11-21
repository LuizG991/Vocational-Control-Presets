# Vocational Control Presets

[![Version](https://img.shields.io/badge/version-1.0.0-blue.svg)](CHANGELOG.md)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Game](https://img.shields.io/badge/game-Dragon's%20Dogma%202-red.svg)](#requirements)
[![REFramework](https://img.shields.io/badge/tool-REFramework-orange.svg)](https://github.com/praydog/REFramework)

**Português (Brasil): [README.pt-BR.md](README.pt-BR.md)**

![Vocational Control Presets cover](VocationalControlPresets/cover.png)

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
