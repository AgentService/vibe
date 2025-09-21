# Zero-Allocation Breach Enemy Tracking Implementation

**Status:** 🔄 Ready to Implement
**Priority:** High Performance
**Estimated Time:** 2-3 hours
**Created:** 2025-09-21

## Problem Statement

Current breach system has frame-rate performance bottlenecks:
- `_update_active_breaches()` iterates all enemies every frame (60Hz)
- `breach_enemies: Dictionary` uses dynamic Arrays that resize during spawn/cleanup
- Multiple `distance_to()` calls per frame for enemy cleanup validation

**Performance Target:** Support 3 breaches × 50+ enemies without frame drops

## Core Implementation

### 1. New File: `scripts/systems/events/BreachEnemyTracker.gd`
**Purpose:** RingBuffer wrapper for breach enemy management with safe concurrent removal

#### Key Functions to Implement:
```gdscript
func setup(capacity: int)  # Initialize with 256-enemy capacity
func add_enemy(enemy: Node2D) -> bool  # Returns false if capacity exceeded
func mark_for_removal(enemy: Node2D)  # Mark for deletion without allocation
func iterate_valid_enemies() -> Array[Node2D]  # Active enemies excluding marked
func cleanup_marked()  # Remove marked enemies during safe cleanup phase
func count() -> int  # Active enemy count excluding marked entries
```

### 2. Modified File: `scripts/systems/events/BreachEventHandler.gd`
**Purpose:** Replace Dictionary-based enemy tracking with RingBuffer system

#### Key Changes Required:
- **Line 16:** Replace `breach_enemies: Dictionary = {}` with `breach_trackers: Dictionary[String, BreachEnemyTracker]`
- **Line 39:** Move `_update_active_breaches(dt)` to EventBus.combat_step signal (30Hz)
- **Line 334-346:** Optimize `_update_active_breaches()` for fixed-step updates
- **Line 348-382:** Replace `_check_and_cleanup_touched_rings()` with mark-for-removal strategy
- **Line 430-432:** Update enemy caching to use `tracker.add_enemy()` instead of `Array.append()`

#### New Functions to Add:
```gdscript
func _initialize_breach_trackers()  # Setup RingBuffer trackers
func _on_combat_step(payload)  # 30Hz update handler
func _add_enemy_to_breach(enemy, breach_id)  # RingBuffer add_enemy wrapper
func _cleanup_breach_enemies_optimized(breach)  # Safe removal strategy
func _handle_capacity_overflow(breach_id)  # Log when 256+ enemies
```

### 3. Test File: `tests/test_breach_enemy_tracking.gd`
**Purpose:** Validate zero-allocation behavior and edge cases

#### Test Coverage Required:
- `test_breach_enemy_tracking_capacity_overflow` - Behavior when adding 300+ enemies to 256-capacity tracker
- `test_safe_enemy_removal_during_iteration` - Concurrent removal while iterating doesn't crash
- `test_30hz_breach_lifecycle_timing_preservation` - Breach timing identical to frame-rate version
- `test_zero_allocation_enemy_spawn_cleanup` - Memory profiler confirms no allocations
- `test_multi_breach_enemy_isolation` - Enemy tracking doesn't leak between breaches

## Implementation Strategy

### Phase 1: BreachEnemyTracker Creation (45 minutes)
1. Create `BreachEnemyTracker.gd` using existing `RingBuffer.gd` utility
2. Implement safe iteration with removal marking (hardest part)
3. Add capacity overflow handling (log warning, reject add)
4. Unit test the tracker in isolation

### Phase 2: BreachEventHandler Integration (60 minutes)
1. Replace `breach_enemies` Dictionary with `breach_trackers` Dictionary
2. Update all enemy add/remove calls to use tracker API
3. Implement `_on_combat_step()` signal handler for 30Hz updates
4. Test integration without breaking existing breach behavior

### Phase 3: Performance Validation (30 minutes)
1. Create stress test scene: 3 breaches × 50+ enemies each
2. Profile memory allocations (should be zero during enemy lifecycle)
3. Measure frame time improvements (target: 50%+ reduction)
4. Validate breach timing preservation with fixed-step updates

## Success Criteria

- ✅ **Performance:** 50%+ reduction in breach update frame time with 150+ enemies
- ✅ **Memory:** Zero allocations during enemy spawn/cleanup confirmed via profiler
- ✅ **Behavior:** Identical breach timing and enemy counts compared to current system
- ✅ **Scalability:** Support 3 breaches × 50+ enemies without frame drops
- ✅ **Reliability:** No crashes during concurrent enemy removal operations

## Technical Challenges

### 1. Safe Concurrent Removal (Hardest)
**Problem:** Current code uses `enemy_list.remove_at(i)` while iterating backwards
**Solution:** Mark-for-removal strategy to avoid RingBuffer API limitations

### 2. RingBuffer vs Array API Compatibility
**Problem:** Existing code expects Array interface (`size()`, `remove_at()`)
**Solution:** BreachEnemyTracker wrapper maintains Array-like semantics

### 3. 30Hz Timing Preservation
**Problem:** Breach lifecycle uses dt accumulation, moving to fixed 1/30 step
**Solution:** Verify no timing regressions in expansion/shrinking phases

### 4. Capacity Overflow Handling
**Problem:** What happens when > 256 enemies spawn in one breach?
**Solution:** Log warning and reject additional enemies (graceful degradation)

## Dependencies

- ✅ **RingBuffer.gd** - Already implemented in `scripts/utils/`
- ✅ **EventBus.combat_step** - Already available for 30Hz updates
- ✅ **BreachEventHandler** - Target file exists and is well-structured

## Files Modified Summary

1. **NEW:** `scripts/systems/events/BreachEnemyTracker.gd` (RingBuffer wrapper)
2. **MODIFY:** `scripts/systems/events/BreachEventHandler.gd` (core performance optimization)
3. **NEW:** `tests/test_breach_enemy_tracking.gd` (validation and edge case testing)

## Notes

- 256 enemy capacity per breach provides generous buffer above current max (~54 enemies)
- RingBuffer power-of-two optimization makes 256 as efficient as 128
- Mark-for-removal strategy maintains zero-allocation goal during cleanup
- 30Hz fixed-step ensures consistent performance regardless of framerate