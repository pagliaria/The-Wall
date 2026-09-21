# 🎯 Training Target System - Implementation Guide

## Overview

The training target system provides players with engaging inter-wave activities to practice combat techniques, test unit combinations, and build up their town without enemy pressure.

---

## What's Been Added

### 1. **Training Target Script** (`scripts/training_target.gd`)
A reusable script for creating practice targets in your town area.

**Key Features:**
- ✅ Two modes: **Basic** (free practice dummies, 300 HP) and **Combat** (800 HP, can attack back)
- ✅ Visual feedback: Red flash on hit, damage numbers, blood effects (for combat mode)
- ✅ Health bar with configurable colors
- ✅ Damage callback system for XP/healing chains
- ✅ Built-in collision detection via `Area2D`

**Signals:**
```gdscript
signal target_destroyed(target: Node)
signal health_changed(current: int, max: int)
signal spawning_complete
```

---

### 2. **Training Target Scene** (`scenes/training_target.tscn`)
Base scene template for training targets with all necessary nodes wired up.

**Scene Structure:**
```
TrainingTarget (StaticBody2D)
├── Sprite2D              # Visual representation
├── CollisionShape2D      # Hitbox
├── AreaHit               # Attackable zone (16 collision mask)
│   └── CollisionShape2D  # Inner hit area
├── SelectionCircle       # Visual selection highlight
├── CombatNumbers         # Damage display node
└── HealthBar             # HP bar overlay (optional)
```

---

### 3. **Main Integration** (`main.gd`)

The `main.gd` file has been updated with:

#### Constants Added:
```gdscript
const TRAINING_TARGET_BASIC_SCENE  = preload("res://scenes/training_target_dummy.tscn")
const TRAINING_TARGET_BASIC_HP     = 300
const TRAINING_TARGET_COMBAT_HP    = 800

var _training_targets             : Array = []
var _spawned_basic_count          : int = 0
var _spawned_combat_count         : int = 0
```

#### Methods Added:
| Method | Description | Example |
|--------|-------------|---------|
| `_setup_training_targets()` | Spawns 4 basic training targets on start | `main._setup_training_targets()` |
| `_cleanup_training_targets()` | Clears all targets between waves | Auto-called after each wave ends |
| `spawn_training_target(mode, position)` | Spawn new target (optional mode/position) | `spawn_training_target("basic")` |
| `get_random_town_position_for_dummy()` | Get random valid spawn position | Automatically used for basic targets |
| `_is_valid_position(position)` | Check if position is valid for spawning | Internal validation helper |
| `_training_target_config(mode)` | Get config dictionary for target setup | Returns HP and other settings |
| `get_training_target_count()` | Get count of active targets | Useful for UI indicators |

---

## How It Works

### **On Game Start**
```gdscript
# Training targets are automatically spawned in _ready()
main._setup_training_targets()  # Spawns 4 basic dummies
```

### **Between Waves**
When a wave ends:
1. All training targets are cleared (`_cleanup_training_targets()`)
2. Players can spawn new ones using `spawn_training_target()`
3. New targets appear in random town positions (avoiding buildings)

### **Damage Handling**
When units hit training targets:
1. `take_damage(amount, attacker)` is called
2. Visual feedback: Red flash + damage numbers
3. Blood effects spawn (combat mode only for high damage hits)
4. Health bar updates
5. If HP <= 0: Target destroyed and respawned on next wave

---

## Usage Examples

### **Spawn Basic Training Target (Free)**
```gdscript
main.spawn_training_target("basic")
# Automatically spawns at random town location
```

### **Spawn Combat Dummy (Advanced Practice)**
```gdscript
main.spawn_training_target("combat")
# Spawns near castle with higher HP and attack capability
```

### **Spawn at Specific Position**
```gdscript
var pos = Vector2(1000.0, 800.0)
main.spawn_training_target("basic", pos)
```

