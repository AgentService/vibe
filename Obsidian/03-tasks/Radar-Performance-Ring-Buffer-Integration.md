# Radar Performance Ring Buffer Integration

**Status:** 🔄 In Progress (September 2025)  
**Priority:** High  
**Estimated Effort:** 2-3 hours  
**Dependencies:** Performance Optimization System (completed)

## 🎯 Problem Statement

Radar system experiences frame drops at 500+ entities due to inefficient EntityTracker scanning and missing ring buffer optimizations.

### Current Bottleneck
```gdscript
# RadarSystem._update_and_emit_radar_data() at 60Hz
var enemy_ids = EntityTracker.get_entities_by_type("enemy")     # O(N) iteration through ALL entities
var boss_ids = EntityTracker.get_entities_by_type("boss")      # O(N) iteration through ALL entities

# EntityTracker.get_entities_by_type() - PERFORMANCE KILLER
func get_entities_by_type(entity_type: String) -> Array[String]:
    var result: Array[String] = []
    for id in _entities.keys():                                 # Iterates ALL entities (500+ enemies + 500+ bosses)
        var entity_data = _entities[id]                         # Dictionary lookup per entity
        if entity_data.get("type", "") == entity_type and entity_data.get("alive", false):
            result.append(id)                                   # Array append per matching entity
    return result
```

**Performance Impact at 500 enemies + 500 bosses:**
- 60Hz radar updates × 1000 total entities = 60,000 iterations/second
- 2 type queries per frame (enemy + boss) = 120,000 dictionary lookups/second  
- Array allocations and string comparisons every radar update
- O(N) scan complexity instead of O(1) cached lookups

## 🏗️ Solution: Cached Entity Lists + Ring Buffer Integration

### Architecture Integration
Extend the proven ring buffer infrastructure from the enemy performance optimization:
- **RadarUpdateManager**: Single combat step connection, batched entity caching
- **Type-Indexed Cache**: Pre-computed entity lists by type (enemies, bosses) 
- **Ring Buffer Integration**: Reuse existing `RingBufferUtil`, `ObjectPoolUtil`, `PayloadReset`
- **30Hz Decimation**: Match combat step frequency instead of 60Hz visual updates

### Implementation Plan

#### Phase 1: Create RadarUpdateManager System
```gdscript
class_name RadarUpdateManager
extends Node

# Reuse proven infrastructure from enemy optimization
const RingBufferUtil = preload("res://scripts/utils/RingBuffer.gd")
const ObjectPoolUtil = preload("res://scripts/utils/ObjectPool.gd") 
const PayloadResetUtil = preload("res://scripts/utils/PayloadReset.gd")

# Cached entity lists by type (updated at 30Hz instead of scanned at 60Hz)
var _cached_enemy_entities: Array[EventBus.RadarEntity] = []
var _cached_boss_entities: Array[EventBus.RadarEntity] = []
var _player_position: Vector2 = Vector2.ZERO

# Ring buffer infrastructure for batched updates
var _radar_update_queue: RingBufferUtil
var _radar_payload_pool: ObjectPoolUtil
var _cache_dirty: bool = true

func _ready():
    # Single connection to 30Hz combat step instead of 60Hz _process
    EventBus.combat_step.connect(_on_combat_step)
    
    # Listen to entity registration changes for cache invalidation
    if EntityTracker:
        EntityTracker.entity_registered.connect(_on_entity_registered)
        EntityTracker.entity_unregistered.connect(_on_entity_unregistered)
    
    # Initialize ring buffer infrastructure
    _radar_update_queue = RingBufferUtil.new(1000)
    _radar_payload_pool = ObjectPoolUtil.new(PayloadResetUtil.create_radar_update_payload, PayloadResetUtil.clear_radar_update_payload)
```

