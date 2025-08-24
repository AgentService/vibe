# Enemy System Architecture

**Status:** ✅ Implemented (August 2025)  
**Architecture:** Typed EnemyEntity objects with JSON-driven configuration and 4-tier visual classification  
**Performance:** MultiMesh batch rendering for thousands of enemies with pooled object management

## 🏗️ System Overview

The enemy system uses typed [[EnemyEntity]] objects backed by data-driven JSON configuration. All enemy definitions live in JSON files, with runtime objects providing type safety and performance optimization through object pooling.

### Core Principles
- **Typed Objects**: EnemyEntity provides compile-time safety while maintaining Dictionary compatibility
- **JSON-Driven**: No hardcoded enemy definitions, pure data-driven configuration
- **Tier-Based Rendering**: [[EnemyRenderTier]] system for visual hierarchy and performance scaling
- **Object Pooling**: Pre-allocated enemy pools in [[WaveDirector]] for zero-allocation gameplay
- **Visual Clarity**: Color-coded tiers for gameplay clarity and debugging support

## 📊 Data Flow Pipeline

```
JSON Files → EnemyRegistry → WaveDirector → EnemyEntity Pool → EnemyRenderTier → MultiMesh
    ↓              ↓             ↓              ↓                   ↓               ↓
Registry     Individual     Pool Mgmt      Typed Objects      Tier Assignment   Rendering
Loading      Enemy Data     (Spawning)     (Type Safety)      (Visual Routing)  (GPU Batch)
```

### 1. JSON Loading Phase
- **Registry**: `enemy_registry.json` lists all available enemy types with spawn weights
- **Individual**: Each `knight_*.json` contains complete enemy definition (health, speed, size, etc.)
- **Validation**: Schema validation ensures consistent data structure and type safety

### 2. Object Pool Initialization
- **Pool Creation**: [[WaveDirector]] pre-allocates Array[EnemyEntity] with max_enemies capacity
- **Zero Allocation**: Runtime spawning reuses pooled objects, no garbage collection during gameplay
- **Type Setup**: EnemyEntity.setup_with_type() configures pooled objects from [[EnemyType]] resources

### 3. Tier Assignment Phase
- **[[EnemyRenderTier]]**: Converts Array[EnemyEntity] to Dictionary arrays grouped by visual tier
- **Type-Based**: Primary assignment using EnemyType.render_tier property
- **Size Fallback**: Pixel dimension boundaries when type data unavailable
- **Dictionary Conversion**: EnemyEntity.to_dictionary() provides MultiMesh compatibility

### 4. Rendering Phase
- **Tier Routing**: Each tier (SWARM/REGULAR/ELITE/BOSS) uses dedicated MultiMeshInstance2D
- **Batch Updates**: GPU instancing with tier-specific colors and transforms
- **Performance Scaling**: SWARM enemies optimized for high counts, BOSS for individual detail

## 🎯 Enemy Type Specifications

### Knight Enemy Family
| Type | Size | Tier | Color | Weight | HP | Speed | Purpose |
|------|------|------|-------|--------|----|----|-------|
| knight_swarm | 20px | SWARM | Red | 40% | 3.0 | 80 | Fast, numerous |
| knight_regular | 36px | REGULAR | Green | 30% | 6.0 | 60 | Balanced |
| knight_elite | 56px | ELITE | Blue | 20% | 12.0 | 45 | Tanky |
| knight_boss | 80px | BOSS | Magenta | 10% | 30.0 | 30 | High-value target |

### Tier Assignment Rules
```gdscript
# Size-based boundaries
SWARM_MAX_SIZE = 24.0     # ≤24px
REGULAR_MAX_SIZE = 48.0   # 25-48px  
ELITE_MAX_SIZE = 64.0     # 49-64px
BOSS_MIN_SIZE = 65.0      # >64px

# Type-based overrides (primary)
match type_id:
    "knight_swarm": return Tier.SWARM
    "knight_regular": return Tier.REGULAR
    "knight_elite": return Tier.ELITE
    "knight_boss": return Tier.BOSS
```

## 🗂️ File Structure

### Data Files
```
/vibe/data/enemies/
├── config/
│   ├── enemy_registry.json    # Central registry (spawn weights)
│   └── enemy_tiers.json       # Tier boundaries & render configs
├── knight_swarm.json          # Fast, small enemies
├── knight_regular.json        # Balanced enemies  
├── knight_elite.json          # Tank enemies
└── knight_boss.json           # High-value enemies
```

### System Files
```
/vibe/scripts/
├── domain/
│   ├── EnemyType.gd           # JSON enemy definition wrapper
│   └── EnemyEntity.gd         # Runtime typed enemy object
└── systems/
    ├── EnemyRegistry.gd       # JSON loading & weighted selection
    ├── WaveDirector.gd        # Enemy pool management & spawning
    ├── EnemyRenderTier.gd     # Visual tier assignment logic
    └── EnemyBehaviorSystem.gd # AI patterns (chase/flee/patrol)
```

### Registry Configuration
```json
{
  "enemy_types": {
    "knight_swarm": {
      "spawn_weight": 40,
      "config_path": "res://data/enemies/knight_swarm.json",
      "tier": "swarm",
      "behavior_type": "fast_melee"
    }
  }
}
```

### Individual Enemy Schema
```json
{
  "id": "knight_swarm",
  "display_name": "Swarm Knight", 
  "health": 3.0,
  "speed": 80.0,
  "size": {"x": 20, "y": 20},
  "collision_radius": 10.0,
  "xp_value": 1,
  "spawn_weight": 0.4,
  "visual": {
    "color": {"r": 1.0, "g": 0.0, "b": 0.0, "a": 1.0},
    "shape": "square"
  },
  "behavior": {
    "ai_type": "chase_player",
    "aggro_range": 300.0
  }
}
```

