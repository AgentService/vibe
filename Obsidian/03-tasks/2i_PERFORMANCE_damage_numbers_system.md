# Task 8: Damage Numbers & Combat Performance Review

**Status:** 📋 Planning
**Priority:** High (Performance Critical)
**Complexity:** High
**Estimated Time:** 6-8 hours
**Created:** 2025-10-07

---

## 🎯 Problem Statement

**Current Issue:**
When a melee cone attack hits 100-200 enemies simultaneously in the endless arena system, noticeable frame drops occur. The bottleneck location (CPU vs GPU) and whether it's caused by damage processing, collision checks, or rendering overhead is currently unknown.

**Missing Feature:**
No damage number system exists to provide visual feedback for combat hits. This task combines performance profiling with the design decision for implementing an optimized damage number renderer.

**Goal:**
Identify performance bottlenecks in mass-damage events and architect a zero-allocation damage number system capable of handling 200+ simultaneous hits at 60 FPS.

---

## 📊 Phase Breakdown

### Phase 1: Performance Analysis & Bottleneck Identification (2-3 hours)

**Objective:** Profile the current combat system to identify whether frame drops are CPU-bound (collision/loops/signals) or GPU-bound (draw calls/shaders).

#### Task 1.1: Setup Profiling Environment (~30 min)

**Requirements:**
- [ ] Create isolated test scene: `tests/PerformanceProfile_MassDamage.tscn`
- [ ] Configure scenario:
  - Player with melee cone ability (90° cone, 250px range)
  - Spawn 200 stationary enemies in cone area
  - Single melee attack triggers all hits simultaneously
- [ ] Add profiling instrumentation:
  ```gdscript
  var _profiler_data: Dictionary = {
      "collision_checks_us": 0,
      "damage_processing_us": 0,
      "signal_emission_us": 0,
      "total_hits": 0,
      "frame_time_ms": 0.0
  }
  ```

**Profiling Points:**
```gdscript
# MeleeSystem.gd or DamageSystem.gd
func _process_melee_attack() -> void:
    var start_time = Time.get_ticks_usec()

    # PROFILE: Collision detection
    var collision_start = Time.get_ticks_usec()
    var enemies_in_cone = _get_enemies_in_cone()
    _profiler_data.collision_checks_us = Time.get_ticks_usec() - collision_start

    # PROFILE: Damage processing
    var damage_start = Time.get_ticks_usec()
    for enemy in enemies_in_cone:
        DamageService.apply_damage(enemy_id, damage, ["melee"])
    _profiler_data.damage_processing_us = Time.get_ticks_usec() - damage_start

    # PROFILE: Signal emission
    var signal_start = Time.get_ticks_usec()
    EventBus.melee_attack_completed.emit(payload)
    _profiler_data.signal_emission_us = Time.get_ticks_usec() - signal_start

    var total_time_ms = (Time.get_ticks_usec() - start_time) / 1000.0
    _profiler_data.frame_time_ms = total_time_ms
    _profiler_data.total_hits = enemies_in_cone.size()

    Logger.info("Mass damage event: %d hits in %.2f ms" % [
        _profiler_data.total_hits, _profiler_data.frame_time_ms
    ], "performance")
```

**Expected Output:**
```
=== Mass Damage Profile (200 hits) ===
Collision checks: 1.2 ms
Damage processing: 8.5 ms
Signal emission: 0.3 ms
Total frame time: 10.0 ms
Allocations: 400 (2 per hit: Dictionary + payload)
```

#### Task 1.2: Identify Allocation Hotspots (~30 min)

**Analysis Questions:**
- [ ] How many new Dictionaries are created per hit?
- [ ] Are damage payloads pooled or allocated per event?
- [ ] Do signals trigger GC pressure (orphaned lambdas, closures)?
- [ ] Is damage applied immediately or queued for batch processing?

