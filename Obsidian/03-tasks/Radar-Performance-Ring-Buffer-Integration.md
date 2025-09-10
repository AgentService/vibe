# Radar Performance Ring Buffer Integration

Status: 🔄 In Progress (September 2025)  
Priority: High  
Estimated Effort: 2–3 hours  
Dependencies: Performance Optimization System (completed)

## 🎯 Problem Statement

Radar system experiences frame drops at 500+ entities due to inefficient EntityTracker scanning and missing ring buffer optimizations.

### Current Bottleneck
```gdscript
# RadarSystem._update_and_emit_radar_data() at 60 Hz
var enemy_ids = EntityTracker.get_entities_by_type("enemy") # O(N) iteration through ALL entities
var boss_ids = EntityTracker.get_entities_by_type("boss")   # O(N) iteration through ALL entities

# EntityTracker.get_entities_by_type() - PERFORMANCE KILLER
func get_entities_by_type(entity_type: String) -> Array[String]:
    var result: Array[String] = []
    for id in _entities.keys(): # Iterates ALL entities (500+ enemies + 500+ bosses)
        var entity_data = _entities[id] # Dictionary lookup per entity
        if entity_data.get("type", "") == entity_type and entity_data.get("alive", false):
            result.append(id) # Array append per matching entity
    return result
```

Performance Impact at 500 enemies + 500 bosses:
- 60 Hz radar updates × 1000 total entities = 60,000 iterations/second
- 2 type queries per frame (enemy + boss) = 120,000 dictionary lookups/second
- Array allocations and string comparisons every radar update
- O(N) scan complexity instead of O(1) cached/indexed lookups

## 🏗️ Solution: Type-Indexed Views + Batched Ring Buffer (Latest-Only)

Single manager that:
- Uses EntityTracker-maintained, O(1) type-indexed arrays (no per-frame scans)
- Emits one batched payload per step (ids, positions, types) with latest-only semantics
- Avoids allocating per-entity objects (no `RadarEntity` in hot path)
- Aligns update frequency with 30 Hz combat step; UI smooths/interpolates at 60 Hz

## ✅ Refinements and Constraints (Added)

- Incremental caches via EntityTracker
  - Maintain `_entities_by_type: Dictionary[String, PackedStringArray]` inside EntityTracker (updated on register/unregister).
  - Provide `get_entities_by_type_view(entity_type)` returning the internal array by reference (read-only view, no copying).
  - Provide `get_positions_for(ids, out_positions)` to fill a caller-owned `PackedVector2Array` without allocations.

- Data shape: arrays, not objects
  - Emit parallel arrays (ids: `PackedStringArray`, positions `PackedVector2Array`, types: `PackedByteArray` or `PackedInt32Array`).
  - Avoid allocating `EventBus.RadarEntity` per entity per tick. If a class is required elsewhere, pool instances and update fields.

- Update frequency and UI smoothing
  - Produce radar data at 30 Hz (combat step). Consumers interpolate marker positions to 60 Hz if needed; document this in `RadarSystem`.

- Ring buffer backpressure: latest-only
  - Radar data is transient. Use a small ring buffer and coalesce to the latest payload on read (drop-old).
  - Add helper `pop_latest_or_null()` to `RingBufferUtil` to consume only the most recent.

- Static typing and signal hygiene
  - Typed signals and payloads (e.g., `EventBus.CombatStepPayload`).
  - Connect/disconnect via `Callable`; guard against duplicate connections.

- Zero-allocation discipline
  - Reuse pre-allocated arrays with `resize(0)` between frames; use `append_array` to avoid temp allocations.
  - Avoid building new arrays from `Dictionary.keys()`; never copy type lists in hot paths.

- Tests and profiling
  - Add tests for ring buffer backpressure (latest-only), type-index integrity (swap-remove correctness), and zero-alloc hot loops (profiler snapshots).
  - Benchmark with 1000+ entities; assert no frame drops and no allocation spikes.

