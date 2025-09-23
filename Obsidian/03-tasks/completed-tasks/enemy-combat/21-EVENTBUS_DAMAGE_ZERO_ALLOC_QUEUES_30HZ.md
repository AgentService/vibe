# EventBus/Damage Pipeline Zero-Allocation Queues (GDScript 30Hz)

Status: Ready to Start
Owner: Solo (Indie)
Priority: High
Type: Performance/Architecture
Dependencies: EventBus, Damage v2 (scripts/systems/damage_v2/DamageRegistry.gd), Logger, StateManager, PauseManager, RNG; RunClock (optional, if available)
Risk: Medium-Low (additive path, API-compatible)
Complexity: 5/10

---

## Purpose

Introduce a zero-allocation, batched event path for hot damage processing using preallocated ring buffers and payload pools, drained at a fixed 30Hz combat step. Preserve the single entry point architecture (DamageService.apply_damage) while eliminating per-frame allocations and reducing dispatch overhead.

**Key Architectural Decision:** Centralize the queue inside DamageService to preserve the single entry point and avoid sprinkling feature-flag conditionals across systems. All callers continue using DamageService.apply_damage(...) - the queueing is an internal optimization.

Decision: GDScript-first prototype (no GDExtension/atomics). Lock-free atomics are unnecessary on main-thread production/consumption; we'll add atomics only if we later introduce multi-thread producers.

---

## Goals & Acceptance Criteria

- [ ] Single entry point preserved:
  - All damage requests continue through DamageService.apply_damage()
  - No branching in MeleeSystem/DamageSystem - they remain unchanged
  - Queue is internal to DamageService (flag on = enqueue, flag off = process immediately)
- [ ] Zero-allocation in hot path:
  - Ring buffers for damage events preallocated at boot
  - Payload dictionaries/arrays acquired from pools and reused; no per-event allocations during gameplay
- [ ] Batched processing:
  - Drain queues at fixed cadence (30Hz combat step) to reduce dispatch overhead and stabilize frame times
- [ ] Determinism:
  - FIFO ordering per queue, deterministic batch size, stable behavior across runs
- [ ] Overflow policy:
  - Drop-oldest with counter and throttled warning logs; never crash. Metrics exposed for observability
- [ ] EventBus compatibility:
  - EventBus.damage_requested adapter routes to same DamageService path (both paths share queue)
- [ ] Tests & docs:
  - A/B testing with feature flag to ensure identical outcomes
  - Isolated tests for queue correctness and damage pipeline integrity
  - Architecture docs and changelog updated

---

## Design

### Centralized Architecture

**DamageService Internal Components:**
- `_damage_queue: RingBuffer` - Internal queue for damage requests
- `_payload_pool: ObjectPool` - Pooled damage payload dictionaries
- `_tags_pool: ObjectPool` - Pooled tag arrays
- `_processor_timer: Timer` - 30Hz processor (only when flag enabled)
- `_process_tick()` - Drain queue and call existing internal processing

**Feature Flag Integration:**
- `DamageService.apply_damage()` behavior:
  - Flag ON: enqueue payload for batch processing
  - Flag OFF: process immediately (current behavior)
- EventBus.damage_requested adapter routes to same DamageService path

### Components

1) **RingBuffer** (RefCounted, single-producer/consumer on main thread)
- Preallocated Array for slots
- Head/tail indices wrap with mask (size power-of-two recommended)
- Methods: `try_push(item)`, `try_pop()`, `is_full()`, `is_empty()`, `count()`

2) **ObjectPool** (RefCounted)
- Preallocated Dictionary payloads and Array pools for tags
- Methods: `acquire() -> Dictionary`, `release(dict: Dictionary)`
- Clear/reset payload fields on release (reuse underlying objects)

3) **PayloadReset** (RefCounted, static helpers)
- Payload cleanup utilities to avoid shape changes

### Payload Shape (Enhanced)
Dictionary with keys (superset for compatibility):
```gdscript
{
  target: StringName,           # Required
  base_damage: float,           # Required  
  source: StringName,           # Required
  tags: Array[StringName],      # Required (pooled)
  damage_type: StringName,      # Optional (default: "generic")
  knockback: float,             # Optional (default: 0.0)
  source_pos: Vector2           # Optional (default: Vector2.ZERO)
}
```

---

## Implementation Plan (Phases & Checklist)

