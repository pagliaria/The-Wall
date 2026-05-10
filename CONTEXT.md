# The Wall - Project Context

## Overview
Godot 4.4 town-defense prototype. Player builds town on right, gathers resources, stages units for waves. Prefer scene-driven visuals/UI, code-driven state/spawning/nav.

## World
- Map: `48x27` tiles at `64px` (`3072x1728`)
- Water: top 3 rows. Wilds: cols 0-19. Town: cols 20-47
- Enemy side: `x 0-640`. Staging: `x 640-1280`. Town: `x 1280+`

## Architecture
- `main.gd` wires everything; three autoloads: `ResourceManager`, `UiAudio`, `MusicManager`, `CombatAudio`
- `ResourceLayer` — spawns gold/trees/sheep, hover areas, placement blockers, ResourceNodes. Now respects building positions when respawning
- `BuildingsLayer` — placed buildings. `BuildingPlacer` handles ghost/overlap
- `UnitsLayer` — all units and enemies
- `UnitSelection` — selection, move orders, gather orders
- `NavRegion` — rebaked after placement, depletion, wave changes
- `WaveManager` — runtime-created by `main.gd`; exposes `register_enemy()` for mid-battle spawns

## Buildings
- Castle placed first via `castle_prompt.tscn`; build button locked until placed
- All buildings check `ResourceManager.spend_meat()` before spawning; timer pauses if insufficient meat
- `castle.gd`: 3 pawns, 5s interval, meat cost 1
- `barracks.gd`: 4 warriors, 8s, cost 3
- `archery.gd`: 4 archers, 8s, cost 3
- `monastery.gd`: 2 monks, 10s, cost 2
- `placed_building.gd`: creates controller + building indicator + drop animation with squash/settle/dust particles on placement. Giant fall sound plays on landing
- `building_indicator.gd`: ring shows spawn timer, count text, red ring + pulsing meat icon when starved
- Build menu cards show unit portrait + meat cost per unit

## Units — Base Class
- `unit_base.gd`: signals, selection, map constants, separation force (replaces old push system), HP bar (hidden until damaged), `take_damage`, `receive_heal`, `die`, virtual hooks `_on_unit_ready/_process_state/_on_move_to/_on_end_battle/_on_die/_on_selected`
- Collision: player units layer 4 mask 1, enemies layer 2 mask 1 — no unit-vs-unit physics

## Units — Player
- **Pawn**: gather/return worker. Plays `pop_2` on gather order, resource-specific sound on delivery, impact sound on last frame of each extract animation
- **Warrior**: melee combat. `start_battle/end_battle/update_battle_target`. Plays `male_ready` on select, `male_go` on move order
- **Archer**: ranged combat, kites. Shoots arrow projectile (`arrow.tscn`) with parabolic arc + shadow. Plays `female_ready/female_go`. `shoot` anim triggers arrow spawn mid-animation
- **Monk**: heals injured allies first (priority), attacks enemies second with holy bolt (`heal_effect.tscn`). Heals during idle/move too (scans every 1s). Plays buff sound on cast. Effect is green for heal, red for attack

## Arrow / Heal Effect
- `arrow.gd`: Area2D, homes weakly on target, parabolic visual arc via sprite Y offset + shadow. Mask 2 (enemies)
- `heal_effect.gd`: spawns directly on target, plays `Heal_Effect.png` animation once, green/red tint, frees on finish

## Wave / Combat
- Countdown: 90s. Enemies spawn gradually, all done by 30s left
- At 0: drawbridge raises, separator opens, nav rebakes, battle starts
- `wave_manager` snapshots player unit positions at battle start; teleports survivors home on wave end
- Wave counts: 4/6/8 enemies. `register_enemy()` hook for mid-battle spawns (e.g. lancer duplication)
- Voice lines (select/order) use 0.4s cooldown gate — multi-unit select plays once

## Enemy System
- `enemy_base.gd`: shared movement/combat base, separation force, HP bar
- `enemy_warrior.tscn` — active spawned enemy
- `enemy.tscn/enemy.gd` — legacy, unused

## Audio
- `UiAudio`: SFX bus, single player, UI clicks + building land sound (giant fall, starts at 0.3s)
- `MusicManager`: Music bus, two-player crossfade (2s). Chill → warning (countdown) → battle → chill
- `CombatAudio`: SFX bus, 8-player pool. Sounds: hurt/death (random pick), arrow/arrow_hit/buff, voice lines, gather/resource delivery/impact sounds. Exclusive cooldown gate for voice + gather
- Audio buses: Master / Music / SFX. Settings persist to `user://settings.cfg`

## Resources
- `ResourceManager` autoload: gold/wood/meat + multipliers, `spend/add/has_*` helpers, emits `resources_changed`
- Starting: gold 100, wood 50, meat 10 (overridden by settings on startup)

## Settings
- `settings_screen.tscn/gd`: ESC or ⚙ button. Tabs: Audio (master/music/SFX sliders), Display (fullscreen/vsync), Gameplay (wave interval, starting resources)
- Pauses game while open (saves/restores `Engine.time_scale`). Persists via `ConfigFile`
- Fullscreen emits `display_changed` → `main._fit_camera_to_screen()`

## Speed Controls
- HUD action bar: ⏸ 1x 2x 5x buttons. Sets `Engine.time_scale`. HUD has `PROCESS_MODE_ALWAYS`

## Not Built Yet
- Tower / house gameplay
- Win/lose end state
- Wave difficulty scaling / more enemy types
- Building info/upgrade panels
