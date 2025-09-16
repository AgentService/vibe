# Monster Pack Zone System V1 - UPDATED STATUS

## Overview
Unified SpawnDirector system handling multiple spawn types with scene-based zone spawning:
1. **Pack Spawning (PreSpawn)**: Instant zone population with dynamic enemy groups (500px range)
2. **Auto Spawn (Waves)**: Continuous spawning using zone restrictions (300px range)
3. **Boss Spawning**: Existing boss spawn integration
4. **Future: Event Spawning**: Area2D trigger-based spawning

**Status Update**: ✅ COMPLETED - Scene-based zone spawning with proper geometry detection
**Current Progress**: Phase 1 ✅ COMPLETED - MapLevel system, pack spawning, debug interface, zone geometry fixes
**Next Priority**: Pre-spawn packs on map level progression + minimum distance constraints

## Current Implementation Status (✅ COMPLETED)

### 1. Unified SpawnDirector Architecture ✅
- **Single System**: SpawnDirector handles waves, packs, bosses via `_handle_*_spawning()` methods
- **MapLevel Scaling**: Global `MapLevel` autoload provides time-based difficulty progression (replaces scattered time calculations)
- **Scene-Based Zones**: Uses actual Area2D nodes from editor instead of hardcoded .tres config
- **Proximity Ranges**: 300px auto spawn, 500px pack spawn (meaningful proximity detection)

### 2. Zone-Based Spawning System ✅
- **Scene Integration**: Uses actual Area2D spawn zones from editor with CollisionShape2D detection
- **Geometry Support**: Proper radius detection for CircleShape2D and RectangleShape2D zones
- **Proximity Filtering**: Only spawn in zones within player range (300px auto, 500px pack)
- **Formation Support**: Circle, line, cluster patterns within zone boundaries
- **Debug Interface**: "Spawn Pack" button in debug panel for immediate testing

### 3. MapLevel Progression System ✅
- **Global Autoload**: `MapLevel` singleton tracks time-based difficulty progression
- **Consistent Scaling**: Replaces scattered time calculations across systems
- **Pack Size Scaling**: 15% larger packs per level via `get_pack_size_scaling()`
- **Integration**: SpawnDirector uses MapLevel instead of manual time tracking

## Next Phase: Enhanced Spawning Features

### Priority 1: Unified MapLevel Integration ⚠️
**Issue**: SpawnDirector uses scattered MapLevel calls instead of centralized level awareness
**Goal**: SpawnDirector receives level updates and propagates to all spawn systems

```gdscript
# Add to MapLevel.gd
signal map_level_increased(new_level: int, old_level: int)

# Enhanced SpawnDirector.gd - Level-aware spawning
var current_map_level: int = 1

func _on_map_level_increased(new_level: int, old_level: int):
    current_map_level = new_level
    Logger.info("SpawnDirector received level %d -> %d" % [old_level, new_level], "waves")

    # Trigger immediate pack spawn on level increase
    if new_level > 1:
        _spawn_level_progression_pack()

    # Update all spawn systems with new level info
    _update_spawn_scaling_for_level(new_level)

func _update_spawn_scaling_for_level(level: int):
    # Wave spawning gets more frequent/intense
    # Pack spawning gets larger groups
    # All systems use consistent level-based scaling
```

### Priority 2: Minimum Distance Constraints ⚠️
**Issue**: Enemies can spawn very close to player, causing unfair situations
**Goal**: Add minimum spawn distance (e.g., 150px) while respecting zone boundaries

```gdscript
# Enhanced proximity detection with min/max ranges
var min_spawn_distance: float = 150.0  # Don't spawn too close
var max_spawn_distance: float = 1000.0  # Don't spawn too far

# Filter zones that are within acceptable range
func filter_zones_by_safe_proximity(zones: Array[Area2D], player_pos: Vector2) -> Array[Area2D]
```

### Priority 3: MonsterPackResource System ⚠️
**Issue**: Pack composition is hardcoded in SpawnDirector
**Goal**: Data-driven pack definitions with inheritance support

