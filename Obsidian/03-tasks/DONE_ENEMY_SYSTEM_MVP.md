# Enemy System MVP - Phase 1
> Minimal viable implementation for enemy variety and data-driven spawning

## Goal
Get enemy variety working with existing systems in 1-2 days without breaking current functionality.

## Core Principles
- **Build on existing WaveDirector** - Don't replace working code
- **Keep MultiMesh rendering** - Already handles 800 enemies well  
- **Data-driven from JSON** - Follow existing BalanceDB patterns
- **Minimal disruption** - Other systems keep working

## Implementation Plan

### Day 1: Data Foundation

#### 1. Enemy Type System (2 hours)
```
CREATE: vibe/scripts/domain/EnemyType.gd
- Load from JSON files
- Validate schema
- Cache type definitions
```

#### 2. Enemy Entity Model (1 hour)
```
CREATE: vibe/scripts/domain/EnemyEntity.gd
- Extend current dictionary structure
- Add type reference
- Keep position, velocity, hp, alive
```

#### 3. Enemy Registry (2 hours)
```
CREATE: vibe/scripts/systems/EnemyRegistry.gd
- Load all enemy JSONs from /data/enemies/
- Integrate with BalanceDB hot-reload (F5)
- Provide type lookup
```

#### 4. Create Enemy JSON Files (1 hour)
```
CREATE: vibe/data/enemies/
├── grunt_basic.json      # Current red square enemy
├── slime_green.json      # First new enemy type
└── archer_skeleton.json  # Ranged enemy example
```

Schema:
```json
{
  "id": "slime_green",
  "display_name": "Green Slime",
  "health": 10.0,
  "speed": 50.0,
  "size": {"x": 24, "y": 24},
  "collision_radius": 12.0,
  "xp_value": 1,
  "spawn_weight": 0.3,
  "visual": {
    "color": {"r": 0.2, "g": 0.8, "b": 0.2, "a": 1.0},
    "shape": "circle"
  },
  "behavior": {
    "ai_type": "chase_player",
    "aggro_range": 300.0
  }
}
```

### Day 2: Integration

#### 5. Update WaveDirector (3 hours)
```
MODIFY: vibe/scripts/systems/WaveDirector.gd
- Add enemy_type field to pool
- Implement weighted spawning
- Use EnemyRegistry for type selection
```

Key changes:
- `_spawn_enemy()` → `_spawn_enemy_typed(type_id)`
- Add spawn weight calculation
- Keep existing pool structure

#### 6. Enhanced MultiMesh Rendering (2 hours)
```
MODIFY: vibe/scenes/arena/Arena.gd (_update_enemy_multimesh)
- Color enemies based on type
- Size variation per type
- Keep single MultiMesh for now
```

#### 7. Basic Behavior System (2 hours)
```
CREATE: vibe/scripts/systems/EnemyBehaviorSystem.gd
- Read enemy array from WaveDirector
- Update velocities based on ai_type
- Simple chase/flee patterns
```

#### 8. Testing & Debug (1 hour)
- Verify spawning works
- Check performance (maintain 60 FPS with 500 enemies)
- Hot-reload testing (F5)

## Success Criteria
✅ 3+ enemy types spawning with different colors/sizes
✅ Data-driven from JSON files
✅ Hot-reload working
✅ No performance regression
✅ Existing systems still work

## What This MVP Provides
- **Enemy variety** through JSON definitions
- **Visual differentiation** (color, size)
- **Basic AI behaviors** (chase, flee)
- **Foundation for expansion** without refactor

## What This MVP Doesn't Include
- ❌ Sprite animations (just colored shapes)
- ❌ Complex AI patterns
- ❌ Boss enemies
- ❌ Damage resistances/weaknesses
- ❌ Loot drops beyond XP

## Next Steps After MVP
→ See [ENEMY_SYSTEM_PHASE_2.md](ENEMY_SYSTEM_PHASE_2.md) for full implementation

## Code Examples

### EnemyType.gd (simplified)
```gdscript
extends Resource
class_name EnemyType

var id: String
var display_name: String
var health: float
var speed: float
var size: Vector2
var collision_radius: float
var xp_value: int
var spawn_weight: float
var visual_config: Dictionary
var behavior_config: Dictionary

static func from_json(data: Dictionary) -> EnemyType:
    var type := EnemyType.new()
    type.id = data.get("id", "unknown")
    type.health = data.get("health", 10.0)
    # ... populate other fields
    return type
```

### WaveDirector spawn change
```gdscript
func _spawn_enemy() -> void:
    var free_idx := _find_free_enemy()
    if free_idx == -1:
        return
    
    # NEW: Select enemy type based on weights
    var enemy_type := EnemyRegistry.get_random_enemy_type("waves")
    
    var enemy := enemies[free_idx]
    enemy["type_id"] = enemy_type.id  # NEW
    enemy["hp"] = enemy_type.health   # From type
    enemy["max_hp"] = enemy_type.health
    enemy["speed"] = enemy_type.speed
    enemy["size"] = enemy_type.size
    # ... rest stays same
```

## Risk Mitigation
- **Keep WaveDirector core logic** - Only add type support
- **Backward compatible** - Old spawning still works
- **Feature flag option** - Can disable new system if issues
- **Incremental testing** - Test each component separately

## Estimated Time: 12-16 hours (1.5-2 days)