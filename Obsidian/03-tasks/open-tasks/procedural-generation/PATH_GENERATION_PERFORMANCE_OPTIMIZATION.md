# PATH_GENERATION_PERFORMANCE_OPTIMIZATION

**Priority**: High
**Complexity**: High
**Category**: Performance Optimization
**Estimated Effort**: 2-3 weeks
**Target Performance**: Sub-1ms generation, 90%+ allocation reduction

## 🎯 **Objective**

Optimize the path generation pipeline to achieve sub-millisecond performance while maintaining current visual quality (7,000+ trees with organic boundaries). The current system takes 3ms+ with thousands of allocations - we need 5-10x performance improvement.

## 📊 **Current Performance Analysis**

### **Critical Bottlenecks Identified**:

1. **O(N×M×P) Tree Clearing Algorithm** - `scripts/resources/TreeBoundaryConfiguration.gd:719`
   - `_clear_walkable_paths_simple()` uses triple nested loops
   - 7,000+ trees × 10 paths × multiple segments = 70,000+ distance calculations
   - No spatial optimization - brute force approach

2. **Massive Array Allocations** - `scripts/resources/PathConfiguration.gd:116`
   - `PathSegment.get_full_path()` creates new Array[Vector2] for each call
   - Called in hot loops: `TreeBoundaryConfiguration.gd:727`, `PathAwareArenaGenerator.gd:342`
   - No caching between operations

3. **Grid-Based Exhaustive Search** - `scripts/resources/TreeBoundaryConfiguration.gd:240`
   - `_generate_gradient_density_trees()` samples every grid position
   - Dense sampling at `tree_spacing * 0.5` intervals
   - Missing early rejection patterns

4. **Unused Zero-Alloc Infrastructure**
   - Codebase has `RingBuffer` (`scripts/utils/RingBuffer.gd:1`) and `ObjectPool` (`scripts/utils/ObjectPool.gd:1`)
   - Path generation creates new `RandomNumberGenerator` instances (`scripts/systems/TreeBoundaryGenerator.gd:32`)
   - Should use `RNG.stream("treegen")` pattern

5. **Hash Dictionary Overhead** - `scripts/resources/TreeBoundaryConfiguration.gd:158`
   - `used_tiles: Dictionary` for collision detection
   - `_find_nearest_tree_distance` uses generic hash lookups

## 🚀 **Implementation Plan**

### **Phase 1: Critical Performance Fixes** ⚡

#### **1.1 Spatial Grid Tree-Path Collision System**
**Files**: `scripts/systems/TreeBoundaryGenerator.gd:23`, `scripts/resources/TreeBoundaryConfiguration.gd:628,719`

**Problem**: O(N×M×P) tree clearing in `_clear_walkable_paths_simple()` and `_is_position_in_path_buffer_zone()`

**Solution**: Build `PathSegmentGrid` helper module
- Pre-build spatial grid of path segments (512px cells)
- Tree collision becomes O(1) grid lookup instead of O(N×M×P)
- Note: `SimpleTileSpawnValidator` pattern exists only in docs (`scripts/systems/CLAUDE.md:351`) - need actual implementation

**Implementation**:
```gdscript
# New: scripts/utils/PathSegmentGrid.gd
class_name PathSegmentGrid
var cells: Dictionary  # Vector2i -> Array[PathSegment]
var cell_size: int = 512

func build_grid(paths: Array) -> void:
    # Pre-process all path segments into spatial cells

func get_nearby_segments(pos: Vector2) -> Array[PathSegment]:
    # O(1) lookup instead of O(N×M) iteration
```

**Success Criteria**:
- Tree clearing time: <0.1ms (from 2ms+)
- Replace nested loops with single grid queries

#### **1.2 Path Data Caching & Object Pooling**
**Files**: `scripts/resources/PathConfiguration.gd:116`, hot loop calls at `:727` and `:342`

**Problem**: `PathSegment.get_full_path()` allocates fresh Array[Vector2] per call in tree loops

**Solution**: Implement `PathDataCache` with ObjectPool
- Cache PackedVector2Array results of `get_full_path()` calls once per generation
- Pool Array[Vector2] instances using existing `ObjectPool` utility
- Replace `RandomNumberGenerator.new()` with `RNG.stream("treegen")`

**Implementation**:
```gdscript
# New: scripts/utils/PathDataCache.gd
class_name PathDataCache
var segment_cache: Dictionary  # PathSegment -> PackedVector2Array
var array_pool: ObjectPool     # for Array[Vector2] reuse

func get_cached_path(segment: PathSegment) -> PackedVector2Array:
    # Return cached result or compute once and cache
```

