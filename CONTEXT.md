# The Wall - Project Context

## Overview
Godot 4.4 town-defense prototype. Player builds town on right, gathers resources, stages units for waves. Prefer scene-driven visuals/UI, code-driven state/spawning/nav.

## World
- Map: `48x27` tiles at `64px` (`3072x1728`)
- Water: top 3 rows. Wilds: cols 0-19. Town: cols 20-47
- Enemy side: `x 0-640`. Staging: `x 640-1280`. Town: `x 1280+`

## Architecture
- `main.gd` wires everything
- Autoloads: `ResourceManager`, `UiAudio`, `MusicManager`, `CombatAudio`
- `ResourceLayer` — spawns gold/trees/sheep, respects building positions
- `BuildingsLayer` — placed buildings. `BuildingPlacer` handles ghost/overlap
- `UnitsLayer` — all units and enemies
- `UnitSelection` — selection, move orders, gather orders
- `NavRegion` — rebaked after placement, depletion, wave changes
- `WaveManager` — runtime-created; exposes `register_enemy()` for mid-battle spawns

## Buildings
- Castle placed first via `castle_prompt.tscn`; build button locked until placed
- All buildings check `ResourceManager.spend_meat()` before spawning; timer pauses if insufficient
- `castle.gd`: 3 pawns, 5s, cost 1 meat
- `barracks.gd`: 4 warriors, 8s, cost 3
- `archery.gd`: 4 archers, 8s, cost 3
- `monastery.gd`: 2 monks, 10s, cost 2
- `placed_building.gd`: drop animation (squash/settle) + 4-emitter dust particles + giant fall sound on landing
- `building_indicator.gd`: ring = spawn timer, count text, red ring + pulsing meat icon when starved
- Build menu cards show unit portrait + meat cost

## Units — Base Class
- `unit_base.gd`: signals, selection, map constants, separation force, HP bar, `take_damage`, `receive_heal`, `die`
- Virtual hooks: `_on_unit_ready/_process_state/_on_move_to/_on_end_battle/_on_die/_on_selected`
- Collision: player units layer 4 mask 1, enemies layer 2 mask 1

## Units — Player
- **Pawn**: gather/return. `pop_2` on order, resource sound on delivery, impact sound per extract frame
- **Warrior**: melee. `male_ready/male_go` voice
- **Archer**: ranged, kites. Arrow projectile with parabolic arc + shadow. `female_ready/female_go` voice
- **Monk**: heals allies first, attacks second. Heals during idle/move (scan every 1s). `monk_ready/monk_go` voice. `heal_effect.tscn` = green heal / red attack

## Arrow / Heal Effect
- `arrow.gd`: Area2D, weak homing, parabolic visual arc, mask 2
- `heal_effect.gd`: spawns on target, animates `Heal_Effect.png` once, green/red tint, auto-frees

## Wave / Combat
- Countdown: 90s. Enemies spawn gradually
- At 0: drawbridge raises (deep-thumps 0–1s), separator opens, nav rebakes, battle starts
- Wave end: drawbridge opens (deep-thumps 3–4s), victory/defeat sound plays
- `wave_manager` snapshots positions at battle start; teleports survivors home on end
- Voice lines use 0.4s exclusive cooldown gate

## Enemy System
- `enemy_base.gd`: movement/combat base, separation force, HP bar
- `enemy_warrior.tscn` — active enemy

## Audio
### UiAudio (SFX bus)
- Single player: UI clicks, `building_land` (giant fall at 0.3s)
- Trimmed player (+9dB): `deep_thumps` for drawbridge events — `play_trimmed(sound, from, to)`

### MusicManager (Music bus)
- Two-player crossfade (2s). Zones: Chill / Battle
- Countdown triggers: `play_battle()` + `play_horn()` (war_horn.mp3, dedicated player at +6dB)
- Wave end → `play_chill()`
- Supports OGG and MP3 loop at runtime

### CombatAudio (SFX bus)
- 8-player pool, round-robin. `SOUND_TRIM` dict for per-sound `[from, to, volume_db]`
- Sounds: hurt/death (random), arrow/arrow_hit/buff, voice lines, gather/delivery/impact, victory/defeat
- Exclusive cooldown gate (1s) for voice + gather sounds
- `monk_ready` trimmed 0.4–3.0s at +6dB

### Audio Buses
- Master / Music / SFX. Settings persist to `user://settings.cfg`

## Resources
- `ResourceManager` autoload: gold/wood/meat, `spend/add/has_*`, emits `resources_changed`
- Starting: gold 100, wood 50, meat 10 (overridden by settings)

## Settings
- `settings_screen.tscn/gd`: ESC or ⚙. Tabs: Audio, Display, Gameplay
- Pauses game (saves/restores `Engine.time_scale`). Persists via `ConfigFile`
- Fullscreen → emits `display_changed` → `_fit_camera_to_screen()`

## Speed Controls
- HUD: ⏸ 1x 2x 5x. Sets `Engine.time_scale`. HUD `PROCESS_MODE_ALWAYS`

## Not Built Yet
- Tower / house gameplay
- Win/lose end state
- Wave difficulty scaling / more enemy types
- Building info/upgrade panels