### Phase A — Utilities (RingBuffer + ObjectPool + PayloadReset)
- [ ] `scripts/utils/RingBuffer.gd`
  ```gdscript
  extends RefCounted
  class_name RingBuffer

  var _buf: Array
  var _capacity: int
  var _mask: int
  var _head: int = 0
  var _tail: int = 0
  var _count: int = 0

  func setup(capacity: int) -> void:
      # Use next power-of-two for simple masking
      _capacity = max(2, _next_pow2(capacity))
      _mask = _capacity - 1
      _buf = []
      _buf.resize(_capacity)
      _head = 0
      _tail = 0
      _count = 0

  func try_push(item) -> bool:
      if _count == _capacity:
          return false
      _buf[_head] = item
      _head = (_head + 1) & _mask
      _count += 1
      return true

  func try_pop():
      if _count == 0:
          return null
      var item = _buf[_tail]
      _buf[_tail] = null
      _tail = (_tail + 1) & _mask
      _count -= 1
      return item

  func count() -> int: return _count
  func is_full() -> bool: return _count == _capacity
  func is_empty() -> bool: return _count == 0

  static func _next_pow2(v: int) -> int:
      v -= 1
      v |= v >> 1
      v |= v >> 2
      v |= v >> 4
      v |= v >> 8
      v |= v >> 16
      return v + 1
  ```

- [ ] `scripts/utils/ObjectPool.gd`
  ```gdscript
  extends RefCounted
  class_name ObjectPool

  var _pool: Array = []
  var _factory: Callable
  var _reset: Callable

  func setup(initial_size: int, factory: Callable, reset: Callable) -> void:
      _factory = factory
      _reset = reset
      _pool.resize(0)
      for i in initial_size:
          _pool.push_back(_factory.call())

  func acquire():
      if _pool.is_empty():
          return _factory.call()
      return _pool.pop_back()

  func release(obj) -> void:
      _reset.call(obj)
      _pool.push_back(obj)
  ```

- [ ] `scripts/utils/PayloadReset.gd`
  ```gdscript
  extends RefCounted
  class_name PayloadReset

  static func clear_damage_payload(d: Dictionary) -> void:
      # Preserve keys to avoid shape changes; reset values
      d["target"] = &""
      d["source"] = &""
      d["base_damage"] = 0.0
      d["damage_type"] = &"generic"
      d["knockback"] = 0.0
      d["source_pos"] = Vector2.ZERO
      var tags: Array = d.get("tags", [])
      if tags:
          tags.clear()
      else:
          d["tags"] = []
  ```

### Phase B — Feature Flag & Config
- [ ] Add config keys to BalanceDB (or config/debug.tres):
  ```gdscript
  # In CombatBalance.gd or debug config
  @export var use_zero_alloc_damage_queue: bool = false
  @export var damage_queue_capacity: int = 4096
  @export var damage_pool_size: int = 4096
  @export var damage_queue_max_per_tick: int = 2048
  @export var damage_queue_tick_rate_hz: float = 30.0
  ```
- [ ] Hook into hot-reload (F5) for A/B testing without restart

