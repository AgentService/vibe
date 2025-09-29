# SpawnDirector Phase 5: Advanced Spatial & Threading Optimization

**Created:** 2025-09-30
**Priority:** Medium
**Estimated Effort:** 2-3 weeks
**Dependencies:** Phase 4 optimizations complete
**Status:** Planning

## Overview

Building on the exceptional performance baseline (146.4 FPS with 500 entities), Phase 5 focuses on advanced optimizations that will enable scaling to 1000+ entities while maintaining 60+ FPS. The primary focus is multi-threaded entity updates and spatial indexing improvements.

## Current Performance Baseline

```
✅ Achieved Performance (September 2025):
- Average FPS: 146.40 with 500 entities
- Memory Growth: 0.00 MB (perfect stability)
- FPS Stability: 99.9%
- 95th Percentile Frame Time: 7.14ms

✅ Optimizations Already Implemented:
- Dictionary-based entity pools (Phase 4)
- Pre-generated entity ID strings (Phase 4)
- Bit-field alive/dead tracking (Phase 7)
- Ring buffer entity update queues (Phase 4)
- Zero-allocation hot paths
```

## Task 1: Multi-threaded Entity Updates 🔥 **HIGH IMPACT**

### Problem Analysis
Current entity updates run sequentially on the main thread during the 30Hz combat step:

```gdscript
# Current: Sequential O(n) on main thread
func _update_enemies(dt: float) -> void:
    for enemy in get_alive_enemies():
        enemy.pos += enemy.vel * dt
        enemy.direction = (PlayerState.position - enemy.pos).normalized()
        enemy.vel = enemy.direction * enemy.speed
```

**Bottleneck:** With 500+ entities, position/velocity calculations consume significant main thread time.

### Threading Architecture Design

**Godot 4.x WorkerThreadPool Integration:**
```gdscript
# Phase 5: Parallel entity updates using WorkerThreadPool
class_name ThreadedEntityUpdateManager

const ENTITIES_PER_THREAD := 64  # Optimal batch size for cache locality
var _worker_tasks: Array[WorkerThreadPool.TaskID] = []
var _thread_results: Array[Dictionary] = []

func update_entities_threaded(entities: Array[EnemyEntity], dt: float) -> void:
    var batch_count = (entities.size() + ENTITIES_PER_THREAD - 1) / ENTITIES_PER_THREAD
    _worker_tasks.clear()
    _thread_results.resize(batch_count)

    # Submit batched work to thread pool
    for batch_idx in range(batch_count):
        var start_idx = batch_idx * ENTITIES_PER_THREAD
        var end_idx = min(start_idx + ENTITIES_PER_THREAD, entities.size())
        var batch_entities = entities.slice(start_idx, end_idx)

        var task_id = WorkerThreadPool.add_task(
            _update_entity_batch.bind(batch_entities, dt, batch_idx)
        )
        _worker_tasks.append(task_id)

    # Wait for all threads to complete
    for task_id in _worker_tasks:
        WorkerThreadPool.wait_for_task_completion(task_id)

func _update_entity_batch(entities: Array[EnemyEntity], dt: float, batch_idx: int) -> void:
    # Thread-safe entity updates (no shared state modification)
    var player_pos = PlayerState.get_cached_position()  # Read-only access

    for entity in entities:
        # Pure mathematical operations - thread safe
        var direction = (player_pos - entity.pos).normalized()
        entity.vel = direction * entity.speed
        entity.pos += entity.vel * dt

        # Boundary checking
        if entity.pos.length() > arena_bounds:
            entity.pos = entity.pos.normalized() * arena_bounds
```

**Performance Target:** 3-4x improvement for entity updates with 500+ entities.

### Implementation Strategy

1. **Thread-Safe Data Access Patterns**
   ```gdscript
   # Read-only player state cache for threads
   class PlayerStateCache:
       static var _cached_position: Vector2
       static var _cache_frame: int = -1

       static func get_cached_position() -> Vector2:
           var current_frame = Engine.get_process_frames()
           if current_frame != _cache_frame:
               _cached_position = PlayerState.position
               _cache_frame = current_frame
           return _cached_position
   ```

