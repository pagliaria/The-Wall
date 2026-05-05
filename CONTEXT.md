# The Wall — Project Context

## Game Overview
A 2D tower-defence style game built in Godot 4.4. Enemies spawn on the left side of the map and attack a player-built town on the right. The player gathers resources, constructs buildings, and commands units. Asset pack: **Tiny Swords (Free Pack)**.

---

## Development Preferences
- **UI layout in scene files** — UI elements and sprite frames should be defined as nodes in `.tscn` files rather than generated in code. Code-side generation is a last resort only for truly dynamic content (e.g. runtime tile queries).
- Scripts wire up signals and update state; scenes define structure and assets.
- Buildings place exactly where the ghost highlights — no automatic sprite offset or repositioning.

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
Main (Node2D)                      main.gd
├── wall (Node2D)                  drawbridge.gd — do not remove
│   ├── bridge_down (Sprite2D)     bridge_down.png, z=5, starts hidden
│   ├── bridge_up (Sprite2D)       bridge_up.png, z=5, starts visible
│   ├── base6–13 (Sprite2D)        wall_the_one.png segments, z=5
│   ├── Wall_Collision             StaticBody2D with collision shapes
│   └── AnimationPlayer            "lower" / "raise" animations (2.0s crossfade)
├── Terrain (Node2D)               terrain.gd
│   ├── WaterLayer                 TileMapLayer — water strip
│   ├── GroundLayer                TileMapLayer — terrain zones
│   ├── DecorationLayer            Node2D — bushes, rocks, water rocks
│   └── WallLayer                  Node2D — reserved for code-built wall
├── ResourceLayer (Node2D)         resource_spawner.gd
├── TownZone (Node2D)              anchor marker at (1280, 576)
├── EnemyZone (Node2D)             anchor marker at (352, 576)
├── Camera2D
├── HUD (CanvasLayer)              hud.gd
│   ├── ActionBar (NinePatchRect)  WoodTable_Slots.png — bottom-centre
│   │   └── BuildButton           hammer icon (Icon_01), opens build menu
│   ├── BuildMenu (Control)        build_menu.gd — centred popup
│   └── ResourceDisplay (Control)  resource_display.gd — top-right ribbon
├── BuildingsLayer (Node2D)        z=3 — container for all placed buildings
├── UnitsLayer (Node2D)            z=3 — container for all spawned units (pawns etc.)
├── UnitSelection (Node2D)         unit_selection.gd
│   └── Overlay (CanvasLayer)      always-on-top canvas for drag box
│       └── Draw (Node2D)          selection_overlay.gd — draws the drag rect
├── BuildingPlacer (Node2D)        building_placer.gd
│   ├── GhostSprite (Sprite2D)     ghost preview, hidden when not placing
│   └── ShapeCast2D                overlap check for placement validity
└── NavRegion (NavigationRegion2D) hand-drawn polygon covering town zone;
                                   excludes wall strip and water rows
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

#### Available Buildings
| ID | Name | Asset |
|---|---|---|
| archery | Archery Range | `Archery.png` |
| barracks | Barracks | `Barracks.png` |
| castle | Castle | `Castle.png` |
| house1 | House | `House1.png` |
| monastery | Monastery | `Monastery.png` |
| tower | Tower | `Tower.png` |

All from `assets/Buildings/Black Buildings/`. House2 and House3 removed (duplicate angles).

### Resource Display (`resource_display.tscn` / `resource_display.gd`)
- Single horizontal ribbon anchored top-right of screen
- Icons: `Icon_03` (gold), `Icon_02` (wood), `Icon_04` (meat)
- Labels updated via `set_resources(gold, wood, meat)` or individual setters
- Starting values: gold=100, wood=50, meat=25 (placeholder, set in `main.gd _ready()`)

---

## Wall & Drawbridge
Built manually in the editor under the `wall` Node2D. **Do not remove or modify from code.**

- Drawbridge controlled by `drawbridge.gd` on the `wall` node
- Press **B** to toggle — AnimationPlayer crossfades between `bridge_up` and `bridge_down` over 2.0 seconds
- `Wall_Collision` StaticBody2D has collision shapes for the wall segments