```gdscript
# MonsterPackResource.gd - Base pack template
class_name MonsterPackResource
extends Resource

@export var pack_id: StringName = ""
@export var display_name: String = ""
@export var base_pack: MonsterPackResource  # Inheritance support
@export var formation: PackFormation = PackFormation.CIRCLE
@export var spawn_radius: float = 80.0
@export var monsters: Array[MonsterPackEntry] = []

# MonsterPackEntry.gd - Individual enemy in pack
class_name MonsterPackEntry
extends Resource

@export var enemy_type_id: StringName = ""
@export var count: int = 1
@export var level_modifier: float = 1.0  # 1.5 = 50% stronger
@export var size_modifier: float = 1.0   # 1.2 = 20% larger
```

**Pack Inheritance Examples**:
```tres
# base_swarm_pack.tres - Template for swarm packs
[resource]
pack_id = "base_swarm"
formation = 0  # CIRCLE
spawn_radius = 60.0
monsters = []  # Empty - to be overridden

# goblin_squad.tres - Inherits from base_swarm_pack
[resource]
base_pack = load("res://data/content/packs/base_swarm_pack.tres")
pack_id = "goblin_squad"
display_name = "Goblin Squad"
monsters = [
    MonsterPackEntry { enemy_type_id = "banana_lord", count = 1, level_modifier = 1.5 },
    MonsterPackEntry { enemy_type_id = "grunt_basic", count = 5 }
]
```

**Benefits**:
- Reusable pack templates across arenas
- Designer-friendly .tres file editing
- Hot-reloadable pack definitions (F5)
- Inheritance reduces duplication
- Debug panel can load/test specific packs

### Priority 4: Enemy Cleanup & Pool Management ⚠️
**Issue**: Enemies far from player may prevent new spawns when max_concurrent_enemies reached
**Goal**: Smart cleanup system that maintains gameplay quality while freeing spawn capacity

```gdscript
# Enemy cleanup considerations:
var cleanup_distance: float = 4000.0  # Far enough player won't notice
var cleanup_types: Array[String] = ["wave_spawned"]  # Only auto-spawned enemies
# NOT pack_spawned or boss_spawned - these are intentional encounters

func _cleanup_distant_enemies():
    # Only cleanup wave/auto spawned enemies beyond 4000px
    # Keep pack spawned enemies (they're intentional encounters)
    # Keep boss enemies (always important)
    # Maybe keep "elite" tier enemies even if wave spawned?
```

**Cleanup Strategy Options**:
1. **Distance-based**: Remove wave enemies >4000px from player
2. **Time-based**: Remove wave enemies after 5+ minutes if far away
3. **Tier-based**: Only cleanup "swarm" tier, keep "elite"+ even if distant
4. **Hybrid**: Distance + time + tier considerations
5. **Auto-chase consideration**: Wave enemies naturally migrate toward player

**Smart Cleanup Recommendations**:

**Option A: Conservative Distance Cleanup**
```gdscript
# Only cleanup wave enemies that are both distant AND old
func should_cleanup_enemy(enemy_data: Dictionary) -> bool:
    if enemy_data.spawn_type != "wave": return false
    if enemy_data.distance_to_player < 4000.0: return false
    if enemy_data.age_seconds < 300.0: return false  # 5 minutes
    return true
```

**Option B: Smart Chase-Aware Cleanup**
```gdscript
# Cleanup enemies that are "stuck" (not moving toward player)
func should_cleanup_enemy(enemy_data: Dictionary) -> bool:
    if enemy_data.spawn_type != "wave": return false
    if enemy_data.distance_to_player < 4000.0: return false

    # If enemy has auto-chase but hasn't moved closer in 2+ minutes, it's stuck
    if enemy_data.had_auto_chase and enemy_data.stuck_duration > 120.0:
        return true

    # Fallback: very old and very distant
    return enemy_data.age_seconds > 600.0  # 10 minutes
```

**Option C: No Cleanup (Auto-Chase Handles It)**
```gdscript
# Let auto-chase naturally bring enemies to player
# Only cleanup if performance becomes critical
# Pro: No artificial disappearing
# Con: Potential spawn blocking with max_concurrent_enemies = 400
```

**Key Insight**: If wave enemies have auto-chase, they should naturally migrate toward player over time, reducing the need for aggressive cleanup. Cleanup becomes mainly for "stuck" enemies (blocked by walls, caught in geometry, etc.)

