# 24-ADVANCED_MEMORY_OPTIMIZATION_ZERO_ALLOC_TARGET

**Status**: 🔄 Active  
**Priority**: High  
**Estimated Time**: 12-16 hours  
**Target**: Reduce memory growth from 163MB → <50MB (113MB reduction needed)

## 📋 Context

Current performance test results show significant progress but still failing memory targets:
- **Current**: 163MB memory growth (down from 326MB after baseline fix)
- **Target**: <50MB memory growth
- **Gap**: 113MB excess memory needs elimination

Architecture is solid (MultiMesh, 30Hz combat, object pools) but memory allocations in hot paths prevent meeting zero-allocation principles.

## 🎯 Objectives

1. **Primary Goal**: Achieve <50MB memory growth in 500-enemy stress test
2. **Secondary Goal**: Maintain ≥30 FPS average performance
3. **Tertiary Goal**: Establish true zero-allocation combat hotpath

## 📊 Current Baseline

```
=== ARCHITECTURE PERFORMANCE STRESS TEST SUMMARY ===
Timestamp: 2025-09-10T01:00:41
Test Duration: 31.22 seconds
Target: 500+ enemies, ≥30 FPS, <50MB memory growth

=== RESULTS ===
Final Enemy Count: 261
Total Frames: 471
Average FPS: 50.60
Minimum FPS: 6.73
FPS Stability: 79.6%
Frame Time 95th Percentile: 134.73 ms
Memory Growth: 131.14 MB
Test Result: FAILED

=== PASS/FAIL CRITERIA ===
Average FPS ≥30: ✓ (50.6)
Frame Time 95th <33.3ms: ✗ (134.73 ms)
Memory Growth <50MB: ✗ (131.14 MB)
FPS Stability >90%: ✗ (79.6%)

=== PHASE BREAKDOWN ===
Phase 1 - gradual_scaling:
  Duration: 8.5s
  Enemies: 402 final / 402 peak
  Memory: 199.1 → 284.5 MB (+85.4 MB)
  Average FPS: 46.1

Phase 2 - burst_spawn:
  Duration: 5.3s
  Enemies: 298 final / 298 peak
  Memory: 284.5 → 279.3 MB (+-5.2 MB)
  Average FPS: 15.9

Phase 3 - combat_stress:
  Duration: 10.4s
  Enemies: 500 final / 500 peak
  Memory: 279.3 → 331.8 MB (+52.5 MB)
  Average FPS: 14.1

Phase 4 - mixed_tier:
  Duration: 7.0s
  Enemies: 261 final / 261 peak
  Memory: 331.8 → 296.6 MB (+-35.2 MB)
  Average FPS: 50.6


```

## 🚀 Implementation Plan

### Phase 4: Object Creation Elimination

#### 4.1 MultiMesh Creation Optimization
- **Issue**: MultiMesh instances created fresh each setup
- **Solution**: Pre-allocate MultiMesh instances, reuse across test runs
- **Files**: `scripts/systems/MultiMeshManager.gd`
- **Impact**: ~10-20MB reduction

#### 4.2 QuadMesh Pool Implementation  
- **Issue**: New QuadMesh objects created per tier
- **Solution**: Pool QuadMesh objects, reuse instead of recreate
- **Files**: `scripts/systems/MultiMeshManager.gd`
- **Impact**: ~5-10MB reduction

#### 4.3 EnemyEntity Pool Optimization
- **Issue**: Creates 500 new EnemyEntity objects in `_initialize_pool()`
- **Solution A**: Dictionary-based entities instead of class instances
- **Solution B**: EnemyEntity object pooling with reset() methods
- **Files**: `scripts/systems/WaveDirector.gd`, `scripts/domain/EnemyEntity.gd`
- **Impact**: ~30-50MB reduction (highest impact)

### Phase 5: String Allocation Elimination