---

## Building Placement System

### Flow
1. Player clicks a building card → `building_selected` signal fires → build menu closes
2. `main.gd` calls `building_placer.start_placement(id)` and sets `unit_selection.disabled = true`
3. A ghost sprite follows the mouse snapped to the tile grid
4. Ghost tints **green** (valid) or **red** (invalid)
5. **Valid zone:** town zone only (col ≥ 20), non-water rows (row ≥ 3), no physics overlap
6. **Left-click** → confirm placement; **Right-click / Escape** → cancel
7. On confirm or cancel, `unit_selection.disabled` is restored to `false`

### `building_placer.gd`
- `start_placement(id)` — enters placement mode, loads ghost texture, sizes ShapeCast2D to the texture (minus `FOOTPRINT_PADDING = Vector2(64, 128)`)
- `cancel_placement()` — exits mode, emits `placement_cancelled`
- Emits `building_placed(building_id, tile)` on confirm

### `placed_building.gd` (StaticBody2D)
- Created at runtime by `main.gd._on_building_placed()`
- `setup(id, tile, units_layer)` — sets position to tile centre, loads sprite, creates collision sized to actual texture dimensions, creates click `Area2D`
- Stores `building_id` (String) and tile in metadata (`get_meta("tile")`)
- Emits `building_clicked(self)` on left-click → `main.gd._on_building_clicked()` (currently prints, future: open UI panel)
- Calls `_attach_controller(id)` which adds building-specific child Node controllers
- `get_controller()` — duck-typed lookup returning the first child with `get_live_pawns()`

---

## Buildings — Controllers

### Castle (`castle.gd`)
- Extends `Node`, attached as `CastleController` child of a placed castle building
- Spawns up to **3 pawns**, one every **5 seconds**
- Spawns at the tile directly **below** the castle (`tile.y + 1`)
- Timer resets when at max capacity so next pawn spawns promptly after a death
- Exposes `get_live_pawns()`, `get_max_pawns()`, `get_spawn_timer()` for future upgrade UI
- `units_layer` injected by `placed_building.gd` after adding to tree

---

## Units — Pawn

### Scene: `pawn.tscn`
```
Pawn (CharacterBody2D)    pawn.gd
├── Sprite (AnimatedSprite2D)   sprite frames defined in scene
├── Collision (CollisionShape2D) CircleShape2D radius=18, offset (0,10)
├── SelectionCircle (Node2D)    selection_circle.gd, z=2, hidden by default
└── NavAgent (NavigationAgent2D) path_desired_distance=8, target_desired_distance=16
```

### Animations (all 192×192px frames, 8 fps, Black Units asset set)
| Animation | Frames | Description |
|---|---|---|
| `idle` | 8 | Standing, no tool |
| `run` | 6 | Running, no tool |
| `idle_axe` | 8 | Idle holding axe |
| `run_axe` | 6 | Running with axe |
| `interact_axe` | 6 | Chopping with axe |
| `idle_gold` | 8 | Idle holding gold |
| `run_gold` | 6 | Running with gold |
| `idle_hammer` | 8 | Idle holding hammer |
| `run_hammer` | 6 | Running with hammer |
| `interact_hammer` | 6 | Building with hammer |
| `idle_knife` | 8 | Idle holding knife |
| `run_knife` | 6 | Running with knife |
| `interact_knife` | 6 | Attacking with knife |
| `idle_meat` | 8 | Idle holding meat |
| `run_meat` | 6 | Running with meat |
| `idle_pickaxe` | 8 | Idle holding pickaxe |
| `run_pickaxe` | 6 | Running with pickaxe |
| `interact_pickaxe` | 6 | Mining with pickaxe |
| `idle_wood` | 8 | Idle holding wood |
| `run_wood` | 6 | Running with wood |

