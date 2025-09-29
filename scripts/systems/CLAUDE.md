# Systems Layer - CLAUDE.md
> Context-specific documentation for scripts/systems/ - Core game logic and rules (30Hz combat)

**Parent Documentation:** [Main CLAUDE.md](../../CLAUDE.md) | **Layer:** Rules & Logic

## Quick Reference

| System | Purpose | Key Signals | EventBus Integration |
|--------|---------|-------------|-------------------|
| **DamageSystem.gd** | Collision detection & damage application | N/A (uses DamageService) | `combat_step` consumer |
| **MeleeSystem.gd** | Cone-based AOE melee attacks | `melee_attack_started`, `enemies_hit` | `combat_step` consumer |
| **SpawnDirector.gd** | AREA_TRIGGERS zone-based enemy spawning | `enemies_spawned` | Entity registration |
| **SimpleTileSpawnValidator.gd** | Tileset-based spawn validation & positioning | N/A (utility autoload) | Spatial partitioning |
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

## New Patterns Added

### 2025-09-22 - SimpleTileSpawnValidator System
- **New Autoload:** SimpleTileSpawnValidator - Spatial partitioned tileset-based spawning
- **Purpose:** Replace Area2D spawn circles with ground tile validation from TileMapLayer
- **Performance:** <2ms spawn queries via 512px spatial grid partitioning (76k+ tiles → ~9 grid cells)
- **Integration:** SpawnDirector fallback pattern - try tileset first, radius-based as backup
- **Core API:** `cache_ground_tiles(arena, ground_layer)`, `get_random_spawn_position(arena, ground_layer, target_pos, radius)`
- **Tile Detection:** Uses `get_used_cells_by_id(2, Vector2i(12, 3))` for ground tile identification

### 2025-09-21 - Breach Event Optimization
- **New System:** BreachEnemyTracker - Zero-allocation enemy tracking with RingBuffer
- **30Hz Compatibility:** Converted from 60Hz per-frame to 30Hz fixed-step via EventBus.combat_step
- **EventBus Integration:** Consumes combat_step signals, maintains breach timing preservation
- **Resource Dependencies:** Uses mark-for-removal strategy for safe concurrent operations
- **Common Gotchas:** 256-enemy capacity with graceful overflow - monitor for capacity warnings

## Integration Examples

### ⚡️ **Zero-Allocation Breach Tracking Pattern**

```gdscript
# BreachEnemyTracker.gd - RingBuffer-based tracking
extends RefCounted
class_name BreachEnemyTracker

const MAX_ENEMIES := 256
var _enemies: Array[String] = []  # Pre-allocated ring buffer
var _count := 0
var _removal_flags: PackedByteArray  # Mark-for-removal flags

func add_enemy(enemy_id: String) -> void:
    if _count >= MAX_ENEMIES:
        Logger.warn("BreachEnemyTracker: Capacity overflow, oldest enemy removed", "breach")
        _remove_oldest()
    
    _enemies[_count] = enemy_id
    _removal_flags[_count] = 0  # Not marked for removal
    _count += 1

func mark_for_removal(enemy_id: String) -> void:
    # Safe concurrent marking - actual removal in fixed-step
    for i in range(_count):
        if _enemies[i] == enemy_id:
            _removal_flags[i] = 1
            break

func process_removals() -> void:
    # Called during 30Hz combat_step - processes all marked removals
    var write_index := 0
    for read_index in range(_count):
        if _removal_flags[read_index] == 0:
            _enemies[write_index] = _enemies[read_index]
            _removal_flags[write_index] = 0
            write_index += 1
    _count = write_index
```

### 🎯 **BreachEventHandler 30Hz Integration**

```gdscript
# BreachEventHandler.gd - Fixed-step breach processing
func _ready() -> void:
    # Connect to 30Hz fixed timestep
    EventBus.combat_step.connect(_on_combat_step)
    
    # Initialize zero-allocation tracker
    _enemy_tracker = BreachEnemyTracker.new()

func _on_combat_step(payload: EventBus.CombatStepPayload_Type) -> void:
    # Process all breach updates at fixed 30Hz
    _enemy_tracker.process_removals()
    _update_breach_effects(payload.delta_time)
    _check_breach_completion()

func _on_enemy_died(enemy_id: String) -> void:
    # Mark for removal - processed in next combat step
    _enemy_tracker.mark_for_removal(enemy_id)
    
    # Immediate breach progress update
    _update_breach_progress()
```

### 📊 **Performance Optimization Notes**

```gdscript
# Before: Dictionary-based tracking with per-frame iteration
# Performance: O(n) iteration every frame (60Hz)
# Memory: Frequent allocations/deallocations during enemy death waves

# After: RingBuffer with fixed-step processing  
# Performance: O(n) batch processing at 30Hz = 50%+ improvement
# Memory: Zero allocation during steady-state enemy management
# Behavior: Identical breach timing and completion detection

# Capacity Management
func _monitor_breach_capacity() -> void:
    if _enemy_tracker.get_count() > (MAX_ENEMIES * 0.8):
        Logger.warn("Breach approaching capacity: %d/%d enemies" % [
            _enemy_tracker.get_count(), MAX_ENEMIES
        ], "breach")
```

