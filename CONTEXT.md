# The Wall — Project Context

## Game Overview
A 2D tower-defence style game built in Godot 4.4. Enemies spawn on the left side of the map and attack a player-built town on the right. The player gathers resources and constructs defences. Asset pack: **Tiny Swords (Free Pack)**.

---

## World Layout
- **Map:** 48 × 27 tiles @ 64px = 3072 × 1728px (16:9)
- **Water strip:** top 3 rows across the full width

| Zone | Columns | Terrain |
|---|---|---|
| Enemy Wilds | 0 – 10 | Dark grass + stone patches |
| No-Man's Land | 11 – 19 | Dirt + stone rubble |
| Town Zone | 20 – 47 | Grass |

Zone borders are **noise-warped** (±3 tiles) so edges are organic, not straight lines. Godot's **blob/Wang terrain autotiling** (`set_cells_terrain_connect`) handles edge and corner tile selection automatically.

---

## Scene Tree
```
Main (Node2D)               main.gd
├── Terrain (Node2D)        terrain.gd
│   ├── WaterLayer          TileMapLayer — water strip
│   ├── GroundLayer         TileMapLayer — terrain zones
│   └── DecorationLayer     Node2D — bushes, rocks, water rocks
├── ResourceLayer (Node2D)  resource_spawner.gd
├── TownZone (Node2D)       anchor marker
├── EnemyZone (Node2D)      anchor marker
└── Camera2D
```

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

## Resources (Town Zone)
All resources share one `placed: Array[Vector2i]` so nothing overlaps across types.

| Resource | Count | Script | Notes |
|---|---|---|---|
| Gold Stone 3 | 6 | `gold_stone.gd` | Static sprite + periodic 6-frame glint, seed 99 |
| Tree1 / Tree2 | 10 | inline | 8-frame looping sway, random flip, seed 77 |
| Sheep | 6 | `sheep.gd` | State machine: idle(40%) graze(40%) move(20%), seed 55 |

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
| `COL_WILDS_END` | terrain.gd | 11 | End of enemy zone |
| `COL_NOMANS_END` | terrain.gd | 20 | End of no-man's land / start of town |
| `WATER_ROWS` | terrain.gd | 3 | Rows of water at top |
| `ZOOM_MAX` | main.gd | 2.0 | Closest zoom level |
| `Z_GOLD` | resource_spawner.gd | 2 | Z layer for gold stones |
| `Z_TREES` | resource_spawner.gd | 4 | Z layer for trees (frontmost) |
| `Z_UNITS` | resource_spawner.gd | 3 | Z layer for sheep, future units |
| `STUMP_RADIUS` | resource_spawner.gd | 28.0 | Collision radius (px) around each tree stump |

---

## What's Not Built Yet
- Enemy units and spawning
- Player units / combat system
- Town buildings (placement, construction)
- Resource collection mechanics
- UI / HUD
- Game state management (win/lose)