## 🔩 Reference Implementation Sketch

Paths/names assume existing utils; adjust if your repo differs.

```gdscript
# res://scripts/systems/radar/RadarUpdateManager.gd
class_name RadarUpdateManager
extends Node

const RingBufferUtil = preload("res://scripts/utils/RingBuffer.gd")
const ObjectPoolUtil = preload("res://scripts/utils/ObjectPool.gd")
const PayloadResetUtil = preload("res://scripts/utils/PayloadReset.gd")

# Reusable batched payload buffers (cleared each step, not reallocated)
var _ids_buf: PackedStringArray = PackedStringArray()
var _pos_buf: PackedVector2Array = PackedVector2Array()
var _type_buf: PackedByteArray = PackedByteArray() # 0 = enemy, 1 = boss

# Temp buffers to fetch positions per type without allocation
var _enemy_pos_tmp: PackedVector2Array = PackedVector2Array()
var _boss_pos_tmp: PackedVector2Array = PackedVector2Array()

var _player_position: Vector2 = Vector2.ZERO

# Queue + pool with latest-only semantics
var _radar_update_queue: RingBufferUtil
var _radar_payload_pool: ObjectPoolUtil

func _ready() -> void:
    EventBus.combat_step.connect(Callable(self, "_on_combat_step"))
    EventBus.player_position_changed.connect(Callable(self, "_on_player_position_changed"))
    if EntityTracker:
        EntityTracker.entity_registered.connect(Callable(self, "_on_entity_registered"))
        EntityTracker.entity_unregistered.connect(Callable(self, "_on_entity_unregistered"))

    _radar_update_queue = RingBufferUtil.new(8) # small, latest-only
    _radar_payload_pool = ObjectPoolUtil.new(
        PayloadResetUtil.create_radar_batch_payload,
        PayloadResetUtil.clear_radar_batch_payload
    )

func _on_player_position_changed(pos: Vector2) -> void:
    _player_position = pos

func _on_entity_registered(_id: String, _type: String) -> void:
    # No rebuild needed with type-indexed views; kept for future diagnostics
    pass

func _on_entity_unregistered(_id: String) -> void:
    pass

func _on_combat_step(_payload: EventBus.CombatStepPayload) -> void:
    # Clear reusable buffers without reallocations
    _ids_buf.resize(0)
    _pos_buf.resize(0)
    _type_buf.resize(0)
    _enemy_pos_tmp.resize(0)
    _boss_pos_tmp.resize(0)

    # Get read-only views from EntityTracker (no copying)
    var enemy_ids: PackedStringArray = EntityTracker.get_entities_by_type_view("enemy")
    var boss_ids: PackedStringArray = EntityTracker.get_entities_by_type_view("boss")

    # Fill temp position buffers without allocations
    EntityTracker.get_positions_for(enemy_ids, _enemy_pos_tmp)
    EntityTracker.get_positions_for(boss_ids, _boss_pos_tmp)

    # Build batched arrays: enemies then bosses (caller knows type buf layout)
    _ids_buf.append_array(enemy_ids)
    _pos_buf.append_array(_enemy_pos_tmp)
    _type_buf.resize(_type_buf.size() + enemy_ids.size())
    for i in enemy_ids.size():
        _type_buf.push_back(0)

    _ids_buf.append_array(boss_ids)
    _pos_buf.append_array(_boss_pos_tmp)
    for i in boss_ids.size():
        _type_buf.push_back(1)

    # Single batched payload per step
    var p = _radar_payload_pool.acquire()
    p["ids"] = _ids_buf
    p["positions"] = _pos_buf
    p["types"] = _type_buf
    p["player_pos"] = _player_position

    # Latest-only queueing: if full, drop oldest
    _radar_update_queue.try_push(p)

    _emit_latest()

func _emit_latest() -> void:
    var latest := _radar_update_queue.pop_latest_or_null()
    if latest == null:
        return
    # Maintain existing EventBus interface (e.g., radar_data_updated(payload))
    EventBus.radar_data_updated.emit(latest)
    _radar_payload_pool.release(latest)
```

