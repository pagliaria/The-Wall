# The Wall - Project Context

## Overview
- Godot 4.4 town-defense prototype.
- Player builds a town on the right side of the map, gathers resources, and commands units.
- Asset pack: Tiny Swords (Free Pack).

## Preferences
- Prefer scene-driven visuals and UI.
- Use code for wiring, state, runtime spawning, and nav/placement logic.
- Buildings place exactly where the ghost preview shows.

## World
- Map: `48 x 27` tiles at `64px` (`3072 x 1728`).
- Water: top `3` rows.
- Wilds: cols `0-19`.
- Town: cols `20-47`.

## Main Scene
- `wall` uses `drawbridge.gd`; manual editor wall, do not rebuild from code.
- `Terrain` builds ground/water/decor.
- `ResourceLayer` spawns gold, trees, sheep, hover areas, placement blockers, and `ResourceNode`s.
- `HUD` contains action bar, build menu, and resource display.
- `BuildingsLayer` stores placed buildings.
- `UnitsLayer` stores pawns, warriors, archers, monks.
- `UnitSelection` handles selection, move orders, and gather orders.
- `BuildingPlacer` handles ghost placement and overlap checks.
- `NavRegion` is rebaked after each placed building.

## HUD
- Bottom action bar with hammer button.
- `build_menu.tscn` owns the visible building cards.
- `build_menu.gd` handles button wiring and banner stitching.
- Resource display starts at `gold=100`, `wood=50`, `meat=25`.

## Buildable Controllers
- `castle.gd`: spawns up to `3` pawns every `5s`.
- `barracks.gd`: spawns up to `4` warriors every `8s`.
- `archery.gd`: spawns up to `4` archers every `8s`.
- `monastery.gd`: spawns up to `3` monks every `10s`.

## Placement
- Town zone only, non-water only.
- Placement uses `ShapeCast2D` plus per-resource `PlacementBlocker` areas.
- Trees, gold, and sheep each have separate placement-clearance tuning in `resource_spawner.gd`.

## Navigation
- Units use `NavigationAgent2D`.
- `main.gd._rebake_nav()` parses static colliders from the scene tree and bakes nav after building placement.
- `agent_radius = 32.0`.
- Gather/return uses explicit reachable interaction points instead of targeting collider centers.

## Resources
- Gold: `6`, `8` chunks, `3s` extract time.
- Trees: `10`, `5` chunks, `4s` extract time.
- Sheep: `5`, `3` chunks, `5s` extract time.
- Each resource has:
  - hover `Area2D` for gather cursor/orders
  - placement blocker `Area2D`
  - `ResourceNode` with `resource_type`, `amount`, `extract_time`, `collision_body`, `interact_position`, `interact_radius`

## Units

### Pawn
- States: `IDLE`, `MOVE`, `MOVE_TO`, `GATHER`, `EXTRACTING`, `RETURN`.
- Uses nav for wander, player moves, gather, and return.
- Delivers gathered resources back to castle and updates HUD through `resource_delivered`.
- Has push/yield/stalemate-break logic for unit traffic.

### Warrior
- Scene-driven animations: `idle`, `run`, `guard`, `attack1`, `attack2`.
- Patrols around barracks, accepts move orders.
- Has the same push/yield/stalemate-break logic.

### Archer
- Spawned from Archery.
- Scene-driven animations: `idle`, `run`, `shoot`.
- Movement behavior currently mirrors warrior.

### Monk
- Spawned from Monastery.
- Scene-driven animations: `idle`, `run`, `heal`.
- Movement behavior currently mirrors warrior; no healing gameplay yet.

## Selection / Orders
- LMB click selects nearest unit.
- Drag box selects groups.
- Shift adds/toggles selection.
- RMB on resource hover issues gather orders to units with `gather_resource`.
- RMB on ground issues move orders.
- Group move formation uses staggered rows and `42px` spacing.

## Drawbridge
- `B` toggles bridge.
- Uses `AnimationPlayer` to crossfade between raised/lowered visuals.

## Important Scripts
- `main.gd`: camera, placement flow, nav rebake, HUD resource updates.
- `placed_building.gd`: runtime building body, sprite, collision, click area, controller attachment.
- `resource_spawner.gd`: all town resource spawning and tuning.
- `resource_node.gd`: gather arbitration and depletion.
- `building_placer.gd`: ghost + placement validation.
- `unit_selection.gd`: selection, move, gather, cursor.
- `pawn.gd`, `warrior.gd`, `archer.gd`, `monk.gd`: unit movement/state.

## Not Built Yet
- Enemy spawning and combat.
- Real archer attacks.
- Monk healing gameplay.
- Building costs / economy balance.
- Building-specific UI panels.
- Tower / house / monastery / archery gameplay beyond spawning.
- Win/lose state.
