# Hybrid Enemy Spawning System Enhancement

## Overview
Enhance the current enemy spawning system to support both pooled enemies (current) and scene-based special bosses while maintaining the existing .tres workflow and performance characteristics.

## Context
- **Current System**: `WaveDirector` + `EnemyRegistry` with pooled `EnemyEntity` arrays
- **Goal**: Add special boss support via editor-created scenes while preserving existing architecture
- **Requirements**: Easy .tres-based content addition, future map event support

## Architecture Decision: Option B (Hybrid System)

### Hybrid Approach Visualization
```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   EnemyRegistry │────│   WaveDirector   │────│   Enemy Pool    │
│  (.tres files)  │    │                  │    │ (regular/rare)  │
└─────────────────┘    └─────────┬────────┘    └─────────────────┘
        │                        │                       
        │                        │              ┌─────────────────┐
        │                        └──────────────│  Scene Bosses   │
        │                                       │ (Node instances)│
        └───────────────────────────────────────└─────────────────┘
                       
    Decision Logic:
    if enemy_type.is_special_boss && enemy_type.boss_scene:
        → spawn scene-based boss
    else:
        → spawn pooled enemy (current system)
```

### Why Hybrid Was Chosen
**✅ Pros:**
- Preserves existing .tres files and workflow unchanged
- Performance optimization: pools for numerous enemies
- Full flexibility: editor-designed special bosses
- Future-proof: supports map events and complex encounters
- Incremental adoption: extend current system gradually

**Rejected Alternatives:**
- **Pure Pooled**: Limited boss complexity, no editor workflow
- **Pure Scene**: Performance issues, over-engineering for simple enemies

## Technical Implementation

### Phase 1: EnemyType.gd Extensions
```gdscript
extends Resource
class_name EnemyType

# Existing properties preserved...
@export var render_tier: String = "regular"  # Current: "swarm", "regular", "elite", "boss"

# NEW: Boss scene support
@export var boss_scene: PackedScene  # For special bosses - editor-created scenes
@export var is_special_boss: bool = false  # Flag for scene-based spawning
@export var boss_spawn_method: String = "pooled"  # "pooled" or "scene" (future extensibility)
```

### Phase 2: WaveDirector.gd Enhanced Spawn Logic
```gdscript
# Enhanced _spawn_enemy with hybrid routing
func _spawn_enemy() -> void:
    var enemy_type = enemy_registry.get_random_enemy_type("waves")
    _spawn_from_type(enemy_type, _get_spawn_position())

func _spawn_from_type(enemy_type: EnemyType, position: Vector2) -> void:
    if enemy_type.is_special_boss and enemy_type.boss_scene:
        _spawn_special_boss(enemy_type, position)
    else:
        _spawn_pooled_enemy(enemy_type, position)  # Current system unchanged

func _spawn_special_boss(enemy_type: EnemyType, position: Vector2) -> void:
    var boss_node = enemy_type.boss_scene.instantiate()
    get_tree().current_scene.add_child(boss_node)
    boss_node.global_position = position
    
    # Connect boss death to EventBus for XP/loot
    if boss_node.has_signal("died"):
        boss_node.died.connect(_on_special_boss_died.bind(enemy_type))

func _spawn_pooled_enemy(enemy_type: EnemyType, position: Vector2) -> void:
    # Existing pooled spawn logic - UNCHANGED
    var free_idx = _find_free_enemy()
    # ... current implementation
```

### Phase 3: Public API for Map Events
```gdscript
# Public API for future map event system
func spawn_boss_by_id(boss_id: String, position: Vector2) -> bool:
    var boss_type = enemy_registry.get_enemy_type(boss_id)
    if boss_type:
        _spawn_from_type(boss_type, position)
        return true
    return false

# Batch spawning for complex encounters
func spawn_event_enemies(spawn_data: Array[Dictionary]) -> void:
    # spawn_data format: [{"id": "dragon_lord", "pos": Vector2(100, 200)}]
    for data in spawn_data:
        spawn_boss_by_id(data.id, data.pos)
```

## Content Pipeline Examples

### Existing Enemies (Unchanged)
```tres
# knight_regular.tres - WORKS EXACTLY AS BEFORE
[gd_resource type="Resource" script_class="EnemyType"]
[resource]
script = ExtResource("EnemyType.gd")
id = "knight_regular"
health = 6.0
render_tier = "regular"
spawn_weight = 0.3
# is_special_boss defaults to false → pooled spawn
```

### New Rare Bosses (Pooled)
```tres
# knight_champion.tres - Still uses pooled system
[resource]
id = "knight_champion"
health = 50.0
render_tier = "rare"
spawn_weight = 0.05  # Very rare random spawn
# is_special_boss = false → pooled spawn
```

### Special Scene Bosses (New)
```tres
# dragon_lord.tres - Uses scene system
[resource]
id = "dragon_lord" 
health = 200.0
render_tier = "special_boss"
spawn_weight = 0.0  # Never random spawn
boss_scene = preload("res://scenes/bosses/DragonLord.tscn")
is_special_boss = true
boss_spawn_method = "scene"
```

## Implementation Plan

### Task Breakdown
1. **Extend EnemyType.gd** - Add boss scene properties
2. **Update WaveDirector spawn logic** - Add hybrid routing
3. **Create example special boss scene** - Validate scene workflow
4. **Add public spawn API** - For future map events
5. **Update EnemyRegistry** - Ensure scene-based enemies load properly
6. **Add signal handling** - Connect scene boss deaths to EventBus
7. **Test both spawn paths** - Verify pooled and scene spawning

### Validation Criteria
- ✅ Existing .tres files work unchanged
- ✅ New scene bosses spawn and behave correctly
- ✅ Performance maintained for pooled enemies  
- ✅ Hot-reload works for both enemy types
- ✅ EventBus integration for scene boss deaths
- ✅ Public API ready for map event system

## Future Extensions

### Map Event Integration
```gdscript
# Future map event usage
func trigger_boss_encounter():
    wave_director.spawn_boss_by_id("dragon_lord", event_position)
    
func spawn_miniboss_pack():
    var spawns = [
        {"id": "knight_champion", "pos": Vector2(100, 100)},
        {"id": "knight_champion", "pos": Vector2(200, 100)}
    ]
    wave_director.spawn_event_enemies(spawns)
```

### Boss Behavior Extensions
- Multi-phase bosses with state machines
- Complex attack patterns and abilities
- Custom death animations and effects
- Loot table integration

## Risk Mitigation

### Potential Issues
- **Mixed architectures complexity**: Mitigated by clear decision logic
- **Scene boss performance**: Limited by spawn_weight = 0.0 (event-only)
- **Signal connection cleanup**: Handle in boss scene _exit_tree()

### Testing Strategy
- Isolated tests for both spawn paths
- Performance testing with mixed enemy types
- Hot-reload validation for scene modifications
- EventBus integration testing

## Success Metrics
- Zero breaking changes to existing enemy spawning
- Special bosses spawnable via editor workflow (use knight sprite sheet as example for boss spawn)
- API ready for future map event system  
- Maintained performance characteristics
- Clear content creation pipeline for both enemy types

---

**Status**: 📋 **PLANNING**
**Priority**: High - Foundation for future boss and event systems
**Dependencies**: Current WaveDirector + EnemyRegistry system
**Timeline**: 2-3 development sessions