#### Phase 2: Cached Entity Type Lookups
```gdscript
# Replace O(N) EntityTracker.get_entities_by_type() scans with O(1) cached lookups
func _rebuild_entity_cache() -> void:
    if not _cache_dirty:
        return
        
    # Clear existing cache
    _cached_enemy_entities.clear()
    _cached_boss_entities.clear()
    
    # Single iteration through EntityTracker instead of 2× type-based scans
    var all_entities = EntityTracker.get_all_alive_entities_optimized()  # New method needed
    for entity_data in all_entities:
        var radar_entity = EventBus.RadarEntity.new(entity_data.pos, entity_data.type)
        
        match entity_data.type:
            "enemy":
                _cached_enemy_entities.append(radar_entity)
            "boss":
                _cached_boss_entities.append(radar_entity)
    
    _cache_dirty = false
    Logger.debug("RadarUpdateManager: Rebuilt cache - %d enemies, %d bosses" % [_cached_enemy_entities.size(), _cached_boss_entities.size()], "radar")

# Cache invalidation on entity lifecycle events
func _on_entity_registered(entity_id: String, entity_type: String) -> void:
    _cache_dirty = true

func _on_entity_unregistered(entity_id: String) -> void:
    _cache_dirty = true
```

#### Phase 3: EntityTracker Optimization
```gdscript
# Add to EntityTracker.gd - Type-indexed storage for O(1) lookups
var _entities_by_type: Dictionary = {}  # "enemy" -> Array[String], "boss" -> Array[String]

func register_entity(id: String, data: Dictionary) -> void:
    _entities[id] = data
    _update_spatial_index(id, data.get("pos", Vector2.ZERO))
    
    # NEW: Maintain type index for O(1) lookups
    var entity_type = data.get("type", "unknown")
    if not _entities_by_type.has(entity_type):
        _entities_by_type[entity_type] = []
    _entities_by_type[entity_type].append(id)
    
    entity_registered.emit(id, entity_type)

func unregister_entity(id: String) -> void:
    if _entities.has(id):
        var entity_data = _entities[id]
        var entity_type = entity_data.get("type", "unknown")
        
        # Remove from type index
        if _entities_by_type.has(entity_type):
            var type_array = _entities_by_type[entity_type]
            var index = type_array.find(id)
            if index != -1:
                type_array.remove_at(index)
        
        _remove_from_spatial_index(id, entity_data.get("pos", Vector2.ZERO))
        _entities.erase(id)
        entity_unregistered.emit(id)

# OPTIMIZED: O(1) type lookup instead of O(N) iteration
func get_entities_by_type_optimized(entity_type: String) -> Array[String]:
    return _entities_by_type.get(entity_type, [])
```

#### Phase 4: 30Hz Radar Updates
```gdscript
# RadarUpdateManager - Replace 60Hz _process with 30Hz combat_step
func _on_combat_step(payload) -> void:
    # Update cached entity lists at combat frequency (30Hz)
    _rebuild_entity_cache()
    
    # Combine cached entities
    var all_radar_entities: Array[EventBus.RadarEntity] = []
    all_radar_entities.append_array(_cached_enemy_entities)
    all_radar_entities.append_array(_cached_boss_entities)
    
    # Emit radar data using zero-allocation payload
    var radar_payload = _radar_payload_pool.acquire()
    radar_payload["entities"] = all_radar_entities
    radar_payload["player_pos"] = _player_position
    
    # Queue for emission
    _radar_update_queue.try_push(radar_payload)
    
    # Batch emit all queued radar updates
    _process_radar_emissions()

# Player position tracking
func _on_player_position_changed(position: Vector2) -> void:
    _player_position = position
```

## 📊 Expected Performance Gains

| Metric | Before (500+500 entities) | After | Improvement |
|--------|---------------------------|-------|-------------|
| **EntityTracker Scans** | 60Hz × 2 type queries × 1000 entities = 120K/sec | 30Hz cache rebuild = 30K/sec | 75% reduction |
| **Dictionary Lookups** | 120,000/sec individual | 30,000/sec batched | 75% reduction |
| **Array Allocations** | Per-frame allocation | Zero-allocation ring buffer | 100% elimination |
| **Update Frequency** | 60Hz visual updates | 30Hz combat step alignment | Consistent w/ combat |

## 🧪 Testing Strategy

### Performance Benchmark
```gdscript
# tests/test_radar_performance_1000_entities.gd
extends SceneTree

func _initialize():
    # Spawn 500 enemies + 500 bosses
    for i in range(500):
        spawn_enemy_at_position(Vector2(i * 10, 0))
        spawn_boss_at_position(Vector2(i * 10, 100))
    
    # Monitor radar system performance for 60 seconds
    test_radar_performance_sustained(60.0)
    
    # Compare against pre-optimization metrics
    validate_performance_improvement()
```