**Success Criteria**:
- Array allocations: <10 per generation (from 100s)
- Path data computed once per generation cycle

#### **1.3 Zero-Allocation Tree Position Management**
**Files**: `scripts/resources/TreeBoundaryConfiguration.gd:402`, `scripts/systems/TreeBoundaryGenerator.gd:130`

**Problem**: Multiple temporaries like `total_field_positions`, `perimeter_points` cause GC pressure

**Solution**: Use pre-sized containers and RingBuffer patterns
- Pre-allocated `PackedVector2Array` with `resize()` to expected capacity
- `RingBuffer<Vector2>` for streaming tree processing
- Fixed-size working sets instead of growing arrays

**Implementation**:
```gdscript
# In TreeBoundaryConfiguration
var _working_positions: PackedVector2Array  # Pre-sized
var _tree_buffer: RingBuffer                # For streaming

func _generate_trees_optimized() -> Array[Vector2]:
    _working_positions.resize(estimated_tree_count)
    # Use pre-sized array, return plain Array for caller compatibility
```

**Success Criteria**:
- Pre-allocate based on tree count estimates (7k cap + margin)
- Maintain plain Array return type for caller compatibility
- Reduce GC pressure by 90%+

### **Phase 2: Algorithm Optimization** 🧠

#### **2.1 Early Rejection Tree Generation**
**Files**: `scripts/resources/TreeBoundaryConfiguration.gd:240` - `_generate_gradient_density_trees()`

**Problem**: Exhaustive bounding box sampling, expensive `_get_min_distance_to_path_with_endpoints` calls

**Solution**: Multi-level spatial rejection
- Coarse bounding box rejection before distance calculations
- Grid-of-cells flagged during path preprocessing
- Skip expensive segment distance computations outside viable zones

**Implementation**:
```gdscript
func _build_rejection_grid(paths: Array) -> PackedByteArray:
    # Pre-compute viable zones during path preprocessing

func _sample_with_early_rejection(bounds: Rect2) -> Array[Vector2]:
    # Check rejection grid before expensive distance calculations
```

#### **2.2 Hierarchical Tree Placement**
**Files**: Path generation leverages ordered segments structure

**Problem**: Single-pass generation without spatial awareness

**Solution**: Distance-band processing with cached metadata
- Pre-sort segments/rings by distance from paths
- Emit band metadata alongside cached paths
- Iterate outer bands without recomputing minimum distances

**Implementation**:
```gdscript
# Enhanced PathDataCache with band metadata
struct PathBandData:
    var segments: PackedVector2Array
    var distance_band: float      # 0-100px, 100-300px, etc.
    var density_multiplier: float
```

#### **2.3 Batch Processing Pipeline**
**Files**: Aligns with existing RingBuffer patterns

**Problem**: Tree-by-tree processing with repeated calculations

**Solution**: Process in 256-tree chunks
- Amortize path distance calculations across batches
- Reuse PackedVector2Array scratch buffer for distance measurements
- Commit survivors to final array after batch validation

### **Phase 3: Memory Layout Optimization** 🗄️

#### **3.1 Pre-allocated Static Arrays**
**Files**: `scripts/resources/TreeBoundaryConfiguration.gd:52`

**Problem**: Dynamic array growth during generation

**Solution**: Size arrays upfront based on current settings
- Calculate tree cap dynamically: `(boundary_area / tree_spacing²) * density`
- Don't hardcode 7k - respect `tree_spacing` tunables
- Pre-resize output arrays before generation loops

#### **3.2 Compact Data Structures**
**Files**: `scripts/resources/TreeBoundaryConfiguration.gd:158` - `_find_nearest_tree_distance`

**Problem**: Generic Dictionary/Array hash overhead

**Solution**: Specialized spatial structures
- Custom grid keyed by `Vector2i` instead of generic Dictionary
- `PackedVector2Array` storage for tree positions
- Eliminate hash overhead in spatial queries

#### **3.3 String Allocation Elimination**
**Files**: Logger formatting in hot paths

**Problem**: Logger string formatting during generation

**Solution**: Conditional logging with performance guards
- Guard expensive format strings behind `Logger.is_enabled("treegen")`
- Cache common log message components
- **Important**: Maintain Logger.* contract - no direct print() calls

**Implementation**:
```gdscript
# Instead of:
Logger.debug("Generating %d trees at position %s" % [count, pos], "treegen")

# Use:
if Logger.is_enabled("treegen"):
    Logger.debug("Generating %d trees at position %s" % [count, pos], "treegen")
```

## 📋 **Implementation Strategy**