### Phase C — DamageService Integration (Internal Queue)
- [ ] Modify `scripts/systems/damage_v2/DamageRegistry.gd` (DamageService):
  ```gdscript
  # Internal queue components (only when flag enabled)
  var _damage_queue: RingBuffer
  var _payload_pool: ObjectPool
  var _tags_pool: ObjectPool
  var _processor_timer: Timer
  var _queue_enabled: bool = false

  # Metrics
  var _enqueued: int = 0
  var _processed: int = 0
  var _dropped_overflow: int = 0
  var _max_watermark: int = 0
  var _last_tick_ms: float = 0.0
  var _total_ticks: int = 0

  func _ready() -> void:
      # ... existing setup ...
      _setup_queue_if_enabled()
      
      # EventBus adapter (routes to same path)
      EventBus.damage_requested.connect(_on_damage_requested_compat)

  func _setup_queue_if_enabled() -> void:
      _queue_enabled = BalanceDB.get_combat_value("use_zero_alloc_damage_queue", false)
      if not _queue_enabled:
          return
          
      # Initialize queue components
      _damage_queue = RingBuffer.new()
      _damage_queue.setup(BalanceDB.get_combat_value("damage_queue_capacity", 4096))
      
      _payload_pool = ObjectPool.new()
      _payload_pool.setup(
          BalanceDB.get_combat_value("damage_pool_size", 4096),
          func(): return {"target":&"","source":&"","base_damage":0.0,"damage_type":&"generic","knockback":0.0,"source_pos":Vector2.ZERO,"tags":[]},
          PayloadReset.clear_damage_payload
      )
      
      _tags_pool = ObjectPool.new()
      _tags_pool.setup(128, func(): return [], func(a: Array): a.clear())
      
      # Setup 30Hz processor
      _processor_timer = Timer.new()
      _processor_timer.one_shot = false
      _processor_timer.wait_time = 1.0 / BalanceDB.get_combat_value("damage_queue_tick_rate_hz", 30.0)
      add_child(_processor_timer)
      _processor_timer.timeout.connect(_process_tick)
      _processor_timer.start()
      
      # Pause/State gates
      PauseManager.paused_changed.connect(_on_paused_changed)
      _apply_pause_state(PauseManager.is_paused())

  func apply_damage(target: String, damage: float, source: String, tags: Array, damage_type: String = "generic", knockback: float = 0.0, source_pos: Vector2 = Vector2.ZERO) -> bool:
      if _queue_enabled:
          return _enqueue_damage(target, damage, source, tags, damage_type, knockback, source_pos)
      else:
          return _process_damage_immediate(target, damage, source, tags, damage_type, knockback, source_pos)

  func _enqueue_damage(target: String, damage: float, source: String, tags: Array, damage_type: String, knockback: float, source_pos: Vector2) -> bool:
      # Acquire pooled payload
      var d = _payload_pool.acquire()
      d["target"] = target
      d["source"] = source
      d["base_damage"] = damage
      d["damage_type"] = damage_type
      d["knockback"] = knockback
      d["source_pos"] = source_pos
      
      # Copy tags using pooled array
      var t = _tags_pool.acquire()
      for tag in tags:
          t.push_back(tag)
      d["tags"] = t
      
      if not _damage_queue.try_push(d):
          # Overflow: drop-oldest
          var dropped = _damage_queue.try_pop()
          if dropped != null:
              var dropped_tags: Array = dropped.get("tags", null)
              if dropped_tags != null:
                  _tags_pool.release(dropped_tags)
              _payload_pool.release(dropped)
          
          if not _damage_queue.try_push(d):
              # Hard drop
              var d_tags: Array = d.get("tags", null)
              if d_tags != null:
                  _tags_pool.release(d_tags)
              _payload_pool.release(d)
              _dropped_overflow += 1
              Logger.warn("DamageService: queue overflow hard-drop", "damage_queue")
              return false
          _dropped_overflow += 1
      
      _enqueued += 1
      if _damage_queue.count() > _max_watermark:
          _max_watermark = _damage_queue.count()
      return true

  func _process_tick() -> void:
      if not _queue_enabled:
          return
          
      var start_time = Time.get_ticks_msec()
      var max_per_tick = BalanceDB.get_combat_value("damage_queue_max_per_tick", 2048)
      var processed = 0
      
      while processed < max_per_tick:
          var d: Dictionary = _damage_queue.try_pop()
          if d == null:
              break
              
          # Process damage using existing internal logic
          var tags: Array = d.get("tags", null)
          _process_damage_immediate(d["target"], d["base_damage"], d["source"], tags if tags else [], d.get("damage_type", "generic"), d.get("knockback", 0.0), d.get("source_pos", Vector2.ZERO))
          
          # Release back to pools
          if tags != null:
              _tags_pool.release(tags)
              d["tags"] = []  # detach to avoid double-release
          _payload_pool.release(d)
          processed += 1
      
      _processed += processed
      _total_ticks += 1
      _last_tick_ms = Time.get_ticks_msec() - start_time

  func _on_damage_requested_compat(payload) -> void:
      # EventBus adapter - route to same apply_damage path
      var source: String = str(payload.get("source_id", "unknown"))
      var target: String = str(payload.get("target_id", "unknown"))
      var damage: float = payload.get("base_damage", 0.0)
      var tags: Array = payload.get("tags", [])
      apply_damage(target, damage, source, tags)
  ```

### Phase D — Debug Commands & Metrics
- [ ] Add console commands via DebugManager or limbo_console:
  ```gdscript
  # In DebugManager or console command handler
  func cmd_damage_queue_toggle() -> void:
      var current = BalanceDB.get_combat_value("use_zero_alloc_damage_queue", false)
      BalanceDB.set_combat_value("use_zero_alloc_damage_queue", not current)
      Logger.info("Damage queue toggled: " + str(not current), "debug")

  func cmd_damage_queue_stats() -> void:
      if DamageService._queue_enabled:
          var stats = {
              "enqueued": DamageService._enqueued,
              "processed": DamageService._processed,
              "dropped_overflow": DamageService._dropped_overflow,
              "max_watermark": DamageService._max_watermark,
              "current_queue_size": DamageService._damage_queue.count(),
              "last_tick_ms": DamageService._last_tick_ms,
              "total_ticks": DamageService._total_ticks
          }
          Logger.info("Damage queue stats: " + str(stats), "debug")
      else:
          Logger.info("Damage queue disabled", "debug")
  ```