2. **Batch Size Optimization**
   - Test batch sizes: 32, 64, 128 entities per thread
   - Profile cache miss rates and thread overhead
   - Target: Minimize context switching while maximizing parallelism

3. **Thread Pool Management**
   ```gdscript
   # Optimal thread count based on hardware
   var optimal_thread_count = min(OS.get_processor_count() - 1, 4)  # Reserve main thread
   WorkerThreadPool.max_threads = optimal_thread_count
   ```

**Risk Mitigation:**
- Keep main thread as fallback for threading failures
- Extensive testing on different CPU configurations
- Thread safety validation with race condition detection

## Task 2: EntityTracker Spatial Grid Optimization

### Problem Analysis
Current EntityTracker uses O(N) scanning for spatial queries:

```gdscript
# Current: O(N) for every radar update, collision check
func get_entities_in_range(center: Vector2, radius: float) -> Array:
    var result = []
    for entity_id in _entities.keys():
        if _entities[entity_id].pos.distance_to(center) <= radius:
            result.append(entity_id)
    return result
```

**Impact:** Radar system performs 120+ spatial queries per second (60Hz * 2 queries/frame).

### Spatial Grid Architecture

**Design: Hierarchical Spatial Indexing**
```gdscript
class_name SpatialEntityGrid

const GRID_CELL_SIZE := 256  # Optimized for typical entity interaction ranges
const MAX_ENTITIES_PER_CELL := 32  # Before cell subdivision

# Spatial grid: world_coord -> entity_lists
var _spatial_grid: Dictionary = {}  # Vector2i -> Array[String]
var _entity_to_cells: Dictionary = {}  # entity_id -> Array[Vector2i]

func update_entity_position(entity_id: String, old_pos: Vector2, new_pos: Vector2) -> void:
    var old_cell = _world_to_grid(old_pos)
    var new_cell = _world_to_grid(new_pos)

    if old_cell != new_cell:
        _remove_from_cell(entity_id, old_cell)
        _add_to_cell(entity_id, new_cell)

func get_entities_in_range(center: Vector2, radius: float) -> Array[String]:
    # O(grid_cells) instead of O(all_entities)
    var grid_radius = int(ceil(radius / GRID_CELL_SIZE)) + 1
    var center_cell = _world_to_grid(center)

    var result: Array[String] = []
    for x in range(center_cell.x - grid_radius, center_cell.x + grid_radius + 1):
        for y in range(center_cell.y - grid_radius, center_cell.y + grid_radius + 1):
            var cell_coord = Vector2i(x, y)
            var entities_in_cell = _spatial_grid.get(cell_coord, [])

            # Fine-grained distance check within cell
            for entity_id in entities_in_cell:
                var entity_pos = EntityTracker.get_entity(entity_id).pos
                if entity_pos.distance_to(center) <= radius:
                    result.append(entity_id)

    return result
```

**Performance Target:** 5-10x improvement for spatial queries (radar, collision detection).

### Integration with Existing Systems

1. **RadarSystem Integration**
   ```gdscript
   # Before: O(N) scan of all entities
   var nearby_enemies = EntityTracker.get_all_entities_by_type("enemy")

   # After: O(grid_cells) spatial query
   var nearby_enemies = EntityTracker.get_entities_in_range(player_pos, radar_range, "enemy")
   ```

2. **Collision Detection Optimization**
   ```gdscript
   # Optimized enemy-player collision detection
   func _check_enemy_player_collisions() -> void:
       var player_pos = PlayerState.get_position()
       var collision_candidates = EntityTracker.get_entities_in_range(
           player_pos, max_enemy_size + player_radius, "enemy"
       )

       for entity_id in collision_candidates:
           # Precise collision check only for spatially filtered entities
           if _circle_overlap(player_pos, entity.pos, collision_radius):
               DamageService.apply_damage(EntityId.player(), enemy.damage)
   ```

## Task 3: Data-Oriented Design Conversion

### Structure of Arrays (SoA) Optimization