### EntityTracker additions

```gdscript
# Type-indexed storage for O(1) lookups (no per-frame scans)
var _entities_by_type: Dictionary = {} # String -> PackedStringArray
# _entities: Dictionary[String, EntityData] must store positions efficiently (e.g., structs or typed resources)

func register_entity(id: String, data: Dictionary) -> void:
    _entities[id] = data
    var t: String = data.get("type", "unknown")
    if not _entities_by_type.has(t):
        _entities_by_type[t] = PackedStringArray()
    var arr: PackedStringArray = _entities_by_type[t]
    arr.push_back(id)
    _entities_by_type[t] = arr # ensure set-back if needed by engine version
    entity_registered.emit(id, t)

func unregister_entity(id: String) -> void:
    if not _entities.has(id):
        return
    var data: Dictionary = _entities[id]
    var t: String = data.get("type", "unknown")
    if _entities_by_type.has(t):
        var arr: PackedStringArray = _entities_by_type[t]
        var idx: int = arr.find(id)
        if idx != -1:
            var last_idx: int = arr.size() - 1
            arr[idx] = arr[last_idx]
            arr.resize(last_idx) # swap-remove O(1)
            _entities_by_type[t] = arr
    _entities.erase(id)
    entity_unregistered.emit(id)

# Read-only view: return internal array by reference (do not mutate)
func get_entities_by_type_view(entity_type: String) -> PackedStringArray:
    return _entities_by_type.get(entity_type, PackedStringArray())

# Fill positions for the given ids into out_positions without allocations
func get_positions_for(ids: PackedStringArray, out_positions: PackedVector2Array) -> void:
    out_positions.resize(0)
    out_positions.reserve(ids.size())
    for i in ids.size():
        var id: String = ids[i]
        var e = _entities.get(id)
        if e:
            out_positions.push_back(e.pos) # pos should be a stored Vector2 field
```

### RadarSystem consumer notes

- Keep `EventBus.radar_data_updated` signal payload shape consistent for UI.
- If UI expects per-entity objects, convert batched arrays at the very edge with a pooled object factory (off the hot path), or refactor UI to consume arrays.
- Interpolate between 30 Hz updates on the UI side for smooth visuals at 60 Hz.

## 📊 Expected Performance Gains

| Metric | Before (500+500 entities) | After | Improvement |
|--------|---------------------------|-------|-------------|
| EntityTracker Scans | 60 Hz × 2 type scans × 1000 entities = 120K/sec | 0 per-frame scans (O(1) views) | Eliminated |
| Dictionary Lookups | 120,000/sec individual | Per-id lookups only when filling positions | 75%+ reduction |
| Array Allocations | Per-frame allocations | Reused arrays, zero-alloc hot path | Eliminated |
| Update Frequency | 60 Hz visual updates | 30 Hz combat step alignment | Consistent with combat |

## 🧪 Testing Strategy

- Isolated tests (scene-based): Validate type-index views, swap-remove behavior, and that consumers do not mutate returned arrays.
- Performance benchmark: 500 enemies + 500 bosses; 60 s sustained; assert stable 30 Hz radar updates and no allocation spikes.
- Backpressure tests: Overfill buffer; assert latest-only consumption and deterministic behavior.
- UI integration test: Ensure interpolation maintains 60 Hz smoothness without visual stutter.

Example micro-benchmark:
```gdscript
# tests/test_radar_performance_1000_entities.gd
extends SceneTree

func _initialize():
    for i in range(500):
        spawn_enemy_at_position(Vector2(i * 10, 0))
        spawn_boss_at_position(Vector2(i * 10, 100))

    test_radar_performance_sustained(60.0)
    validate_performance_improvement()
```

