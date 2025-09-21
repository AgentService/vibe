# Enemy Entity Architecture

**Status:** ✅ Implemented (August 2025)  
**Purpose:** Typed object wrapper for enemy data with Dictionary compatibility  
**Location:** `scripts/domain/EnemyEntity.gd`

## 🏗️ Overview

[[EnemyEntity]] provides compile-time type safety while maintaining compatibility with existing Dictionary-based systems. It serves as a bridge between the data-driven JSON configuration and the performance-optimized MultiMesh rendering pipeline.

## 🎯 Design Goals

### Type Safety
- **Compile-time guarantees**: All enemy properties have explicit types
- **IDE support**: Full autocomplete and error checking
- **Runtime validation**: `is_valid()` method ensures data integrity

### Performance
- **Zero allocation**: Reuses pooled objects in [[WaveDirector]]
- **Dictionary compatibility**: Direct conversion for MultiMesh systems
- **Memory efficient**: Extends Resource for optimal Godot integration

### Flexibility
- **Backward compatibility**: Works with existing Dictionary-based code
- **Future-proof**: Easy to extend with new properties
- **Migration friendly**: Gradual conversion from Dictionary approach

## 📋 Class Structure

```gdscript
class_name EnemyEntity extends Resource

# Core runtime properties
var type_id: String      # Links to EnemyType definition
var pos: Vector2         # World position
var vel: Vector2         # Current velocity
var hp: float           # Current health points
var max_hp: float       # Maximum health points
var alive: bool         # Life state
var speed: float        # Movement speed
var size: Vector2       # Collision dimensions
```

## 🔄 Conversion Methods

### Dictionary Compatibility
```gdscript
# Convert to Dictionary for MultiMesh systems
func to_dictionary() -> Dictionary:
    return {
        "pos": pos,
        "vel": vel,
        "hp": hp,
        "max_hp": max_hp,
        "alive": alive,
        "type_id": type_id,
        "speed": speed,
        "size": size
    }

# Create from Dictionary (migration helper)
static func from_dictionary(enemy_dict: Dictionary, enemy_type: EnemyType = null) -> EnemyEntity
```

### Type Setup Integration
```gdscript
# Setup with EnemyType for proper defaults
func setup_with_type(enemy_type: EnemyType, spawn_pos: Vector2, velocity: Vector2) -> void:
    pos = spawn_pos
    vel = velocity
    hp = enemy_type.health
    max_hp = enemy_type.health
    alive = true
    type_id = enemy_type.id
    speed = enemy_type.speed
    size = enemy_type.size
```

## 🔗 System Integration

### [[WaveDirector]] Pool Management
```gdscript
# Pre-allocated typed array
var enemies: Array[EnemyEntity] = []

# Pool initialization
func _initialize_pool() -> void:
    enemies.resize(max_enemies)
    for i in range(max_enemies):
        enemies[i] = EnemyEntity.new()

# Spawning with type safety
var enemy := enemies[free_idx]
enemy.setup_with_type(enemy_type_obj, spawn_pos, direction * enemy_type_obj.speed)
```

### [[EnemyRenderTier]] Conversion
```gdscript
# Group typed objects by visual tier
func group_enemies_by_tier(alive_enemies: Array[EnemyEntity], enemy_registry: EnemyRegistry) -> Dictionary:
    for enemy in alive_enemies:
        var enemy_type: EnemyType = enemy_registry.get_enemy_type(enemy.type_id)
        var tier: Tier = get_tier_for_enemy(enemy_type)
        var enemy_dict: Dictionary = enemy.to_dictionary()  # Convert for MultiMesh
        
        match tier:
            Tier.SWARM: swarm_enemies.append(enemy_dict)
            # ... other tiers
```

### Signal Architecture
```gdscript
# WaveDirector emits typed arrays
signal enemies_updated(alive_enemies: Array[EnemyEntity])

# Arena processes with type safety
func _on_enemies_updated(alive_enemies: Array[EnemyEntity]) -> void:
    var grouped_enemies = enemy_render_tier.group_enemies_by_tier(alive_enemies, enemy_registry)
    # Update MultiMesh instances with Dictionary arrays
```

## ⚡ Performance Benefits

### Memory Management
- **Pool reuse**: No object allocation during gameplay
- **Reference tracking**: Systems can hold direct object references
- **Cache locality**: Contiguous array storage in WaveDirector

### Collision Detection
```gdscript
# Enhanced DamageSystem with object identity
for e_idx in range(alive_enemies.size()):
    var enemy := alive_enemies[e_idx]
    if not enemy.alive:  # Direct property access
        continue
    var enemy_pos := enemy.pos  # Type-safe Vector2
```

### Combat Integration
```gdscript
# Direct property updates with type safety
func damage_enemy(enemy_index: int, damage: float) -> void:
    var enemy := enemies[enemy_index]
    enemy.hp -= damage  # Direct property access
    
    if enemy.hp <= 0.0:
        enemy.alive = false  # Type-safe boolean
```

## 🔍 Validation & Safety

### Runtime Validation
```gdscript
func is_valid() -> bool:
    return not type_id.is_empty() and max_hp > 0.0 and speed >= 0.0
```

### Pool Safety
- **Bounds checking**: All pool access validates array indices
- **State validation**: Alive flag prevents processing dead enemies
- **Type validation**: EnemyType lookup ensures valid configurations

## 🚀 Migration Benefits

### Incremental Adoption
1. **Dictionary systems continue working**: `to_dictionary()` provides compatibility
2. **New systems use typed access**: Direct property access with IDE support  
3. **Gradual conversion**: Systems migrate one at a time

### Development Experience
- **IntelliSense support**: Full property autocomplete
- **Compile-time errors**: Catch type mismatches before runtime
- **Refactoring safety**: IDE-assisted property renaming

## 🔄 Data Flow Pipeline

```
JSON Enemy Definitions (EnemyType)
    ↓
WaveDirector Pool (Array[EnemyEntity])
    ↓
Signal: enemies_updated(Array[EnemyEntity])
    ↓
EnemyRenderTier.group_enemies_by_tier()
    ↓
Dictionary Arrays (MultiMesh compatibility)
    ↓
Arena.gd MultiMesh Updates
```

## 📈 Future Enhancements

### Immediate Extensions
- **Animation state**: Add current animation frame tracking
- **Status effects**: Buffs/debuffs with typed effect arrays
- **AI state**: Current behavior state (now handled by WaveDirector)

### Advanced Features
- **Component system**: Modular enemy capabilities
- **Serialization**: Save/load enemy states for persistent worlds
- **Network sync**: Multiplayer state synchronization

## 🔗 Related Systems

- [[WaveDirector]]: Pool management and spawning
- [[EnemyRenderTier]]: Visual tier assignment and Dictionary conversion  
- [[DamageSystem]]: Collision detection with object identity
- [[MeleeSystem]]: Combat integration with pool references
- [[EventBus-System]]: Signal architecture with Array[EnemyEntity]

---

**Implementation History:**
- **August 24, 2025**: Complete Dictionary to EnemyEntity migration
- **Type Safety**: Added compile-time guarantees for all enemy operations
- **Pool Integration**: Zero-allocation gameplay with pre-allocated objects
- **Signal Updates**: EventBus now uses Array[EnemyEntity] for enemies_updated