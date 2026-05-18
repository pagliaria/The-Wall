# The Wall - Project Context

## Overview
Godot 4.4 town-defense prototype. The player builds a town on the right side of the map, gathers resources, trains units, equips units with item bonuses, upgrades production buildings, and stages defenders for incoming waves. The project is mostly scene-driven on the UI/visual side and code-driven for state machines, spawning, combat, upgrades, and navigation.

## World
- Map: `48x27` tiles at `64px` (`3072x1728`)
- Water: top 3 rows
- Wilds: cols `0-19`
- Town: cols `20-47`
- Enemy side: `x 0-640`
- Battlefield / staging gap: `x 640-1280`
- Town interior: `x 1280+`

## Architecture
- `main.gd` wires the game together
- Autoloads used by current gameplay:
  - `ResourceManager`
  - `UiAudio`
  - `MusicManager`
  - `CombatAudio`
  - `CombatNumbers`
- `ResourceLayer` spawns gold, trees, and sheep while respecting building footprints
- `BuildingsLayer` holds all placed structures
- `BuildingPlacer` handles ghost placement, overlap checks, and placement/cancel signals
- `UnitsLayer` contains player units and live enemies
- `UnitSelection` handles select/move/gather input and ignores world input while hovering UI
- `NavRegion` is rebaked after building placement, depletion events, and wave transitions
- `WaveManager` is created at runtime by `main.gd` and owns countdowns, wave composition spawning, battle start/end, and cleanup

## HUD / UI
- `SelectionPanel` shows bottom-left unit details for selected player units
- Single-unit selection currently shows:
  - HP
  - status
  - unit type
  - attack range
  - attack damage
  - attack speed
  - move speed
- `BuildingUpgradePanel` sits bottom-left and opens when clicking upgrade-capable buildings
- Upgrade buttons show level progress and tooltip cost/time on hover
- `BuildMenu` remains the structure-purchase UI and now includes tower/lancer content
- `WaveTimer`, speed controls, settings, and resource ribbon are still HUD-driven from `hud.gd`

## Buildings
- Castle must be placed first via `castle_prompt.tscn`; build button stays locked until then
- Generic placed structures are created through `placed_building.gd`
- `placed_building.gd` is responsible for:
  - sprite/collision/click area creation
  - drop animation and dust landing FX
  - spawn-indicator hookup for production buildings
  - building click selection
  - per-building upgrade definitions, timers, and level tracking
  - applying upgrade bonuses to newly spawned and already-live home units
- `building_indicator.gd` renders:
  - outer ring = production timer progress
  - center text = live units / cap
  - red/starved state when meat is missing

## Production Buildings
- All production buildings spend meat to create units
- Production pauses while a building upgrade is in progress
- Base production values before upgrades:
  - `castle.gd`: 3 pawns, every 5s, cost 1 meat
  - `barracks.gd`: 4 warriors, every 8s, cost 3 meat
  - `archery.gd`: 4 archers, every 8s, cost 3 meat
  - `monastery.gd`: 2 monks, every 10s, cost 2 meat
  - `tower.gd`: 3 lancers, every 10s, cost 4 meat

## Building Upgrades
- Upgrades are per-building, not global
- Shared combat-building upgrade categories:
  - attack damage
  - attack speed
  - move speed
  - HP
  - unit cap
  - production speed
- `archery` and `monastery` also expose range upgrades in the building panel
- `castle` has a worker-specific upgrade set:
  - move speed
  - unit cap
  - gather speed
  - production speed
  - bonus resources on turn-in
- Upgrade progress is tracked on the placed building and applied as runtime stat bonuses through `unit_base.gd`

## Units - Base Class
- `unit_base.gd` provides:
  - selection state and signals
  - map/wander bounds
  - shared nav movement and separation
  - HP bar, damage, healing, death flow
  - building bonus hooks
  - item bonus hooks
- Building bonus bundle currently supports:
  - attack damage bonus
  - attack speed multiplier
  - move speed multiplier
  - HP bonus
  - range bonus
  - gather speed multiplier
  - turn-in bonus
- Item bonuses are also tracked on the base unit and currently include:
  - attack damage
  - HP
  - range