**Recommended Approach**: Start with **Option C** (no cleanup) and monitor if spawn blocking occurs. If `max_concurrent_enemies = 400` proves problematic, implement **Option B** (stuck enemy detection).

### Priority 5: Event-Driven Spawning (Future) 🔮
**Goal**: Area2D trigger zones that spawn packs when player enters
**Implementation**: Trigger areas in arena scenes that call SpawnDirector

## Current Technical Implementation (✅ WORKING)

### Current Working Features ✅

**SpawnDirector System**:
- Auto spawn every 5 seconds in zones within 300px of player
- Pack spawn every 60 seconds in zones within 500px of player
- Pack size scaling based on MapLevel progression (15% per level)
- Scene-based zone detection using Area2D nodes from editor
- Proper zone geometry - enemies spawn within zone radius, not at center
- Formation patterns: circle, line, cluster within zones
- Debug panel "Spawn Pack" button for immediate testing

**MapLevel Progression**:
- Global autoload tracking time-based difficulty
- Automatic level increase every 60 seconds
- Consistent scaling across all spawn systems
- Replaces scattered time calculations

**Zone System**:
- Uses actual Area2D spawn zones from scene editor
- Supports CircleShape2D and RectangleShape2D collision detection
- Proximity filtering prevents off-screen spawning
- Shared helper methods in BaseArena for code reuse

#### Enhanced MapConfig with Base + Override Pattern
```gdscript
# scripts/resources/MapConfig.gd - Extended with scaling
@export_group("Base Spawn Scaling")
@export var base_spawn_scaling: Dictionary = {
    "time_scaling_rate": 0.1,        # 10% per minute base
    "wave_scaling_rate": 0.15,       # 15% per wave base
    "pack_base_size_min": 5,
    "pack_base_size_max": 10,
    "max_scaling_multiplier": 2.5,
    "pack_spawn_interval": 60.0      # Seconds between pack spawns
}

@export_group("Arena-Specific Scaling")
@export var arena_scaling_overrides: Dictionary = {}
# Example: {"time_scaling_rate": 0.2, "pack_base_size_min": 8}

@export_group("Proximity Ranges")
@export var auto_spawn_range: float = 800.0     # Auto spawn proximity
@export var pack_spawn_range: float = 1600.0    # Pack pre-spawn proximity

func get_effective_scaling() -> Dictionary:
    var effective = base_spawn_scaling.duplicate()
    for key in arena_scaling_overrides:
        effective[key] = arena_scaling_overrides[key]
    return effective
```

#### Dynamic Enemy Selection (No Static Files)
```gdscript
# In SpawnDirector - Dynamic pack composition
func _select_pack_enemies(pack_size: int) -> Array[EnemyType]:
    var available_enemies = EnemyRegistry.get_available_enemies()
    var selected_enemies: Array[EnemyType] = []

    # Use tier weights from MapConfig
    var tier_weights = {
        "swarm": 3.0,
        "regular": 2.0,
        "elite": 1.0,
        "boss": 0.2
    }

    for i in pack_size:
        var enemy_type = _select_weighted_enemy_type(available_enemies, tier_weights)
        selected_enemies.append(enemy_type)

    return selected_enemies

enum FormationType {
    RANDOM,      # Random positions within radius
    CIRCLE,      # Arranged in circle formation
    LINE,        # Arranged in line formation
    CLUSTER,     # Tight grouped formation
}
```

### Phase 2: Dynamic Zone Pre-Spawner System

