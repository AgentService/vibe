# Autoload Layer - CLAUDE.md
> Context-specific documentation for autoload/ - Global singletons and coordination systems

**Parent Documentation:** [Main CLAUDE.md](../CLAUDE.md) | **Layer:** Foundation

## Quick Reference

| Autoload | Purpose | Key Signals/Methods | Dependencies |
|----------|---------|-------------------|--------------|
| **EventBus.gd** | Central event hub with typed payloads | All cross-system signals | Domain payload classes |
| **GameOrchestrator.gd** | System initialization & dependency injection | `initialize_systems()`, `world_ready` | All system classes |
| **StateManager.gd** | Scene transitions & game state | `go_to_arena()`, `go_to_hideout()` | SceneTransitionManager |
| **RunManager.gd** | 30Hz fixed-step combat timing + RNG seeding | `combat_step` signal (30Hz), `run_seed` | RNG, BalanceDB |
| **RNG.gd** | Deterministic random streams | `stream(name)` for seeded RNG | None (pure) |
| **Logger.gd** | Centralized logging with categories | `info()`, `warn()`, `debug()` | BalanceDB for config |
| **BalanceDB.gd** | Hot-reloadable balance data | `balance_reloaded` signal | None (foundation) |
| **SessionState.gd** | Session-only run tracking (MEGABONK/ROR2) | `start_run()`, `end_run()`, `get_final_stats()` | EventBus, MetaProgression |
| **MetaProgression.gd** | Persistent currency & unlocks | `add_rift_fragments()`, `get_rift_fragments()` | None (persistence) |
| **LocalLeaderboard.gd** | Personal best tracking per map/tier | `add_run()`, `get_personal_best()`, `get_leaderboard()` | None (persistence) |
| **PlayerProgression.gd** | In-run XP & leveling (simplified) | `leveled_up`, `xp_gained` | None (session-only) |
| **MapLevel.gd** | Time-based progression tracking | `level_increased`, `level_changed` | StateManager for run lifecycle |
| **MultiMeshProjectileManager.gd** | High-performance projectile system | `combat_step` consumer, `ability_projectile_requested` | EventBus, MultiMeshManager |

## Autoload Architecture Patterns

### 🏗️ **Initialization Order & Dependencies**

```gdscript
# Core Foundation (No dependencies)
1. Logger             ← Base logging
2. RNG                ← Deterministic seeding
3. BalanceDB          ← Data foundation

# Persistence Layer
4. MetaProgression    ← Persistent currency & unlocks (user://meta_progression.tres)
5. LocalLeaderboard   ← Personal best tracking (user://local_leaderboard.tres)

# System Coordination
6. EventBus           ← Signal hub (depends on payload classes)
7. RunManager         ← Fixed-step timing + RNG seeding (depends on RNG, BalanceDB)
8. StateManager       ← Scene management
9. SessionState       ← Session-only run tracking (depends on EventBus, MetaProgression)

# Game Systems
10. PlayerProgression        ← In-run XP (simplified, session-only)
11. MapLevel                 ← Time-based progression tracking
12. MultiMeshProjectileManager ← High-performance projectile rendering (200-500+ projectiles)
13. GameOrchestrator         ← System initialization (last)
```

### 🔄 **EventBus Signal Architecture**

**Typed Payload Pattern:**
```gdscript
# ✓ Correct: Use typed payloads
const CombatStepPayload_Type = preload("res://scripts/domain/signal_payloads/CombatStepPayload.gd")
signal combat_step(payload)  # payload: CombatStepPayload_Type

# EventBus emits (called from RunManager._physics_process at 30Hz)
var payload = CombatStepPayload_Type.new(delta)
EventBus.combat_step.emit(payload)

# Systems connect
EventBus.combat_step.connect(_on_combat_step)
func _on_combat_step(payload: EventBus.CombatStepPayload_Type) -> void:
    # payload.dt contains fixed timestep (0.033s for 30Hz)
```

**High-Frequency Optimization:**
```gdscript
# Object pools for damage signals to reduce allocations
var _damage_applied_pool: ObjectPool
var _damage_dealt_pool: ObjectPool
```