## Units - Player
- **Pawn**
  - gathers resources and returns them to the castle
  - can receive castle upgrades for move speed, gather speed, cap, spawn speed, and extra turn-in yield
  - delivery flows through `pawn_delivered_resource` into `main.gd` / `ResourceManager`
- **Warrior**
  - melee defender with voice lines
  - now reads building bonuses and item range bonuses at runtime
- **Archer**
  - ranged kite unit using `arrow.tscn`
  - supports building range upgrades and item range bonuses
- **Monk**
  - support caster: heals allies first, attacks enemies second
  - idle/move heal scan remains active
  - supports building casting-range upgrades
- **Lancer**
  - heavy spear unit produced by towers
  - tower gameplay is active

## Items / Equipment
- Item/equipment logic exists in `item.gd`
- Item stat packages currently include examples such as:
  - tome -> range bonus
  - amulet -> attack damage + HP + range
- Unit stat display now resolves both building and item range bonuses where relevant

## Combat / Waves
- Countdown warning begins at 90s
- `WaveManager` progressively spawns enemies during prep time
- At wave start:
  - battle music and horn trigger
  - drawbridge raises
  - battle separator opens
  - player selection is cleared/disabled
  - nav is rebaked
- `WaveManager` snapshots battlefield unit positions at battle start and teleports surviving player units back afterward
- At wave end:
  - drawbridge lowers
  - victory/defeat audio plays
  - chill music resumes
  - unit control is restored if not in placement mode

## Enemies
- `enemy_base.gd` contains the shared enemy movement/combat state machine, HP, and target logic
- Current enemy scenes in active use:
  - `enemy_slime`
  - `enemy_badger`
  - `enemy_cat_boss`
- `enemy_warrior` still exists in the project but the current wave composition is built around slime, badger, and cat boss scenes
- Some enemy types can spawn additional enemies during battle through `WaveManager.register_enemy()`

## Wave Composition
- `wave_manager.gd` contains explicit wave composition tables rather than only a generic “gradual spawn” description
- Current waves include mixes of:
  - `enemy_slime`
  - `enemy_badger`
  - `enemy_cat_boss`
- Wave system already supports overflow scaling once predefined compositions are exhausted

## Effects / Projectiles
- `arrow.gd`: ranged projectile with weak homing, parabolic visual arc, and shadow
- `heal_effect.gd`: one-shot green/red effect used for monk healing and holy damage
- `combat_numbers.gd`: floating combat text system is present and can be toggled from gameplay settings

## Audio
### UiAudio
- UI clicks plus `building_land`
- `play_trimmed()` is used for drawbridge thump timing

### MusicManager
- Crossfades between chill and battle
- Countdown can trigger horn + battle music

### CombatAudio
- Pooled SFX playback with trim metadata
- Handles hurt/death, arrows, buffs, gather/delivery/resource impacts, and voice lines
- Exclusive cooldown gating still applies to key voice/gather sounds

### Audio Buses
- Master / Music / SFX
- Settings persist to `user://settings.cfg`

## Resources
- `ResourceManager` tracks gold, wood, and meat
- Emits `resources_changed`
- Supports:
  - `spend_*`
  - `spend(Dictionary)`
  - `has_*`
  - `add()`
- Starting values are configured by gameplay settings and then pushed into the HUD

## Settings / Speed
- Settings screen owns audio, display, and gameplay tabs
- Gameplay settings include:
  - starting resources
  - wave interval
  - combat numbers toggle
- Display changes call back into `_fit_camera_to_screen()`
- Speed controls remain `pause / 1x / 2x / 5x` through `Engine.time_scale`

## Git / Workspace Note
- This workspace is in a git repository
- Git commands are currently blocked in this environment by a Windows `safe.directory` / dubious ownership warning for `C:/Dev/The Wall`
- To use git normally here, the repo would need to be added to git’s safe directory list

## Not Built Yet / Still Rough
- House gameplay still looks unfinished
- End-state / full win-lose loop still appears incomplete
- Wave scaling and enemy balance are in progress rather than fully polished
- The upgrade and item systems exist, but they still need in-engine verification and balancing