### Validation Criteria
- **Target**: 1000+ entities with stable 30Hz radar updates
- **Memory**: No allocation spikes during radar processing
- **Consistency**: Radar remains responsive during heavy combat

## 🔧 Integration Points

### Ring Buffer Infrastructure Reuse
- **RingBufferUtil**: Radar update queue management
- **ObjectPoolUtil**: Radar payload lifecycle management  
- **PayloadResetUtil**: Extend with `create_radar_update_payload()` and `clear_radar_update_payload()`

### System Dependencies
- **EntityTracker**: Add type-indexed storage for O(1) lookups
- **RadarSystem**: Consume cached data instead of scanning EntityTracker
- **EventBus**: Maintain existing radar_data_updated signal interface

## 🔄 Implementation Phases

### Phase 1: EntityTracker Type Indexing (45 min)
- [ ] Add `_entities_by_type` dictionary to EntityTracker
- [ ] Update `register_entity()` and `unregister_entity()` to maintain type index
- [ ] Add `get_entities_by_type_optimized()` for O(1) lookups
- [ ] Test with 50+ entities of mixed types

### Phase 2: RadarUpdateManager Infrastructure (45 min)  
- [ ] Create `RadarUpdateManager` class with ring buffer setup
- [ ] Implement entity cache management with dirty flag system
- [ ] Connect to EntityTracker lifecycle signals for cache invalidation
- [ ] Test cache rebuilding with entity spawning/despawning

### Phase 3: 30Hz Combat Step Integration (30 min)
- [ ] Replace RadarSystem 60Hz _process with RadarUpdateManager combat_step
- [ ] Implement batched radar emission using ring buffer
- [ ] Maintain existing EventBus.radar_data_updated interface
- [ ] Test radar update consistency at 30Hz

### Phase 4: Performance Testing (30 min)
- [ ] Benchmark 1000+ entity radar performance 
- [ ] Compare against pre-optimization EntityTracker scanning
- [ ] Validate no visual degradation from 30Hz updates

### Phase 5: Documentation & Cleanup (30 min)
- [ ] Update Obsidian performance documentation
- [ ] Remove old EntityTracker.get_entities_by_type() direct usage
- [ ] Create migration guide for radar system architecture

## 📋 Cleanup Checklist (Final Phase)

After verifying the new system works:

### Code Removal
- [ ] Remove direct `EntityTracker.get_entities_by_type()` calls from RadarSystem
- [ ] Remove 60Hz _process updates in favor of 30Hz combat_step alignment
- [ ] Clean up redundant entity scanning loops

### Performance Validation
- [ ] Confirm 1000+ entity radar updates maintain stable performance
- [ ] Verify EntityTracker type lookups are O(1) instead of O(N)
- [ ] Validate zero-allocation radar updates during sustained gameplay

### Documentation Updates
- [ ] Update `Obsidian/systems/Performance-Optimization-System.md` to include radar optimization
- [ ] Add radar performance metrics to system documentation
- [ ] Document EntityTracker type-indexed architecture

## 🎯 Success Criteria

✅ **Performance**: 1000+ entities with stable 30Hz radar updates  
✅ **Efficiency**: EntityTracker type lookups converted from O(N) to O(1)  
✅ **Architecture**: Reuses proven ring buffer infrastructure  
✅ **Consistency**: Radar updates aligned with 30Hz combat step frequency  
✅ **Memory**: Zero-allocation radar processing during runtime

---

**Related Systems:**
- [[Performance-Optimization-System]] - Base ring buffer infrastructure
- [[Boss-Performance-Ring-Buffer-Integration]] - Similar optimization pattern
- [[Enemy-System-Architecture]] - Combat step alignment reference

**Implementation Notes:**
- Leverage existing battle-tested ring buffer code from enemy optimization
- Maintain existing EventBus.radar_data_updated signal interface for UI compatibility
- Focus on EntityTracker type scanning as primary bottleneck (O(N) → O(1))
- Align radar frequency with combat step (30Hz) instead of visual updates (60Hz)