### 🎮 **GameOrchestrator Dependency Injection**

**System Creation Pattern:**
```gdscript
# GameOrchestrator creates systems with proper dependencies
func initialize_systems() -> void:
    card_system = CardSystem_Type.new()
    spawn_director = SpawnDirector_Type.new()
    radar_system = RadarSystem_Type.new(spawn_director)  # Inject dependency

    # Systems register with autoloads
    systems["card_system"] = card_system
    systems["spawn_director"] = spawn_director
```

**Arena Integration:**
```gdscript
# Arena receives injected systems from GameOrchestrator
func setup_systems(injected_systems: Dictionary) -> void:
    _card_system = injected_systems.card_system
    _spawn_director = injected_systems.spawn_director
```

### ⏱️ **RunManager Fixed-Step Pattern**

**30Hz Combat Timing (Godot Native):**
```gdscript
# Uses Godot's built-in _physics_process() for fixed timestep
# Configured in project.godot: physics_ticks_per_second=30

func _physics_process(delta: float) -> void:
    # delta is always constant (0.033s for 30Hz)
    # Godot handles the fixed timestep automatically

    # Create typed payload with fixed physics delta
    var payload := EventBus.CombatStepPayload_Type.new(delta)

    # Emit combat step - all systems process at 30Hz
    EventBus.combat_step.emit(payload)

# Physics interpolation (project.godot: physics_interpolation=true)
# - Godot automatically smooths rendering between 30Hz physics steps
# - No manual position tracking needed for entities
# - Call reset_physics_interpolation() when teleporting pooled entities
```

### 🔄 **EntityPool Physics Interpolation Pattern**

**Pooled Entity Reset with Interpolation:**
```gdscript
# EntityPool.gd - Reset callable for pooled entities
func _create_entity_reset() -> Callable:
    return func(entity: Node) -> void:
        # Remove from scene tree
        if entity.get_parent():
            entity.get_parent().remove_child(entity)

        # Reset common properties
        if "position" in entity:
            entity.position = Vector2.ZERO
        if "visible" in entity:
            entity.visible = true

        # Reset physics interpolation to prevent streaking
        if entity.has_method("reset_physics_interpolation"):
            entity.reset_physics_interpolation()

# Why this matters:
# - Godot's physics interpolation tracks previous position for smoothing
# - When pooled entity is repositioned (e.g., arrow fired at new location),
#   interpolation would streak from old position to new position
# - reset_physics_interpolation() clears previous position, preventing artifact
```

**Usage Pattern:**
- Applied automatically to: Projectiles, XP orbs, visual effects
- Not needed for: Continuous movement entities (enemies, player)
- Called when: Entity returned to pool and before repositioning

### 🎲 **RNG Deterministic Streams**

**Named Stream Pattern:**
```gdscript
# Different streams for different game systems
RNG.stream("crit")    # Critical hit calculations
RNG.stream("loot")    # Item drops and rewards
RNG.stream("waves")   # Enemy spawning
RNG.stream("boss")    # Boss AI decisions

# Usage in systems
var crit_roll = RNG.stream("crit").randf()
var spawn_type = RNG.stream("waves").randi_range(0, enemy_types.size() - 1)
```

### 📊 **BalanceDB Hot-Reload Pattern**

**Resource Monitoring:**
```gdscript
# BalanceDB watches .tres files for changes
func _ready() -> void:
    # Monitor specific balance files
    _monitor_file("res://data/balance/combat.tres")
    _monitor_file("res://data/balance/player.tres")

    # Emit reload signal when changed
    balance_reloaded.emit()
```

**System Integration:**
```gdscript
# Systems connect to balance reload
func _ready() -> void:
    BalanceDB.balance_reloaded.connect(_reload_balance)

func _reload_balance() -> void:
    # Refresh cached balance values
    _damage_multiplier = BalanceDB.combat.damage_multiplier
```

### 🎯 **MultiMeshProjectileManager Pattern (2025-01-10)**

