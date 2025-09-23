# Boss Performance Ring Buffer Integration

Status: 🔄 In Progress (September 2025)  
Priority: High  
Estimated Effort: 2–3 hours  
Dependencies: Performance Optimization System (completed)

## 🎯 Problem Statement

Boss system experiences frame drops at 500+ entities due to individual signal connection overhead and missing ring buffer optimizations.

### Current Bottleneck
```gdscript
# Each boss connects individually (500+ connections)
EventBus.combat_step.connect(_on_combat_step)         # 500+ signal connections
EntityTracker.update_entity_position(entity_id, pos)  # 30K/sec individual calls
DamageService.update_entity_position(entity_id, pos)  # 30K/sec individual calls
```

Performance Impact at 500 bosses:
- 500+ individual signal connections to `combat_step` (30 Hz)
- 30,000 individual system calls per second
- Missing zero-allocation patterns from regular enemy optimization
- O(N) signal dispatch overhead every combat step

## 🏗️ Solution: Centralized Boss Update Manager

Single autoloaded manager that:
- Keeps a typed, array-backed registry of bosses
- Batches position/flags into a single payload per step
- Uses ring buffer + object pool with clear backpressure policy
- Avoids per-frame allocations and dictionary iteration

## ✅ Refinements and Constraints (Added)

- Autoload and access
  - Promote `BossUpdateManager` to an autoload singleton (or inject via `GameOrchestrator` consistently across runtime/tests).
  - Registration is done via the manager; no boss scene connects to `combat_step` directly.

- Static typing and interfaces
  - Use explicit types in vars/functions per repo rules.
  - Enforce a boss batch interface (e.g., `_update_ai_batch(dt: float) -> void`) to avoid `has_method` checks in hot loops.

- Zero-alloc registry and iteration
  - Maintain parallel arrays for O(1) swap-remove and allocation-free iteration:
    - `_boss_ids: PackedStringArray`
    - `_boss_nodes: Array[CharacterBody2D]`
    - `_boss_index: Dictionary` (id → index)
  - Never iterate `Dictionary.keys()` in hot loops.

- Single batched payload per step
  - Replace per-entity payload queues (≤ 500 pushes) with one batched payload containing arrays (ids, positions, flags).
  - Pre-size object pool and ring buffer; define overflow policy (drop-old or coalesce-to-latest).

- Stable IDs
  - Use IDs from central `CharacterManager`/`EntityTracker` (single source of truth). Avoid ad-hoc `"boss_"+instance_id`.

- Batch into EntityTracker
  - Add `EntityTracker.batch_update_positions(ids: PackedStringArray, positions: PackedVector2Array) -> void`.
  - Replace individual `update_entity_position()` calls.

- Concurrency/teardown safety
  - Iterate over arrays by index; handle spawn/despawn by swap-remove outside active iteration.
  - Connect/disconnect all signals in `_ready()`/`_exit_tree()`; prevent duplicate connections.

- Tests and profiling
  - Add overflow/backpressure tests for ring buffer.
  - Assert no allocations in hot loops (profiler snapshot).
  - Deterministic RNG seeds for repeatability.

## 🔩 Reference Implementation Sketch

Paths/names assume existing utils; adjust if your repo differs.