## 🔧 Integration Points

- RingBufferUtil: Add/ensure `pop_latest_or_null()` to coalesce to newest radar payload.
- ObjectPoolUtil: Add `create_radar_batch_payload()`/`clear_radar_batch_payload()` factories.
- EntityTracker: Implement type-indexing, `get_entities_by_type_view()`, and `get_positions_for()` (zero-alloc).
- EventBus: Maintain `radar_data_updated` interface; ensure typed signal payloads for clarity.

## 🔄 Implementation Phases

### Phase 1: EntityTracker Type Indexing (45 min)
- [x] Define `_entities_by_type` dictionary in EntityTracker
- [ ] Update `register_entity()` and `unregister_entity()` with swap-remove maintenance
- [ ] Add `get_entities_by_type_view()` (read-only view, no copy)
- [ ] Add `get_positions_for(ids, out_positions)` zero-alloc API
- [ ] Test with 50+ mixed entities for correctness

### Phase 2: RadarUpdateManager Infrastructure (45 min)
- [ ] Create `RadarUpdateManager` class with reusable buffers and latest-only ring buffer
- [ ] Wire to `EventBus.combat_step` (30 Hz)
- [ ] Provide batched payload emission; avoid per-entity allocations
- [ ] Test payload structure and integrity

### Phase 3: 30 Hz Integration and UI Adaptation (30 min)
- [ ] Replace RadarSystem 60 Hz scanning with RadarUpdateManager 30 Hz payload consumption
- [ ] Add UI interpolation for smooth visuals (if needed)
- [ ] Maintain existing `EventBus.radar_data_updated` interface

### Phase 4: Performance Testing (30 min)
- [ ] Benchmark 1000+ entity radar performance
- [ ] Validate latest-only backpressure and no allocation spikes
- [ ] Confirm no visual degradation from 30 Hz updates

### Phase 5: Documentation & Cleanup (30 min)
- [ ] Update Obsidian performance documentation
- [ ] Remove `EntityTracker.get_entities_by_type()` direct usage
- [ ] Document type-indexed view and zero-alloc APIs in EntityTracker

## 📋 Cleanup Checklist (Final Phase)

Code Removal
- [ ] Remove direct `EntityTracker.get_entities_by_type()` scans in RadarSystem
- [ ] Remove 60 Hz `_process` scans in favor of 30 Hz combat step consumption
- [ ] Clean up redundant entity scanning loops

Performance Validation
- [ ] Confirm 1000+ entity radar updates maintain stable performance at 30 Hz
- [ ] Verify EntityTracker type lookups are O(1) view-based
- [ ] Validate zero-allocation radar updates during sustained gameplay

Documentation Updates
- [ ] Update `Obsidian/systems/Performance-Optimization-System.md` to include radar optimization
- [ ] Add radar performance metrics and latest-only backpressure policy
- [ ] Document EntityTracker type-indexed architecture and "view" semantics

## 🎯 Success Criteria

- Performance: 1000+ entities with stable 30 Hz radar updates  
- Efficiency: EntityTracker type lookups converted from O(N) scans to O(1) views  
- Architecture: Reuses ring buffer/object pool infrastructure with typed APIs  
- Consistency: Radar updates aligned with 30 Hz combat step frequency  
- Memory: Zero-allocation radar processing in hot paths

---

Related Systems:
- [[Performance-Optimization-System]] — Base ring buffer infrastructure
- [[Boss-Performance-Ring-Buffer-Integration]] — Similar optimization pattern
- [[Enemy-System-Architecture]] — Combat step alignment reference

Implementation Notes:
- Prefer batched arrays and latest-only semantics for transient data
- Treat type-index arrays as read-only views; never mutate from consumers
- Add UI interpolation to bridge 30 Hz data to 60 Hz rendering without stutter
