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

Introduce a zero-allocation, batched event path for hot signals (starting with damage) using preallocated ring buffers and payload pools, drained at a fixed 30Hz combat step. Preserve public EventBus signal contracts and determinism while eliminating per-frame allocations and reducing dispatch overhead.

Decision: GDScript-first prototype (no GDExtension/atomics). Lock-free atomics are unnecessary on main-thread production/consumption; we’ll add atomics only if we later introduce multi-thread producers.

---

## Goals & Acceptance Criteria

- [ ] API compatibility:
  - EventBus public signals (e.g., `damage_requested`) remain supported.
  - Existing systems can keep emitting/listening; the new path is an internal optimization layer.
- [ ] Zero-allocation in hot path:
  - Ring buffers for hot events (start with damage) preallocated at boot.
  - Payload dictionaries/arrays acquired from pools and reused; no per-event allocations during gameplay.
- [ ] Batched processing:
  - Drain queues at fixed cadence (30Hz combat step) to reduce dispatch overhead and stabilize frame times.
- [ ] Determinism:
  - FIFO ordering per queue, deterministic batch size, stable behavior across runs.
- [ ] Overflow policy:
  - Drop-oldest with counter and throttled warning logs; never crash. Metrics exposed for observability.
- [ ] Tests & docs:
  - Isolated tests for queue correctness and damage pipeline integrity.
  - Architecture docs and changelog updated.

---

## Design

### Components

1) RingBuffer (GDScript, single-producer/consumer on main thread)
- Preallocated Array for slots.
- Head/tail indices wrap with mask (size power-of-two recommended).
- Methods: `push(item)`, `try_push(item)`, `pop()`, `try_pop()`, `is_full()`, `is_empty()`, `count()`.

2) ObjectPool (GDScript)
- Preallocated of Dictionary payloads (and optional Array pools for tags).
- Methods: `acquire() -> Dictionary`, `release(dict: Dictionary)`.
- Clear/reset payload fields on release (reuse underlying objects).

3) EventQueueAdapter (Autoload)
- Subscribes to EventBus hot signals (initially `damage_requested`).
- On emission: acquire pooled dict, copy fields into pooled dict (no new allocations), enqueue to ring buffer.
- Optional: provide a direct enqueue API for future producers to bypass signals entirely.

4) DamageQueueProcessor (Autoload)
- Drains the damage queue at 30Hz:
  - For each payload: call DamageRegistry entrypoint once (centralized), then release payload back to pool.
- Cadence source:
  - Preferred: subscribe to RunClock tick (if implemented).
  - Fallback: internal Timer set to 0.0333s, paused via PauseManager and gated by StateManager.

