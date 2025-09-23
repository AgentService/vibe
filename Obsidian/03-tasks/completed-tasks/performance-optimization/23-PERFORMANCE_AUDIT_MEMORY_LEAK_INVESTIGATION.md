# Performance Audit: Memory Leak Investigation & Zero-Alloc Compliance

Status: Ready to Start  
Owner: Solo (Indie)  
Priority: Critical  
Type: Performance Investigation  
Dependencies: Performance baseline, MultiMesh systems, Object pools, Ring buffers  
Risk: High (blocks performance validation)  
Complexity: 6/10

---

## Background

Performance audit revealed critical memory management failures preventing the project from meeting agreed performance targets:

**Critical Issues Identified:**
- ❌ **Memory Growth**: 153.39 MB vs <50MB target (306% over limit)
- ❌ **Enemy Count**: Only 9/500 enemies spawned (98% shortfall)
- ❌ **Test Duration**: 1.44 seconds indicates premature termination

**Compliant Systems Verified:**
- ✅ **MultiMesh2D Rendering**: Confirmed for enemies with tier-based instances
- ✅ **Scene-Based Bosses**: AnimatedSprite2D nodes verified in scenes/bosses/
- ✅ **30 Hz Combat Loop**: Fixed-step combat via RunManager.gd with accumulator
- ✅ **Damage Batching**: Ring buffer queue system in DamageRegistry.gd
- ✅ **Object Pools**: Extensive pooling for enemies, projectiles, particles
- ✅ **Spatial Hash**: Grid-based collision system in EntityTracker.gd

---

## Goals & Acceptance Criteria

### Primary Investigation Goals
- [ ] **Root Cause Analysis**: Identify source of 153MB memory growth during enemy spawning
- [ ] **Spawn Failure**: Determine why only 9/500 enemies spawned in stress test
- [ ] **Memory Leak Detection**: Find and fix allocation issues preventing cleanup
- [ ] **Performance Validation**: Re-run stress test to achieve 500+ enemies at <50MB growth

### Secondary Compliance Goals
- [ ] **SoA Implementation**: Convert enemy data to Structure-of-Arrays using PackedFloat32Array
- [ ] **Allocation Audit**: Review combat loop for remaining temporary object creation
- [ ] **GC Monitoring**: Implement garbage collection spike detection and metrics

### Success Criteria
- [ ] Stress test reaches 500+ enemies consistently
- [ ] Memory growth stays under 50MB during full test
- [ ] Frametime remains <16ms under target load
- [ ] No GC spikes or array reallocation spikes detected
- [ ] All zero-allocation principles verified in hotpath

---

## Investigation Plan

### Phase 1: Memory Leak Root Cause Analysis (3 hours)
**Priority**: Critical

**Tasks:**
1. **Analyze Performance Test Failure**:
   - Review `tests/test_performance_500_enemies.gd` for early termination logic
   - Check WaveDirector enemy spawning limits and pool initialization
   - Validate MultiMesh instance count updates vs enemy pool size

2. **Memory Profiling Setup**:
   - Add detailed memory tracking to performance test
   - Instrument object pool allocation/deallocation counters
   - Track MultiMesh instance memory usage over time

3. **Identify Allocation Sources**:
   - Profile enemy spawning loop for temporary allocations
   - Check EnemyEntity creation vs pool reuse
   - Validate ring buffer and object pool cleanup

**Files to investigate:**
- `tests/test_performance_500_enemies.gd` - Test termination logic
- `scripts/systems/WaveDirector.gd` - Enemy pool management
- `scripts/systems/MultiMeshManager.gd` - Instance memory usage
- `scripts/systems/damage_v2/DamageRegistry.gd` - Ring buffer cleanup

### Phase 2: Enemy Spawning System Debug (2 hours)
**Priority**: Critical

**Tasks:**
1. **WaveDirector Analysis**:
   - Verify `max_enemies` configuration and pool initialization
   - Check `_find_free_enemy()` logic for pool exhaustion
   - Validate enemy lifecycle: spawn → active → cleanup → pool return

