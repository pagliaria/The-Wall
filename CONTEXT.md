# The Wall - Project Context

## Overview
- Godot 4.4 town-defense prototype.
- Player builds a town on the right, gathers resources, and stages units outside the wall for waves.
- Prefer scene-driven visuals/UI and code-driven state, spawning, placement, and nav logic.

## World
- Map: `48 x 27` tiles at `64px` (`3072 x 1728`).
- Water: top `3` rows.
- Wilds: cols `0-19` (`x 0-1280`).
- Enemy side: `x 0-640`.
- Friendly staging side: `x 640-1280`.
- Town: cols `20-47` (`x 1280+`).

## Main Scene
- `wall` is manual in the scene and uses `drawbridge.gd`.
- `ResourceLayer` spawns gold, trees, sheep, hover areas, placement blockers, and `ResourceNode`s.
- `BuildingsLayer` stores placed buildings.
- `UnitsLayer` stores pawns, warriors, archers, monks, and enemies.
- `UnitSelection` handles selection, move orders, and gather orders.
- `BuildingPlacer` handles ghost placement and overlap checks.
- `NavRegion` is rebaked after building placement, resource depletion, and wave bridge/separator changes.
- `WaveManager` is created at runtime by `main.gd`.

## HUD
- Build menu cards live in `build_menu.tscn`.
- Wave UI is under `HUD/WaveTimer` and anchored to the top center.
- Starting resources: `gold=100`, `wood=50`, `meat=10`.

## Buildings
- Castle is placed first through `castle_prompt.tscn`; build button is disabled until then.
- `castle.gd`: spawns up to `3` pawns every `5s`.
- `barracks.gd`: spawns up to `4` warriors every `8s`.
- `archery.gd`: spawns up to `4` archers every `8s`.
- `monastery.gd`: spawns up to `3` monks every `10s`.

## Placement / Resources / Nav
- Placement is town-only, non-water, and uses `ShapeCast2D` plus per-resource blocker areas.
- Trees, gold, and sheep have separate placement-clearance tuning in `resource_spawner.gd`.
- Gather/return uses explicit interaction points instead of collider centers.
- Depleted resources remove their blocker bodies and trigger nav rebakes.

## Units
- Pawn: gather/return worker, non-combat.
- Warrior: current player combat unit with `start_battle`, `end_battle`, `update_battle_target`.
- Archer: movable/selectable, no combat yet.
- Monk: movable/selectable, no healing/combat yet.
- Group move formation uses staggered rows with `42px` spacing.

## Wave / Combat
- Countdown is `90s`.
- Enemies spawn gradually during prep and all finish spawning by `30s` left.
- A battlefield separator keeps sides apart before battle.
- At `0`, the drawbridge raises, the separator opens, nav rebakes, and only player combat units already in the friendly staging lane join the battle.
- Battle membership is decided at wave start and then persists until death; it is not re-filtered by position mid-fight.
- During battle, selected player units are cleared and combat-unit selection is disabled until the wave ends.
- When battle ends, the bridge lowers, the separator closes again, nav rebakes, and the next countdown starts.
- Current waves: `4`, `6`, `8` enemy warriors, with later waves scaling by `LATE_WAVE_SCALE`.

## Enemy System
- `enemy_base.gd` is the current shared enemy combat/movement base.
- `enemy_warrior.gd` / `enemy_warrior.tscn` are the active spawned enemies.
- `enemy.gd` / `enemy.tscn` appear to be older leftovers and are not used by `wave_manager.gd`.

## Not Built Yet
- Archer combat.
- Monk healing/combat.
- Building-specific info/upgrade panels.
- Tower / house gameplay beyond placement.
- Win/lose game state beyond wave label updates.
- More enemy types and balance tuning.