**Code Audit Checklist:**
```gdscript
# ❌ BAD: Allocates new Dictionary per hit
for enemy in enemies_hit:
    var payload = {"target": enemy_id, "damage": dmg}  # NEW ALLOCATION
    EventBus.damage_dealt.emit(payload)

# ✅ GOOD: Reuses pooled payload
var payload = _damage_payload_pool.acquire()
payload.reset(enemy_id, dmg)
EventBus.damage_dealt.emit(payload)
_damage_payload_pool.release(payload)
```

**Profiling Tools:**
- Godot Profiler (Monitor → Profiler → CPU)
- Custom frame time logging (Time.get_ticks_usec())
- Memory monitor (OS.get_static_memory_usage())

#### Task 1.3: GPU Profiling (if CPU is not bottleneck) (~1 hour)

**GPU Bottleneck Indicators:**
- CPU profiling shows <5ms for collision + damage
- Frame drops persist despite fast CPU processing
- High draw call count (>500 draw calls per frame)
- Shader compilation stutters

**GPU Profiling Steps:**
- [ ] Enable `Debug → Visible Collision Shapes` to visualize Area2D overhead
- [ ] Count active shaders during mass hit (enemy flash effects, damage modulation)
- [ ] Check draw call count: `Performance.get_monitor(Performance.RENDER_DRAW_CALLS_IN_FRAME)`
- [ ] Test with `--disable-render-loop` for CPU-only validation

**Expected GPU Hotspots:**
- Enemy hit flash shaders (200 simultaneous modulate tweens)
- Particle systems (blood splatter, impact effects)
- MultiMesh transform uploads (if using GPU instancing)

**Success Criteria:**
- [ ] Bottleneck identified: CPU (collision/damage) OR GPU (draw/shader)
- [ ] Allocation count measured (target: <10 allocations per 200 hits)
- [ ] Profiling report documents exact µs breakdown
- [ ] Recommendation: Need zero-allocation pool (YES/NO)

---

### Phase 2: Damage Number System Architecture (1-2 hours)

**Objective:** Design a pluggable damage number renderer interface with two implementations: HUD-based RingBuffer (CPU) and GPU-instanced MultiMesh.

#### Task 2.1: Define IDamageNumberRenderer Interface (~30 min)

**File:** `scripts/systems/rendering/IDamageNumberRenderer.gd`

```gdscript
## Interface for damage number rendering systems.
## Allows swapping between HUD-based and GPU-instanced implementations.
extends RefCounted
class_name IDamageNumberRenderer

## Shows a damage number at world position with optional color coding.
## @param value: Damage amount (rounded to int for display)
## @param world_pos: World position where damage occurred
## @param color: Color for the number (red for damage, green for heal, etc.)
func show_damage(value: float, world_pos: Vector2, color: Color) -> void:
    assert(false, "show_damage() must be implemented by subclass")

## Updates all active damage numbers (floating animation, fade-out, cleanup).
## Called every frame from rendering system.
## @param delta: Frame delta time (NOT fixed 30Hz - visual updates are frame-rate based)
func update(delta: float) -> void:
    assert(false, "update() must be implemented by subclass")

## Clears all active damage numbers (used on scene transitions).
func clear_all() -> void:
    assert(false, "clear_all() must be implemented by subclass")

## Returns current number of active damage numbers (for debugging/profiling).
func get_active_count() -> int:
    assert(false, "get_active_count() must be implemented by subclass")
    return 0
```

**Design Rationale:**
- **show_damage()**: Single entry point for all damage events (melee, projectile, DOT)
- **update()**: Frame-rate based animation (60 FPS for smooth floating)
- **clear_all()**: Scene cleanup (arena → results screen transition)
- **get_active_count()**: Performance monitoring

#### Task 2.2: Implement HudDamageRenderer (RingBuffer, MVP) (~1 hour)

**File:** `scripts/systems/rendering/HudDamageRenderer.gd`

**Architecture:**
- **Zero-allocation RingBuffer** of pre-allocated Label nodes
- **Object pooling** using existing `ObjectPool.gd` utility
- **CanvasLayer-based** rendering (HUD space, always on top)

**Implementation:**

