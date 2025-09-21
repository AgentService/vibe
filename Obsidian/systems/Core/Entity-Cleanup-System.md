# Entity Cleanup System

## Overview

The Entity Cleanup System provides comprehensive, production-ready entity and resource management across different game scenarios. Built around `EntityClearingService` and integrated with `SessionManager`, it ensures proper cleanup without memory leaks or dangling references.

## Architecture Components

### EntityClearingService (Production Autoload)

**Location**: `res://autoload/EntityClearingService.gd`
**Purpose**: Centralized, safe entity clearing for all production scenarios

```gdscript
# Core cleanup methods
EntityClearingService.clear_all_world_objects()    # Complete reset
EntityClearingService.clear_all_entities()         # Entities only (clean)
EntityClearingService.clear_transient_objects()    # XP orbs, items only
```

### Integration Points

- **SessionManager**: Orchestrates multi-phase cleanup sequences
- **WaveDirector**: MultiMesh pool resets for efficient enemy clearing
- **EntityTracker/DamageService**: Clean registration removal
- **Scene Groups**: Organized entity categorization for selective clearing

## Entity Classification & Clearing

### Entity Categories

#### 1. Pooled Entities (MultiMesh)
- **Examples**: Basic enemies, projectiles
- **Storage**: MultiMesh pools managed by WaveDirector
- **Clearing**: `WaveDirector.reset()` - instant pool clearing
- **Count**: ~50-100 entities per pool

```gdscript
# Efficient pool clearing via WaveDirector
var wave_directors := get_tree().get_nodes_in_group("wave_directors")
for wave_director in wave_directors:
    wave_director.reset()  # Clears entire MultiMesh pool instantly
```

#### 2. Scene-Based Entities (Individual Nodes)
- **Examples**: Bosses, special enemies, interactive objects
- **Storage**: Individual Node2D instances in scene tree
- **Clearing**: Group-based `queue_free()` calls
- **Groups**: `"enemies"`, `"arena_owned"`

```gdscript
# Clear individual scene entities
var enemies := get_tree().get_nodes_in_group("enemies")
for enemy in enemies:
    if is_instance_valid(enemy):
        enemy.queue_free()
```

#### 3. Transient Objects
- **Examples**: XP orbs, dropped items, particle effects
- **Storage**: Scene nodes marked with `"transient"` group
- **Clearing**: Selective group clearing
- **Lifecycle**: Short-lived, frequent creation/deletion

```gdscript
# Clear transient objects only
var transients := get_tree().get_nodes_in_group("transient")
for obj in transients:
    obj.queue_free()
```

#### 4. Tracked Entities
- **Examples**: All entities registered with EntityTracker/DamageService
- **Storage**: Dictionary-based tracking systems
- **Clearing**: Clean unregistration (no death events)
- **Purpose**: Maintain system integrity

```gdscript
# Clean tracking removal
var all_entities := EntityTracker.get_alive_entities()
for entity_id in all_entities:
    if entity_type != "player":  # Preserve player
        EntityTracker.unregister_entity(entity_id)
        DamageService.unregister_entity(entity_id)
```

## Cleanup Strategies by Scenario

### 1. Debug Reset - Complete Clean Slate
```gdscript
func reset_debug():
    # Full world reset - nothing preserved
    EntityClearingService.clear_all_world_objects()
    
# Results:
# ✅ All entities cleared
# ✅ All transients cleared  
# ✅ All tracking cleared
# ✅ No XP orbs spawned (clean removal)
```

### 2. Player Death - Preserve Enemies for Stats
```gdscript
func reset_player_death():
    # Preserve enemies for results screen, clear XP/items only
    EntityClearingService.clear_transient_objects()  # XP orbs, items
    
    # NOTE: Enemies preserved for death statistics display
    
# Results:
# ❌ Enemies preserved (for results screen)
# ✅ XP orbs cleared
# ✅ Items cleared
# ✅ Player reset but tracking maintained
```

**Special Handling**: Player death scenario detected via health check:
```gdscript
func _is_player_death_scenario() -> bool:
    if not PlayerState.has_player_reference():
        return false
    
    var player = PlayerState._player_ref
    var current_hp = player.get_health()
    return current_hp <= 0
```

### 3. Map Transition - Selective Preservation
```gdscript
func reset_map_transition(from_map: String, to_map: String):
    # Clear map-specific entities, preserve progression
    EntityClearingService.clear_all_world_objects()
    
    # Progression preserved via context
    context["preserve_progression"] = true
    
# Results:
# ✅ All entities cleared
# ✅ Player progression preserved
# ✅ Character data maintained
# ✅ Clean transition between maps
```

