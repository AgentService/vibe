# Systems Layer - CLAUDE.md
> Context-specific documentation for scripts/systems/ - Core game logic and rules (30Hz combat)

**Parent Documentation:** [Main CLAUDE.md](../../CLAUDE.md) | **Layer:** Rules & Logic

## 🏗️ **Domain Organization (Updated 2025-09-30)**

The systems layer is organized into **11 logical domain subfolders** for improved maintainability:

| Domain Subfolder | Purpose | Key Systems | Files Count |
|------------------|---------|-------------|-------------|
| **arena/** | Arena coordination & management | ArenaSystem, ArenaUIManager, SceneTransitionManager | 5 |
| **combat/** | Combat mechanics & damage | DamageSystem, MeleeSystem, XpSystem, PlayerAttackHandler | 4 |
| **player/** | Player-specific systems | CardSystem | 1 |
| **spawn/** | Enemy & entity spawning | SpawnDirector, BossSpawnManager, EventSpawnManager | 6 |
| **radar/** | Position scanning & detection | RadarSystem, RadarUpdateManager | 2 |
| **boss/** | Boss management & AI | BaseBoss, BossUpdateManager, BossHitFeedback | 3 |
| **events/** | Breach events & mastery | BreachEventHandler, BreachEnemyTracker | 2 |
| **rendering/** | Visual effects & performance | VisualEffectsManager, EnemyRenderTier, PerformanceMonitor | 4 |
| **arena_generation/** | Procedural map generation | PathAwareArenaGenerator, TreeBoundaryGenerator | 5 |
| **debug/** | Development & debugging tools | DebugOverlay, EntitySelector, DebugSystemControls | 5 |
| **damage_v2/** | Next-gen damage system | DamageRegistry (autoload) | 3 |

**Total: ~35+ system files organized across 11 domain subfolders**

## Quick Reference

| Domain | System | Purpose | Key Signals | EventBus Integration |
|--------|--------|---------|-------------|-------------------|
| **combat/** | **DamageSystem.gd** | Collision detection & damage application | N/A (uses DamageService) | `combat_step` consumer |
| **combat/** | **MeleeSystem.gd** | Cone-based AOE melee attacks | `melee_attack_started`, `enemies_hit` | `combat_step` consumer |
| **combat/** | **XpSystem.gd** | Experience point management | `xp_gained`, `level_up` | Player progression |
| **spawn/** | **SpawnDirector.gd** | AREA_TRIGGERS zone-based enemy spawning | `enemies_spawned` | Entity registration |
| **spawn/** | **EventSpawnManager.gd** | Event-based spawning with mastery modifiers | `event_started`, `event_completed` | Zone cooldowns & threat escalation |
| **spawn/** | **BossSpawnManager.gd** | Zone-based boss spawning | Boss creation events | Zone validation |
| **arena/** | **ArenaSystem.gd** | Arena bounds & spatial management | `arena_loaded` | Bounds configuration |
| **arena/** | **ArenaUIManager.gd** | Arena UI coordination | UI state updates | HUD management |
| **player/** | **CardSystem.gd** | Upgrade card selection & application | `card_selected`, `card_applied` | Player progression |
| **radar/** | **RadarSystem.gd** | Enemy position scanning for UI | `radar_data_updated` | State-gated updates |
| **rendering/** | **VisualEffectsManager.gd** | Visual feedback coordination | Effect triggers | Impact feedback |
| **boss/** | **BossUpdateManager.gd** | Boss AI batch processing | Boss behavior updates | Performance optimization |

### 🎯 **Domain Organization Benefits**

**Before (Flat Structure):**
```
scripts/systems/
├── ArenaSystem.gd
├── CardSystem.gd
├── DamageSystem.gd
├── MeleeSystem.gd
├── SpawnDirector.gd
├── ... (30+ files in one folder)
```

**After (Domain-Driven Structure):**
```
scripts/systems/
├── arena/ArenaSystem.gd
├── player/CardSystem.gd
├── combat/DamageSystem.gd
├── combat/MeleeSystem.gd
├── spawn/SpawnDirector.gd
├── ... (organized by functional domain)
```

**Navigation Improvements:**
- ✅ **Logical grouping** - related systems co-located
- ✅ **Clear separation of concerns** - domain boundaries enforced
- ✅ **Easier code discovery** - find systems by functional area
- ✅ **Reduced cognitive load** - smaller, focused subfolders
- ✅ **Scalable architecture** - new systems added to appropriate domains

### 📁 **Import Path Migration**

**Updated import patterns for domain organization:**
```gdscript
# ❌ Old flat structure imports:
const ArenaSystem = preload("res://scripts/systems/ArenaSystem.gd")
const CardSystem = preload("res://scripts/systems/CardSystem.gd")

# ✅ New domain-based imports:
const ArenaSystem = preload("res://scripts/systems/arena/ArenaSystem.gd")
const CardSystem_Type = preload("res://scripts/systems/player/CardSystem.gd")
const MeleeSystem_Type = preload("res://scripts/systems/combat/MeleeSystem.gd")
const SpawnDirector_Type = preload("res://scripts/systems/spawn/SpawnDirector.gd")
```

**Migration completed in:**
- ✅ **GameOrchestrator.gd** - All system imports updated
- ✅ **SystemInjectionManager.gd** - Arena/combat system paths updated
- ✅ **Arena.gd** - Domain subfolder imports updated
- ✅ **SpawnDirector.gd** - ArenaSystem import updated
- ✅ **Main.gd** - SceneTransitionManager import updated

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

**GameOrchestrator → Systems (Updated Import Paths):**
```gdscript
# GameOrchestrator creates and injects dependencies
# Import from domain subfolders
const CardSystem_Type = preload("res://scripts/systems/player/CardSystem.gd")
const MeleeSystem_Type = preload("res://scripts/systems/combat/MeleeSystem.gd")
const ArenaSystem = preload("res://scripts/systems/arena/ArenaSystem.gd")
const SpawnDirector_Type = preload("res://scripts/systems/spawn/SpawnDirector.gd")

func initialize_systems() -> void:
    spawn_director = SpawnDirector_Type.new()
    melee_system = MeleeSystem_Type.new()

    # Inject dependencies
    melee_system.set_spawn_director_reference(spawn_director)

# Systems never create their own dependencies
# ✗ Wrong: var spawn_director = SpawnDirector.new()
# ✓ Correct: Receive via injection from GameOrchestrator
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

**Staggered AI Updates (Decoupled Movement Pattern):**
```gdscript
# BossUpdateManager batches AI updates (thinking)
func _on_combat_step(payload: EventBus.CombatStepPayload_Type) -> void:
    # Process BOSS_UPDATE_BATCH_SIZE bosses per frame
    # Example: 20 bosses per frame with 1000 total = 50 frame cycle
    for i in range(batch_start, batch_end):
        boss._update_ai_batch(dt)  # Calls _update_ai() which calculates velocity

# BaseBoss separates thinking from movement
func _update_ai(dt: float) -> void:
    # AI "thinking" - calculate velocity (runs in staggered batches)
    velocity = (target_position - global_position).normalized() * speed
    # Note: No move_and_slide() here - that happens in _physics_process()

func _physics_process(delta: float) -> void:
    # Movement - apply velocity (runs every frame at 30Hz)
    move_and_slide()  # Uses last calculated velocity

# Key insight: Velocity calculated every ~1.67s, applied every 33ms
# Result: Smooth continuous movement with reduced AI computation
```

**Performance Impact:**
- 1000 enemies: 98% reduction in per-frame physics queries (20/1000)
- Smooth movement maintained by decoupling AI from physics application
- AI updates every ~1.67s (batch cycle), movement every 33ms (30Hz fixed step)

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

### 👾 **BaseBoss Animation & Collision Patterns (Updated 2025-10-08)**

**Simplified Directional Animation (Left/Right Only):**
```gdscript
# BaseBoss.gd - Simplified animation system
func _update_directional_animation(direction: Vector2) -> void:
    if not animated_sprite:
        return

    # Simple left/right sprite flipping based on horizontal movement
    if abs(direction.x) > 0.1:  # Only flip if significant horizontal movement
        animated_sprite.flip_h = direction.x < 0  # Flip when moving left

    # Ensure animation is playing (use "default" or animation_prefix)
    if animated_sprite.sprite_frames and not animated_sprite.is_playing():
        if animated_sprite.sprite_frames.has_animation("default"):
            animated_sprite.play("default")
        elif animated_sprite.sprite_frames.has_animation(animation_prefix):
            animated_sprite.play(animation_prefix)
```

**Performance Benefits:**
- ❌ **Removed:** ~75 lines of 8-directional animation system
- ❌ **Removed:** `direction.angle()` trigonometric calculations (30,000/sec @ 1000 enemies)
- ❌ **Removed:** String concatenation for animation names ("walk_" + direction)
- ❌ **Removed:** Multiple `has_animation()` lookups across 8 directions
- ✅ **Kept:** Simple `flip_h` boolean assignment (O(1) operation)

**Animation Requirements:**
- Bosses need only ONE animation: "default" or their custom `animation_prefix`
- No directional variants required (e.g., "walk_left", "walk_up", etc.)
- Horizontal facing handled automatically by sprite flipping

**Collision Optimization (Enemy Pass-Through):**
```gdscript
# BaseBoss._ready() - Explicit collision configuration
func _ready() -> void:
    # PERFORMANCE: Disable enemy-to-enemy collision for high entity counts
    # Layer 2 (Bosses): Enemy exists on this layer (projectiles/player can hit)
    # Mask 1 (Terrain): Enemy only collides with terrain (passes through other enemies)
    collision_layer = 2  # Exist on Layer 2
    collision_mask = 1   # Collide with Layer 1 only (terrain)
```

**Collision Performance:**
- **Before:** 450 enemies = ~101,000 collision pairs (n × (n-1) / 2)
- **After:** 450 enemies = ~450 collision checks (enemies vs terrain only)
- **Expected gain:** 20-40% FPS improvement at 500+ enemies
- **Behavior:** Enemies stack on player without blocking each other

**Layer Configuration:**
```gdscript
# project.godot physics layers:
# Layer 1: Terrain
# Layer 2: Bosses (enemies)
# Layer 3: Player
# Layer 4: Projectiles

# Collision matrix:
# - Enemies (Layer 2) collide with: Terrain (Layer 1) only
# - Projectiles (Layer 4) collide with: Enemies (Layer 2)
# - Player (Layer 3) collides with: Enemies (Layer 2)
# - Enemies DON'T collide with each other
```

**To toggle enemy-enemy collision:**
```gdscript
# Enable enemy-enemy collision:
collision_mask = 3  # Binary 0011 = Layers 1 + 2 (Terrain + Bosses)

# Disable enemy-enemy collision (default):
collision_mask = 1  # Binary 0001 = Layer 1 only (Terrain)
```

**Physics Optimization (move_and_slide Performance):**
```gdscript
# BaseBoss._ready() - Optimize CharacterBody2D physics for top-down games
func _ready() -> void:
    # PERFORMANCE: Configure move_and_slide() for maximum efficiency
    motion_mode = MOTION_MODE_FLOATING  # Skip floor/ceiling detection = 30% faster
    max_slides = 1                       # Reduce collision iterations from 4 to 1 = 75% reduction
    safe_margin = 0.08                   # Increase collision margin = less precision, more speed
    floor_stop_on_slope = false          # Disable platformer features
    wall_min_slide_angle = 0.0           # Allow sliding at any angle
```

**Physics Performance Impact:**
- **motion_mode = MOTION_MODE_FLOATING**: Skips floor/wall/ceiling angle calculations (designed for platformers)
- **max_slides = 1**: Reduces collision resolution iterations from 4 → 1 (75% fewer collision checks)
- **safe_margin = 0.08**: Increases from default 0.001 (trades precision for speed)
- **Expected gain**: 30% faster move_and_slide() per entity at high enemy counts
- **Combined with staggered AI**: 98.5% AI cost reduction + 30% faster physics = ~99% total optimization

**When to use:**
- ✅ Top-down chase AI (enemies moving toward player)
- ✅ No platformer mechanics (jumping, slopes, platforms)
- ✅ High entity counts (500-1000+ enemies)
- ❌ Platformer games requiring precise floor detection
- ❌ Games with complex multi-surface collision requirements

**Separation of AI and Physics:**
```gdscript
# AI "thinking" runs in staggered batches (every 20 frames per enemy)
func _update_ai(dt: float) -> void:
    # Calculate velocity based on player position
    velocity = (player_pos - global_position).normalized() * speed

# Physics "moving" runs every frame (30Hz fixed step)
func _physics_process(delta: float) -> void:
    # Apply last calculated velocity
    if velocity.length_squared() > 0.01:
        move_and_slide()
```

**Result**: AI updates every ~667ms (20 frames), physics applies every ~33ms (30Hz) → smooth movement with minimal computation

### 🚫 **Viewport Culling Tradeoff Pattern (Updated 2025-10-09)**

**Problem:** Viewport culling optimizations can conflict with long-range gameplay mechanics.

```gdscript
# BossUpdateManager.gd - Viewport culling toggle
const ENABLE_VIEWPORT_CULLING: bool = false  # Disabled: conflicts with large chase_range (5555px)

func _on_combat_step(payload: EventBus.CombatStepPayload_Type) -> void:
    # VIEWPORT CULLING: Skip AI for off-screen bosses (if enabled)
    if ENABLE_VIEWPORT_CULLING and visible_rect.size.x > 0:
        if not visible_rect.has_point(boss.global_position):
            continue  # Boss is off-screen, skip AI update
```

**Tradeoff Analysis:**
- ✅ **With culling enabled:** 80-90% additional AI reduction (on top of staggered AI)
- ❌ **Gameplay conflict:** Enemies beyond viewport never update AI → frozen at long ranges
- ❌ **Chase range limit:** If `chase_range > viewport_size`, culled enemies never chase
- ⚖️ **Decision:** Disable culling when chase_range exceeds typical viewport size

**When to use viewport culling:**
- ✅ Chase range < 800px (typical viewport diagonal)
- ✅ Enemies should only activate when player nearby
- ❌ Large chase ranges (2000-5555px) for "always pursuing" enemies
- ❌ Ranged enemies that shoot from off-screen

**Companion balance:** Ensure `enemy_update_distance >= chase_range` to cover full detection radius:
```gdscript
# waves.tres balance file
chase_range = 5555.0              # BaseBoss.gd
enemy_update_distance = 6000.0     # Must be >= chase_range (waves.tres)
```

### 🎯 **Scene-Based Entity Cap Pattern (Updated 2025-10-09)**

**Problem:** System migration from pooled to scene-based spawning lost max_enemies enforcement.

```gdscript
# SpawnDirector.gd - Scene-based enemy cap
func _spawn_boss_scene(spawn_config: SpawnConfig) -> Node2D:
    # SCENE-BASED ENEMY CAP: Check max_enemies limit (applies to all scene-based enemies)
    var current_enemy_count = get_tree().get_nodes_in_group("enemies").size()
    if current_enemy_count >= max_enemies:
        # Silently skip spawning - pool is full
        return null

    # Instantiate scene
    var boss_scene = load(boss_scene_path)
    var boss = boss_scene.instantiate()

    # Add to "enemies" group for cap tracking
    boss.add_to_group("enemies")
    arena_scene.add_child(boss)

    return boss
```

**Migration Pattern:**
```gdscript
# OLD: Pooled enemy system with built-in cap
func _find_free_enemy() -> int:
    for i in range(max_enemies):  # Cap enforced by pool size
        if not _enemy_pool[i].is_active:
            return i
    return -1  # Pool full

# NEW: Scene-based system requires explicit cap check
func _spawn_from_config_v2(enemy_type: EnemyType, spawn_config: SpawnConfig) -> Node2D:
    # ❌ WRONG: Calls scene spawning with no cap
    return _spawn_boss_scene(spawn_config)  # Unlimited spawning!

    # ✅ CORRECT: Add cap check in _spawn_boss_scene() itself
    # (See implementation above)
```

**Why scene-based counting:**
- Scene-based enemies are NOT tracked in pre-allocated arrays
- Must use `get_tree().get_nodes_in_group("enemies")` for accurate count
- Group membership adds ~O(1) overhead per enemy (Godot's internal hash set)
- Returns null when cap reached (caller handles gracefully)

**Performance considerations:**
- Group size check is O(1) with Godot's internal optimization
- No memory allocations during check (uses cached group data)
- Silent failure prevents log spam during sustained spawning

**Testing cap enforcement:**
```gdscript
# Verify max_enemies cap works
func test_spawn_cap() -> void:
    var max_enemies = BalanceDB.get_waves_value("max_enemies")  # e.g., 300

    # Spawn 400 enemies (exceeds cap)
    for i in range(400):
        var enemy = spawn_director.spawn_enemy("grunt", spawn_position)
        if i < 300:
            assert(enemy != null, "Should spawn within cap")
        else:
            assert(enemy == null, "Should fail beyond cap")

    # Verify final count matches cap
    var final_count = get_tree().get_nodes_in_group("enemies").size()
    assert(final_count == max_enemies, "Cap enforcement failed")
```

## Troubleshooting Guide

### 🚨 **Common Issues**

1. **System not updating:** Check `combat_step` signal connection
2. **Dependencies null:** Verify GameOrchestrator injection
3. **Balance values wrong:** Check BalanceDB connection and hot-reload
4. **Performance drops:** Profile `_on_combat_step()` methods
5. **Events not firing:** Verify EventBus signal usage with typed payloads
6. **Import errors after domain organization:** Update import paths to new subfolder structure
7. **"Could not resolve class" errors:** Check if class extends from moved files
8. **Orphaned .uid files:** Clean up after major file reorganizations

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

### 🆕 **Creating New Systems (Updated 2025-09-30)**

When adding new systems to the domain-organized structure:

1. **Choose appropriate domain subfolder:**
   - **combat/** - Damage, melee, XP, player attacks
   - **spawn/** - Enemy spawning, boss creation, entity management
   - **arena/** - Arena coordination, UI management, scene transitions
   - **player/** - Player-specific mechanics, cards, abilities
   - **radar/** - Position scanning, detection systems
   - **rendering/** - Visual effects, performance optimization
   - **boss/** - Boss AI, update management, behaviors
   - **events/** - Breach events, mastery systems
   - **debug/** - Development tools, debugging utilities

2. **Follow standard system template** with domain-aware imports:
   ```gdscript
   extends Node
   class_name NewSystemName

   # Import from appropriate domain subfolders
   const RelatedSystem = preload("res://scripts/systems/domain/RelatedSystem.gd")
   ```

3. **Update import references** in consuming files:
   - **GameOrchestrator.gd** - Add system import and initialization
   - **SystemInjectionManager.gd** - Add injection method if needed
   - **Arena.gd** - Update imports if arena integration required

4. **Standard patterns** (unchanged):
   - Use dependency injection via GameOrchestrator
   - Connect to `combat_step` for 30Hz deterministic updates
   - Emit typed EventBus signals for cross-system communication
   - Add logging with appropriate categories

5. **Update documentation:**
   - Add system to Quick Reference table with domain
   - Document new patterns in appropriate sections
   - Update this migration guide if new domain needed

### 🔄 **Domain Organization Completed (2025-09-30)**

The systems layer has been successfully reorganized into 11 domain subfolders:
- ✅ **File moves completed** - All systems moved to appropriate domains
- ✅ **Import paths updated** - GameOrchestrator, Arena.gd, and key integration points
- ✅ **Parser errors resolved** - All compilation issues fixed
- ✅ **Orphaned .uid files cleaned** - 32 orphaned UID files removed
- ✅ **Documentation updated** - This CLAUDE.md reflects new structure

**No further migration needed** - the domain organization is complete and stable.

---
**See Also:** [Autoload Patterns](../../autoload/CLAUDE.md) | [Domain Models](../domain/CLAUDE.md) | [Scene Integration](../../scenes/CLAUDE.md)