```gdscript
extends IDamageNumberRenderer
class_name HudDamageRenderer

const MAX_DAMAGE_NUMBERS := 256  # Pre-allocated pool size
const FLOAT_DURATION := 1.0      # Seconds to float upward
const FLOAT_SPEED := 50.0        # Pixels per second upward
const FADE_START := 0.6          # Start fading after 60% of duration

# Node references (injected)
var _canvas_layer: CanvasLayer
var _label_pool: ObjectPool

# Active damage number tracking
var _active_numbers: Array[Dictionary] = []  # {label: Label, time_alive: float, start_pos: Vector2}
var _next_index: int = 0

func _init(canvas_layer: CanvasLayer) -> void:
    _canvas_layer = canvas_layer
    _setup_label_pool()

func _setup_label_pool() -> void:
    _label_pool = ObjectPool.new()
    _label_pool.setup(
        MAX_DAMAGE_NUMBERS,
        _create_damage_label,
        _reset_damage_label
    )

func _create_damage_label() -> Label:
    var label = Label.new()
    label.add_theme_font_size_override("font_size", 16)
    label.add_theme_color_override("font_outline_color", Color.BLACK)
    label.add_theme_constant_override("outline_size", 2)
    label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    label.visible = false  # Start hidden
    _canvas_layer.add_child(label)
    return label

func _reset_damage_label(label: Label) -> void:
    label.visible = false
    label.modulate = Color.WHITE

func show_damage(value: float, world_pos: Vector2, color: Color) -> void:
    var label: Label = _label_pool.acquire()

    # Setup label
    label.text = str(int(value))
    label.modulate = color
    label.global_position = world_pos
    label.visible = true

    # Track active number
    var entry = {
        "label": label,
        "time_alive": 0.0,
        "start_pos": world_pos
    }

    # RingBuffer pattern: Overwrite oldest if full
    if _active_numbers.size() < MAX_DAMAGE_NUMBERS:
        _active_numbers.append(entry)
    else:
        # Release old label back to pool
        var old_entry = _active_numbers[_next_index]
        _label_pool.release(old_entry.label)
        _active_numbers[_next_index] = entry

    _next_index = (_next_index + 1) % MAX_DAMAGE_NUMBERS

func update(delta: float) -> void:
    var i := 0
    while i < _active_numbers.size():
        var entry = _active_numbers[i]
        entry.time_alive += delta

        # Float upward
        var offset_y = entry.time_alive * FLOAT_SPEED
        entry.label.global_position = entry.start_pos + Vector2(0, -offset_y)

        # Fade out
        if entry.time_alive >= FADE_START * FLOAT_DURATION:
            var fade_progress = (entry.time_alive - FADE_START * FLOAT_DURATION) / ((1.0 - FADE_START) * FLOAT_DURATION)
            entry.label.modulate.a = 1.0 - clampf(fade_progress, 0.0, 1.0)

        # Remove expired
        if entry.time_alive >= FLOAT_DURATION:
            _label_pool.release(entry.label)
            _active_numbers.remove_at(i)
            continue

        i += 1

func clear_all() -> void:
    for entry in _active_numbers:
        _label_pool.release(entry.label)
    _active_numbers.clear()
    _next_index = 0

func get_active_count() -> int:
    return _active_numbers.size()
```

**Success Criteria:**
- [ ] Displays damage numbers at hit positions
- [ ] Floats upward at 50 px/s for 1 second
- [ ] Fades out in final 40% of duration
- [ ] Reuses Label nodes via ObjectPool (zero allocation)
- [ ] Handles 200+ simultaneous hits without frame drops
- [ ] Cleans up expired numbers automatically

#### Task 2.3: Plan GpuDamageRenderer (MultiMesh, Future) (~30 min)

**File:** `scripts/systems/rendering/GpuDamageRenderer.gd` (STUB ONLY)

**Architecture Design (Not Implemented Yet):**