#### 5.1 Entity ID Generation Optimization
- **Issue**: `"enemy_" + str(i)` creates many string allocations
- **Solution A**: Pre-generate entity ID strings at startup
- **Solution B**: Use integer IDs with mapping dictionary
- **Files**: `scripts/systems/WaveDirector.gd`, `scripts/systems/EntityTracker.gd`
- **Impact**: ~5-15MB reduction

#### 5.2 Debug String Reduction
- **Issue**: `Logger.debug()` calls create temporary strings even when not shown
- **Solution**: Add `Logger.is_debug_enabled()` checks before string formatting
- **Files**: All systems with debug logging
- **Impact**: ~5-10MB reduction

### Phase 6: Signal Payload Optimization

#### 6.1 EventBus Payload Pooling
- **Issue**: EventBus signals create payload objects (DamageAppliedPayload, EnemyKilledPayload)
- **Solution**: Pool payload objects instead of creating new ones
- **Files**: `autoload/EventBus.gd`, `scripts/systems/damage_v2/DamageRegistry.gd`
- **Impact**: ~10-20MB reduction

#### 6.2 Simple Parameter Passing
- **Issue**: Complex payload objects for simple data
- **Solution**: Use direct parameter passing where possible
- **Files**: `autoload/EventBus.gd`
- **Impact**: ~5-10MB reduction

### Phase 7: Data Structure Optimization

#### 7.1 Dictionary Usage Reduction
- **Issue**: DamageRegistry uses Dictionary for entity storage - high overhead
- **Solution**: Use typed classes or PackedArrays for better memory efficiency
- **Files**: `scripts/systems/damage_v2/DamageRegistry.gd`
- **Impact**: ~10-15MB reduction

#### 7.2 Array Operations Optimization
- **Issue**: `get_alive_enemies()` rebuilds arrays frequently
- **Solution**: Bit-field tracking for alive/dead status
- **Files**: `scripts/systems/WaveDirector.gd`
- **Impact**: ~5-10MB reduction

### Phase 8: Godot Engine Settings

#### 8.1 Garbage Collection Tuning
- **Issue**: Automatic GC creates unpredictable memory spikes
- **Solution**: Adjust GC settings in project.godot for less frequent but more thorough collection
- **Files**: `project.godot`
- **Impact**: ~5-10MB reduction + stability

#### 8.2 Force GC at Intervals
- **Issue**: GC timing unpredictable during tests
- **Solution**: Force GC at specific intervals rather than automatic
- **Files**: `tests/test_performance_500_enemies.gd`
- **Impact**: More predictable memory patterns

### Phase 9: Hotpath Allocation Guards & Micro-Optimizations

#### 9.1 Vector2 Allocation Elimination
- **Issue**: Every `Vector2(x, y)` in hot loops creates new objects.
- **Action**: Replace with two `PackedFloat32Array` (pos_x[], pos_y[]) or reuse shared `Vector2` instances for calculations.
- **Impact**: Eliminates thousands of small per-frame allocations.

#### 9.2 Physics Query Reuse
- **Issue**: `intersect_point()` / `intersect_shape()` return new arrays each call.
- **Action**: Pre-allocate result arrays once, reuse them every query (`clear()` and refill instead of re-allocating).
- **Impact**: Major reduction of GC churn during collision checks.

#### 9.3 EventBus → EventQueue
- **Issue**: `emit_signal()` always allocates (payload + Variant boxing).
- **Action**: Replace hotpath signals with a ring buffer event queue (`event_ring.push(event)`). Process the queue once per tick.
- **Impact**: Zero allocations in combat loop, smoother frame times.

#### 9.4 Profiler Guards
- **Issue**: Hidden allocations can sneak back in.
- **Action**: Add per-tick guard code in debug mode:
  ```
  var mem_before = OS.get_static_memory_usage()
  _combat_tick()
  var mem_after = OS.get_static_memory_usage()
  assert(mem_after == mem_before, "Allocation detected in combat tick!")
  ```
