# The Wall — Project Context

## Game Overview
A 2D tower-defence style game built in Godot 4.4. Enemies spawn on the left side of the map and attack a player-built town on the right. The player gathers resources and constructs defences. Asset pack: **Tiny Swords (Free Pack)**.

---

## World Layout
- **Map:** 48 × 27 tiles @ 64px = 3072 × 1728px (16:9)
- **Water strip:** top 3 rows across the full width

| Zone | Columns | Terrain |
|---|---|---|
| Enemy Wilds | 0 – 19 | Grass |
| Town Zone | 20 – 47 | Dirt |

Zone boundary is at `COL_WILDS_END = 20`. Noise warping is currently disabled in `_terrain_for_cell()` (commented out).

---

## Scene Tree
```
Main (Node2D)               main.gd
├── wall (Node2D)              manually built in editor — do not remove
│   ├── bridge_down (Sprite2D)  bridge_down.png, z=5
│   ├── bridge_up (Sprite2D)    bridge_up.png, z=5
│   ├── base6 (Sprite2D)        wall_the_one.png segment, z=5
│   ├── base7 (Sprite2D)        wall_the_one.png segment, z=5
│   ├── base11 (Sprite2D)       wall_the_one.png segment, z=5
│   ├── base12 (Sprite2D)       wall_the_one.png segment, z=5 (hidden)
│   └── base13 (Sprite2D)       wall_the_one.png segment, z=5 (hidden)
├── Terrain (Node2D)            terrain.gd
│   ├── WaterLayer              TileMapLayer — water strip
│   ├── GroundLayer             TileMapLayer — terrain zones
│   ├── DecorationLayer         Node2D — bushes, rocks, water rocks
│   └── WallLayer               Node2D — reserved for code-built wall
├── ResourceLayer (Node2D)      resource_spawner.gd
├── TownZone (Node2D)           anchor marker
├── EnemyZone (Node2D)          anchor marker
└── Camera2D
```

---

## Wall (In Progress)
Built manually in the editor under the `wall` Node2D in `main.tscn`. **Do not remove or modify from code.**

| Asset | File | Notes |
|---|---|---|
| Wall segments | `wall_the_one.png` | Sliced with `region_rect`, scaled 1.3x, z=5 |
| Bridge (down) | `bridge_down.png` | Gate/opening in the wall |
| Bridge (up) | `bridge_up.png` | Gate/opening in the wall |

Two segment nodes (`base12`, `base13`) are currently hidden — work in progress. `WallLayer` in the Terrain scene is reserved for a future code-built wall if needed.

---

## Scripts

| File | Purpose |
|---|---|
| `main.gd` | Camera setup, zoom/pan input, fullscreen toggle |
| `terrain.gd` | Builds TileSet in code, fills terrain, scatters decorations |
| `resource_spawner.gd` | Spawns gold, trees, and sheep in the town zone |
| `gold_stone.gd` | Gold stone behaviour — periodic one-shot glint animation |
| `sheep.gd` | Sheep state machine — idle / graze / move |

---

## Camera
- Zoom calculated dynamically from window size — map always fills the window
- `zoom_min` is set at runtime so the user can never zoom out beyond map bounds
- **Scroll wheel** — zoom toward mouse pointer
- **Middle mouse drag** — pan
- **Screen edge** — pan (24px margin)
- **F11** — toggle fullscreen

---

## Z-Index Layers
Fixed per type — no per-frame z sorting anywhere.

| Z | Layer | Contents |
|---|---|---|
| 0 | Ground | WaterLayer, GroundLayer |
| 1 | Decorations | Bushes, rocks, water rocks |
| 2 | Gold | Gold stones |
| 3 | Units | Sheep, future player/enemy units |
| 4 | Trees | Trees (render in front of everything) |

When adding new units, set `z_index = 3` and they will always render on top of gold and decorations, but behind trees.

---

## Collision System
All collision uses Godot's built-in physics — no manual obstacle lists anywhere.

| Node type | Used by | Notes |
|---|---|---|
| `StaticBody2D` + `CollisionShape2D` | Tree stumps, Gold stones | Impassable to all units automatically |
| `CharacterBody2D` | Sheep (and future units) | Uses `move_and_collide()`, bounces off any StaticBody2D |

Collision shapes, sizes, and offsets are tuned in-editor — do not adjust from code.

---

## Resources (Town Zone)
All resources share one `placed: Array[Vector2i]` so nothing overlaps across types.

| Resource | Count | Script | Notes |
|---|---|---|---|
| Gold Stone 3 | 6 | `gold_stone.gd` | Static sprite + periodic 6-frame glint, seed 99. Has StaticBody2D collision |
| Tree1 / Tree2 | 10 | inline | 8-frame looping sway, random flip, seed 77. Stump has StaticBody2D collision |
| Sheep | 20 | `sheep.gd` | State machine: idle(40%) graze(40%) move(20%), seed 55. CharacterBody2D |

Sheep wander within town zone bounds and flip to face direction of travel. Spacing constants (`GOLD_SPACING`, `TREE_SPACING`, `SHEEP_SPACING`) control minimum tile distance between each resource of that type.

---

## Decorations (terrain.gd)
Scattered after terrain paint, skipping empty cells (`get_cell_source_id == -1`):
- **Bushes** (4 variants, 8-frame animated) — town zone + deep wilds
- **Rocks** (4 variants, static) — wilds + no-man's land
- **Water rocks** (4 variants, 16-frame animated) — water strip

---

## Key Constants

| Constant | File | Value | Notes |
|---|---|---|---|
| `MAP_COLS` / `MAP_ROWS` | terrain.gd | 48 / 27 | Change map size here |
| `WORLD_WIDTH` / `WORLD_HEIGHT` | main.gd | 3072 / 1728 | Must equal MAP_* × 64 |
| `COL_WILDS_END` | terrain.gd | 20 | Zone boundary — also where wall sits |
| `COL_NOMANS_END` | terrain.gd | 20 | Currently same as WILDS_END (2-zone map) |
| `WATER_ROWS` | terrain.gd | 3 | Rows of water at top |
| `ZOOM_MAX` | main.gd | 2.0 | Closest zoom level |
| `Z_GOLD` | resource_spawner.gd | 2 | Z layer for gold stones |
| `Z_TREES` | resource_spawner.gd | 4 | Z layer for trees (frontmost) |
| `Z_UNITS` | resource_spawner.gd | 3 | Z layer for sheep, future units |

---

## What's Not Built Yet
- Enemy units and spawning
- Player units / combat system
- Town buildings (placement, construction)
- Resource collection mechanics
- UI / HUD
- Game state management (win/lose)
