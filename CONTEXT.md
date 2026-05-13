# The Wall - Project Context

## Overview
Godot 4.4 town-defense prototype. The player builds a town on the right side of the map, gathers resources, trains units, upgrades production buildings, and stages defenders for incoming waves. The project leans on scene-driven UI and visuals with code-driven state machines, spawning, combat, and navigation.

## World
- Map: `48x27` tiles at `64px` (`3072x1728`)
- Water: top 3 rows
- Wilds: cols `0-19`
- Town: cols `20-47`
- Enemy side: `x 0-640`
- Battlefield / staging gap: `x 640-1280`
- Town interior: `x 1280+`

## Architecture
- `main.gd` wires the game together, owns placement flow, HUD coordination, wave startup/end, and nav rebakes
- Autoloads: `ResourceManager`, `UiAudio`, `MusicManager`, `CombatAudio`
- `ResourceLayer` spawns gold, trees, and sheep while respecting placed building footprints
- `BuildingsLayer` holds all placed structures
- `BuildingPlacer` handles ghost placement, overlap checks, and emits placement/cancel signals
- `UnitsLayer` contains player units and live enemies
- `UnitSelection` handles box/single select, move orders, gather orders, cursor swapping, and now ignores clicks while hovering UI
- `NavRegion` is rebaked after building placement, depletion events, and wave transitions
- `WaveManager` is created at runtime by `main.gd` and owns countdowns, battle state, progressive enemy spawning, and end-of-wave cleanup

## HUD / UI
- `SelectionPanel` shows bottom-left unit details for selected player units
- Single-unit selection now shows HP, status, unit type, attack range, attack damage, attack speed, and move speed
- `BuildingUpgradePanel` sits bottom-left and opens when clicking upgrade-capable buildings
- Upgrade buttons show level progress plus tooltip cost/time on hover
- Clicking UI should no longer leak through into world selection input
- `BuildMenu` remains the main structure-purchase UI
- `WaveTimer`, speed controls, settings, and resource ribbon are still HUD-driven from `hud.gd`

## Buildings
- Castle must be placed first via `castle_prompt.tscn`; build button stays locked until then
- Generic placed structures are created through `placed_building.gd`
- `placed_building.gd` is now responsible for:
  - building sprite/collision/click area creation
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
- Shared combat-building upgrade categories currently include:
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
- Upgrade progress is tracked on the placed building itself and applied as runtime stat bonuses through `unit_base.gd`

## Units - Base Class
- `unit_base.gd` provides:
  - selection state and signals
  - map/wander bounds
  - shared nav movement and separation
  - HP bar, damage, healing, death flow
  - building bonus hooks for spawned-unit stat modifiers
- Building bonus bundle currently supports:
  - attack damage bonus
  - attack speed multiplier
  - move speed multiplier
  - HP bonus
  - range bonus
  - gather speed multiplier
  - turn-in bonus

## Units - Player
- **Pawn**
  - gathers resources and returns them to the castle
  - can receive castle upgrades for move speed, gather speed, cap, spawn speed, and extra turn-in yield
  - delivery still flows through `pawn_delivered_resource` into `main.gd` / `ResourceManager`
- **Warrior**
  - melee defender with voice lines
  - now reads building attack/move/HP bonuses at runtime
- **Archer**
  - ranged kite unit using `arrow.tscn`
  - supports building range upgrades in addition to shared combat bonuses
- **Monk**
  - support caster: heals allies first, attacks enemies second
  - idle/move heal scan remains active
  - supports building casting-range upgrades plus shared combat bonuses
- **Lancer**
  - heavy spear unit produced by towers
  - tower gameplay is now active rather than placeholder-only

## Combat / Waves
- Countdown warning begins at 90s
- `WaveManager` gradually spawns enemies during the prep phase
- At wave start:
  - battle music/horn trigger
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
- Current enemy roster is broader than the old context file:
  - `enemy_warrior`
  - `enemy_slime`
  - `enemy_badger`
  - `enemy_cat_boss`
- Some enemy types can spawn additional enemies during battle through `WaveManager.register_enemy()`

## Effects / Projectiles
- `arrow.gd`: ranged projectile with weak homing, parabolic visual arc, and shadow
- `heal_effect.gd`: one-shot green/red effect used for monk healing and holy damage
- `combat_numbers.gd`: floating combat text is present in the project

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
- Supports `spend_*`, `spend(Dictionary)`, `has_*`, and `add()`
- Starting values are still configured by gameplay settings and then pushed into HUD

## Settings / Speed
- Settings screen still owns audio, display, and gameplay tabs
- Display changes call back into `_fit_camera_to_screen()`
- Gameplay settings include starting resources and wave interval
- Speed controls remain `pause / 1x / 2x / 5x` through `Engine.time_scale`

## Git / Workspace Note
- This workspace is in a git repository, but git commands are currently blocked by a Windows "dubious ownership" safe-directory warning for `C:/Dev/The Wall`
- To use git normally in this environment, the repo would need to be added to git's safe directory list

## Not Built Yet / Still Rough
- House gameplay still looks unfinished
- End-state / full win-lose game loop still appears incomplete
- Wave scaling and enemy variety are in progress rather than fully polished
- The context file may need another refresh after the newest range/worker-upgrade pass is fully playtested in-engine
