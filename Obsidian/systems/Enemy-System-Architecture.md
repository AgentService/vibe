# Enemy System Architecture

**Status:** ✅ Implemented (August 2025)  
**Architecture:** Pure JSON-driven with 4-tier visual classification  
**Performance:** MultiMesh batch rendering for thousands of enemies

## 🏗️ System Overview

The enemy system follows a data-driven architecture where all enemy definitions live in JSON files, eliminating hardcoded fallbacks and enabling easy content expansion.

### Core Principles
- **JSON-Only**: No hardcoded enemy definitions, pure data-driven
- **Tier-Based Rendering**: Size-based classification for visual distinction
- **Weighted Spawning**: Configurable spawn probabilities per enemy type
- **Visual Clarity**: Color-coded tiers for gameplay and debugging

## 📊 Data Flow Pipeline

```
JSON Files → EnemyRegistry → EnemyRenderTier → MultiMesh Rendering
    ↓              ↓               ↓                 ↓
Registry     Individual      Tier Assignment    Visual Rendering
Loading      Enemy Data      (Size + Type)      (Color + Animation)
```

### 1. JSON Loading Phase
- **Registry**: `enemy_registry.json` lists all available enemy types
- **Individual**: Each `knight_*.json` contains complete enemy definition
- **Validation**: Schema validation ensures consistent data structure

### 2. Tier Assignment Phase
- **Size-Based**: Primary assignment by pixel dimensions
- **Type-Based**: Override for specific enemy types (knight_swarm, etc.)
- **Fallback**: Size boundaries when type matching fails

### 3. Rendering Phase
- **MultiMesh**: Batch rendering for performance (thousands of enemies)
- **Tier-Specific**: Different colors/animations per tier
- **Animation Speed**: Varying frame rates (SWARM fast, others normal)

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
- **EnemyRegistry.gd**: JSON loading, type management, weighted selection
- **EnemyRenderTier.gd**: Size/type-based tier assignment logic
- **Arena.gd**: MultiMesh setup, tier-specific rendering, color assignment
- **WaveDirector.gd**: Enemy spawning, integration with registry system

### Error Handling
```gdscript
# Graceful degradation
if loaded_count == 0:
    Logger.error("JSON enemy loading failed completely", "enemies")
    Logger.error("Ensure knight JSON files exist in res://data/enemies/", "enemies")
    # No fallback - system fails explicitly
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