### **Priority Order**:
1. **PathSegmentGrid** (highest impact on O(N×M×P) bottleneck)
2. **PathDataCache** (easy win with existing ObjectPool infrastructure)
3. **RingBuffer Tree Management** (leverage existing zero-alloc patterns)
4. **Early Rejection** (algorithm improvement)
5. **Memory Layout** (polish and final optimization)

### **Risk Mitigation**:
- Implement behind feature flags for A/B testing
- Maintain visual output quality - regression testing
- Gradual rollout with fallback to current implementation
- Preserve existing API contracts (return types, etc.)

### **Development Approach**:
```gdscript
# Feature flag in TreeBoundaryConfiguration
@export var use_optimized_generation: bool = false

func generate_tree_boundaries(...) -> Array[Vector2]:
    if use_optimized_generation:
        return _generate_optimized(...)
    else:
        return _generate_legacy(...)  # Current implementation
```

## 🧪 **Testing & Validation**

### **Performance Testing Framework**
**Location**: `tests/performance/`

**Required Tests**:
```gdscript
# tests/performance/test_path_generation_optimization.gd
extends SceneTree

func test_generation_timing():
    # Target: <1ms generation time

func test_allocation_count():
    # Target: <100 allocations

func test_visual_regression():
    # Maintain 7,000+ tree output
    # Verify identical visual results
```

### **Success Metrics**:
- **Generation Time**: <1ms (from 3ms+) = 3x improvement minimum
- **Memory Allocations**: <100 (from 1000s) = 90%+ reduction
- **Tree Count**: Maintain 7,000+ trees with current quality
- **Visual Quality**: Identical organic boundary appearance

### **Integration Testing**:
- Drive full `PathAwareArenaGenerator.generate_path_aware_arena()` workflow
- Test with various plugin settings (tree_spacing, boundary_width, etc.)
- Validate against current default configuration values
- Ensure compatibility with existing save/load systems

## 📁 **File Structure Changes**

### **New Files**:
```
scripts/utils/
├── PathSegmentGrid.gd          # Spatial collision optimization
├── PathDataCache.gd            # Array caching and pooling
└── TreeGenerationOptimizer.gd  # Batch processing coordinator

tests/performance/
├── test_path_generation_optimization.gd  # Main performance suite
├── benchmark_tree_generation.gd          # Timing harness
└── allocation_counter.gd                  # Memory tracking
```

### **Modified Files**:
- `scripts/systems/TreeBoundaryGenerator.gd` - Integration point
- `scripts/resources/TreeBoundaryConfiguration.gd` - Core optimization
- `scripts/resources/PathConfiguration.gd` - Caching integration

## 🔗 **Dependencies & Prerequisites**

### **Existing Infrastructure to Leverage**:
- `scripts/utils/RingBuffer.gd` - Zero-allocation queuing
- `scripts/utils/ObjectPool.gd` - Object reuse patterns
- `autoload/RNG.gd` - Stream-based random generation
- Logger system with conditional formatting

### **Architecture Constraints**:
- Must maintain `Array[Vector2]` return types for compatibility
- Respect Logger.* usage patterns (no direct print())
- Work within existing @tool mode requirements
- Preserve deterministic seeding with same visual output

## 📈 **Expected Impact**

### **Performance Gains**:
- **5-10x** generation speed improvement
- **90%+** memory allocation reduction
- **Better scalability** for larger maps and higher tree densities
- **Foundation** for real-time procedural generation features

### **Development Benefits**:
- **Zero-allocation patterns** established for other systems
- **Spatial optimization** techniques reusable across codebase
- **Performance testing** infrastructure for future optimizations
- **Memory profiling** capabilities for ongoing development

### **User Experience**:
- **Instant feedback** in editor plugin (sub-frame generation)
- **Larger map support** without performance degradation
- **Better iteration speed** for procedural content creation
- **Stable performance** across different hardware configurations

## ✅ **Definition of Done**

- [ ] All Phase 1 optimizations implemented and tested
- [ ] Performance targets achieved: <1ms generation, <100 allocations
- [ ] Visual regression tests pass (identical tree output)
- [ ] Feature flag system allows safe rollout
- [ ] Documentation updated with new optimization patterns
- [ ] Performance test suite integrated into CI/automated testing
- [ ] Code review completed with architecture team approval
- [ ] Memory profiling confirms allocation reduction targets

---

**Next Steps**:
1. Start with PathSegmentGrid prototype behind feature flag
2. Add timing harness under `tests/performance/`
3. Implement PathDataCache with ObjectPool integration
4. Validate <1ms/<100 allocation targets before proceeding to Phase 2

**Status**: Ready for implementation
**Owner**: TBD
**Review Required**: Architecture team approval for zero-allocation patterns