#### ZoneDynamicSpawner.gd (System)
```gdscript
class_name ZoneDynamicSpawner
extends Node

signal pack_spawned(zone_id: StringName, enemy_count: int, positions: Array[Vector2])
signal pack_spawn_failed(zone_id: StringName, reason: String)

var _arena_reference: Node
var _spawn_director: SpawnDirector
var _pack_config: DynamicPackConfig

func _ready():
    _pack_config = load("res://data/balance/dynamic_pack_config.tres")

# Spawn dynamic pack using available enemies (no .tres files needed!)
func spawn_dynamic_pack_in_zone(zone_id: StringName, player_progression: int, survival_time: float) -> bool:
    var zone_data = _arena_reference.get_spawn_zone(zone_id)
    if zone_data.is_empty():
        pack_spawn_failed.emit(zone_id, "Zone not found")
        return false

    # Check if zone is in player range
    var player_pos = _get_player_position()
    var zone_pos = zone_data.get("position", Vector2.ZERO)
    var distance = player_pos.distance_to(zone_pos)

    if distance > _arena_reference.map_config.spawn_activation_range:
        pack_spawn_failed.emit(zone_id, "Zone out of player range")
        return false

    # Calculate dynamic pack size
    var pack_size = _pack_config.get_scaled_pack_size(player_progression, survival_time)

    # Select enemies dynamically from available types
    var selected_enemies = _select_pack_enemies(pack_size)

    # Generate formation positions
    var formation_positions = get_formation_positions(
        _pack_config.default_formation,
        pack_size,
        zone_pos,
        _pack_config.formation_radius
    )

    # Spawn each enemy via SpawnDirector
    for i in range(selected_enemies.size()):
        var enemy_type = selected_enemies[i]
        var spawn_pos = formation_positions[i] if i < formation_positions.size() else zone_pos
        _spawn_director.spawn_enemy_at_position(enemy_type, spawn_pos)

    pack_spawned.emit(zone_id, pack_size, formation_positions)
    return true

# Dynamic enemy selection from EnemyRegistry
func _select_pack_enemies(pack_size: int) -> Array[EnemyType]:
    var available_enemies = EnemyRegistry.get_available_enemies()
    var selected_enemies: Array[EnemyType] = []

    for i in pack_size:
        var enemy_type = _select_weighted_enemy_type(available_enemies)
        selected_enemies.append(enemy_type)

    return selected_enemies

func _select_weighted_enemy_type(available_enemies: Array[EnemyType]) -> EnemyType:
    # Use tier weights from config to select enemy types
    var weighted_enemies: Array[EnemyType] = []

    for enemy in available_enemies:
        var tier = enemy.render_tier
        var weight = _pack_config.enemy_tier_weights.get(tier, 1.0)
        for w in range(int(weight * 10)):  # Convert weight to repetitions
            weighted_enemies.append(enemy)

    return weighted_enemies[randi() % weighted_enemies.size()]

# Spawn pack in any zone within player range
func spawn_dynamic_pack_near_player(player_progression: int, survival_time: float) -> bool:
    var player_pos = _get_player_position()
    var available_zones = _arena_reference.get_zones_in_range(player_pos, _arena_reference.map_config.spawn_activation_range)

    if available_zones.is_empty():
        pack_spawn_failed.emit("", "No zones in player range")
        return false

    var selected_zone = available_zones[randi() % available_zones.size()]
    var zone_id = selected_zone.get("name", "unknown")

    return spawn_dynamic_pack_in_zone(zone_id, player_progression, survival_time)
```

### Phase 3: Range-Based Auto Spawn Integration

The auto spawn system needs **player proximity detection** to only spawn in zones near the player.

#### Current Implementation Status
```gdscript
# SpawnDirector._spawn_enemy_v2() already calls:
var spawn_pos = current_scene.get_random_spawn_position()

# UnderworldArena.get_random_spawn_position() already uses zones:
func get_random_spawn_position() -> Vector2:
    var selected_zone_data = get_weighted_spawn_zone()
    # ... spawn within selected zone
```

**Current Issue**: Auto spawn uses ALL zones regardless of player position ❌
**Required Enhancement**: Only spawn in zones within player range ⚠️

#### Range-Based Spawning Enhancement
```gdscript
# Enhanced MapConfig with range detection
@export var spawn_activation_range: float = 800.0  # Only spawn in zones within 800px of player

# Enhanced Arena.get_random_spawn_position() with range checking:
func get_random_spawn_position() -> Vector2:
    var player_pos = _get_player_position()
    var available_zones = _get_zones_in_range(player_pos, spawn_activation_range)

    if available_zones.is_empty():
        return Vector2.ZERO  # No spawning if player not near any zones

    var selected_zone = _select_weighted_zone(available_zones)
    return _random_position_in_zone(selected_zone)
```

**Result**: Auto spawn only happens near player! ✅

## 🎮 Proximity-Based Spawning Options

### Industry Standard Approaches

**★ Insight ─────────────────────────────────────**
- **Distance-Based**: Simple radius checks (Diablo, Path of Exile)
- **Area-Based**: Invisible trigger zones (WoW, MMORPGs)
- **Frustum-Based**: Camera/viewport awareness (Vampire Survivors)
- **Hybrid Systems**: Combine multiple approaches for best results
**─────────────────────────────────────────────────**