### 4. Hideout Return - Character Preservation
```gdscript
func reset_hideout_return():
    # Full entity clear but preserve character state
    EntityClearingService.clear_all_world_objects()
    
    context["preserve_character"] = true
    
# Results:
# ✅ All arena entities cleared
# ✅ Character stats preserved
# ✅ Equipment maintained
# ✅ Ready for hideout state
```

## Multi-Phase Clearing Process

### Phase 1: Entity Clearing (Context-Aware)
```gdscript
func _clear_entities(reason: ResetReason, context: Dictionary) -> void:
    if _is_player_death_scenario():
        # Preserve enemies for results display
        EntityClearingService.clear_transient_objects()
    else:
        # Full clear for other scenarios
        EntityClearingService.clear_all_world_objects()
```

### Phase 2: Systems Reset
```gdscript
func _reset_systems(reason: ResetReason, context: Dictionary) -> void:
    # Reset WaveDirector pools
    wave_director.reset()
    
    # Reset progression (conditionally)
    if not context.get("preserve_progression", false):
        PlayerProgression.reset_session()
```

### Phase 3: Player State Reset & Registration
```gdscript
func _reset_player_state(reason: ResetReason, context: Dictionary) -> void:
    # Reset player position, health, velocity
    player.global_position = spawn_pos
    player.reset_health()
    player.velocity = Vector2.ZERO
    
    # CRITICAL: Re-register with damage systems
    player._register_with_damage_system()
    
    # Validate registration with retry logic
    for retry in range(3):
        if player.is_registered_with_damage_system():
            Logger.info("Player registration validated - SUCCESS", "session")
            break
        else:
            Logger.warn("Player registration failed - retry %d/3" % (retry + 1), "session")
            player._register_with_damage_system()
            await get_tree().process_frame
```

### Phase 4: Temporary Effects Clearing
```gdscript
func _clear_temporary_effects() -> void:
    # Clear MultiMesh projectiles
    var multimesh_projectiles = _find_multimesh_projectiles()
    for mm_node in multimesh_projectiles:
        mm_node.multimesh.instance_count = 0
    
    # Clear temporary melee effects (preserve permanent nodes like MeleeCone)
    var melee_effects = _find_melee_effects()
    for child in melee_effects.get_children():
        if _is_temporary_effect_node(child):
            child.queue_free()  # Only clear temporary effects
```

## Advanced Clearing Techniques

### Smart Node Preservation
```gdscript
func _is_temporary_effect_node(node: Node) -> bool:
    var node_name = node.name.to_lower()
    
    # Preserve permanent visual nodes
    if node_name.contains("meleecone") or node_name.contains("cone"):
        return false  # Keep permanent visual elements
    
    # Clear temporary effects
    if node_name.contains("projectile") or node_name.contains("particle"):
        return true
    
    return false  # Default: preserve unless explicitly temporary
```

### MultiMesh Pool Management
```gdscript
func _find_multimesh_projectiles(node: Node) -> Array[MultiMeshInstance2D]:
    var result: Array[MultiMeshInstance2D] = []
    
    if node is MultiMeshInstance2D:
        var mm_node = node as MultiMeshInstance2D
        if mm_node.name.contains("projectile") or mm_node.name.contains("MM_"):
            result.append(mm_node)
    
    # Recursive search through scene tree
    for child in node.get_children():
        result.append_array(_find_multimesh_projectiles(child))
    
    return result
```

### Clean Tracking Removal
```gdscript
func _clean_entity_tracking() -> void:
    """Remove entities from tracking without triggering death events"""
    var all_entities := EntityTracker.get_alive_entities()
    
    for entity_id in all_entities:
        var entity_data := EntityTracker.get_entity(entity_id)
        var entity_type = entity_data.get("type", "unknown")
        
        # Skip player entities
        if entity_type == "player":
            continue
        
        # Clean removal - no death events, no XP spawning
        EntityTracker.unregister_entity(entity_id)
        if DamageService.is_entity_alive(entity_id):
            DamageService.unregister_entity(entity_id)
```

## Integration with Scene Groups

### Group-Based Organization
```gdscript
# Enemies group - bosses, special enemies
get_tree().add_to_group("enemies")

# Arena owned - projectiles, temporary objects
get_tree().add_to_group("arena_owned") 

# Transient - XP orbs, items, short-lived effects
get_tree().add_to_group("transient")

# Wave directors - pool management systems
get_tree().add_to_group("wave_directors")
```

