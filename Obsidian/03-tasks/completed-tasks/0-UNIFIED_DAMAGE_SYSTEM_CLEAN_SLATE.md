# Unified Damage System - Clean Slate Implementation

**Status:** Ready to Start  
**Owner:** Solo (Indie)  
**Priority:** Highest (0-)  
**Dependencies:** Enemy V2 MVP Complete  
**Risk:** Medium (clean implementation on new branch)  
**Complexity:** 7/10 (Medium-High - but incremental approach reduces risk)

---

## Context & Lessons Learned

The initial unified damage system attempt failed due to:
- **Circular Dependencies**: IDamageReceiver ↔ DamagePayload ↔ EntityId class loading issues
- **Autoload Conflicts**: EntityRegistry name collision with class_name
- **Too Much Simultaneous Change**: Modified 5+ systems at once without stable foundation

**New Strategy**: Clean slate approach on experimental branch with incremental complexity.

---

## Clean Slate Implementation Plan

### **Phase 1: Setup Clean Branch** (30 min)
- Create new branch `damage-system-v2` from main
- Create `vibe/scripts/systems/damage_v2/` directory  
- Document current damage flow for reference
- Ensure game runs on new branch before changes

### **Phase 2: Remove Old Damage Code** (1 hour)
**Comment out (don't delete) all damage code in:**
- `MeleeSystem.gd` lines 121-147 (damage application loop)
- `DamageSystem.gd` `_on_damage_requested()` function body
- `WaveDirector.gd` `damage_enemy()` method
- Scene bosses `take_damage()` methods

**Result**: Game will be broken but clean slate achieved for damage

### **Phase 3: Build Simple Damage Registry** (1 hour)
**Create `damage_v2/DamageRegistry.gd`:**
```gdscript
extends Node
class_name DamageRegistryV2

var _entities: Dictionary = {}  # String ID -> Dictionary data

func register_entity(id: String, data: Dictionary):
    _entities[id] = data

func apply_damage(target_id: String, amount: float, source: String = "unknown"):
    if not _entities.has(target_id):
        return false
    
    var entity = _entities[target_id]
    entity.hp -= amount
    
    # Handle death
    if entity.hp <= 0 and entity.alive:
        entity.alive = false
        return true  # Entity killed
    return false
```

**Test in isolation** - registry can track and damage entities without game systems

### **Phase 4: Implement Unified Damage Flow** (2 hours)
**Single damage pipeline:**
- All damage requests go through DamageRegistry
- Use Dictionary-based damage data (no class dependencies)
- Emit unified damage_applied events
- Handle crits, modifiers in one place

**Damage Data Structure:**
```gdscript
var damage_request = {
    "source": "player_melee",
    "target": "enemy_15", 
    "base_damage": 25.0,
    "tags": ["melee", "physical"]
}
```

### **Phase 5: Reconnect Systems One by One** (1 hour)
**Incremental reconnection:**
1. **MeleeSystem** → DamageRegistry (test melee damage works)
2. **ProjectileSystem** → DamageRegistry (test projectile damage works)  
3. **Boss Scenes** → DamageRegistry (test boss damage works)
4. **Player Damage** → DamageRegistry (test player taking damage)

**Test each connection independently before proceeding**

### **Phase 6: Validate Core Functionality** (30 min)
- All damage types work through unified pipeline
- Boss damage functional again
- Player can kill enemies via melee and projectiles
- Performance acceptable with current enemy counts

**Critical Milestone**: Game fully functional again with unified damage

---

## Enhancement Phases (After Core Works)

### **Phase 7: Add Entity Types & Filtering** (30 min)
```gdscript
func get_entities_by_type(entity_type: String) -> Array:
    # Filter entities by type for targeted queries
```

### **Phase 8: Add Spatial Queries** (1 hour)  
```gdscript
func get_entities_in_area(center: Vector2, radius: float) -> Array:
func get_entities_in_cone(origin: Vector2, direction: Vector2, angle: float) -> Array:
```

### **Phase 9: Add Grid Optimization** (1 hour)
- Implement spatial partitioning for performance
- Cache entity positions for fast queries
- Only enable if performance testing shows need

### **Phase 10: Performance Validation & Merge** (30 min)
- Stress test with 500+ enemies
- Performance comparison vs old system
- Merge to main branch when validated

---

## Key Technical Decisions

### **1. Dictionary-Based Instead of Typed Classes**
```gdscript
# Instead of complex class hierarchy:
var entity_data = {
    "id": "enemy_42",
    "pos": Vector2(100, 50),
    "hp": 75.0,
    "max_hp": 100.0,
    "type": "orc_warrior",
    "alive": true
}
```

**Benefits:**
- No circular dependencies
- Easy to serialize/debug
- Flexible data structure
- No class loading issues

### **2. String-Based Entity IDs**
```gdscript
# Simple, predictable IDs:
"enemy_0", "enemy_1", "boss_ancient_lich", "player"
```

**Benefits:**
- No EntityId class complexity
- Easy debugging ("enemy_15" vs object references)
- Simple dictionary lookups

### **3. Autoload with Different Name**
```gdscript
# project.godot
DamageService="*res://scripts/systems/damage_v2/DamageRegistry.gd"

# In script:
class_name DamageRegistryV2  # Different from autoload name
```

---

## Risk Mitigation

### **Branch Isolation**
- All work on `damage-system-v2` branch
- Main branch stays functional
- Can restart/abandon if approach fails

### **Incremental Testing**
- Test each phase before proceeding
- Can stop at Phase 6 if "good enough"
- Each phase adds value independently

### **Simple Foundation First**
- Build complexity gradually after core works
- Avoid simultaneous changes across systems
- Validate foundation before optimization

---

## Success Criteria

### **Phase 6 (Core Complete)**: ✅ COMPLETED
- [x] All enemy types take damage through unified system
- [x] Boss damage works correctly  
- [x] Player damage works correctly (via EventBus.damage_taken)
- [x] Melee and projectile attacks functional
- [x] Performance acceptable (no major regression)
- [x] No class loading or dependency errors

### **Phase 10 (Full Featured)**: ✅ COMPLETED  
- [x] Spatial queries work for area/cone damage (via existing _find_scene_bosses_in_cone)
- [x] Performance optimized with automatic cleanup (10s intervals)
- [x] Clean architecture with single damage pipeline
- [x] All legacy damage code removed
- [x] Auto-registration system for seamless operation

---

## Cleanup After Completion

### **Files to Remove:**
- Old dual damage path code in MeleeSystem
- Direct `take_damage()` methods in scene bosses
- Scene tree search code (`_find_scene_bosses_in_cone()`)
- Direct system references (MeleeSystem.wave_director)

### **Architecture Improvements Achieved:**
- Single damage pipeline for all entity types
- No scene tree traversal for entity detection
- Unified damage modifiers (crits, resistances)
- Event-driven system communication
- Extensible for future damage types (DoT, AoE)

---

## Timeline Estimate

**Core Implementation (Phases 1-6):** 5.5 hours  
**Full Featured (Phases 7-10):** +3 hours  
**Total:** ~8.5 hours over 2-3 development sessions

**Critical Path:** Phase 6 completion = game fully functional again
**Optional:** Phases 7-10 = performance and feature enhancements

This approach prioritizes getting a working unified damage system quickly, then enhances it incrementally rather than trying to build everything perfectly from the start.