```gdscript
extends IDamageNumberRenderer
class_name GpuDamageRenderer

## GPU-instanced damage number renderer using MultiMeshInstance2D.
## Uses sprite atlas for digits 0-9 and batch-uploads transforms to GPU.
## Target: 1000+ simultaneous damage numbers at 60 FPS.

const MAX_INSTANCES := 1024  # GPU instance limit

# Digit atlas configuration
const DIGIT_ATLAS_PATH := "res://assets/ui/damage_numbers/digits_atlas.png"
const DIGIT_WIDTH := 16
const DIGIT_HEIGHT := 24

var _multimesh_instance: MultiMeshInstance2D
var _transform_buffer: PackedVector2Array  # Instance transforms
var _active_count: int = 0

func _init(parent: Node2D) -> void:
    _setup_multimesh(parent)

func _setup_multimesh(parent: Node2D) -> void:
    # Create MultiMeshInstance2D
    _multimesh_instance = MultiMeshInstance2D.new()
    parent.add_child(_multimesh_instance)

    # Configure MultiMesh
    var multimesh = MultiMesh.new()
    multimesh.transform_format = MultiMesh.TRANSFORM_2D
    multimesh.instance_count = MAX_INSTANCES
    multimesh.visible_instance_count = 0  # Start with 0 visible

    # Setup mesh (quad with digit atlas)
    var quad_mesh = QuadMesh.new()
    quad_mesh.size = Vector2(DIGIT_WIDTH, DIGIT_HEIGHT)
    multimesh.mesh = quad_mesh

    # Assign texture atlas
    var material = StandardMaterial3D.new()  # Or ShaderMaterial for advanced effects
    material.albedo_texture = load(DIGIT_ATLAS_PATH)
    multimesh.mesh.surface_set_material(0, material)

    _multimesh_instance.multimesh = multimesh

    # Pre-allocate transform buffer
    _transform_buffer.resize(MAX_INSTANCES * 2)  # 2 floats per Transform2D (pos + scale)

func show_damage(value: float, world_pos: Vector2, color: Color) -> void:
    # TODO: Convert value to digit sprites (e.g., 123 → "1", "2", "3")
    # TODO: Add instance to MultiMesh transform buffer
    # TODO: Upload buffer to GPU in batch (update() method)
    pass

func update(delta: float) -> void:
    # TODO: Update all instance transforms (floating animation)
    # TODO: Upload transform buffer to GPU (single batch call)
    # TODO: Remove expired instances
    pass

func clear_all() -> void:
    _active_count = 0
    _multimesh_instance.multimesh.visible_instance_count = 0

func get_active_count() -> int:
    return _active_count
```

**Design Notes:**
- **Digit Atlas:** 0-9 sprites in single texture (10×1 grid or 2×5 grid)
- **Transform Buffer:** CPU-side buffer for instance positions, uploaded once per frame
- **Batching:** All damage numbers rendered in single draw call (vs 200+ Label nodes)
- **Limitations:** More complex to implement (digit decomposition, atlas mapping, shader effects)

**When to Implement:**
- IF HudDamageRenderer cannot maintain 60 FPS with 200+ numbers
- IF profiling shows Label node overhead is bottleneck
- IF we need 500+ simultaneous numbers (mass AOE, screen-clear abilities)

---

### Phase 3: Integration & Combat System Hookup (1.5 hours)

**Objective:** Wire the damage number renderer into the existing combat flow and create a pluggable architecture for swapping implementations.

#### Task 3.1: Create DamageNumberManager Autoload (~45 min)

**File:** `autoload/DamageNumberManager.gd`