2. **MultiMesh Integration**:
   - Confirm MultiMesh instance count matches enemy pool usage
   - Verify `update_enemies()` signal chain from WaveDirector to MultiMeshManager
   - Check for MultiMesh memory leaks on enemy death/cleanup

3. **Performance Test Validation**:
   - Add logging to track actual vs expected enemy counts
   - Implement progressive spawn rate to identify failure threshold
   - Validate test duration and termination conditions

**Expected Outcomes:**
- Identify why spawning stops at 9 enemies
- Fix pool exhaustion or initialization issues
- Restore 500+ enemy spawning capability

### Phase 3: Zero-Allocation Hotpath Audit (2 hours)
**Priority**: High

**Tasks:**
1. **Combat Loop Analysis**:
   - Profile 30Hz combat step for temporary allocations
   - Review damage processing pipeline for object creation
   - Check signal emission patterns for allocation spikes

2. **Object Pool Validation**:
   - Verify all pools return objects correctly
   - Check for pool exhaustion scenarios
   - Validate ring buffer overflow handling

3. **MultiMesh Performance**:
   - Confirm no per-frame allocations in MultiMesh updates
   - Verify transform cache reuse in Arena.gd
   - Check enemy animation system for temporary objects

**Files to audit:**
- `autoload/RunManager.gd` - 30Hz combat step
- `scripts/systems/MeleeSystem.gd` - Combat allocations
- `scripts/systems/EnemyAnimationSystem.gd` - Animation updates
- `scenes/arena/Arena.gd` - Transform cache usage

### Phase 4: Structure-of-Arrays Implementation (3 hours)
**Priority**: Medium (after memory leaks fixed)

**Tasks:**
1. **Enemy Data Conversion**:
   - Convert `Array[EnemyEntity]` to SoA format using PackedFloat32Array
   - Implement position, health, damage arrays for bulk processing
   - Maintain compatibility with existing systems via accessor methods

2. **Performance Optimization**:
   - Use PackedVector2Array for enemy positions
   - Implement SIMD-friendly data layouts where possible
   - Batch operations on packed arrays for better cache performance

3. **Integration Testing**:
   - Ensure MultiMesh updates work with SoA data
   - Validate damage system compatibility
   - Test performance improvement vs object-oriented approach

**New Files:**
- `scripts/systems/EnemyDataSoA.gd` - Structure-of-Arrays implementation
- `scripts/utils/PackedArrayUtils.gd` - Helper functions for packed arrays

### Phase 5: Enhanced Performance Monitoring (1 hour)
**Priority**: Medium

**Tasks:**
1. **GC Monitoring**:
   - Add garbage collection spike detection
   - Track allocation patterns during gameplay
   - Implement performance budget warnings

2. **Memory Metrics**:
   - Add real-time memory usage display
   - Track object pool utilization rates
   - Monitor MultiMesh instance counts

3. **Performance Dashboard**:
   - Create debug overlay with key performance metrics
   - Add memory growth rate tracking
   - Implement performance regression detection

**Files to create:**
- `scripts/systems/debug/PerformanceProfiler.gd` - Enhanced monitoring
- `scenes/ui/debug/PerformanceDashboard.tscn` - Debug overlay

### Phase 6: Validation & Documentation (1 hour)
**Priority**: High

**Tasks:**
1. **Stress Test Validation**:
   - Re-run performance test with fixes applied
   - Validate 500+ enemies at <50MB memory growth
   - Confirm stable frametime under target load

2. **Performance Baseline Update**:
   - Generate new baseline with compliant results
   - Document performance improvements achieved
   - Update performance targets if needed

3. **Architecture Documentation**:
   - Document zero-allocation patterns used
   - Update performance guidelines
   - Create troubleshooting guide for future issues

---

## Expected Root Causes

### Memory Leak Hypotheses
1. **Pool Return Failure**: Objects not properly returned to pools on enemy death
2. **MultiMesh Leaks**: Instance data not cleaned up when enemies removed
3. **Signal Accumulation**: Event handlers creating temporary objects without cleanup
4. **Ring Buffer Overflow**: Damage events accumulating without proper drainage