```gdscript
# res://scripts/systems/boss/BossUpdateManager.gd
class_name BossUpdateManager
extends Node

const RingBufferUtil = preload("res://scripts/utils/RingBuffer.gd")
const ObjectPoolUtil = preload("res://scripts/utils/ObjectPool.gd")
const PayloadResetUtil = preload("res://scripts/utils/PayloadReset.gd")

# Array-backed registry for zero-alloc iteration and O(1) removal (swap-remove)
var _boss_ids: PackedStringArray = PackedStringArray()
var _boss_nodes: Array[CharacterBody2D] = []
var _boss_index: Dictionary = {} # id -> index

# Reusable batched payload buffers (cleared each step, not reallocated)
var _ids_buf: PackedStringArray = PackedStringArray()
var _pos_buf: PackedVector2Array = PackedVector2Array()
var _ai_flags_buf: PackedByteArray = PackedByteArray() # 1 = true, 0 = false

# Ring buffer with latest-only or drop-old policy (configure explicitly)
var _boss_update_queue: RingBufferUtil
var _batched_payload_pool: ObjectPoolUtil

func _ready() -> void:
    EventBus.combat_step.connect(Callable(self, "_on_combat_step"))
    _boss_update_queue = RingBufferUtil.new(64) # one payload per frame is sufficient
    _batched_payload_pool = ObjectPoolUtil.new(
        PayloadResetUtil.create_boss_batch_payload,
        PayloadResetUtil.clear_boss_batch_payload
    )

func register_boss(boss: CharacterBody2D, boss_id: String) -> void:
    # boss_id should come from CharacterManager/EntityTracker for consistency
    if _boss_index.has(boss_id):
        return
    var idx: int = _boss_ids.size()
    _boss_index[boss_id] = idx
    _boss_ids.push_back(boss_id)
    _boss_nodes.push_back(boss)
    Logger.info("Boss registered: %s" % boss_id, "performance")

func unregister_boss(boss_id: String) -> void:
    if not _boss_index.has(boss_id):
        return
    var idx: int = _boss_index[boss_id]
    var last_idx: int = _boss_ids.size() - 1
    var last_id: String = _boss_ids[last_idx]

    # swap to keep O(1)
    _boss_ids[idx] = last_id
    _boss_nodes[idx] = _boss_nodes[last_idx]
    _boss_index[last_id] = idx

    _boss_ids.resize(last_idx)
    _boss_nodes.resize(last_idx)
    _boss_index.erase(boss_id)

func _on_combat_step(payload: EventBus.CombatStepPayload) -> void:
    var dt: float = payload.dt
    var count: int = _boss_ids.size()

    # Clear reusable buffers without reallocations
    _ids_buf.resize(0)
    _pos_buf.resize(0)
    _ai_flags_buf.resize(0)

    # Iterate by index; avoid dictionary key arrays
    for i in range(count):
        var boss := _boss_nodes[i]
        if not is_instance_valid(boss):
            continue

        _ids_buf.push_back(_boss_ids[i])
        _pos_buf.push_back(boss.global_position)
        _ai_flags_buf.push_back(1) # true

        # Enforce an interface to avoid per-frame has_method checks
        boss._update_ai_batch(dt)

    # Single batched payload per step
    var p = _batched_payload_pool.acquire()
    # Depending on your pool payload shape, either fields or dict keys:
    p["ids"] = _ids_buf
    p["positions"] = _pos_buf
    p["ai_flags"] = _ai_flags_buf

    # Backpressure policy: if full, drop oldest or replace latest (configure in RingBufferUtil)
    _boss_update_queue.try_push(p)

    _process_position_updates()

func _process_position_updates() -> void:
    # Consume just the latest payload if queue > 1 to coalesce updates
    var latest := _boss_update_queue.pop_latest_or_null()
    if latest == null:
        return

    # Batch update entity positions in one call
    EntityTracker.batch_update_positions(
        latest["ids"],
        latest["positions"]
    )

    _batched_payload_pool.release(latest)
```

### Boss scene scripts

```gdscript
# In each boss script (e.g., AncientLich.gd, BananaLord.gd)
extends CharacterBody2D

func _ready() -> void:
    # OLD: EventBus.combat_step.connect(_on_combat_step)  # REMOVE
    # NEW: Register with centralized manager
    var boss_id: String = CharacterManager.get_id_for(self) # or EntityTracker API; single source of truth
    BossUpdateManager.register_boss(self, boss_id)

    # Keep existing damage sync and other connections
    EventBus.damage_entity_sync.connect(Callable(self, "_on_damage_entity_sync"))

func _exit_tree() -> void:
    var boss_id: String = CharacterManager.get_id_for(self)
    BossUpdateManager.unregister_boss(boss_id)
    if EventBus.damage_entity_sync.is_connected(Callable(self, "_on_damage_entity_sync")):
        EventBus.damage_entity_sync.disconnect(Callable(self, "_on_damage_entity_sync"))

# Enforced batch AI interface
func _update_ai_batch(dt: float) -> void:
    _update_ai(dt)
    last_attack_time += dt
```

### EntityTracker additions

```gdscript
# Batch API to replace per-entity updates
func batch_update_positions(ids: PackedStringArray, positions: PackedVector2Array) -> void:
    var n: int = ids.size()
    for i in range(n):
        var id: String = ids[i]
        var pos: Vector2 = positions[i]
        # Update internal storage/spatial index without allocations
        _update_spatial_index(id, pos)
        var data = _entities.get(id)
        if data:
            data.pos = pos
```

## 📊 Expected Performance Gains