**High-Performance Projectile System:**
```gdscript
# MultiMeshProjectileManager.gd - Autoload for GPU-batched projectiles
extends Node

const MAX_PROJECTILES := 500
const COLLISION_RADIUS := 16.0

# Zero-allocation storage (pre-allocated to max capacity)
var _projectile_positions: PackedVector2Array = []
var _projectile_velocities: PackedVector2Array = []
var _projectile_lifetimes: PackedFloat32Array = []
var _projectile_damages: PackedFloat32Array = []

# String lookup tables (avoid storing strings in PackedArrays)
var _damage_type_lookup: Array[String] = ["physical", "fire", "cold", "lightning", "chaos"]
var _element_lookup: Array[String] = ["", "fire", "cold", "lightning", "chaos"]
var _ability_id_lookup: Array[String] = []

var _multimesh_manager = null
var _is_active: bool = false
var _active_count: int = 0

func _ready() -> void:
    # Pre-allocate arrays to max capacity
    _projectile_positions.resize(MAX_PROJECTILES)
    _projectile_velocities.resize(MAX_PROJECTILES)
    _projectile_lifetimes.resize(MAX_PROJECTILES)
    _projectile_damages.resize(MAX_PROJECTILES)

    # Connect to fixed-step physics
    EventBus.combat_step.connect(_on_combat_step)

    # Connect to projectile spawn requests
    EventBus.ability_projectile_requested.connect(_on_ability_projectile_requested)

func _on_combat_step(payload) -> void:
    var dt: float = payload.dt
    var write_index := 0

    for read_index in range(_active_count):
        # Update lifetime
        _projectile_lifetimes[read_index] -= dt

        # Skip expired projectiles
        if _projectile_lifetimes[read_index] <= 0.0:
            continue

        # Update position
        _projectile_positions[read_index] += _projectile_velocities[read_index] * dt

        # Check collision
        var hit := _check_collision(_projectile_positions[read_index], read_index)
        if hit:
            continue  # Despawn

        # Compact alive projectiles (no reallocation)
        if write_index != read_index:
            _projectile_positions[write_index] = _projectile_positions[read_index]
            _projectile_velocities[write_index] = _projectile_velocities[read_index]
            _projectile_lifetimes[write_index] = _projectile_lifetimes[read_index]
            _projectile_damages[write_index] = _projectile_damages[read_index]

        write_index += 1

    _active_count = write_index

    # Update rendering
    if _multimesh_manager:
        var active_positions := PackedVector2Array()
        active_positions.resize(_active_count)
        for i in range(_active_count):
            active_positions[i] = _projectile_positions[i]
        _multimesh_manager.update_projectiles(active_positions)
```

**Spawn Pattern:**
```gdscript
# ProjectileAbility emits to EventBus
EventBus.ability_projectile_requested.emit({
    "use_multimesh": true,
    "source_position": player_pos,
    "direction": Vector2.RIGHT,
    "projectile_speed": 600.0,
    "damage": 25.0,
    "projectile_lifetime": 2.0,
    "damage_type": "physical",
    "element": "",
    "ability_id": "volley_multimesh"
})

# MultiMeshProjectileManager handles spawn
func _on_ability_projectile_requested(projectile_data: Dictionary) -> void:
    if not projectile_data.get("use_multimesh", false):
        return  # Scene-based projectile, ignore

    spawn_projectile(projectile_data)

func spawn_projectile(projectile_data: Dictionary) -> void:
    if _active_count >= MAX_PROJECTILES:
        Logger.warn("Capacity full, skipping spawn", "projectiles")
        return

    # Extract with EXPLICIT types (avoid Variant inference)
    var position: Vector2 = projectile_data.get("source_position", Vector2.ZERO)
    var direction: Vector2 = projectile_data.get("direction", Vector2.RIGHT)
    var speed: float = projectile_data.get("projectile_speed", 800.0)
    var damage: float = projectile_data.get("damage", 15.0)
    var lifetime: float = projectile_data.get("projectile_lifetime", 2.0)

    # Add to active projectiles
    _projectile_positions[_active_count] = position
    _projectile_velocities[_active_count] = direction.normalized() * speed
    _projectile_lifetimes[_active_count] = lifetime
    _projectile_damages[_active_count] = damage

    _active_count += 1
```