### `pawn.gd` — State Machine
| State | Description |
|---|---|
| `IDLE` | Plays `idle` animation, waits 1–3.5s then picks next state |
| `MOVE` | Wanders randomly, biases back toward spawn if > 200px away |
| `MOVE_TO` | Moves directly to a commanded target position, then returns to `IDLE` |
| `GATHER` | Walks to a resource's collision body; steers toward live `world_position` each frame |
| `EXTRACTING` | Plays interact animation, counts down `extract_time`; on completion takes one chunk and enters `RETURN` |
| `RETURN` | Walks back to castle collision body; on touch delivers resource, loops back to `GATHER` if stock remains |

- **`move_to(target: Vector2)`** — enters `MOVE_TO` state; on arrival (within 12px) returns to `IDLE`
- **`gather_resource(resource_node, resource_body)`** — assigns gather target and enters `GATHER`
- **`on_resource_depleted()`** — called by `ResourceNode`; aborts gather and returns to `IDLE`
- **`set_selected(bool)`** — shows/hides `SelectionCircle`, emits `selected_changed`
- **`take_damage(amount)`** / **`die()`** — emits `died` signal, calls `queue_free()`
- **`request_push(direction, distance, requester_pos)`** — pushes pawn sideways when another unit collides during `MOVE_TO`
- Movement uses `NavigationAgent2D` for pathfinding — `_enter_state()` sets `nav_agent.target_position`; `_do_nav_move()` follows `get_next_path_position()` each frame
- Arrival for gather/return is **collision-based** (`move_and_collide` result checked against target body) — no magic radius constants
- `_ready()` defers first `_enter_state` call so nav mesh is ready before first path request
- Speed: 50 px/sec. Wander radius: 200px.

### Selection Circle (`selection_circle.gd`)
- Draws a flat cyan ellipse at the unit's feet (offset `Vector2(0, 36)`)
- Ellipse is scaled to 38% height to look grounded
- Radius 28, filled at 20% alpha, rim fully opaque

---

## Unit Selection System

### `unit_selection.gd` (Node2D in main scene)
- **LMB click** — point-selects nearest unit within 32px of click in world space
- **LMB drag** (> 6px travel) — box-selects all units whose screen position falls inside the drag rect
- **Shift + click/drag** — additive selection (toggle individual unit or add to group)
- **RMB** (units selected, over resource) — issues gather order to all selected units; cursor changes to `Cursor_02` when hovering a resource with units selected
- **RMB** (units selected, over ground) — issues move order to all selected units
- **RMB** (nothing selected) — deselects all
- Formation: up to 4 units wide, 32px spacing, centred on the click point. Additional rows offset downward.
- `disabled = true` while `BuildingPlacer` is active — set by `main.gd`

### `selection_overlay.gd` (Node2D inside CanvasLayer)
- Draws the drag-selection rectangle in screen space on top of everything
- Reads `_pressing` and `_drag_active` from parent `UnitSelection` node
- Cyan fill (8% alpha) + cyan border (70% alpha), 1.5px width

---

## Scripts

| File | Purpose |
|---|---|
| `main.gd` | Camera, zoom/pan, fullscreen, wires all systems together |
| `drawbridge.gd` | Toggles drawbridge on B key |
| `hud.gd` | Owns ActionBar, BuildMenu, ResourceDisplay — bubbles signals |
| `build_menu.gd` | Banner stitching, building card grid, building_selected signal |
| `resource_display.gd` | set_resources / set_gold / set_wood / set_meat |
| `terrain.gd` | Builds TileSet, fills terrain, scatters decorations |
| `resource_spawner.gd` | Spawns gold stones, trees, sheep in town zone; attaches ResourceNode to each |
| `resource_node.gd` | Tracks resource amount/type/extract time; arbitrates gatherer slots; signals depletion |
| `gold_stone.gd` | Periodic glint animation |
| `sheep.gd` | Sheep state machine: idle / graze / move |
| `building_placer.gd` | Ghost preview, tile validity, placement confirmation |
| `placed_building.gd` | Generic placed building — sprite, collision, click area, controller attachment |
| `castle.gd` | Castle controller — pawn spawning timer, live pawn tracking |
| `pawn.gd` | Player unit — wander AI, MOVE_TO, selection, push response, health |
| `unit_selection.gd` | Click and drag-box selection, move order issuing |
| `selection_circle.gd` | Draws flat ellipse indicator at unit feet |
| `selection_overlay.gd` | Draws drag-select rectangle in screen space |