## ⚡ Performance Characteristics

### MultiMesh Batch Rendering
- **SWARM Tier**: Hundreds of enemies, fast animation (0.012s/frame)
- **REGULAR Tier**: Moderate count, normal animation (0.1s/frame)  
- **ELITE Tier**: Lower count, enhanced visuals
- **BOSS Tier**: Individual rendering, special effects

### Memory Usage
- **JSON Loading**: One-time cost during initialization
- **Runtime**: Minimal overhead, all data cached in EnemyType objects
- **Rendering**: GPU instancing via MultiMeshInstance2D

## 🔧 Technical Implementation

### Key Components
- **[[EnemyEntity]]**: Typed runtime objects with Dictionary compatibility methods
- **[[EnemyRegistry]]**: JSON loading, type management, weighted selection
- **[[WaveDirector]]**: Object pool management, spawning logic, Array[EnemyEntity] maintenance
- **[[EnemyRenderTier]]**: Tier assignment and Dictionary conversion for MultiMesh
- **[[DamageSystem]]**: Updated collision detection with object identity matching
- **[[MeleeSystem]]**: Enhanced to reference WaveDirector for proper pool indexing
- **Arena.gd**: MultiMesh setup, tier-specific rendering, receives grouped Dictionary arrays

### Error Handling & Type Safety
```gdscript
# Entity validation
func is_valid() -> bool:
    return not type_id.is_empty() and max_hp > 0.0 and speed >= 0.0

# Pool bounds checking
func damage_enemy(enemy_index: int, damage: float) -> void:
    if enemy_index < 0 or enemy_index >= max_enemies:
        return

# Graceful registry degradation
if loaded_count == 0:
    Logger.error("JSON enemy loading failed completely", "enemies")
    Logger.error("Ensure knight JSON files exist in res://data/enemies/", "enemies")
    # No fallback - system fails explicitly for data-driven purity
```

### Path Resolution
- **Corrected Paths**: `res://data/enemies/` (not `res://vibe/data/enemies/`)
- **Godot Project Base**: `/vibe/` directory is project root
- **Resource Loading**: Standard Godot resource path handling

## 🎮 Gameplay Impact

### Visual Distinction
- **Combat Clarity**: Different colors help players identify threat levels
- **Tactical Decisions**: Size/color indicates enemy capabilities
- **Debug Support**: Easy identification of tier assignment issues

### Balance Considerations
- **Spawn Distribution**: 40% SWARM, 30% REGULAR, 20% ELITE, 10% BOSS
- **Risk/Reward**: Higher tiers = more HP + XP but lower frequency
- **Performance Scaling**: SWARM enemies numerous but fast to kill

## 🔗 Signal Architecture & Communication

### [[EventBus]] Integration
The enemy system communicates via typed signals for loose coupling:

```gdscript
# WaveDirector → Arena (rendering updates)
signal enemies_updated(alive_enemies: Array[EnemyEntity])

# DamageSystem → EventBus → XpSystem (enemy kills)
EventBus.enemy_killed.emit(EnemyKilledPayload.new(death_pos, xp_value))

# EventBus → All Systems (fixed-step updates)
EventBus.combat_step.connect(_on_combat_step)
```

### Signal Flow Changes (August 2025 Update)
- **enemies_updated**: Now emits Array[EnemyEntity] instead of Array[Dictionary]
- **Object Identity**: Systems can now track enemies by reference instead of index
- **Type Safety**: Payload objects provide compile-time guarantees
- **Performance**: Cached alive enemy arrays reduce per-frame allocations

### Cross-System Dependencies
```
WaveDirector (enemies: Array[EnemyEntity])
    ↓ enemies_updated signal
Arena.gd (rendering coordination)
    ↓ EnemyRenderTier grouping
MultiMeshInstance2D (GPU batch rendering)

DamageSystem ← WaveDirector reference (pool index resolution)
MeleeSystem ← WaveDirector reference (collision detection)
EnemyBehaviorSystem ← WaveDirector signal (AI updates)
```

## 🚀 Future Enhancements

### Immediate Expansions
- **Animation Integration**: Connect `animation_config` to actual animation system
- **Behavior Variants**: Different AI patterns per tier
- **Sound Integration**: Tier-specific audio cues

### Medium Term
- **Dynamic Spawning**: Wave-based enemy type restrictions
- **Status Effects**: Tier-specific abilities (poison, armor, etc.)
- **Procedural Stats**: Generated enemy variants

### Long Term  
- **Modding Support**: External JSON override system
- **Network Sync**: Multiplayer enemy synchronization
- **Editor Tools**: Visual enemy designer in Godot

## 📋 Adding New Enemy Types

### Checklist for New Enemies
1. **Create JSON**: Follow schema in `/enemies/new_enemy.json`
2. **Register**: Add entry to `enemy_registry.json` with spawn weight
3. **Test Size**: Verify tier assignment with size boundaries
4. **Add Type Match**: Update `EnemyRenderTier.gd` if needed
5. **Color Assignment**: Add color mapping in `Arena.gd`
6. **Validate**: Test spawning, rendering, and combat integration

### Schema Validation
- All required fields present (id, health, speed, size, etc.)
- Size format: `{"x": number, "y": number}`
- Spawn weight: 0.0-1.0 range recommended
- Visual/behavior objects: Complete nested structure

---

**Implementation History:**
- **August 22, 2025**: Initial pure JSON system implementation
- **Path Fix**: Corrected `res://vibe/` → `res://` resolution issue  
- **Fallback Removal**: Eliminated hardcoded enemy definitions
- **Visual Tiers**: Implemented 4-tier color-coded system