**Collision Pattern:**
```gdscript
func _check_collision(position: Vector2, projectile_index: int) -> bool:
    # Use EntityTracker spatial hash (O(1) lookup)
    var nearby_enemy_ids: Array[String] = EntityTracker.get_entities_in_radius(
        position, COLLISION_RADIUS, "enemy"
    )

    if nearby_enemy_ids.is_empty():
        return false

    var enemy_id: String = nearby_enemy_ids[0]

    # Overkill prevention
    if not DamageService.is_entity_alive(enemy_id):
        return false

    # Apply damage via DamageService
    var damage: float = _projectile_damages[projectile_index]
    DamageService._process_damage_immediate(
        enemy_id,
        damage,
        "player",
        ["physical"],
        0.0,  # No knockback for MultiMesh projectiles
        PlayerState.get_position()
    )

    return true  # Hit detected, despawn projectile
```

**Arena Integration:**
```gdscript
# Arena.gd - Wire projectile manager to rendering
func _ready() -> void:
    super._ready()

    if MultiMeshProjectileManager:
        MultiMeshProjectileManager.setup(multimesh_manager)
        Logger.debug("MultiMeshProjectileManager wired to MultiMeshManager", "projectiles")
```

**Key Design Points:**
1. **Zero allocation**: Pre-allocated PackedArrays avoid runtime allocations
2. **Compacting**: Write-index loop removes dead projectiles without reallocation
3. **Type safety**: All variables use explicit type annotations (no Variant inference)
4. **Collision**: EntityTracker spatial hash for O(1) lookups
5. **String optimization**: Lookup tables prevent storing strings in PackedArrays
6. **Overkill prevention**: Check entity alive state before applying damage

**Performance Characteristics:**
- **Target**: 200-500+ simultaneous projectiles at 60 FPS
- **Overhead**: <2ms per frame for 500 projectiles
- **Use cases**: Volley abilities, barrage storms, particle-like effects
- **NOT for**: Homing projectiles, chaining, pierce logic (use scene-based)

### 🎮 **Progression Autoloads (Task 04 - MEGABONK/ROR2 Architecture)**

**SessionState - Session-Only Run Tracking:**
```gdscript
# Start a new run (clears previous session data)
SessionState.start_run(character_id, map_id, tier)

# Session stats tracked via EventBus signals
EventBus.enemy_killed.connect(_on_enemy_killed)  # Auto-tracked
EventBus.damage_dealt.connect(_on_damage_dealt)  # Auto-tracked
EventBus.xp_gained.connect(_on_xp_gained)        # Auto-tracked

# Access current run state
var is_active = SessionState.is_run_active()
var current_char = SessionState.current_character
var current_tier = SessionState.current_tier
var kills = SessionState.kills
var damage = SessionState.damage_dealt

# End run and calculate rewards
SessionState.end_run()  # Emits run_ended signal with final stats

# Get comprehensive final stats
var stats = SessionState.get_final_stats()
# Returns: {character_id, map_id, tier, kills, damage_dealt, time_survived,
#           stage_reached, xp_gained, final_swarm_entered, rift_fragments_earned}
```

**MetaProgression - Persistent Currency:**
```gdscript
# Award Rift Fragments (persistent across runs)
MetaProgression.earn_rift_fragments(amount)  # Emits rift_fragments_changed signal

# Check balance
var balance = MetaProgression.get_rift_fragments()

# Spend fragments (for unlocks/upgrades)
if MetaProgression.can_afford(cost):
    MetaProgression.spend_rift_fragments(cost)

# Reset for testing
MetaProgression.reset_all()
```