| Metric | Before (500 bosses) | After | Improvement |
|--------|---------------------|-------|-------------|
| Signal Connections | 500+ individual | 1 centralized | ~99.8% fewer |
| Position Updates | 30K/sec individual | 30 Hz × 1 batched payload | Orders of magnitude fewer |
| Memory Allocations | Per-call allocation | Zero-allocation hot loop | Eliminated |
| Frame Consistency | Drops at 500+ | Stable scaling | Improved |

## 🧪 Testing Strategy

- Isolated tests (scene-based): Validate registration, swap-remove correctness, and signal lifecycles.
- Performance benchmark: 500+ bosses, 60 s sustained; assert 60 FPS and no allocation spikes during `combat_step`.
- Backpressure tests: Fill ring buffer; assert policy (drop-old or coalesce-latest) behaves deterministically.
- Regression tests: No change in boss AI outcomes vs baseline.

Example micro-benchmark:
```gdscript
# tests/test_boss_performance_500_entities.gd
extends SceneTree

func _initialize():
    for i in range(500):
        spawn_banana_boss_at_position(Vector2(i * 10, 0))

    test_performance_sustained(60.0)
    validate_performance_parity()
```

## 🔧 Integration Points

- RingBufferUtil: One payload per step; provide `pop_latest_or_null()` helper for coalescing.
- ObjectPoolUtil: Add `create_boss_batch_payload()`/`clear_boss_batch_payload()` factories.
- EntityTracker: Implement `batch_update_positions()`; ensure zero-alloc updates.
- EventBus: Typed `combat_step` payload (e.g., `EventBus.CombatStepPayload`).

## 🔄 Implementation Phases

### Phase 1: Infrastructure (30 min)
- [x] Create `BossUpdateManager` class skeleton (autoload)
- [ ] Extend `PayloadReset` with boss batch payload factories
- [ ] Initialize ring buffer (capacity ~64) + define backpressure policy (latest-only or drop-old)

### Phase 2: Registration System (30 min)
- [ ] Implement array-backed registry with swap-remove
- [ ] Use stable IDs from `CharacterManager`/`EntityTracker`
- [ ] Test with 1–5 bosses and validate register/unregister

### Phase 3: Batch Processing (45 min)
- [ ] Replace individual signal connections in boss scripts
- [ ] Implement `_on_combat_step` batching (ids/positions/flags)
- [ ] Implement `EntityTracker.batch_update_positions`
- [ ] Test with 50+ bosses

### Phase 4: Performance Testing (45 min)
- [ ] Benchmark 500+ boss performance
- [ ] Stress ring buffer overflow; assert policy correctness
- [ ] Validate zero-alloc in hot loop (profiler)

### Phase 5: Documentation & Cleanup (30 min)
- [ ] Update Obsidian performance docs
- [ ] Remove old individual connection code
- [ ] Migration guide for boss types (`_on_combat_step` → `_update_ai_batch`)

## 📋 Cleanup Checklist (Final Phase)

Code Removal
- [ ] Remove `EventBus.combat_step.connect()` calls from all boss scripts
- [ ] Remove individual `_on_combat_step()` methods (use `_update_ai_batch`)
- [ ] Remove direct per-entity position updates; use batch API

Documentation Updates
- [ ] Update `Obsidian/systems/Performance-Optimization-System.md` with boss optimization
- [ ] Add boss performance metrics and ring buffer backpressure policy
- [ ] Add migration guide for new boss types

Testing Validation
- [ ] Confirm 500+ bosses maintain 60 FPS
- [ ] Verify no regressions in boss AI/damage handling
- [ ] Validate memory usage stability and zero-alloc hot path

## 🎯 Success Criteria

- Performance: 500+ bosses at stable 60 FPS  
- Consistency: Performance parity with regular enemy system  
- Architecture: Reuses ring buffer/object pool infra with typed APIs  
- Maintainability: Centralized system with clear migration path  
- Memory: Zero-alloc boss updates during runtime

---

Related Systems:
- [[Performance-Optimization-System]] — Base ring buffer infrastructure
- [[Enemy-System-Architecture]] — Regular enemy comparison baseline
- [[Boss-System-Architecture]] — Boss scene patterns (to be updated)

Implementation Notes:
- Enforce interface for batch AI updates to avoid per-frame reflection checks
- Maintain array-backed registries; avoid `Dictionary.keys()` in hot loops
- Prefer latest-only coalescing for transient updates when consumers stall