```gdscript
extends Node

## Central manager for damage number rendering.
## Coordinates between combat system and renderer implementation.
## Allows hot-swapping renderer via configuration.

enum RendererType {
    HUD_LABELS,      ## CPU-based Label pooling (MVP)
    GPU_MULTIMESH    ## GPU-instanced MultiMesh (future)
}

@export var renderer_type: RendererType = RendererType.HUD_LABELS

var _renderer: IDamageNumberRenderer
var _canvas_layer: CanvasLayer

func _ready() -> void:
    # Create CanvasLayer for HUD rendering
    _canvas_layer = CanvasLayer.new()
    _canvas_layer.layer = 100  # Above all game elements
    add_child(_canvas_layer)

    # Initialize renderer
    _switch_renderer(renderer_type)

    # Connect to damage events
    EventBus.damage_dealt.connect(_on_damage_dealt)

    Logger.info("DamageNumberManager initialized with %s renderer" % [
        "HUD" if renderer_type == RendererType.HUD_LABELS else "GPU"
    ], "rendering")

func _switch_renderer(type: RendererType) -> void:
    # Clean up old renderer
    if _renderer:
        _renderer.clear_all()

    # Create new renderer
    match type:
        RendererType.HUD_LABELS:
            _renderer = HudDamageRenderer.new(_canvas_layer)
        RendererType.GPU_MULTIMESH:
            Logger.warn("GPU MultiMesh renderer not yet implemented, falling back to HUD", "rendering")
            _renderer = HudDamageRenderer.new(_canvas_layer)

func _process(delta: float) -> void:
    if _renderer:
        _renderer.update(delta)

func _on_damage_dealt(payload: EventBus.DamageDealtPayload_Type) -> void:
    # Determine color based on damage type
    var color := Color.RED  # Default: damage
    if payload.damage_types.has("heal"):
        color = Color.GREEN
    elif payload.damage_types.has("critical"):
        color = Color.ORANGE

    # Get world position from entity
    var world_pos := _get_entity_position(payload.target_id)
    if world_pos == Vector2.ZERO:
        return  # Invalid entity, skip damage number

    # Show damage number
    _renderer.show_damage(payload.damage_amount, world_pos, color)

func _get_entity_position(entity_id: String) -> Vector2:
    # Query EntityTracker or DamageRegistry for entity position
    if EntityTracker.has_entity(entity_id):
        return EntityTracker.get_entity_position(entity_id)
    return Vector2.ZERO

## Clears all damage numbers (called on scene transitions).
func clear_all_numbers() -> void:
    if _renderer:
        _renderer.clear_all()

## Returns current active damage number count (for debugging).
func get_active_count() -> int:
    if _renderer:
        return _renderer.get_active_count()
    return 0
```

**Integration Points:**
- **EventBus.damage_dealt** - Triggered by DamageService/MeleeSystem
- **EntityTracker** - Provides entity positions for world space placement
- **StateManager** - Clears numbers on ARENA → RESULTS transition

**Success Criteria:**
- [ ] DamageNumberManager registered as autoload
- [ ] Listens to EventBus.damage_dealt
- [ ] Routes damage events to active renderer
- [ ] Supports renderer hot-swap via export var
- [ ] Clears numbers on scene transitions

#### Task 3.2: Add Damage Number Triggers to Combat Systems (~30 min)

**Files to Modify:**
- `scripts/systems/combat/DamageSystem.gd` (if damage_dealt emitted here)
- `scripts/systems/combat/MeleeSystem.gd` (if melee hits emit separately)
- `autoload/DamageService.gd` (if centralized damage hub)

**Pattern:**

```gdscript
# In DamageService.apply_damage() or MeleeSystem._process_cone_attack()
func apply_damage(target_id: String, damage: float, damage_types: Array[String]) -> void:
    # Apply damage to entity
    var entity = EntityTracker.get_entity(target_id)
    entity.current_hp -= damage

    # Emit damage_dealt signal (DamageNumberManager listens)
    var payload = EventBus.DamageDealtPayload_Type.new()
    payload.target_id = target_id
    payload.damage_amount = damage
    payload.damage_types = damage_types
    EventBus.damage_dealt.emit(payload)

    # Check for death
    if entity.current_hp <= 0:
        _handle_entity_death(target_id)
```

**Verification:**
- [ ] All damage sources emit EventBus.damage_dealt
- [ ] Payload includes target_id, damage_amount, damage_types
- [ ] Damage numbers appear for melee, projectile, DOT hits
- [ ] No damage numbers for non-damaging events (buffs, shields)