**Current: Array of Structures (AoS)**
```gdscript
# Cache-unfriendly: scattered memory access
var enemies: Array[EnemyEntity] = []  # Each entity = separate allocation

for enemy in enemies:
    enemy.pos += enemy.vel * dt  # Memory jumps between objects
```

**Target: Structure of Arrays (SoA)**
```gdscript
# Cache-friendly: contiguous memory access
class_name EnemyArrayManager
var positions: PackedVector2Array = PackedVector2Array()
var velocities: PackedVector2Array = PackedVector2Array()
var healths: PackedFloat32Array = PackedFloat32Array()
var alive_flags: PackedByteArray = PackedByteArray()

func update_positions_vectorized(dt: float) -> void:
    # SIMD-friendly vectorized operations
    for i in range(positions.size()):
        if alive_flags[i]:
            positions[i] += velocities[i] * dt
```

**Performance Target:** 20-30% improvement in entity update throughput via better cache locality.

## Task 4: Performance Monitoring & Regression Testing

### Automated Performance Baselines

```gdscript
# Comprehensive performance regression detection
extends Node
class_name PerformanceRegressionMonitor

const BASELINE_TARGETS = {
    "500_entities_fps": 60.0,
    "1000_entities_fps": 30.0,
    "spatial_query_ms": 2.0,
    "memory_growth_mb": 10.0
}

func run_regression_suite() -> Dictionary:
    var results = {}

    # Entity scaling test
    results["entity_scaling"] = _test_entity_scaling()

    # Spatial query performance
    results["spatial_performance"] = _test_spatial_queries()

    # Memory stability
    results["memory_stability"] = _test_memory_stability()

    # Threading efficiency
    results["threading_efficiency"] = _test_threading_performance()

    return results
```

### CI/CD Integration

```yaml
# GitHub Actions performance validation
- name: Performance Regression Testing
  run: |
    "./Godot_v4.4.1-stable_win64_console.exe" --headless tests/performance/regression_suite.tscn
    # Fail build if performance degrades >10%
```

## Implementation Timeline

**Week 1: Multi-threaded Entity Updates**
- Day 1-2: Thread safety analysis and design
- Day 3-4: WorkerThreadPool integration
- Day 5: Batch size optimization and testing

**Week 2: Spatial Grid Optimization**
- Day 1-2: Spatial grid implementation
- Day 3-4: EntityTracker integration
- Day 5: RadarSystem and collision detection optimization

**Week 3: Data Layout & Testing**
- Day 1-2: Structure of Arrays conversion
- Day 3-4: Performance regression test suite
- Day 5: Documentation and validation

## Risk Assessment

**High Risk:**
- Threading complexity and race conditions
- Platform-specific performance variations

**Medium Risk:**
- Spatial grid memory overhead
- Integration complexity with existing systems

**Low Risk:**
- Data layout changes (incremental improvement)
- Performance monitoring (tooling enhancement)

## Success Metrics

**Primary Targets:**
- [ ] 1000+ entities at 60+ FPS
- [ ] 3x improvement in entity update performance
- [ ] 5x improvement in spatial query performance
- [ ] Zero memory growth under load

**Secondary Targets:**
- [ ] Comprehensive performance regression testing
- [ ] Documentation of optimization patterns
- [ ] Platform performance validation (Windows/Linux/macOS)

## Next Steps

1. **Immediate:** Create detailed threading safety analysis document
2. **Week 1:** Implement multi-threaded entity updates with fallback
3. **Week 2:** Spatial grid optimization with EntityTracker integration
4. **Week 3:** Performance validation and regression testing framework

---

**Dependencies:**
- Godot 4.x WorkerThreadPool API
- Current Phase 4 optimizations (dictionary pools, bit-fields)
- EntityTracker spatial query interfaces

**References:**
- [Godot WorkerThreadPool Documentation](https://docs.godotengine.org/en/stable/classes/class_workerthreadpool.html)
- Current performance baseline: 146.4 FPS @ 500 entities
- SpawnDirector Phase 4 implementation patterns