5) Metrics & Logging
- Counters: `enqueued `dropped_overflow`, `processed`, `max_watermark`.
- Expose via DebugManager/console command (limbo_console).
- Throttled warns on overflow (e.g., one per 5 seconds with totals since last).

### Payload shape (unchanged)
- Dictionary with keys `{ source: String, target: String, base_damage: float, tags: Array[StringName] or Array[String] }`.
- tags Array acquired from a small Array pool to avoid transient allocation on tag copying.

---

## Implementation Plan (Phases & Checklist)

### Phase A — Utilities (RingBuffer + ObjectPool)
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

  func count -> int: return _count
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

- [ ] `scripts/utils/PayloadReset.gd` (helpers)
  ```gdscript
  extends RefCounted
  class_name PayloadReset

  static func clear_damage_payload(d: Dictionary) -> void:
      # Preserve keys to avoid shape changes; reset values
      d["source"] = ""
      d["target"] = ""
      d["base_damage"] = 0.0
      var tags: Array = d.get("tags", [])
      if tags:
          tags.clear()
      else:
          d["tags"] = []
  ```

### Phase B — EventQueueAdapter (Autoload)
- [ ] `autoload/EventQueue.gd`
  ```gdscript
  extends Node
  class_name EventQueue

  const DAMAGE_QUEUE_CAPACITY := 4096
 const DAMAGE_POOL_SIZE := 4096

  var damage_queue := RingBuffer.new()
  var damage_payload_pool := ObjectPool.new()
  var tags_array_pool := ObjectPool.new()

  var dropped_overflow_damage: int = 0
  var enq_damage_count: int = 0
  var max_watermark_damage: int = 0

  func _ready() -> void:
      damage_queue.setup(DAMAGE_QUEUE_CAPACITY)
      damage_payload_pool.setup(DAMAGE_POOL_SIZE, func():
          return {"source":"","target":"","base_damage":0.0,"tags":[]}
      , PayloadReset.clear_damage_payload)
      tags_array_pool.setup(128, func(): return [], func(a: Array): a.clear())

      # Subscribe to hot EventBus signal
      EventBus.damage_requested.connect(_on_damage_requested)

  func _on_damage_requested(payload: Dictionary) -> void:
      # Acquire pooled dict and copy fields without allocating
      var d = damage_payload_pool.acquire()
      d["source"] = payload.get("source","")
      d["target"] = payload.get("target","")
      d["base_damage"] = float(payload.get("base_damage", 0.0))

      # Copy tags using pooled array
      var tags: Array = payload.get("tags", [])
      var t = tags_array_pool.acquire()
      # Copy by push_back to avoid new array alloc
      for tag in tags:
          t.push_back(tag)
      d["tags"] = t

      if not damage_queue.try_push(d):
          # Overflow: drop-oldest (pop one, release, then push)
          var dropped = damage_queue.try_pop()
          if dropped != null:
              # Release both dropped payload and its tags array
              var dropped_tags: Array = dropped.get("tags", null)
              if dropped_tags != null:
                  tags_array_pool.release(dropped_tags)
              damage_payload_pool.release(dropped)
          if not damage_queue.try_push(d):
              # Queue full even after drop-oldest (should not happen): release d
              var d_tags: Array = d.get("tags", null)
              if d_tags != null:
                  tags_array_pool.release(d_tags)
              damage_payload_pool.release(d)
              dropped_overflow_damage += 1
              Logger.warn("EventQueue: damage overflow hard-drop", "event_queue")
              return
          dropped_overflow_damage += 1
      enq_damage_count += 1
      if damage_queue.count() > max_watermark_damage:
          max_watermark_damage = damage_queue.count()
  ```

- [ ] Provide optional fast-path API (future):
  ```gdscript
  func enqueue_damage_fast(source: String, target: String, base_damage: float, tags: Array) -> void:
      _on_damage_requested({"source":source,"target":target,"base_damage":base_damage,"tags":tags})
  ```

### Phase C — DamageQueueProcessor (Autoload, 30Hz)
- [ ] `autoload/DamageQueueProcessor.gd`
  ```gdscript
  extends Node
  class_name DamageQueueProcessor

  @export var tick_rate_hz: float = 30.0
  var _timer: Timer

  func _ready() -> void:
      # Prefer RunClock if available and emitting at 30Hz; else use Timer
      if Engine.has_singleton("RunClock"):
          RunClock.tick.connect(_on_tick) # Ensure RunClock configured to 30Hz if desired
      else:
          _timer = Timer.new()
          _timer.one_shot = false
          _timer.wait_time = 1.0 / tick_rate_hz
          add_child(_timer)
          _timer.timeout.connect(_on_tick)
          _timer.start()

      # Pause/State gates
      PauseManager.paused_changed.connect(_on_paused_changed)
      _apply_pause_state(PauseManager.is_paused())

  func _on_paused_changed(paused: bool) -> void:
      _apply_pause_state(paused)

  func _apply_pause_state(paused: bool) -> void:
      if _timer:
          _timer.paused = paused

  func _on_tick(_arg := null) -> void:
      # Drain damage queue in a bounded batch
      var max_per_tick := 2048  # guard to prevent long stalls
      var processed := 0
      while processed < max_per_tick:
          var d: Dictionary = EventQueue.damage_queue.try_pop()
          if d == null:
              break
          # Extract tags and release after processing
          var tags: Array = d.get("tags", null)
          DamageRegistry.request_damage(d)  # Single sanctioned entry point
          if tags != null:
              EventQueue.tags_array_pool.release(tags)
              d["tags"] = []  # detach to avoid double-release
          EventQueue.damage_payload_pool.release(d)
          processed += 1
  ```

- Notes:
  - If RunClock cadence != 30Hz, set `tick_rate_hz` to 30 and use Timer, or add a 30Hz sub-divider when driven by RunClock 10Hz.

### Phase D — Config & Toggles
- [ ] Add BalanceDB/config flag to enable queue path (default: enabled in dev):
  - `use_zero_alloc_damage_queue: bool`
- [ ] When disabled:
  - `EventQueue` unsubscribes or becomes a pass-through (directly emits to DamageRegistry immediately).

### Phase E — Tests
- [ ] Extend `tests/DamageSystem_Isolated_Clean.gd`:
  - Emit N (e.g., 10k) `damage_requested` events quickly; assert processed count matches after T seconds.
  - Assert FIFO ordering for a tagged sequence (use incremental ids in tags).
- [ ] New `tests/EventQueue_Isolated.gd/.tscn`:
  - Unit test RingBuffer push/pop boundaries and overflow policy.
  - Validate metrics counters and throttled warnings (may need Logger spy or counters).
- [ ] `tests/test_signal_contracts.gd`:
  - Ensure `damage_requested` is still a valid and observed signal; compatibility preserved.

### Phase F — Docs & Changelog
- [ ] `docs/ARCHITECTURE_QUICK_REFERENCE.md`: Add zero-alloc queue path diagram and notes.
- [ ] `docs/ARCHITECTURE_RULES.md`: State that hot EventBus signals may route via internal queue with preserved contracts.
- [ ] `changelogs/features/YYYY_MM_DD-zero_alloc_event_damage_queues.md`: Feature entry with metrics fields.

---

## File Touch List

Code (NEW):
- `scripts/utils/RingBuffer.gd`
- `scripts/utils/ObjectPool.gd`
- `scripts/utils/PayloadReset.gd`
- `autoload/EventQueue.gd`
- `autoload/DamageQueueProcessor.gd`

Code (EDIT, optional):
- `autoload/BalanceDB.gd` or `config/debug.tres` (toggle)
- `autoload/EventBus.gd` (no API changes; ensure signals are present)
- `scripts/systems/damage_v2/DamageRegistry.gd` (verify single entrypoint compatibility)

Tests:
- `tests/EventQueue_Isolated.gd` / `.tscn` (NEW)
- `tests/DamageSystem_Isolated_Clean.gd` (extend)
- `tests/test_signal_contracts.gd` (extend)

Docs:
- `docs/ARCHITECTURE_QUICK_REFERENCE.md` (update)
- `docs/ARCHITECTURE_RULES.md` (update)
- `changelogs/features/YYYY_MM_DD-zero_alloc_event_damage_queues.md` (NEW)

---

## Notes & Guards

- No per-frame allocations in queue hot path; all payloads/arrays pooled.
- Overflow drops oldest with counters; log warns throttled (Logger, category `event_queue`).
- Pause/State gates ensure no processing while paused or outside Arena state.
- Determinism: queue preserves FIFO; batch size is fixed and documented; processing on a fixed cadence avoids jitter.
- Backwards compatible: existing listeners relying on `damage_requested` still work; we optimize internal routing to DamageRegistry.

---

## Minimal Milestone

- [ ] A1: Utilities implemented (RingBuffer/ObjectPool) with tests
- [ ] B1: EventQueue subscribes to `damage_requested` and enqueues
- [ ] C1: DamageQueueProcessor drains at 30Hz into DamageRegistry
- [ ] Sanity: DamageSystem_Isolated_Clean passes; enqueued == processed on test run; no crashes under overflow