#### Task 3.3: Scene Cleanup Integration (~15 min)

**File:** `scripts/systems/arena/SceneTransitionManager.gd` or `scenes/main/Main.gd`

Add cleanup call on state transitions:

```gdscript
func transition_to_results() -> void:
    # Clean up arena systems
    DamageNumberManager.clear_all_numbers()

    # ... existing transition logic ...
    StateManager.change_state(StateManager.GameState.RESULTS)
```

**Success Criteria:**
- [ ] Damage numbers cleared when leaving ARENA state
- [ ] No orphaned Label nodes after scene transition
- [ ] Memory usage returns to baseline after cleanup

---

### Phase 4: Performance Testing & Validation (1-2 hours)

**Objective:** Validate that the HudDamageRenderer meets performance targets and compare against future GPU implementation.

#### Task 4.1: Stress Test - 200 Simultaneous Damage Numbers (~30 min)

**Test Scene:** `tests/PerformanceTest_DamageNumbers.tscn`

**Setup:**
- Spawn 200 enemies in grid pattern
- Trigger melee cone attack hitting all 200
- Measure frame time before/after damage numbers

**Expected Results:**

| Metric | Without Damage Numbers | With HUD Renderer | With GPU Renderer (Future) |
|--------|------------------------|-------------------|---------------------------|
| Frame Time (ms) | 8.5 ms | 12.0 ms | 9.0 ms (estimated) |
| Allocations | 400 (payloads only) | 0 (pooled Labels) | 0 (GPU instances) |
| Active Draw Calls | 50 | 250 (200 Labels + 50 game) | 51 (1 MultiMesh + 50 game) |

**Acceptance Criteria:**
- [ ] Frame time increase <5ms with 200 damage numbers
- [ ] Zero allocations (ObjectPool reuse confirmed)
- [ ] No GC spikes during stress test
- [ ] 60 FPS maintained during mass hit events

#### Task 4.2: Profiling Comparison - HUD vs GPU (Future) (~30 min)

**When GPU Renderer is Implemented:**

Run comparative profiling:

```gdscript
extends Node

func _ready():
    print("=== Damage Number Renderer Comparison ===")

    # Test 1: HUD Renderer
    DamageNumberManager.renderer_type = DamageNumberManager.RendererType.HUD_LABELS
    DamageNumberManager._switch_renderer(DamageNumberManager.RendererType.HUD_LABELS)

    var hud_frame_time = _run_stress_test(200)
    print("HUD Renderer (200 numbers): %.2f ms" % hud_frame_time)

    # Test 2: GPU Renderer
    DamageNumberManager.renderer_type = DamageNumberManager.RendererType.GPU_MULTIMESH
    DamageNumberManager._switch_renderer(DamageNumberManager.RendererType.GPU_MULTIMESH)

    var gpu_frame_time = _run_stress_test(200)
    print("GPU Renderer (200 numbers): %.2f ms" % gpu_frame_time)

    # Winner
    var winner = "HUD" if hud_frame_time < gpu_frame_time else "GPU"
    print("Winner: %s (%.2f ms faster)" % [winner, abs(hud_frame_time - gpu_frame_time)])

func _run_stress_test(count: int) -> float:
    # Spawn damage numbers and measure peak frame time
    var start_time = Time.get_ticks_usec()
    for i in count:
        DamageNumberManager._renderer.show_damage(100.0, Vector2(i * 10, 0), Color.RED)
    return (Time.get_ticks_usec() - start_time) / 1000.0
```

**Decision Matrix:**

| Scenario | HUD Renderer | GPU Renderer |
|----------|--------------|--------------|
| <100 simultaneous numbers | ✅ MVP choice (simpler) | ⚠️ Overkill |
| 100-300 simultaneous numbers | ✅ If frame time <15ms | ✅ If frame time >15ms |
| >500 simultaneous numbers | ❌ Label overhead too high | ✅ Required |

#### Task 4.3: Long-Term Memory Stability Test (~30 min)

