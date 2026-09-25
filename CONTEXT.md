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
- Sudden death: `WaveManager.sudden_death_delay` seconds into a battle (0 = off), every combatant (player, battle hired, enemies, bosses included) takes escalating %-max-HP damage each second. Tuning consts `SUDDEN_DEATH_*` in `wave_manager.gd`. HUD: `sudden_death_banner.tscn` (top-center, pulse animation) fed by `sudden_death_changed`; warns during last 15s. Visual: `sudden_death_overlay.tscn` (world-space, covers the same battlefield rect as `battlefield_overlay.gd`) pulses a green plague fog and rains cosmetic falling arrows while active; no collision, no damage. Setting: Gameplay tab "Sudden Death After (seconds)", applies live on Apply, persists as `gameplay/sudden_death_delay`, default 90.
- Battle roster: `_player_units` and `_battle_hired_units` are committed in `_begin_battle` using the player-battlefield x-range (640 to 1280). Units behind the wall (town) never join, count for win/loss, or get targeted. `_hired_units` is every hire the player owns. `get_hired_units()` returns the battle subset during a battle, all hires otherwise.
- `enemy_base.gd` contains the shared enemy state machine and targeting.
- Active enemy content includes slime, badger, boar, witch doctor, skeleton, and cat boss variants.

## Audio / Settings
- Audio is split across `UiAudio`, `MusicManager`, and `CombatAudio`.
- Settings persist to `user://settings.cfg`.
- Gameplay settings include starting resources, wave interval, and combat numbers.
- Debug tab (needs "Enable Debug Tools"): spawn chest, max resources, and "Mirror My Defense As Enemy" (`CheckDebugMirror`). Mirror sets `WaveManager.debug_mirror_defense`; each wave the player's units in no man's land are captured and respawned as hostile mirrored enemies via the versus rebuild path (`spawn_mirrored_defense`). Nothing saved/uploaded. Empty defense falls back to PvE wave. Persists as `debug/mirror_defense` in `settings.cfg`.

## Versus Mode (async ghost PvP)
- No live netcode. Each player fights a mirrored copy of another player's saved defense.
- `GameMode` autoload: `Mode.SOLO` / `Mode.VERSUS`, plus persistent `player_id` / `player_name` (`user://profile.cfg`).
- `mode_select.tscn` (opened from title Start) picks the mode.
- `wave_manager.gd`, versus wave start: `capture_defense_snapshot()` -> save JSON to `user://defense_snapshots/wave_N.json` -> `_get_opponent_snapshot()` -> `spawn_mirrored_defense()`.
- Snapshot schema v2: `player_id`, `player_name`, `game_version`, `day`, `captured_at`, `power`, `units[]`, `hired_units[]`.
- `sanitize_snapshot()` rebuilds every snapshot from scratch (own + incoming): whitelisted unit types (`MIRRORABLE_UNIT_TYPES`), level/position/bonus clamps (`BONUS_LIMITS` mirrors `placed_building.gd` upgrade maxima), valid item enums, unit count caps. `power` always recomputed locally.
- Hired units ride in the snapshot as `hired_units[]` = `{hire_id, position}` (id from `house.gd` `HIRE_ROSTER`; no stats needed, every hire of an id is identical). Only hired units standing in no man's land (x 640-1280) at gate close are captured, same rule as player units. Self-summoned hires (hired Witch Doctor skeletons) have no `hire_id` meta, so `_get_hire_id()` matches by scene path. Mirrored copies are plain `enemy_*.tscn` (faction enemy, `hired = false`).
- Empty own snapshot is not saved. Empty/invalid opponent snapshot falls back to that wave's PvE composition (`_spawn_pve_fallback()`).
- `spawn_mirrored_defense()` returns spawned count. `register_enemy()` only parents nodes that have no parent yet.
- Backend: Supabase free tier (PostgREST). `supabase/schema.sql` (run once in SQL Editor) creates `defense_snapshots` (anon insert-only via RLS, size/range checks, trigger keeps one row per player+wave) and RPC `get_opponent_snapshot(p_wave, p_power, p_exclude)` (one random snapshot, prefers +-40% power). Free projects pause after 7 days idle; first request after pause is slow.
- `SnapshotService` autoload SCENE (`scenes/snapshot_service.tscn`, script `snapshot_service.gd`): 3 HTTPRequest child nodes (Upload/Fetch/Test) with signals wired in the scene. Config in `user://versus.cfg` (URL, publishable key, `allow_self_match`). Key goes on `apikey` header ONLY (no Authorization Bearer). Signals: `opponent_fetched`, `snapshot_uploaded`, `request_failed`, `connection_tested`.
- Flow: `_prepare_next_wave()` -> `_begin_opponent_fetch()` (async, wave = `_wave_number + 1`, power = `estimate_defense_power()`) -> `_on_opponent_fetched` stores sanitized snapshot in `_pending_opponent_snapshot` -> wave start: `_start_versus_battle()` uploads own snapshot, spawns pending opponent. Nothing arrived / empty = PvE wave fallback. No loopback anymore.
- Settings screen has a Versus tab (player name, server URL, key, self-match testing toggle, Test button). Values live in `GameMode` / `SnapshotService`, not `settings.cfg`.
- TODO: `versus_status.tscn` HUD panel (opponent name / fetch status), result reporting, version filter on matchmaking.

## Notes
- The project is in git, but git commands are blocked here by a Windows `safe.directory` warning for `C:/Dev/The Wall`.
