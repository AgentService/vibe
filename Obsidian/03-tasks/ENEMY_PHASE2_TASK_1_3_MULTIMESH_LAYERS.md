# Enemy Phase 2 - Task 1.3: MultiMesh Layer Setup

## Overview
**Duration:** 2 hours  
**Priority:** High (Rendering Foundation)  
**Dependencies:** Tasks 1.1 & 1.2 completed  

## Goal
Create 3 MultiMesh layers for different enemy tiers and route enemies to appropriate layers while maintaining performance.

## What This Task Accomplishes
- ✅ Create 3 MultiMesh layers (Swarm, Regular, Elite)
- ✅ Route enemies to appropriate layer based on tier
- ✅ Maintain single MultiMesh performance
- ✅ Foundation for visual hierarchy rendering

## Files to Create/Modify

### 1. Modify Arena.tscn
**Location:** `vibe/scenes/arena/Arena.tscn`
- Add new MultiMesh nodes for each tier
- Keep existing MM_Enemies for backward compatibility
- Organize nodes in logical hierarchy

### 2. Modify Arena.gd
**Location:** `vibe/scenes/arena/Arena.gd`
- Initialize tier-based MultiMeshes
- Route enemies to appropriate layer
- Maintain existing rendering functionality

### 3. Create EnemyVisualSystem.gd
**Location:** `vibe/scripts/systems/EnemyVisualSystem.gd`
- Manage tier-based MultiMesh routing
- Handle enemy visual updates
- Optimize rendering performance

## Implementation Steps

### Step 1: Modify Arena.tscn (30 min)
1. Add MM_Enemies_Swarm node
2. Add MM_Enemies_Regular node  
3. Add MM_Enemies_Elite node
4. Organize node hierarchy

### Step 2: Modify Arena.gd (45 min)
1. Initialize tier-based MultiMeshes
2. Add tier routing logic
3. Maintain existing rendering
4. Test with current enemies

### Step 3: Create EnemyVisualSystem.gd (30 min)
1. Create tier routing system
2. Handle enemy visual updates
3. Optimize performance
4. Test routing functionality

### Step 4: Testing & Validation (15 min)
1. Verify enemies route to correct layers
2. Check performance (maintain 60 FPS)
3. Validate existing functionality works

## MultiMesh Layer Structure

```
Arena (Node2D)
├── MM_Enemies (existing - for backward compatibility)
├── MM_Enemies_Swarm     # 90% enemies (small, fast)
├── MM_Enemies_Regular   # 8% enemies (medium)
├── MM_Enemies_Elite     # 2% enemies (large)
└── MM_Enemies_Boss      # <1% enemies (individual sprites)
```

## Performance Considerations
- **Keep single MultiMesh per tier** for batching
- **Route enemies efficiently** based on tier
- **Maintain existing performance** (60 FPS with 500+ enemies)
- **Use transform caching** for efficiency

## Success Criteria
- ✅ 3 MultiMesh layers created and working
- ✅ Enemies route to correct layers based on tier
- ✅ Performance maintained (no regression)
- ✅ Existing rendering continues to work
- ✅ Clean, maintainable code

## Backward Compatibility
- **Existing enemies** → Route to appropriate tier layer
- **Missing tier** → Default to "regular" layer
- **Performance** → Maintain current frame rates

## Next Task
**Task 2.1: Basic Instance Data** - Pack animation data into instance custom data

## Notes
- Test each layer separately
- Monitor performance closely
- Document routing logic
- Keep changes minimal and focused