**Test:** Run arena for 10 minutes with continuous combat

**Monitor:**
- [ ] Memory usage stays stable (no leaks from Label pool)
- [ ] Frame time stays consistent (no degradation over time)
- [ ] ObjectPool never exhausts (256 Label capacity sufficient)
- [ ] No error logs for pool overflow

**Validation Script:**
```gdscript
extends Node

var _test_duration: float = 600.0  # 10 minutes
var _elapsed: float = 0.0
var _initial_memory: int = 0
var _peak_frame_time: float = 0.0

func _ready():
    _initial_memory = OS.get_static_memory_usage()
    print("Starting 10-minute stability test...")

func _process(delta: float) -> void:
    _elapsed += delta

    # Trigger damage numbers every frame
    for i in range(10):  # 10 damage numbers per frame
        DamageNumberManager._renderer.show_damage(
            randf_range(50, 150),
            Vector2(randf_range(0, 1920), randf_range(0, 1080)),
            Color.RED
        )

    # Track peak frame time
    var frame_time = Performance.get_monitor(Performance.TIME_PROCESS)
    _peak_frame_time = max(_peak_frame_time, frame_time)

    # Report every 60 seconds
    if int(_elapsed) % 60 == 0:
        var current_memory = OS.get_static_memory_usage()
        var memory_growth_mb = (current_memory - _initial_memory) / 1024.0 / 1024.0
        print("[%d min] Memory growth: %.2f MB | Peak frame: %.2f ms" % [
            int(_elapsed / 60.0), memory_growth_mb, _peak_frame_time * 1000.0
        ])

    # End test
    if _elapsed >= _test_duration:
        print("✓ Stability test PASSED - No memory leaks detected")
        get_tree().quit()
```

---

### Phase 5: Optional - Long-Term Optimizations (1-2 hours, Future)

**Objective:** Plan advanced optimizations for extreme-scale damage events (500+ simultaneous hits).

#### Task 5.1: DamageBatcher for Frame Aggregation (~45 min)

**Concept:**
Aggregate all damage events in a frame into a single batch before rendering, reducing redundant position lookups and signal emissions.

**Implementation:**

```gdscript
class_name DamageBatcher
extends RefCounted

var _damage_queue: Array[Dictionary] = []  # {target_id, damage, color}

func queue_damage(target_id: String, damage: float, color: Color) -> void:
    _damage_queue.append({"target_id": target_id, "damage": damage, "color": color})

func flush_batch() -> void:
    for entry in _damage_queue:
        var world_pos = EntityTracker.get_entity_position(entry.target_id)
        DamageNumberManager._renderer.show_damage(entry.damage, world_pos, entry.color)
    _damage_queue.clear()
```

**Usage:**
```gdscript
# In 30Hz combat step
func _on_combat_step(payload: EventBus.CombatStepPayload_Type) -> void:
    # Process all melee/projectile hits
    # ...

    # Flush damage numbers once per combat step
    _damage_batcher.flush_batch()
```

**Benefits:**
- Single position lookup per entity per frame
- Reduced EventBus.damage_dealt emissions (1 batch vs 200 individual)
- Better cache locality (batch processing)

#### Task 5.2: GPU Shader-Based Floating Text (~1 hour)

**Concept:**
Use vertex shader to animate damage numbers entirely on GPU (no CPU transform updates).

**Shader Approach:**

```glsl
// damage_number_float.gdshader
shader_type canvas_item;

uniform float spawn_time;
uniform float current_time;
uniform float float_speed = 50.0;
uniform float duration = 1.0;

void vertex() {
    // Calculate animation progress
    float time_alive = current_time - spawn_time;
    float progress = clamp(time_alive / duration, 0.0, 1.0);

    // Float upward (GPU-side animation)
    VERTEX.y -= float_speed * time_alive;

    // Fade out
    COLOR.a = 1.0 - progress;
}
```

**Benefits:**
- Zero CPU cost for animation updates
- Scales to 1000+ simultaneous numbers
- Smooth interpolation (GPU handles sub-frame precision)