### Option 1: Simple Distance Check (Recommended for MVP)
```gdscript
# Pros: Simple, performant, predictable
# Cons: Circular areas only, no complex shapes
func is_zone_in_spawn_range(zone_pos: Vector2, player_pos: Vector2, range: float) -> bool:
    return zone_pos.distance_to(player_pos) <= range

# Usage: Check each zone against player position
var spawn_range = 800.0  # Pixels
for zone in spawn_zones:
    if is_zone_in_spawn_range(zone.position, player.global_position, spawn_range):
        # This zone can spawn enemies
```

**Games using this**: Diablo 3, Path of Exile, most ARPGs

### Option 2: Area2D Trigger Zones (Best for Complex Shapes)
```gdscript
# Pros: Supports any shape, visual editing, collision detection
# Cons: More setup, slightly more overhead
# Create Area2D nodes around player with CollisionShape2D

extends Area2D  # PlayerSpawnActivationArea
@export var activation_radius: float = 800.0

func _ready():
    var shape = CircleShape2D.new()
    shape.radius = activation_radius
    $CollisionShape2D.shape = shape

    area_entered.connect(_on_spawn_zone_entered)
    area_exited.connect(_on_spawn_zone_exited)

func _on_spawn_zone_entered(area: Area2D):
    if area.is_in_group("spawn_zones"):
        # Enable spawning in this zone
        SpawnManager.enable_zone(area.name)

func _on_spawn_zone_exited(area: Area2D):
    if area.is_in_group("spawn_zones"):
        # Disable spawning in this zone
        SpawnManager.disable_zone(area.name)
```

**Games using this**: World of Warcraft, MMORPGs with complex spawn areas

### Option 3: Viewport/Frustum-Based (Performance Focused)
```gdscript
# Pros: Only spawn what player can potentially see, best performance
# Cons: Complex implementation, edge cases near screen borders
func is_zone_in_viewport_range(zone_pos: Vector2, camera: Camera2D, margin: float = 200.0) -> bool:
    var viewport_rect = camera.get_viewport_rect()
    var camera_pos = camera.global_position
    var zoom = camera.zoom

    # Calculate screen bounds with margin
    var screen_size = viewport_rect.size / zoom
    var screen_rect = Rect2(
        camera_pos - screen_size / 2 - Vector2(margin, margin),
        screen_size + Vector2(margin * 2, margin * 2)
    )

    return screen_rect.has_point(zone_pos)
```

**Games using this**: Vampire Survivors, Risk of Rain 2

### Option 4: Grid-Based Activation (MMO Style)
```gdscript
# Pros: Scales to massive worlds, predictable chunks
# Cons: More complex, best for large open worlds
class_name SpawnGrid

var grid_size: int = 1000  # 1000x1000 pixel chunks
var active_chunks: Dictionary = {}

func get_chunk_id(world_pos: Vector2) -> Vector2i:
    return Vector2i(int(world_pos.x / grid_size), int(world_pos.y / grid_size))

func update_active_chunks(player_pos: Vector2, activation_radius: int = 2):
    var player_chunk = get_chunk_id(player_pos)
    var new_active_chunks: Dictionary = {}

    # Activate chunks in radius around player
    for x in range(-activation_radius, activation_radius + 1):
        for y in range(-activation_radius, activation_radius + 1):
            var chunk_id = player_chunk + Vector2i(x, y)
            new_active_chunks[chunk_id] = true

            if not active_chunks.has(chunk_id):
                _activate_chunk(chunk_id)

    # Deactivate chunks no longer in range
    for chunk_id in active_chunks:
        if not new_active_chunks.has(chunk_id):
            _deactivate_chunk(chunk_id)

    active_chunks = new_active_chunks
```

**Games using this**: Minecraft, most MMORPGs, open-world games

### Recommended Implementation (Hybrid Approach)

**For Vibe Game - Best Practice Combination:**