### 🎯 **SimpleTileSpawnValidator Spatial Partitioning Pattern**

```gdscript
# SimpleTileSpawnValidator.gd - Optimized tileset-based spawning
extends Node

const GRID_SIZE := 512  # Spatial grid cell size in world units
var _arena_spatial_grids: Dictionary = {}  # arena_id -> Dictionary[Vector2i, Array[Vector2i]]

func cache_ground_tiles(arena: Node, ground_layer: TileMapLayer) -> void:
    var arena_id := arena.get_instance_id()
    var ground_positions: Array[Vector2i] = []
    var spatial_grid: Dictionary = {}

    # Get all ground tiles using Godot's efficient tile query
    for atlas_coords in GROUND_ATLAS_IDS:
        var tiles_at_coords := ground_layer.get_used_cells_by_id(GROUND_SOURCE_ID, atlas_coords)
        ground_positions.append_array(tiles_at_coords)

    # Build spatial grid for O(grid cells) lookup instead of O(all tiles)
    for tile_pos in ground_positions:
        var world_pos := ground_layer.map_to_local(tile_pos)
        var grid_coord := Vector2i(
            int(world_pos.x / GRID_SIZE),
            int(world_pos.y / GRID_SIZE)
        )

        if not spatial_grid.has(grid_coord):
            spatial_grid[grid_coord] = []
        spatial_grid[grid_coord].append(tile_pos)

    _arena_spatial_grids[arena_id] = spatial_grid
    Logger.info("Cached %d ground tiles in %d grid cells" % [
        ground_positions.size(), spatial_grid.size()
    ], "tilespawn")

func get_random_spawn_position(arena: Node, ground_layer: TileMapLayer, target_pos: Vector2, radius: float) -> Vector2:
    var spatial_grid: Dictionary = _arena_spatial_grids.get(arena.get_instance_id(), {})

    # Calculate which grid cells to check (dramatically reduces search space)
    var grid_radius := int(ceil(radius / GRID_SIZE)) + 1
    var center_grid := Vector2i(int(target_pos.x / GRID_SIZE), int(target_pos.y / GRID_SIZE))

    var valid_tiles: Array[Vector2i] = []
    # Only check nearby grid cells (e.g., 9 cells for 500px radius)
    for x in range(center_grid.x - grid_radius, center_grid.x + grid_radius + 1):
        for y in range(center_grid.y - grid_radius, center_grid.y + grid_radius + 1):
            var grid_coord := Vector2i(x, y)
            var tiles_in_cell: Array = spatial_grid.get(grid_coord, [])

            # Fine-grained distance check within grid cell
            for tile_pos in tiles_in_cell:
                var world_pos := ground_layer.map_to_local(tile_pos)
                if world_pos.distance_to(target_pos) <= radius:
                    valid_tiles.append(tile_pos)

    # Deterministic random selection
    if not valid_tiles.is_empty():
        var spawn_rng := RNG.stream("spawn")
        var selected_tile := valid_tiles[spawn_rng.randi() % valid_tiles.size()]
        return ground_layer.map_to_local(selected_tile)

    return Vector2.ZERO
```

### 🔄 **SpawnDirector Integration Pattern**

```gdscript
# SpawnDirector.gd - Hybrid spawn approach
func _spawn_enemy_v2(enemy_type: String, position: Vector2) -> Node2D:
    # Try tileset-based spawning first
    var tileset_spawn_pos = _try_tileset_spawn_position(position)
    if tileset_spawn_pos != Vector2.ZERO:
        return _create_enemy(enemy_type, tileset_spawn_pos)

    # Fallback to radius-based spawning for compatibility
    var fallback_pos = _find_spawn_position_in_radius(position, spawn_radius)
    if fallback_pos != Vector2.ZERO:
        return _create_enemy(enemy_type, fallback_pos)

    Logger.warn("No valid spawn position found for enemy: %s" % enemy_type, "spawning")
    return null

func _try_tileset_spawn_position(target_pos: Vector2) -> Vector2:
    var ground_layer = arena_scene.get_node("Ground")
    if not ground_layer or not ground_layer is TileMapLayer:
        return Vector2.ZERO

    # Use SimpleTileSpawnValidator for tileset-based positioning
    return SimpleTileSpawnValidator.get_random_spawn_position(
        arena_scene, ground_layer, target_pos, spawn_radius
    )
```

### 📊 **Performance Monitoring Pattern**

```gdscript
# Monitor tileset spawn performance
func _validate_spawn_performance() -> void:
    var performance_metrics = SimpleTileSpawnValidator.get_performance_metrics()

    if performance_metrics.query_time_ms > 2.0:  # 2ms threshold
        Logger.warn("Slow tileset spawn query: %.2f ms" % performance_metrics.query_time_ms, "performance")

    Logger.debug("Spawn query completed in %.1f μs (%d grid cells)" % [
        performance_metrics.last_query_time_us,
        performance_metrics.total_grid_cells
    ], "tilespawn")
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