### Selective Group Clearing
```gdscript
# Clear specific groups based on scenario
var groups_to_clear = []

match scenario:
    "debug_reset":
        groups_to_clear = ["enemies", "arena_owned", "transient"]
    "player_death":
        groups_to_clear = ["transient"]  # Preserve enemies
    "map_transition":
        groups_to_clear = ["enemies", "arena_owned", "transient"]

for group_name in groups_to_clear:
    var nodes = get_tree().get_nodes_in_group(group_name)
    for node in nodes:
        if is_instance_valid(node):
            node.queue_free()
```

## Performance Considerations

### Batch Operations
```gdscript
# ✅ Efficient - Single WaveDirector reset clears entire pool
wave_director.reset()  # ~50 entities cleared instantly

# ❌ Inefficient - Individual entity removal
for enemy in enemy_list:
    enemy.queue_free()  # 50 separate operations
```

### Memory Management
```gdscript
# MultiMesh instance_count reset (instant)
multimesh.instance_count = 0

# vs queue_free() (deferred to end of frame)
node.queue_free()

# Wait for cleanup to complete
await get_tree().process_frame
await get_tree().process_frame  # Extra frame for safety
```

### Validation & Monitoring
```gdscript
# Track cleanup performance
var cleanup_start = Time.get_ticks_msec()
EntityClearingService.clear_all_world_objects()
var cleanup_duration = Time.get_ticks_msec() - cleanup_start

Logger.info("Cleanup completed in %.1fms" % cleanup_duration, "performance")
# Typical: 10-50ms for full world reset
```

## Error Handling & Recovery

### Registration Validation
```gdscript
func _validate_player_registration_post_reset() -> void:
    var is_registered = player.is_registered_with_damage_system()
    
    if not is_registered:
        Logger.error("CRITICAL: Player not registered after reset", "session")
        
        # Emergency re-registration
        if player.has_method("ensure_damage_registration"):
            var success = player.ensure_damage_registration()
            Logger.info("Emergency registration result: %s" % success, "session")
```

### Invalid Node Handling
```gdscript
func _safe_node_clearing(nodes: Array) -> void:
    for node in nodes:
        if is_instance_valid(node):
            node.queue_free()
        else:
            Logger.debug("Skipping invalid node during cleanup", "session")
```

### Cleanup Verification
```gdscript
func _verify_cleanup_success() -> void:
    var remaining_enemies = get_tree().get_nodes_in_group("enemies").size()
    var remaining_transients = get_tree().get_nodes_in_group("transient").size()
    
    if remaining_enemies > 0 or remaining_transients > 0:
        Logger.warn("Cleanup incomplete - enemies: %d, transients: %d" % [remaining_enemies, remaining_transients], "session")
```

## Best Practices

### 1. Use Context-Aware Clearing
```gdscript
# ✅ Different clearing for different scenarios
if scenario == "player_death":
    EntityClearingService.clear_transient_objects()  # Preserve enemies
else:
    EntityClearingService.clear_all_world_objects()  # Full clear
```

### 2. Always Validate Critical Registrations
```gdscript
# ✅ Verify player remains tracked after cleanup
if not player.is_registered_with_damage_system():
    Logger.error("CRITICAL: Player registration lost!")
    player.ensure_damage_registration()
```

### 3. Use Group-Based Organization
```gdscript
# ✅ Organize entities into logical groups
_ready():
    add_to_group("enemies")      # For combat entities
    add_to_group("transient")    # For temporary objects
    add_to_group("arena_owned")  # For arena-specific content
```

### 4. Handle Frame Delays
```gdscript
# ✅ Wait for cleanup to complete
EntityClearingService.clear_all_world_objects()
await get_tree().process_frame
await get_tree().process_frame  # Safety frame
# Now safe to proceed with next phase
```

## Console Commands & Debugging

### Manual Cleanup Commands
```gdscript
# Console commands for testing
EntityClearingService.clear_all_entities()
EntityClearingService.clear_transient_objects()
EntityClearingService.clear_all_world_objects()
```

### Cleanup Logging
```gdscript
# Automatic logging for all operations
Logger.info("EntityClearingService: Starting clean entity clear", "system")
Logger.debug("Cleared MultiMesh projectiles: ProjectileMM", "system")
Logger.info("EntityClearingService: Cleared 15 transient objects", "system")
```

### Performance Monitoring
```gdscript
# Track cleanup metrics
session_reset_completed.emit(reason, duration_ms)
# Typical duration: 10-50ms for full world reset
# Duration > 100ms indicates potential performance issues
```

## Related Systems

- **[[Scene-Transition-System]]**: State management and cleanup orchestration
- **[[Performance-Optimization-System]]**: MultiMesh pool management
- **[[EventBus-System]]**: Cleanup event communication
- **[[Enemy-System-Architecture]]**: Entity lifecycle management