```gdscript
# SpawnRangeManager.gd - Combines distance + frustum for optimal results
class_name SpawnRangeManager
extends Node

@export var base_activation_range: float = 800.0
@export var viewport_margin: float = 200.0
@export var use_viewport_culling: bool = true

func get_active_spawn_zones(player_pos: Vector2, camera: Camera2D, all_zones: Array[Dictionary]) -> Array[Dictionary]:
    var active_zones: Array[Dictionary] = []

    for zone in all_zones:
        if is_zone_active(zone, player_pos, camera):
            active_zones.append(zone)

    return active_zones

func is_zone_active(zone: Dictionary, player_pos: Vector2, camera: Camera2D) -> bool:
    var zone_pos = zone.get("position", Vector2.ZERO)

    # Primary check: Distance-based activation
    var distance = zone_pos.distance_to(player_pos)
    if distance > base_activation_range:
        return false

    # Secondary check: Viewport awareness (optional optimization)
    if use_viewport_culling:
        if not is_zone_in_viewport_range(zone_pos, camera, viewport_margin):
            return false

    return true

func is_zone_in_viewport_range(zone_pos: Vector2, camera: Camera2D, margin: float) -> bool:
    var viewport_rect = camera.get_viewport_rect()
    var camera_pos = camera.global_position
    var zoom = camera.zoom.x  # Assume uniform zoom

    var screen_size = viewport_rect.size / zoom
    var screen_rect = Rect2(
        camera_pos - screen_size / 2 - Vector2(margin, margin),
        screen_size + Vector2(margin * 2, margin * 2)
    )

    return screen_rect.has_point(zone_pos)
```

### Performance Comparison

| Method | Setup Cost | Runtime Cost | Flexibility | Best For |
|--------|------------|--------------|-------------|----------|
| Distance Check | Low | Very Low | Medium | Small-medium arenas |
| Area2D Triggers | Medium | Low | High | Complex shaped areas |
| Viewport-Based | High | Medium | Low | Performance-critical |
| Grid-Based | High | Low | High | Large open worlds |
| **Hybrid (Recommended)** | Medium | Low | High | **Most games** |

### Integration with Your System

**Recommended for Vibe Game:**
1. **Start with Distance Check** (simple, immediate implementation)
2. **Add Viewport Culling** when performance becomes critical
3. **Consider Area2D Triggers** for special zones with complex shapes

```gdscript
# Enhanced MapConfig with proximity settings
@export_group("Spawn Activation")
@export var spawn_activation_range: float = 800.0
@export var use_viewport_culling: bool = false  # Disable by default
@export var viewport_margin: float = 200.0
@export var activation_method: ActivationMethod = ActivationMethod.DISTANCE

enum ActivationMethod {
    DISTANCE,           # Simple radius check
    VIEWPORT,          # Camera frustum + margin
    AREA_TRIGGERS,     # Area2D collision detection
    HYBRID             # Distance + viewport
}
```

This gives you the **flexibility to tune performance vs complexity** based on your arena size and enemy count needs!

### Phase 4: Event Integration

#### Area-Based Pre-Spawn Triggers
```gdscript
# Add to arena scenes
extends Area2D

@export var trigger_pack_ids: Array[StringName] = []
@export var spawn_zone_id: StringName = ""
@export var trigger_once: bool = true

var _triggered: bool = false

func _on_body_entered(body):
    if body.has_method("is_player") and not _triggered:
        if trigger_once:
            _triggered = true
        ZonePreSpawner.spawn_pack_in_zone(pack_resource, spawn_zone_id)
```

## Implementation Plan

### Small Commit Strategy

**Commit 1**: MonsterPackResource foundation
- Create MonsterPackResource.gd and MonsterPackEntry.gd
- Add example pack .tres files (goblin_patrol.tres, archer_squad.tres)
- Add to data/content/monster-packs/

**Commit 2**: ZonePreSpawner system
- Create ZonePreSpawner.gd system
- Implement spawn_pack_in_zone() method
- Add formation generation (RANDOM, CIRCLE, LINE)
- Add to scripts/systems/

**Commit 3**: Arena integration
- Add ZonePreSpawner to Arena initialization
- Connect to SpawnDirector for enemy spawning
- Add debug commands (F12 panel spawn pack buttons)

**Commit 4**: Event triggers
- Create TriggerArea.gd for area-based pack spawning
- Add example trigger areas to UnderworldArena.tscn
- Test player entering zones and spawning packs

