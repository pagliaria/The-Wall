# The Wall — Project Context

## Game Overview
A 2D tower-defence style game built in Godot 4.4. Enemies spawn on the left side of the map and attack a player-built town on the right. The player gathers resources and constructs defences. Asset pack: **Tiny Swords (Free Pack)**.

---

## Development Preferences
- **UI layout in scene files** — UI elements should be defined as nodes in `.tscn` files rather than generated in code. Code-side UI generation is a last resort (e.g. dynamic lists where count is unknown at edit time).
- Scripts should wire up signals and update state; scenes define the structure.

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
Main (Node2D)                    main.gd
├── wall (Node2D)                drawbridge.gd — do not remove
│   ├── bridge_down (Sprite2D)   bridge_down.png, z=5, starts hidden (alpha=0)
│   ├── bridge_up (Sprite2D)     bridge_up.png, z=5, starts visible
│   ├── base6–13 (Sprite2D)      wall_the_one.png segments, z=5
│   ├── Wall_Collision           StaticBody2D with collision shapes
│   └── AnimationPlayer          "lower" / "raise" animations (2.0s crossfade)
├── Terrain (Node2D)             terrain.gd
│   ├── WaterLayer               TileMapLayer — water strip
│   ├── GroundLayer              TileMapLayer — terrain zones
│   ├── DecorationLayer          Node2D — bushes, rocks, water rocks
│   └── WallLayer                Node2D — reserved for code-built wall
├── ResourceLayer (Node2D)       resource_spawner.gd
├── TownZone (Node2D)            anchor marker at (1280, 576)
├── EnemyZone (Node2D)           anchor marker at (352, 576)
├── Camera2D
└── HUD (CanvasLayer)            hud.gd
    ├── ActionBar (NinePatchRect) WoodTable_Slots.png — bottom-centre
    │   └── BuildButton          hammer icon (Icon_01), opens build menu
    ├── BuildMenu (Control)      build_menu.gd — centred popup
    └── ResourceDisplay (Control) resource_display.gd — top-centre ribbon