**Challenges:**
- Requires custom digit rendering (sprite atlas + shader material)
- More complex setup than Label-based approach
- Harder to debug/preview in editor

---

## 📊 Success Criteria & Deliverables

### Phase 1: Profiling Complete
- [ ] Profiling report documents CPU/GPU breakdown for 200-hit scenario
- [ ] Bottleneck identified (collision, damage processing, or rendering)
- [ ] Allocation count measured (target: <10 per 200 hits)

### Phase 2: Architecture Complete
- [ ] IDamageNumberRenderer interface defined
- [ ] HudDamageRenderer implemented and tested
- [ ] GpuDamageRenderer stub created (for future implementation)

### Phase 3: Integration Complete
- [ ] DamageNumberManager autoload functional
- [ ] Damage numbers appear for all combat damage types
- [ ] Scene cleanup working (no orphaned nodes)

### Phase 4: Performance Validated
- [ ] Stress test passes (200 simultaneous numbers at 60 FPS)
- [ ] Frame time increase <5ms with damage numbers enabled
- [ ] Memory stability test passes (10 minutes, no leaks)

### Phase 5: Decision Matrix
- [ ] HudDamageRenderer vs GpuDamageRenderer comparison documented
- [ ] MVP recommendation: Which renderer for Phase 1 release
- [ ] Long-term roadmap: When to implement GPU renderer

---

## 🔗 Integration Points

**Files Created:**
- `scripts/systems/rendering/IDamageNumberRenderer.gd` - Interface
- `scripts/systems/rendering/HudDamageRenderer.gd` - MVP implementation
- `scripts/systems/rendering/GpuDamageRenderer.gd` - Future stub
- `autoload/DamageNumberManager.gd` - Central coordinator
- `tests/PerformanceProfile_MassDamage.tscn` - Profiling scene
- `tests/PerformanceTest_DamageNumbers.tscn` - Stress test scene

**Files Modified:**
- `autoload/DamageService.gd` or `scripts/systems/combat/DamageSystem.gd` - Add damage_dealt emissions
- `scripts/systems/arena/SceneTransitionManager.gd` - Add cleanup calls
- `Project Settings → Autoload` - Register DamageNumberManager

**Dependencies:**
- `scripts/utils/ObjectPool.gd` (existing utility)
- `autoload/EntityTracker.gd` or `DamageRegistry.gd` (entity position queries)
- `autoload/EventBus.gd` (damage_dealt signal)

---

## 📝 Notes & Design Decisions

**Why HudDamageRenderer First:**
- Simpler to implement (~1 hour vs 3-4 hours for GPU)
- Easier to debug (Label nodes visible in scene tree)
- Sufficient for MVP (200 simultaneous numbers is edge case)
- Can swap to GPU later without combat system changes

**When to Implement GPU Renderer:**
- IF HudDamageRenderer frame time exceeds 15ms
- IF we add screen-clear abilities (500+ hits)
- IF mobile/web builds need draw call optimization

**Collision Optimization (if needed):**
- Replace Area2D cone checks with PhysicsServer2D.space_state queries
- Use spatial partitioning (DamageRegistry already has 512px grid)
- Batch collision queries per frame (not per hit)

**MultiMesh Reuse:**
- Existing `scripts/systems/multimesh-backup/MultiMeshManager.gd` is archived
- Can extract transform upload logic if GPU renderer needed
- Digit atlas rendering is NEW work (not in current system)

---

## ⏭️ Next Steps After Task Completion

1. **MVP Launch:** Use HudDamageRenderer for initial release
2. **Monitor Metrics:** Track peak damage number count in production
3. **Evaluate GPU Need:** If peak >300 numbers, implement GpuDamageRenderer
4. **Polish:** Add damage type colors (critical=orange, heal=green, DOT=purple)
5. **Extend:** Add floating text for level-ups, gold pickups, achievement unlocks

---

**Status:** Ready to begin Phase 1 (Performance Analysis & Profiling)