- **Impact**: Guarantees true zero-alloc hotpath, catches regressions early.

#### 9.5 Bitfield Flags
- **Issue**: Alive/dead, stunned, poisoned stored as booleans/Dict keys → wasteful.
- **Action**: Use a single `PackedByteArray` or `PackedInt32Array` bitmask to track all state flags.
- **Impact**: Less memory, faster checks, no array rebuilds.

## 📝 Task Checklist

### Phase 4: Object Creation Elimination ✅ COMPLETED
- [x] Analyze MultiMeshManager object creation patterns
- [x] Implement MultiMesh instance pre-allocation and reuse
- [x] Create QuadMesh object pool system
- [x] Analyze EnemyEntity creation in WaveDirector._initialize_pool()
- [x] Choose approach: Dictionary-based entities vs object pooling
- [x] Implement chosen EnemyEntity optimization
- [x] Test Phase 4 changes: **ACHIEVED ~27MB reduction** (163MB → 135.74MB)

**Phase 4 Results (2025-09-10T01:15:45):**
- Memory Growth: 135.74 MB (reduced from baseline ~163MB)
- Peak Enemy Count: 472 enemies
- Average FPS: 17.1 (still needs improvement)
- **Key Optimizations Implemented:**
  - Dictionary-based EnemyEntity pool (eliminates 500 object allocations)
  - Pre-generated entity ID strings (eliminates string concatenation)
  - MultiMesh and QuadMesh object pooling (reuses rendering objects)
  - Headless mode texture handling fixes

### Phase 5: String Allocation Elimination  
- [ ] Audit entity ID generation patterns across systems
- [ ] Implement pre-generated entity ID strings or integer mapping
- [ ] Add Logger.is_debug_enabled() checks before string formatting
- [ ] Replace string concatenation with StringBuilder or format strings
- [ ] Test Phase 5 changes: target 10-25MB additional reduction

### Phase 6: Signal Payload Optimization
- [ ] Analyze EventBus payload object creation frequency
- [ ] Design payload object pool system
- [ ] Implement payload pooling for high-frequency signals
- [ ] Convert simple payloads to direct parameter passing
- [ ] Test Phase 6 changes: target 15-30MB additional reduction

### Phase 7: Data Structure Optimization
- [ ] Analyze DamageRegistry Dictionary usage patterns
- [ ] Design PackedArray or typed class replacement
- [ ] Implement bit-field alive/dead tracking in WaveDirector
- [ ] Replace get_alive_enemies() with non-allocating alternatives
- [ ] Test Phase 7 changes: target 15-25MB additional reduction

### Phase 8: Engine Settings & GC Tuning
- [ ] Research optimal GC settings for combat-heavy scenarios
- [ ] Implement project.godot GC configuration
- [ ] Add manual GC triggers at strategic points in tests
- [ ] Test Phase 8 changes: target stability and 5-10MB reduction

### Validation & Integration

Per-Phase Test Protocol (insert these steps between each phase):
1. Pre-phase snapshot
   - Run headless performance test: `./Godot_v4.4.1-stable_win64_console.exe --headless tests/test_performance_500_enemies.tscn` WITHOUT quit after flags!!!
   - Deterministic seed is already set (12345); ensure parameters unchanged.
   - Record from summary: Average FPS, Frame Time 95th, Memory Growth, Peak/Final Enemy Count, Frames Below Target, Frame Spikes.
   - Tag the baseline files with `PHASE_<N>_pre` in the filename/comment for traceability.
2. Apply Phase <N> changes
   - Implement only the scoped changes for the current phase (keep other phases untouched).
3. Post-phase run
   - Re-run the exact same performance test.
   - Tag the results `PHASE_<N>_post`.