### Phase E — Tests (A/B Validation)
- [ ] `tests/EventQueue_Isolated.gd/.tscn`:
  - Unit test RingBuffer push/pop boundaries, FIFO ordering, overflow policy
  - Validate ObjectPool acquire/release cycles
  - Test metrics counters accuracy

- [ ] Extend `tests/DamageSystem_Isolated_Clean.gd`:
  - A/B test: run identical damage sequence with flag ON/OFF
  - Assert identical outcomes and order for labeled sequence (use incremental id tags)
  - Performance stress test: N=10k damage requests, assert stable processing

- [ ] `tests/test_signal_contracts.gd`:
  - Ensure EventBus.damage_requested adapter preserves contract
  - Test both direct DamageService calls and EventBus emissions produce same results

### Phase F — Docs & Changelog
- [ ] `docs/ARCHITECTURE_QUICK_REFERENCE.md`: Add internal queue diagram, emphasize single entry point preserved
- [ ] `docs/ARCHITECTURE_RULES.md`: Document that queue is internal optimization, producers still call DamageService only
- [ ] `changelogs/features/YYYY_MM_DD-zero_alloc_damage_queues.md`: Feature entry with A/B testing results and metrics

---

## File Touch List

Code (NEW):
- `scripts/utils/RingBuffer.gd`
- `scripts/utils/ObjectPool.gd`
- `scripts/utils/PayloadReset.gd`

Code (EDIT):
- `scripts/systems/damage_v2/DamageRegistry.gd` - Add internal queue system
- `autoload/BalanceDB.gd` or `config/debug.tres` - Add feature flags and tunables
- `autoload/DebugManager.gd` - Add console commands (optional)

Tests (NEW/EDIT):
- `tests/EventQueue_Isolated.gd/.tscn` - Unit tests for queue components
- `tests/DamageSystem_Isolated_Clean.gd` - Extend for A/B testing
- `tests/test_signal_contracts.gd` - Extend for adapter testing

Docs:
- `docs/ARCHITECTURE_QUICK_REFERENCE.md` - Update with queue internals
- `docs/ARCHITECTURE_RULES.md` - Clarify single entry point preservation
- `changelogs/features/YYYY_MM_DD-zero_alloc_damage_queues.md` - Feature documentation

---

## Benefits of Centralized Approach

### Architectural Clarity
- **Single entry point preserved**: All systems continue calling DamageService.apply_damage()
- **No system branching**: MeleeSystem, DamageSystem remain unchanged
- **Internal optimization**: Queue is implementation detail, not API change
- **Clean rollback**: Single flag disables entire queue system

### Performance & Safety
- **Zero hot-path allocations**: All payloads and arrays pooled and reused
- **Bounded processing**: Max items per tick prevents frame stalls
- **Overflow handling**: Drop-oldest policy with metrics, never crash
- **A/B testable**: Runtime toggle for performance comparison

### Maintainability
- **Centralized logic**: All queue code in one place (DamageService)
- **Clear ownership**: DamageService owns damage processing and optimization
- **Metrics visibility**: Console commands for observability
- **Deterministic**: FIFO ordering, fixed batch sizes, stable behavior

---

## Success Criteria

- [ ] Queue path produces identical game behavior to direct path
- [ ] No frame drops under 10k damage events/second
- [ ] Memory usage remains flat during combat (no allocation spikes)
- [ ] All tests pass with flag enabled/disabled
- [ ] Performance improves by >20% in heavy combat scenarios
- [ ] A/B testing shows no behavioral differences
- [ ] Console commands provide clear queue metrics and control

---

## Minimal Milestone

- [ ] A1: Utilities implemented (RingBuffer/ObjectPool/PayloadReset) with unit tests
- [ ] B1: Feature flag and config integration with hot-reload
- [ ] C1: DamageService internal queue with 30Hz processor
- [ ] D1: EventBus adapter routes to same DamageService path
- [ ] E1: A/B test passes - identical outcomes with flag ON/OFF
- [ ] Sanity: All existing damage tests pass; no behavioral changes; queue metrics accurate