```

---

## HUD System

### Action Bar
- Anchored bottom-centre of screen via CanvasLayer (unaffected by camera zoom/pan)
- Background: `WoodTable_Slots.png` as NinePatchRect
- **Build Button**: `SmallBlueSquareButton` + `Icon_01` (hammer)
- Press hammer to toggle build menu open/close

### Build Menu (`build_menu.tscn` / `build_menu.gd`)
- Centred popup, anchored to screen centre (0.5, 0.5)
- Background: `Banner.png` stitched at runtime via pixel-alpha scanning (9-patch)
- Title ribbon uses `BigRibbons.png` with `MonteCarlo-Regular.ttf` font
- Close button: `SmallRedSquareButton` top-right
- Grid: 4 columns of building cards, built dynamically in `_build_grid()`
- Emits `building_selected(building_id: String)` → bubbles through `hud.gd` → `main.gd`
- Building cards are `PanelContainer` nodes created in code (dynamic count)

#### Available Buildings
| ID | Name | Gold | Wood |
|---|---|---|---|
| archery | Archery Range | TBD | TBD |
| barracks | Barracks | TBD | TBD |
| castle | Castle | TBD | TBD |
| house1 | House | TBD | TBD |
| monastery | Monastery | TBD | TBD |
| tower | Tower | TBD | TBD |

All from `assets/Buildings/Black Buildings/`. House2 and House3 removed (duplicate angles of House1).

### Resource Display (`resource_display.tscn` / `resource_display.gd`)
- Single horizontal ribbon anchored top-centre of screen
- Uses bottom ribbon from `SmallRibbons.png` (darkest slate, y=580, h=54)
  - Left cap: `Rect2(1.58, 580, 62.5, 54)`
  - Centre (×3 tiled): `Rect2(128.3, 580, 63.7, 54)`
  - Right cap: `Rect2(256, 580, 62, 54)`
- Icons: `Icon_03` (gold), `Icon_02` (wood), `Icon_04` (meat)
- Labels updated via `set_resources(gold, wood, meat)` or individual `set_gold/wood/meat()`
- Starting values set in `main.gd _ready()`: gold=100, wood=50, meat=25 (placeholder)

---

## Wall & Drawbridge
Built manually in the editor under the `wall` Node2D. **Do not remove or modify from code.**

| Asset | File | Notes |
|---|---|---|
| Wall segments | `wall_the_one.png` | Sliced with `region_rect`, scaled 1.3×, z=5 |
| Bridge (down) | `bridge_down.png` | Open/lowered state |
| Bridge (up) | `bridge_up.png` | Closed/raised state |

- Drawbridge controlled by `drawbridge.gd` on the `wall` node
- Press **B** to toggle — AnimationPlayer crossfades between `bridge_up` (visible) and `bridge_down` (visible) over 2.0 seconds
- `Wall_Collision` StaticBody2D has collision shapes for the wall segments

---

## Scripts

| File | Purpose |
|---|---|
| `main.gd` | Camera setup, zoom/pan input, fullscreen toggle, HUD wiring |
| `drawbridge.gd` | Toggles drawbridge animation on B key press |
| `hud.gd` | Owns ActionBar, BuildMenu, ResourceDisplay — bubbles signals to main |
| `build_menu.gd` | Banner stitching, dynamic building card grid, building_selected signal |
| `resource_display.gd` | Exposes set_resources / set_gold / set_wood / set_meat |
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

| Z | Layer | Contents |
|---|---|---|
| 0 | Ground | WaterLayer, GroundLayer |
| 1 | Decorations | Bushes, rocks, water rocks |
| 2 | Gold | Gold stones |
| 3 | Units | Sheep, future player/enemy units |
| 4 | Trees | Trees (render in front of everything) |
| 5 | Wall | Wall segments and bridge sprites |

---

## Collision System
All collision uses Godot's built-in physics — no manual obstacle lists anywhere.

| Node type | Used by | Notes |
|---|---|---|
| `StaticBody2D` + `CollisionShape2D` | Tree stumps, Gold stones, Wall | Impassable to all units |
| `CharacterBody2D` | Sheep (and future units) | Uses `move_and_collide()` |

---

## Resources (Town Zone)
All resources share one `placed: Array[Vector2i]` so nothing overlaps across types.

| Resource | Count | Script | Notes |
|---|---|---|---|
| Gold Stone 3 | 6 | `gold_stone.gd` | Static sprite + periodic 6-frame glint, seed 99 |
| Tree1 / Tree2 | 10 | inline | 8-frame looping sway, random flip, seed 77 |
| Sheep | 20 | `sheep.gd` | State machine: idle(40%) graze(40%) move(20%), seed 55 |

---

## Decorations (terrain.gd)
Scattered after terrain paint, skipping empty cells:
- **Bushes** (4 variants, 8-frame animated) — town zone + deep wilds
- **Rocks** (4 variants, static) — wilds + no-man's land
- **Water rocks** (4 variants, 16-frame animated) — water strip

---

## Key Constants

| Constant | File | Value | Notes |
|---|---|---|---|
| `MAP_COLS` / `MAP_ROWS` | terrain.gd | 48 / 27 | Change map size here |
| `WORLD_WIDTH` / `WORLD_HEIGHT` | main.gd | 3072 / 1728 | Must equal MAP_* × 64 |
| `COL_WILDS_END` | terrain.gd | 20 | Zone boundary — wall sits here |
| `WATER_ROWS` | terrain.gd | 3 | Rows of water at top |
| `ZOOM_MAX` | main.gd | 2.0 | Closest zoom level |
| `Z_GOLD` | resource_spawner.gd | 2 | Z layer for gold stones |
| `Z_TREES` | resource_spawner.gd | 4 | Z layer for trees |
| `Z_UNITS` | resource_spawner.gd | 3 | Z layer for sheep, future units |

---

## What's Not Built Yet
- Enemy units and spawning
- Player units / combat system
- Building placement (ghost preview → click to place)
- Resource costs and collection mechanics
- Game state management (win/lose)