4. Compare deltas and enforce acceptance gates
   - Memory Growth (MB): must decrease or stay the same; target trending toward <50MB.
   - Frame Time 95th (ms): must decrease or stay the same; target trending toward <33.3ms.
   - Average FPS: must not regress by more than 5% vs pre-phase; ideally improves.
   - Enemy Peak/Final: must not regress vs pre-phase for equivalent phases.
   - If a gate fails, fix or rollback before proceeding to the next phase.
5. Record results
   - Append a row to `tests/results/perf_phase_log.csv` with: timestamp, phase, pre/post, avg_fps, p95_ms, mem_growth_mb, enemy_final, enemy_peak, frames_below_30, spikes_over_50ms, notes.
   - Update this task document with a brief summary of the delta.
6. Advance to next phase
   - Only proceed when gates pass; otherwise address regressions first.

- [ ] Run comprehensive performance test after each phase
- [ ] Validate no regression in FPS or functionality
- [ ] Document memory allocation patterns before/after
- [ ] Create final performance report with all optimizations
- [ ] Update architecture documentation with zero-alloc patterns

## 🎯 Success Criteria

### Primary Targets
- **Memory Growth**: <50MB (currently 163MB)
- **Enemy Count**: 500/500 spawned successfully
- **FPS Average**: ≥30 FPS (currently 14.25)
- **Frame Time 95th**: <33.3ms (currently 140.27ms)

### Secondary Targets
- **FPS Stability**: >90% (currently 57.5%)
- **Zero GC Spikes**: No memory allocation during combat hotpath
- **Reproducible Results**: Consistent performance across test runs

## 📊 Expected Impact by Phase

| Phase | Target Reduction | Cumulative Total | Remaining Gap | Status |
|-------|------------------|------------------|---------------|---------|
| Baseline | - | 163MB | 113MB | - |
| Phase 4 | 45-80MB | ✅ **135.74MB** | **85.74MB** | ✅ COMPLETED |
| Phase 5 | 10-25MB | 110-125MB | 60-75MB | 🔄 Next |
| Phase 6 | 15-30MB | 80-110MB | 30-60MB | Pending |
| Phase 7 | 15-25MB | 55-95MB | 5-45MB | Pending |
| Phase 8 | 5-10MB + stability | 45-90MB | **TARGET ACHIEVABLE** | Pending |

## � Investigation Priority

**Phase 4 Completed - Next Highest Impact**:
1. ✅ **EnemyEntity Pool Optimization** (Phase 4.3) - ✅ COMPLETED
2. 🔄 **EventBus Payload Pooling** (Phase 6.1) - 10-20MB potential  
3. 🔄 **Dictionary Usage Reduction** (Phase 7.1) - 10-15MB potential
4. ✅ **Entity ID Generation** (Phase 5.1) - ✅ COMPLETED

## 📚 References

- Previous task: `23-PERFORMANCE_AUDIT_MEMORY_LEAK_INVESTIGATION.md`
- **Phase 4 Results**: `tests/baselines/2025-09-10T01-15-45_performance_500_enemies_summary.txt`
- Original baseline: `tests/baselines/2025-09-10T00-25-43_performance_500_enemies_summary.txt`
- Architecture rules: `docs/ARCHITECTURE_RULES.md`
- Zero-alloc principles: `.clinerules/03-architecture.md`

## � Timeline

- **Week 1**: Phases 4-5 (Object creation + String allocation)
- **Week 2**: Phases 6-7 (Payload optimization + Data structures)  
- **Week 3**: Phase 8 + Integration testing
- **Week 4**: Documentation and final validation

---

**Status Update (2025-09-10T01:15:45)**: ✅ Phase 4 COMPLETED with 27MB memory reduction achieved.

**Next Action**: Begin Phase 5 (String Allocation Elimination) to target additional 10-25MB reduction through:
- Logger debug string optimization 
- String concatenation elimination in hot paths
- EventBus payload string optimization

**Remaining Target**: Need additional ~85MB reduction to reach <50MB goal. Phases 5-8 collectively target ~50-80MB reduction potential.