### **Check Active Targets**
```gdscript
var count = main.get_training_target_count()
print("Active training targets:", count)
```

---

## Integration with Your Game

### **UI Hook (Optional - Future Enhancement)**
You could add a UI button to spawn targets between waves:

```gdscript
# In HUD or a new "Training" menu panel
func _on_training_sparkles_pressed() -> void:
    main.spawn_training_target("basic")  # Free practice dummy
    print("Basic training target spawned!")
    
func _on_combat_dummy_pressed() -> void:
    if ResourceManager.gold >= 100:
        main.spawn_training_target("combat")
        print("Combat training target spawned!")
```

### **Building Upgrades (Future Enhancement)**
Training targets could be upgraded to have more HP, less damage reduction, or visual changes similar to building upgrades.

---

## Configuration Details

### **Basic Training Target**
| Property | Value | Description |
|----------|-------|-------------|
| `max_hp` | 300 | Starting health pool |
| `damage_reduction` | 50% | Takes 50% of incoming damage (no attack back) |
| `position` | Random town area | Avoids building zones |
| `cost` | Free | No resource cost to spawn or destroy |

### **Combat Training Target**
| Property | Value | Description |
|----------|-------|-------------|
| `max_hp` | 800 | Higher HP pool for serious practice |
| `damage_reduction` | 30% | Takes more damage, can attack back |
| `position` | Near castle area | Advanced training zone |
| `cost` | Gold (optional) | Can charge gold to spawn premium dummy |

### **Spawn Position Calculation**
- **Basic**: Random position between columns 23-34 and rows 8-15 (town center-ish)
- **Combat**: Near castle at column ~28, row ~7 (advanced practice zone)

---

## Visual Assets Used

The training target uses your existing `Chests.png` as a placeholder texture. You can:

1. **Replace with custom art** - Add new image files to `assets/Items/`
2. **Add multiple variations** - Create different textures for basic vs combat modes
3. **Add particle effects** - Spawn special effects on hit or destruction

---

## Future Enhancement Ideas

### **1. Upgrade System**
```gdscript
func upgrade_training_target(upgrade_id: String, level: int):
    match upgrade_id:
        "hp_boost": target.base_max_hp += 50
        "damage_reduction": target.damage_reduction -= 0.1
        "visual_theme": target._apply_visual_variant(level)
```

### **2. Merchant Caravan Integration**
Add temporary spawn discounts or special units between waves.

### **3. Training Scenarios**
Create predefined scenarios like:
- "Arrow Practice" - Targets that require archery hits
- "Melee Training" - Heavy armor targets for warrior practice
- "Combo Challenge" - Multiple weak targets appearing sequentially

---

## Files Modified/Created

| File | Purpose | Status |
|------|---------|--------|
| `scripts/training_target.gd` | Main training target logic | ✅ Created |
| `scenes/training_target.tscn` | Base scene template | ✅ Created |
| `scenes/training_target_dummy.tscn` | Dummy dummy scene (uses chest texture) | ✅ Created |
| `main.gd` | Integrated with training targets | ✅ Modified |
| `TRAINING_TARGET_README.md` | This documentation | ✅ Created |

---

## Testing Tips

1. **Start the game** - Should see 4 training targets in town area
2. **Attack with units** - Try using different unit types (archers, melee, monks)
3. **Observe visual feedback** - Red flash + damage numbers when hit
4. **Between waves** - Targets are cleared automatically
5. **Check spawn positions** - Should avoid overlapping buildings

---

## Notes & Considerations

- ⚠️ Training targets only work between waves (checked in `spawn_training_target()`)
- ⚠️ Target destruction is temporary - respawns on next wave or manual spawn
- ✅ Works with existing collision system and navmesh
- ✅ Compatible with building upgrade bonuses (if applicable)
- 💡 Can be extended with new visual assets anytime

---

## License / Credits

Created for "The Wall" Godot 4.4 town defense prototype.
