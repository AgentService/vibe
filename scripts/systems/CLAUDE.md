# Systems Layer - CLAUDE.md
> Context-specific documentation for scripts/systems/ - Core game logic and rules (30Hz combat)

**Parent Documentation:** [Main CLAUDE.md](../../CLAUDE.md) | **Layer:** Rules & Logic

## Quick Reference

| System | Purpose | Key Signals | EventBus Integration |
|--------|---------|-------------|-------------------|
| **DamageSystem.gd** | Collision detection & damage application | N/A (uses DamageService) | `combat_step` consumer |
| **MeleeSystem.gd** | Cone-based AOE melee attacks | `melee_attack_started`, `enemies_hit` | `combat_step` consumer |
| **SpawnDirector.gd** | Enemy spawning with zone restrictions | `enemies_spawned` | Entity registration |
| **ArenaSystem.gd** | Arena bounds & spatial management | `arena_loaded` | Bounds configuration |
| **CardSystem.gd** | Upgrade card selection & application | `card_selected`, `card_applied` | Player progression |
| **BossSpawnManager.gd** | Zone-based boss spawning | Boss creation events | Zone validation |
| **RadarSystem.gd** | Enemy position scanning for UI | `radar_data_updated` | State-gated updates |

## System Architecture Patterns

### ⚙️ **Core System Structure**

**Standard System Template:**
```gdscript
extends Node
class_name SystemName

# 1. Dependencies (injected by GameOrchestrator)
var spawn_director: SpawnDirector
var other_system: OtherSystem

# 2. Balance values (loaded from BalanceDB)
var damage: float
var cooldown: float

# 3. System state
var is_active: bool = false

func _ready() -> void:
    # 4. Load balance values
    _load_balance_values()

    # 5. Connect to 30Hz combat step
    EventBus.combat_step.connect(_on_combat_step)

    # 6. Setup hot-reload
    if BalanceDB:
        BalanceDB.balance_reloaded.connect(_load_balance_values)

func _on_combat_step(payload: EventBus.CombatStepPayload_Type) -> void:
    # 7. Fixed-step game logic here
```

### 🔧 **Dependency Injection Pattern**

**GameOrchestrator → Systems:**
```gdscript
# GameOrchestrator creates and injects dependencies
func initialize_systems() -> void:
    spawn_director = SpawnDirector.new()
    damage_system = DamageSystem.new()

    # Inject dependencies
    damage_system.spawn_director = spawn_director
    melee_system.spawn_director = spawn_director

# Systems never create their own dependencies
# ✗ Wrong: var spawn_director = SpawnDirector.new()
# ✓ Correct: Receive via injection
```

**Arena Integration:**
```gdscript
# Arena receives fully-initialized systems
func setup_systems(injected_systems: Dictionary) -> void:
    _damage_system = injected_systems.damage_system
    _melee_system = injected_systems.melee_system

    # Arena coordinates but doesn't own systems
```

### ⏱️ **30Hz Combat Step Pattern**

**Fixed-Step Logic:**
```gdscript
func _on_combat_step(payload: EventBus.CombatStepPayload_Type) -> void:
    # All game logic runs at fixed 30Hz
    var delta_time = payload.delta_time  # Always 1/30 = 0.0333...

    # Update cooldowns
    if attack_cooldown > 0.0:
        attack_cooldown -= delta_time

    # Process game logic
    _process_attacks()
    _update_enemy_ai()
```

**Performance Considerations:**
```gdscript
# ✓ Cache expensive lookups outside combat step
var _cached_enemies: Array[EnemyEntity] = []

func _on_balance_reloaded() -> void:
    # Update cache when balance changes
    _update_enemy_cache()

func _on_combat_step(payload: EventBus.CombatStepPayload_Type) -> void:
    # Use cached data in hot path
    for enemy in _cached_enemies:
        _process_enemy(enemy)
```

### 🎯 **EventBus Communication Patterns**

**Emit Domain Events:**
```gdscript
# Systems emit high-level domain events
func _deal_damage_to_enemy(enemy_id: String, damage: float) -> void:
    # Apply damage via DamageService
    DamageService.apply_damage(EntityId.enemy(enemy_id), damage, ["melee"])

    # Emit for other systems to react
    var payload = EventBus.DamageDealtPayload_Type.new()
    payload.target_id = enemy_id
    payload.damage_amount = damage
    payload.damage_types = ["melee"]
    EventBus.damage_dealt.emit(payload)
```

**Signal Subscription:**
```gdscript
func _ready() -> void:
    # Subscribe to relevant domain events
    EventBus.enemy_killed.connect(_on_enemy_killed)
    EventBus.player_leveled_up.connect(_on_player_leveled_up)

func _on_enemy_killed(payload: EventBus.EnemyKilledPayload_Type) -> void:
    # React to domain events
    _update_kill_counter(payload.enemy_type)
```

### 🏗️ **Resource-Based Configuration**

**@export Resource Pattern:**
```gdscript
# ArenaSystem.gd - Scene-based hot-reload
@export var arena_config: ArenaConfig

func _ready() -> void:
    # @export automatically hot-reloads when .tres changes
    arena_loaded.emit(get_arena_bounds())
```

**BalanceDB Pattern:**
```gdscript
# MeleeSystem.gd - Autoload-based hot-reload
func _load_balance_values() -> void:
    damage = BalanceDB.get_melee_value("damage")
    attack_range = BalanceDB.get_melee_value("range")
    cone_angle = BalanceDB.get_melee_value("cone_angle")

func _ready() -> void:
    BalanceDB.balance_reloaded.connect(_load_balance_values)
```

## System Integration Patterns

### 🎮 **Combat Systems Integration**