---

## Camera
- Zoom calculated dynamically from window size — map always fills the window
- `zoom_min` set at runtime; user cannot zoom out beyond map bounds
- **Scroll wheel** — zoom toward mouse pointer
- **Middle mouse drag** — pan
- **Screen edge** (24px margin) — pan at 600 px/sec
- **F11** — toggle fullscreen

---

## Z-Index Layers

| Z | Layer | Contents |
|---|---|---|
| 0 | Ground | WaterLayer, GroundLayer |
| 1 | Decorations | Bushes, rocks, water rocks |
| 2 | Gold / SelectionCircle | Gold stones, unit selection rings |
| 3 | Units / Buildings | Sheep, pawns, placed buildings |
| 4 | Trees | Trees (render in front of everything) |
| 5 | Wall | Wall segments and bridge sprites |

---

## Collision System

| Node type | Used by | Notes |
|---|---|---|
| `StaticBody2D` + `CollisionShape2D` | Trees, gold stones, wall, placed buildings | Impassable |
| `CharacterBody2D` | Sheep, pawns | Uses `move_and_collide()` |
| `Area2D` | Placed buildings (click detection) | `input_pickable = true` |
| `ShapeCast2D` | BuildingPlacer | Overlap check during ghost preview |

---

## Resources (Town Zone)
All resources share one `placed: Array[Vector2i]` so nothing overlaps across types.

| Resource | Count | Script | Notes |
|---|---|---|---|
| Gold Stone 3 | 6 | `gold_stone.gd` | Static + periodic 6-frame glint, seed 99. 8 chunks, 3s/chunk |
| Tree1 / Tree2 | 10 | inline | 8-frame sway, random flip, seed 77. 5 chunks, 4s/chunk. Pawn navigates to stump |
| Sheep | 5 | `sheep.gd` | idle/graze/move/dead states, seed 55. 3 chunks, 5s/chunk. Dies on first extraction, stays harvestable. `world_position` updates every frame while alive |

---

## Key Constants

| Constant | File | Value |
|---|---|---|
| `MAP_COLS` / `MAP_ROWS` | terrain.gd | 48 / 27 |
| `WORLD_WIDTH` / `WORLD_HEIGHT` | main.gd | 3072 / 1728 |
| `COL_WILDS_END` / `COL_TOWN_START` | terrain.gd / others | 20 |
| `WATER_ROWS` | terrain.gd | 3 |
| `TILE_SIZE` | all scripts | 64 |
| `ZOOM_MAX` | main.gd | 2.0 |
| `MOVE_SPEED` (pawn) | pawn.gd | 50 px/sec |
| `WANDER_RADIUS` (pawn) | pawn.gd | 200 px |
| `ARRIVAL_RADIUS` (pawn) | pawn.gd | 12 px |
| `MAX_PAWNS` (castle) | castle.gd | 3 |
| `SPAWN_INTERVAL` (castle) | castle.gd | 5.0 sec |

---

## Navigation
- `NavRegion` (NavigationRegion2D) in main scene covers the town zone with a hand-drawn polygon excluding the wall strip and water rows
- After each building is placed, `main.gd._rebake_nav()` re-parses all `StaticBody2D` colliders in the scene tree and rebakes the nav mesh asynchronously using `NavigationServer2D.parse_source_geometry_data` + `bake_from_source_geometry_data`
- `agent_radius = 32.0` on the polygon gives pawns a clearance buffer around buildings
- Bake completion callback calls `NavigationServer2D.region_set_navigation_polygon()` to push the updated mesh to the live server
- `placed_building.gd` exposes `get_nav_footprint() -> Rect2` (reads its own CollisionShape2D) — currently unused but available

---

## What's Not Built Yet
- Enemy units and spawning
- Combat system (pawns attacking enemies)
- Resource costs for building placement
- Building upgrade UI (castle panel showing live pawns, upgrade options)
- Win/lose game state
- Other building controllers (barracks, tower, archery, monastery, house)