**LocalLeaderboard - Personal Best Tracking:**
```gdscript
# Add run to leaderboard (called by SessionState on end_run)
var rank = LocalLeaderboard.add_run(map_id, tier, run_data)
# Returns 1-10 if made leaderboard, -1 if didn't qualify

# Get personal best for specific map+tier
var best = LocalLeaderboard.get_personal_best("forest_arena", 1)
# Returns: {character_id, kills, time_survived, stage_reached, ...}

# Get full leaderboard for display
var leaderboard = LocalLeaderboard.get_leaderboard("forest_arena", 1)
# Returns: Array[Dictionary] sorted by rift_fragments_earned

# Get all maps/tiers with entries
var maps = LocalLeaderboard.get_maps_with_entries()
var tiers = LocalLeaderboard.get_tiers_with_entries("forest_arena")
```

**Architecture Notes:**
- **No CharacterManager:** Character selection handled by SessionState + MainMenu UI
- **No Profiles Directory:** Only two persistence files:
  - `user://meta_progression.tres` (Rift Fragments)
  - `user://local_leaderboard.tres` (Personal bests)
- **Session vs Meta Separation:** SessionState = temporary run data, MetaProgression = permanent unlocks
- **Bottom-Up Migration:** Phase 1-6 built new systems first, Phase 7 verified integration complete

## Common Integration Patterns

### 🔌 **System ↔ Autoload Communication**

```gdscript
# ✓ Systems emit to EventBus
EventBus.enemy_killed.emit(payload)

# ✓ Autoloads provide services
var damage = BalanceDB.combat.base_damage
var random_enemy = RNG.stream("waves").pick_random(enemy_types)

# ✗ Never directly reference systems from autoloads
# autoload_script.gd should NOT call arena.get_player()
```

### 📝 **Logging Integration**

```gdscript
# Category-based logging in autoloads
Logger.info("System initialized", "orchestrator")
Logger.warn("Balance file missing", "balance")
Logger.debug("RNG seed updated", "rng")

# F6 toggles DEBUG/INFO levels
# F5 reloads log configuration
```

### 🔄 **State Transition Patterns**

```gdscript
# StateManager handles all scene transitions
StateManager.go_to_arena()           # Menu → Arena
StateManager.go_to_hideout()         # Arena → Hideout
StateManager.go_to_character_select() # Menu → Character Select

# Never use direct EventBus for navigation:
# ✗ EventBus.request_scene_change.emit("arena")
```

## Performance Considerations

### ⚡ **Zero-Allocation Patterns**

- **EventBus:** Object pools for high-frequency payloads (damage_applied, damage_dealt)
- **RunManager:** Uses Godot's native _physics_process(), no manual accumulation overhead
- **RNG:** Cached stream instances, no dynamic creation

### 🔍 **Process Mode Management**

```gdscript
# Critical autoloads continue during pause
Logger:     PROCESS_MODE_ALWAYS    # Logging always available
EventBus:   PROCESS_MODE_ALWAYS    # Events during pause menus

# Game systems pause properly
RunManager: PROCESS_MODE_PAUSABLE  # Combat stops during pause
```

## Troubleshooting Guide

### 🚨 **Common Issues**

1. **"Unknown autoload" errors:** Check initialization order
2. **Signal not firing:** Verify EventBus signal connections use typed payloads
3. **RNG not deterministic:** Ensure same seed and stream usage
4. **Balance not reloading:** Check BalanceDB file monitoring setup
5. **Systems not initialized:** Verify GameOrchestrator.initialize_systems() called

### 🔧 **Debug Tools**

- **F6:** Toggle Logger DEBUG/INFO levels
- **F5:** Force reload balance data
- **Logger categories:** "orchestrator", "balance", "rng", "state"

## Migration Notes

When creating new autoloads:
1. **Add to initialization order** in GameOrchestrator
2. **Use typed EventBus signals** with payload classes
3. **Follow PROCESS_MODE patterns** (ALWAYS vs PAUSABLE)
4. **Integrate with Logger** using appropriate categories
5. **Update this documentation** with new patterns

---
**See Also:** [System Integration](../scripts/systems/CLAUDE.md) | [Domain Models](../scripts/domain/CLAUDE.md) | [Architecture Rules](../ARCHITECTURE.md)