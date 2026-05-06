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
- Wilds: cols `0-19` (x 0–1280).
  - Enemy mill zone: cols `0-9` (x 0–640) — enemies spawn and wander here.
  - Deployment zone: cols `10-19` (x 640–1280) — player positions units before a wave.
- Town: cols `20-47` (x 1280+).

## Main Scene
- `wall` uses `drawbridge.gd`; manual editor wall, do not rebuild from code.
- `Terrain` builds ground/water/decor.
- `ResourceLayer` spawns gold, trees, sheep, hover areas, placement blockers, and `ResourceNode`s.
- `HUD` contains action bar, build menu, resource display, and wave countdown label.
- `BuildingsLayer` stores placed buildings.
- `UnitsLayer` stores pawns, warriors, archers, monks, and enemy units.
- `UnitSelection` handles selection, move orders, and gather orders.
- `BuildingPlacer` handles ghost placement and overlap checks.
- `NavRegion` is rebaked after each placed building.
- `WaveManager` (added at runtime by `main.gd`) owns the wave loop.

## HUD
- Bottom action bar with hammer button and `WaveLabel` for countdown/wave state.
- `build_menu.tscn` owns the visible building cards.
- `build_menu.gd` handles button wiring and banner stitching.
- Resource display starts at `gold=100`, `wood=50`, `meat=25`.
- `hud.update_resources(gold, wood, meat)` forwards to both resource display and build menu.
- `hud.set_wave_countdown(s)`, `hud.set_wave_active(n)`, `hud.set_wave_ended(won)` drive the wave label.

## Building Costs (single source of truth: `build_menu.gd` → `BUILDING_COSTS`)
| Building   | Gold | Wood | Meat |
|------------|------|------|------|
| Castle     | 0    | 0    | 0    |
| House      | 20   | 30   | 0    |
| Monastery  | 50   | 30   | 20   |
| Archery    | 60   | 60   | 0    |
| Barracks   | 80   | 40   | 0    |
| Tower      | 100  | 20   | 0    |

- `main.gd._spend_building_cost()` reads `BUILDING_COSTS` at runtime and deducts on placement.
- Build menu buttons are disabled (cost label turns red) when the player can't afford a building.

## Castle Placement Flow
- On game start a `castle_prompt.tscn` overlay appears (semi-transparent dimmer + castle card).
- The build button is disabled until the castle is placed.
- Cancelling placement re-shows the prompt.
- After castle placement the prompt is freed and the build button is enabled.
- Castle is not in the build menu — it is only placed via the startup prompt.

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
- `faction` is not set (not a combat unit, excluded from wave targeting).

### Warrior (`warrior.gd`)
- `faction = "player"`.
- States: `IDLE`, `MOVE`, `MOVE_TO`, `BATTLE`, `ATTACKING`.
- Scene-driven animations: `idle`, `guard`, `run`, `attack1`, `attack2`.
- Patrols around barracks, accepts move orders.
- Has push/yield/stalemate-break logic.
- Combat API: `start_battle(enemies)`, `end_battle()`, `update_battle_target(enemies)`.
- Melee range `48px`, damage `5`, attack rate `1.0s`.

### Archer
- `faction = "player"` (set in script).
- Spawned from Archery. Movement mirrors warrior. No ranged attack yet.

### Monk
- `faction = "player"` (set in script).
- Spawned from Monastery. Movement mirrors warrior. No healing yet.

## Selection / Orders
- LMB click selects nearest unit.
- Drag box selects groups.
- Shift adds/toggles selection.
- RMB on resource hover issues gather orders to units with `gather_resource`.
- RMB on ground issues move orders.
- Group move formation uses staggered rows and `42px` spacing.

## Drawbridge
- `B` toggles bridge manually.
- `force_raise()` / `force_lower()` called programmatically by `WaveManager`.
- Uses `AnimationPlayer` to crossfade between raised/lowered visuals.

## Wave System

### Zones
- Enemy mill zone (x 0–640): enemies spawn here and wander during prep phase.
- Deployment zone (x 640–1280): player positions combat units here before a wave.
- The wall (x ~1280): drawbridge separates the two sides.

### Flow
1. Countdown timer (`WAVE_INTERVAL = 90s`) ticks down on HUD.
2. At 0: drawbridge raises, enemies spawn, all combat units enter BATTLE state.
3. Each enemy finds nearest player unit and walks into melee range.
4. Each player warrior finds nearest enemy.
5. `WaveManager` retargets both sides every `1s` and checks for battle-over every `0.5s`.
6. When one side is wiped: drawbridge lowers, player units return to IDLE, next countdown starts.

### Wave Compositions (`wave_manager.gd` → `WAVE_COMPOSITIONS`)
- Defined as an array of wave entries, each a list of `{ path, count }`.
- Waves beyond the defined list repeat the last entry with counts scaled by `LATE_WAVE_SCALE = 1.5`.
- Currently: wave 1 = 4 warriors, wave 2 = 6, wave 3 = 8.

### Adding a New Enemy Type
1. Create `scripts/enemy_xyz.gd` extending `enemy_base.gd`.
2. Create `scenes/enemy_xyz.tscn` with appropriate sprites.
3. Add an entry to `WAVE_COMPOSITIONS` in `wave_manager.gd`.

## Enemy System

### `enemy_base.gd`
- Base class for all enemies. Do not instantiate directly.
- `@export` stats: `max_hp`, `move_speed`, `patrol_radius`, idle/move time ranges.
- States: `IDLE`, `MILL`, `BATTLE`, `ATTACKING`, `DEAD`.
- `_battle_ready` flag prevents `_initial_state()` from overwriting BATTLE if `start_battle()` fires first.
- Nav fallback: if nav has no path, steers directly toward target using `direction_to`.
- Virtual methods to override: `_get_engage_range()`, `_get_attack_rate()`, `_do_attack_hit()`, `_do_attack_tick(delta)`, and five `_on_enter_*_state()` animation hooks.

### `enemy_warrior.gd` / `enemy_warrior.tscn`
- Extends `enemy_base.gd`.
- Red warrior sprites (Attack1, Attack2, Guard, Idle, Run).
- Melee range `48px`, damage `4`, attack rate `1.2s`.
- Alternates `attack1`/`attack2` animations; plays `guard`/`idle` at rest.

## Important Scripts
- `main.gd`: camera, placement flow, nav rebake, HUD resource updates, wave manager setup.
- `placed_building.gd`: runtime building body, sprite, collision, click area, controller attachment.
- `resource_spawner.gd`: all town resource spawning and tuning.
- `resource_node.gd`: gather arbitration and depletion.
- `building_placer.gd`: ghost + placement validation.
- `unit_selection.gd`: selection, move, gather, cursor.
- `pawn.gd`, `warrior.gd`, `archer.gd`, `monk.gd`: unit movement/state.
- `enemy_base.gd`: shared enemy state machine, nav, push, combat.
- `enemy_warrior.gd`: warrior enemy subclass.
- `wave_manager.gd`: wave countdown, enemy spawning, battle trigger, battle-over detection.
- `build_menu.gd`: building costs, affordability checks, HUD card wiring.
- `castle_prompt.gd`: startup castle placement overlay.
- `drawbridge.gd`: bridge toggle, `force_raise()`, `force_lower()`.

## Not Built Yet
- Real archer attacks (ranged projectile).
- Monk healing gameplay.
- Building-specific UI panels (clicking a building shows info/upgrades).
- Tower / house gameplay beyond spawning.
- Win/lose state (currently wave outcome shown in label only).
- Enemy types beyond warrior (lancer, archer, shaman stubs exist in wave_manager comments).
- Economy balance tuning.