**Damage Flow:**
```
1. MeleeSystem detects cone attack
2. MeleeSystem calls DamageService.apply_damage()
3. DamageService emits damage_dealt signal
4. SpawnDirector listens for enemy deaths
5. XpSystem awards experience points
```

**Collision Detection:**
```gdscript
# DamageSystem handles all collision types
func _check_enemy_player_collisions() -> void:
    var alive_enemies = spawn_director.get_alive_enemies()
    var player_pos = PlayerState.get_position()

    for enemy in alive_enemies:
        if _circle_overlap(player_pos, player_radius, enemy.pos, enemy_radius):
            DamageService.apply_damage(EntityId.player(), enemy.damage, ["physical"])
```

### 🎯 **Spawn System Integration**

**Zone-Based Spawning:**
```gdscript
# SpawnDirector uses zone validation
func spawn_enemy_at_position(enemy_type: String, position: Vector2) -> Node2D:
    # 1. Validate spawn zone
    if not _is_valid_spawn_position(position):
        return null

    # 2. Create enemy via factory
    var enemy = EnemyFactory.create_enemy(enemy_type, position)

    # 3. Register with EntityTracker
    EntityTracker.register_entity(enemy, "enemy")

    # 4. Emit spawn event
    EventBus.enemy_spawned.emit(enemy_spawn_payload)

    return enemy
```

**Boss Integration:**
```gdscript
# BossSpawnManager coordinates with zones
func spawn_boss_in_zone(zone_index: int) -> void:
    var spawn_position = _get_zone_spawn_position(zone_index)
    var boss = spawn_director.spawn_boss_by_id("ancient_lich", spawn_position)

    # Boss inherits from BaseBoss with automatic shadow, scaling, etc.
```

### 📊 **Performance Optimization Patterns**

**Spatial Queries:**
```gdscript
# EntityTracker provides efficient spatial lookups
func get_enemies_in_range(center: Vector2, radius: float) -> Array[EnemyEntity]:
    return EntityTracker.get_entities_in_range(center, radius, "enemy")

# Use for cone attacks, radar scans, etc.
func _check_cone_attack_hits(player_pos: Vector2, target_pos: Vector2) -> Array:
    var nearby_enemies = EntityTracker.get_entities_in_range(player_pos, attack_range, "enemy")
    return _filter_enemies_in_cone(nearby_enemies, player_pos, target_pos)
```

**Batch Processing:**
```gdscript
# BossUpdateManager batches boss updates
func _on_combat_step(payload: EventBus.CombatStepPayload_Type) -> void:
    # Single update call for all bosses
    BossUpdateManager.process_boss_batch(payload.delta_time)

    # Avoid individual boss _process() methods
```

## System-Specific Patterns

### ⚔️ **MeleeSystem Cone Detection**

```gdscript
func _is_enemy_in_cone(enemy_pos: Vector2, player_pos: Vector2, target_pos: Vector2) -> bool:
    # 1. Check range first (fast rejection)
    var distance = player_pos.distance_to(enemy_pos)
    if distance > attack_range:
        return false

    # 2. Check cone angle (dot product)
    var to_target = (target_pos - player_pos).normalized()
    var to_enemy = (enemy_pos - player_pos).normalized()
    var angle = acos(to_target.dot(to_enemy))

    return angle <= deg_to_rad(cone_angle / 2.0)
```

### 🎯 **RadarSystem State Gating**

```gdscript
func _should_update() -> bool:
    # Only active in ARENA state
    if StateManager.get_current_state() != StateManager.GameState.ARENA:
        return false

    # Respect pause state
    if PauseManager.is_paused():
        return false

    return true
```

### 🃏 **CardSystem Modifier Application**

```gdscript
func apply_card_effects(card_data: Dictionary) -> void:
    # Update RunManager stats for persistence
    if card_data.has("damage_multiplier"):
        RunManager.stats.melee_damage_multiplier *= card_data.damage_multiplier

    # Trigger system reloads
    _broadcast_stat_changes()
```

## Troubleshooting Guide

### 🚨 **Common Issues**

1. **System not updating:** Check `combat_step` signal connection
2. **Dependencies null:** Verify GameOrchestrator injection
3. **Balance values wrong:** Check BalanceDB connection and hot-reload
4. **Performance drops:** Profile `_on_combat_step()` methods
5. **Events not firing:** Verify EventBus signal usage with typed payloads

### 🔧 **Debug Patterns**

```gdscript
# System-specific logging
Logger.debug("Melee attack hit {count} enemies".format({"count": hit_count}), "combat")
Logger.warn("SpawnDirector: No valid spawn zones available", "spawning")

# Performance monitoring in systems
var start_time = Time.get_ticks_msec()
_expensive_operation()
var elapsed = Time.get_ticks_msec() - start_time
if elapsed > 5:  # Warn if >5ms
    Logger.warn("Slow operation took {time}ms".format({"time": elapsed}), "performance")
```

### 📊 **Architecture Validation**

Systems layer rules:
- ✅ **May import:** Domain classes, autoload references
- ✅ **May call:** Other systems via injection, EventBus signals
- ❌ **Must not:** Reference scenes directly, use get_node() for UI
- ❌ **Must not:** Create autoload instances

## Migration Notes

When creating new systems:
1. **Follow standard template** with `_ready()`, `_load_balance_values()`, `_on_combat_step()`
2. **Use dependency injection** via GameOrchestrator
3. **Connect to combat_step** for 30Hz deterministic updates
4. **Emit typed EventBus signals** for cross-system communication
5. **Add logging** with appropriate categories
6. **Update this documentation** with new patterns

---
**See Also:** [Autoload Patterns](../../autoload/CLAUDE.md) | [Domain Models](../domain/CLAUDE.md) | [Scene Integration](../../scenes/CLAUDE.md)