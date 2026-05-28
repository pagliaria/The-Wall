# The Wall - Project Context

## Overview
Godot 4.4 town-defense prototype. The player builds on the right side of the map, gathers resources, trains units, hires enemy units, upgrades buildings, and survives waves.

## Core Systems
- `main.gd` wires the game together.
- `WaveManager` is created at runtime by `main.gd` and owns wave flow, countdowns, spawning, and cleanup.
- `BuildingPlacer` handles placement, overlap checks, and cancel flow.
- `ResourceLayer` spawns gold, trees, and sheep.
- `BuildingsLayer` and `UnitsLayer` hold placed buildings and live units.
- `UnitSelection` handles select/move/gather input and ignores world input over UI.

## HUD / UI
- `SelectionPanel` shows single-unit stats for player units and hired units.
- Hired unit selection uses the same portrait data as the hire panel.
- `BuildingUpgradePanel` sits bottom-left and shows per-building upgrades and hire options.
- All in-game text now uses the `Cardo` font family. `MonteCarlo` is no longer used.

## Buildings
- Castle must be placed first via `castle_prompt.tscn`.
- `placed_building.gd` owns click handling, upgrade definitions, timers, and stat bonuses.
- Production pauses while a building upgrade is in progress.
- Shared combat-building upgrades: damage, attack speed, move speed, HP, unit cap, production speed.
- `archery` and `monastery` also have range upgrades.
- `castle` has worker upgrades: move speed, unit cap, gather speed, production speed, and turn-in bonus.

## Units
- `unit_base.gd` provides shared selection, movement, HP, damage, healing, death, and bonus hooks.
- Player units: `Pawn`, `Warrior`, `Archer`, `Monk`, `Lancer`.
- Hired units come from `house.gd` and use enemy scenes with `hired = true`.
- `SelectionPanel` now shows attack range, damage, speed, and move speed for selected units.

## Waves / Combat
- Wave start raises the drawbridge, opens the separator, clears selection, and rebakes nav.
- Wave end lowers the bridge and restores control.
- `enemy_base.gd` contains the shared enemy state machine and targeting.
- Active enemy content includes slime, badger, boar, witch doctor, skeleton, and cat boss variants.

## Audio / Settings
- Audio is split across `UiAudio`, `MusicManager`, and `CombatAudio`.
- Settings persist to `user://settings.cfg`.
- Gameplay settings include starting resources, wave interval, and combat numbers.

## Notes
- The project is in git, but git commands are blocked here by a Windows `safe.directory` warning for `C:/Dev/The Wall`.
