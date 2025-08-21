# Enemy Phase 2 - Task 1.1: Basic Render Tiers

## Overview
**Duration:** 2 hours  
**Priority:** High (Foundation)  
**Dependencies:** MVP completed  

## Goal
Define 4 render tiers and route enemies to appropriate MultiMesh layers based on their tier.

## What This Task Accomplishes
- ✅ Define render tiers: SWARM, REGULAR, ELITE, BOSS
- ✅ Route enemies to appropriate MultiMesh based on tier
- ✅ Keep existing rendering working
- ✅ Foundation for visual hierarchy

## Files to Create/Modify

### 1. Create EnemyRenderTier.gd
**Location:** `vibe/scripts/systems/EnemyRenderTier.gd`
```gdscript
enum EnemyRenderTier {
    SWARM = 0,      # 90% of enemies (small, fast) - MultiMesh
    REGULAR = 1,    # 8% of enemies (medium) - MultiMesh  
    ELITE = 2,      # 2% of enemies (large) - MultiMesh
    BOSS = 3        # <1% of enemies (animated) - Individual sprites
}
```

### 2. Create enemy_tiers.json
**Location:** `vibe/data/enemies/enemy_tiers.json`
```json
{
  "tiers": {
    "swarm": {
      "name": "SWARM",
      "description": "Small, fast enemies rendered in bulk",
      "max_size": 24,
      "max_speed": 120,
      "render_method": "multimesh"
    },
    "regular": {
      "name": "REGULAR", 
      "description": "Medium enemies with basic animations",
      "max_size": 48,
      "max_speed": 80,
      "render_method": "multimesh"
    },
    "elite": {
      "name": "ELITE",
      "description": "Large enemies with special effects",
      "max_size": 64,
      "max_speed": 60,
      "render_method": "multimesh"
    },
    "boss": {
      "name": "BOSS",
      "description": "Unique enemies with individual rendering",
      "min_size": 80,
      "render_method": "individual_sprite"
    }
  }
}
```

### 3. Modify Arena.gd
**Location:** `vibe/scenes/arena/Arena.gd`
- Add tier-based MultiMesh routing logic
- Keep existing rendering working

## Implementation Steps

### Step 1: Create EnemyRenderTier.gd (30 min)
1. Create enum with 4 render tiers
2. Add helper methods for tier validation
3. Test enum compilation

### Step 2: Create enemy_tiers.json (15 min)
1. Define tier configuration data
2. Add validation rules
3. Test JSON loading

### Step 3: Modify Arena.gd (45 min)
1. Add tier-based routing logic
2. Test with existing enemies
3. Ensure no performance regression

### Step 4: Testing & Validation (30 min)
1. Verify enemies route to correct tiers
2. Check performance (maintain 60 FPS)
3. Validate existing functionality works

## Success Criteria
- ✅ 4 render tiers defined and working
- ✅ Enemies route to appropriate MultiMesh layers
- ✅ Existing rendering continues to work
- ✅ No performance regression
- ✅ Clean, maintainable code

## Next Task
**Task 1.2: Enhanced Enemy JSON Schema** - Add render_tier field to enemy definitions

## Notes
- Keep changes minimal and focused
- Test each step before proceeding
- Document any architecture decisions
- Maintain backward compatibility