### Spawn Failure Hypotheses
1. **Pool Exhaustion**: `max_enemies` limit reached due to cleanup failure
2. **MultiMesh Limits**: Instance count limits preventing further spawns
3. **Performance Throttling**: System detecting performance issues and limiting spawns
4. **Test Logic Error**: Performance test terminating prematurely due to conditions

---

## File Touch List

### Investigation Files
- `tests/test_performance_500_enemies.gd` - Add detailed logging and profiling
- `scripts/systems/WaveDirector.gd` - Debug pool management
- `scripts/systems/MultiMeshManager.gd` - Memory usage tracking
- `scripts/systems/damage_v2/DamageRegistry.gd` - Ring buffer analysis

### New Monitoring Files
- `scripts/systems/debug/PerformanceProfiler.gd` - Enhanced profiling
- `scripts/systems/EnemyDataSoA.gd` - Structure-of-Arrays implementation
- `scripts/utils/PackedArrayUtils.gd` - Packed array utilities
- `scenes/ui/debug/PerformanceDashboard.tscn` - Debug overlay

### Updated Documentation
- `docs/PERFORMANCE_GUIDELINES.md` - Zero-allocation patterns
- `docs/TROUBLESHOOTING.md` - Memory leak debugging guide
- `tests/baselines/` - Updated performance baselines

---

## Success Metrics

### Critical Fixes
- [ ] **Memory Growth**: <50MB during 500+ enemy stress test
- [ ] **Enemy Count**: Consistent 500+ enemy spawning
- [ ] **Test Duration**: Full test completion without premature termination
- [ ] **Frametime**: <16ms average under target load

### Performance Improvements
- [ ] **GC Spikes**: Zero garbage collection spikes during combat
- [ ] **Allocation Rate**: Zero per-frame allocations in hotpath
- [ ] **Pool Efficiency**: >95% object pool reuse rate
- [ ] **Memory Stability**: Flat memory usage after initial allocation

### Monitoring Capabilities
- [ ] **Real-time Metrics**: Live performance dashboard
- [ ] **Regression Detection**: Automated performance regression alerts
- [ ] **Profiling Tools**: Easy-to-use performance profiling for developers

---

## Timeline & Effort

**Total Effort:** ~12 hours across 6 phases

- **Phase 1 (Memory Analysis):** 3 hours - Critical path
- **Phase 2 (Spawn Debug):** 2 hours - Critical path  
- **Phase 3 (Hotpath Audit):** 2 hours - High priority
- **Phase 4 (SoA Implementation):** 3 hours - Medium priority
- **Phase 5 (Monitoring):** 1 hour - Medium priority
- **Phase 6 (Validation):** 1 hour - High priority

**Critical Path:** Phases 1-2 must be completed first to unblock performance validation

**Recommended Schedule:**
- Day 1: Phases 1-2 (Memory leak investigation and spawn system debug)
- Day 2: Phase 3 + Phase 6 (Hotpath audit and validation)
- Day 3: Phases 4-5 (SoA implementation and enhanced monitoring)

---

## Risk Assessment

### High Risk - Memory Leak Complexity
- **Risk**: Memory leaks may be distributed across multiple systems
- **Mitigation**: Systematic investigation starting with highest-impact areas
- **Fallback**: Implement memory usage caps and forced cleanup cycles

### Medium Risk - Performance Regression
- **Risk**: Fixes may introduce new performance issues
- **Mitigation**: Incremental changes with performance validation at each step
- **Validation**: Automated performance regression testing

### Low Risk - SoA Compatibility
- **Risk**: Structure-of-Arrays may break existing system integrations
- **Mitigation**: Maintain compatibility layer during transition
- **Validation**: Comprehensive integration testing

---

## Definition of Done

- [ ] Performance stress test consistently reaches 500+ enemies
- [ ] Memory growth stays under 50MB during full test duration
- [ ] No garbage collection spikes detected during combat
- [ ] Zero per-frame allocations confirmed in hotpath
- [ ] Enhanced monitoring tools provide real-time performance insights
- [ ] Updated performance baselines reflect compliant behavior
- [ ] Documentation updated with zero-allocation patterns and troubleshooting guides

This investigation will restore the project's performance compliance and establish robust monitoring to prevent future regressions.