**Commit 5**: Enhanced formations
- Add CLUSTER and SCATTERED formation types
- Add formation debug visualization
- Add pack validation and error handling

## Data Examples

### goblin_patrol.tres
```tres
[gd_resource type="Resource" script_class="MonsterPackResource"]

[resource]
script = ExtResource("MonsterPackResource.gd")
pack_id = "goblin_patrol"
display_name = "Goblin Patrol"
formation = 2  # CIRCLE
spawn_radius = 80.0
level_range = Vector2i(1, 5)
monsters = [
    # 3 basic goblins
    MonsterPackEntry { enemy_type_id = "grunt_basic", count = 3 },
    # 1 goblin leader
    MonsterPackEntry { enemy_type_id = "grunt_basic", count = 1, level_modifier = 1.5, size_modifier = 1.2 }
]
```

### archer_ambush.tres
```tres
[resource]
script = ExtResource("MonsterPackResource.gd")
pack_id = "archer_ambush"
display_name = "Archer Ambush"
formation = 3  # LINE
spawn_radius = 120.0
monsters = [
    MonsterPackEntry { enemy_type_id = "archer_skeleton", count = 4 }
]
```

## API Usage Examples

### Manual Pack Spawning
```gdscript
# Spawn specific pack in specific zone
var pack = load("res://data/content/monster-packs/goblin_patrol.tres")
ZonePreSpawner.spawn_pack_in_zone(pack, "north_cavern")

# Spawn pack at player position + offset
var spawn_pos = player.global_position + Vector2(200, 0)
ZonePreSpawner.spawn_pack_at_position(pack, spawn_pos)
```

### Event-Driven Spawning
```gdscript
# In arena _ready()
EventBus.player_entered_zone.connect(_on_player_entered_zone)

func _on_player_entered_zone(zone_id: StringName):
    match zone_id:
        "north_cavern":
            var pack = load("res://data/content/monster-packs/goblin_patrol.tres")
            ZonePreSpawner.spawn_pack_in_zone(pack, zone_id)
        "south_cavern":
            var pack = load("res://data/content/monster-packs/archer_ambush.tres")
            ZonePreSpawner.spawn_pack_in_zone(pack, zone_id)
```

## Testing Strategy

### Unit Tests
- `test_monster_pack_validation.gd`: Validate pack resources
- `test_formation_generation.gd`: Test formation position algorithms
- `test_zone_spawning.gd`: Verify spawning in correct zones

### Integration Tests
- `test_pack_spawn_integration.gd`: End-to-end pack spawning
- `test_trigger_areas.gd`: Area-based trigger functionality
- `test_auto_spawn_zones.gd`: Verify auto spawn uses zones

### Manual Testing
- F12 debug panel: "Spawn Pack" dropdown with all packs
- Area trigger testing: Walk into zones, verify packs spawn
- Formation testing: Visual verification of formation patterns

## Future Enhancements

### Phase 6: Advanced Features (Post-MVP)
- **Pack Scripting**: Lua/GDScript for complex pack behaviors
- **Conditional Spawning**: Time of day, player level, previous kills
- **Pack Persistence**: Save spawned pack state across sessions
- **Dynamic Packs**: Generate packs based on player power level
- **Pack Interactions**: Packs that react to other nearby packs

### Phase 7: Performance Optimizations
- **Pack Pooling**: Reuse pack instances for performance
- **Streaming**: Load/unload packs based on player proximity
- **LOD System**: Simplify distant pack AI/rendering

## Success Metrics

### Phase 1-5 Complete When:
1. ✅ Can define monster packs in .tres files
2. ✅ Can spawn packs manually via code/debug panel
3. ✅ Can spawn packs via area triggers when player enters zones
4. ✅ Packs spawn in correct zones with proper formations
5. ✅ Auto spawn continues working in zones (already working)
6. ✅ System is performant with 5+ simultaneous packs
7. ✅ Error handling gracefully handles invalid packs/zones

### Integration Requirements
- **Zero Breaking Changes**: Existing auto spawn continues working
- **Data-Driven**: All pack configuration via .tres files
- **MCP Compatible**: Can edit packs via Godot MCP tools
- **Hot-Reload**: F5 reloads pack definitions
- **Debug Friendly**: F12 panel for manual pack testing