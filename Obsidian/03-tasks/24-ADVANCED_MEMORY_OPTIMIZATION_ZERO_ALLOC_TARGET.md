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
=== LATEST TEST RESULTS ===
Final Enemy Count: 235/500
Average FPS: 14.25
Memory Growth: 166.31 MB (target: <50MB)
Frame Time 95th: 140.27 ms
Test Result: FAILED
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

## 📝 Task Checklist

### Phase 4: Object Creation Elimination
- [ ] Analyze MultiMeshManager object creation patterns
- [ ] Implement MultiMesh instance pre-allocation and reuse
- [ ] Create QuadMesh object pool system
- [ ] Analyze EnemyEntity creation in WaveDirector._initialize_pool()
- [ ] Choose approach: Dictionary-based entities vs object pooling
- [ ] Implement chosen EnemyEntity optimization
- [ ] Test Phase 4 changes: target 40-60MB reduction

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

| Phase | Target Reduction | Cumulative Total | Remaining Gap |
|-------|------------------|------------------|---------------|
| Baseline | - | 163MB | 113MB |
| Phase 4 | 45-80MB | 83-118MB | 33-68MB |
| Phase 5 | 10-25MB | 58-108MB | 8-58MB |
| Phase 6 | 15-30MB | 28-93MB | 0-43MB |
| Phase 7 | 15-25MB | 3-78MB | 0-28MB |
| Phase 8 | 5-10MB + stability | 0-73MB | **TARGET MET** |

## � Investigation Priority

**Highest Impact First**:
1. **EnemyEntity Pool Optimization** (Phase 4.3) - 30-50MB potential
2. **EventBus Payload Pooling** (Phase 6.1) - 10-20MB potential  
3. **Dictionary Usage Reduction** (Phase 7.1) - 10-15MB potential
4. **Entity ID Generation** (Phase 5.1) - 5-15MB potential

## 📚 References

- Previous task: `23-PERFORMANCE_AUDIT_MEMORY_LEAK_INVESTIGATION.md`
- Test results: `tests/baselines/2025-09-10T00-25-43_performance_500_enemies_summary.txt`
- Architecture rules: `docs/ARCHITECTURE_RULES.md`
- Zero-alloc principles: `.clinerules/03-architecture.md`

## � Timeline

- **Week 1**: Phases 4-5 (Object creation + String allocation)
- **Week 2**: Phases 6-7 (Payload optimization + Data structures)  
- **Week 3**: Phase 8 + Integration testing
- **Week 4**: Documentation and final validation

---

**Next Action**: Begin with Phase 4.3 (EnemyEntity Pool Optimization) as it has the highest potential impact (30-50MB reduction).
