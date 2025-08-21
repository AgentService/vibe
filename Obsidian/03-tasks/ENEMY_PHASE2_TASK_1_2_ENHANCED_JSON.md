# Enemy Phase 2 - Task 1.2: Enhanced Enemy JSON Schema

## Overview
**Duration:** 1 hour  
**Priority:** High (Data Foundation)  
**Dependencies:** Task 1.1 completed  

## Goal
Add `render_tier` field to enemy definitions and validate tier assignments while maintaining backward compatibility.

## What This Task Accomplishes
- ✅ Add render_tier field to enemy JSON schema
- ✅ Validate tier assignments against tier definitions
- ✅ Maintain backward compatibility with existing enemies
- ✅ Foundation for tier-based rendering

## Files to Create/Modify

### 1. Create slime_green_v2.json
**Location:** `vibe/data/enemies/slime_green_v2.json`
```json
{
  "id": "slime_green_v2",
  "display_name": "Green Slime (Enhanced)",
  "render_tier": "swarm",
  "health": 10.0,
  "speed": 50.0,
  "size": {"x": 24, "y": 24},
  "collision_radius": 12.0,
  "xp_value": 1,
  "despawn_timer": 30.0,
  "spawn_weight": 1.0,
  "themes": ["forest", "dungeon", "cave"],
  "visual": {
    "sprite_sheet": "res://assets/sprites/slime_green.png",
    "frame_size": {"x": 32, "y": 32},
    "animations": {
      "idle": {"frames": [0, 1, 2, 3], "fps": 8.0},
      "move": {"frames": [0, 1, 2, 3], "fps": 12.0},
      "death": {"frames": [0, 1, 2, 3], "fps": 10.0}
    }
  },
  "behavior": {
    "ai_type": "chase_player",
    "aggro_range": 300.0,
    "attack_range": 20.0,
    "movement_pattern": "direct_chase"
  },
  "scaling": {
    "health_multiplier": 1.2,
    "speed_multiplier": 1.1,
    "xp_multiplier": 1.3
  },
  "_schema_version": "2.0.0",
  "_description": "Enhanced green slime with render tier support"
}
```

### 2. Modify EnemyType.gd
**Location:** `vibe/scripts/systems/EnemyType.gd`
- Add render_tier field validation
- Ensure backward compatibility for enemies without tier
- Validate tier against tier definitions

### 3. Update data/README.md
**Location:** `vibe/data/README.md`
- Document new render_tier field
- Add tier validation rules
- Update schema version information

## Implementation Steps

### Step 1: Create Enhanced Enemy JSON (20 min)
1. Create slime_green_v2.json with render_tier
2. Test JSON loading and validation
3. Verify all required fields present

### Step 2: Modify EnemyType.gd (25 min)
1. Add render_tier field support
2. Implement tier validation logic
3. Add backward compatibility for old enemies
4. Test with both old and new enemy definitions

### Step 3: Update Documentation (15 min)
1. Update README.md with new schema
2. Document tier validation rules
3. Add examples of tier usage

## Success Criteria
- ✅ render_tier field added to enemy schema
- ✅ Tier validation working correctly
- ✅ Backward compatibility maintained
- ✅ Documentation updated
- ✅ Clean, maintainable code

## Backward Compatibility
- **Old enemies without render_tier** → Default to "regular" tier
- **Invalid tier values** → Log warning and default to "regular"
- **Missing tier definitions** → Fallback to basic rendering

## Next Task
**Task 1.3: MultiMesh Layer Setup** - Create tier-based MultiMesh layers

## Notes
- Test with existing enemy definitions
- Ensure no breaking changes
- Validate tier assignments make sense
- Document any schema changes
