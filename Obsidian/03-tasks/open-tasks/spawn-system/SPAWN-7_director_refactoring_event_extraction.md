# SpawnDirector Refactoring - Event System Extraction

**Status:** Ready for Implementation
**Priority:** High
**Estimated Time:** 45-60 minutes
**Created:** 2025-01-16

## Context

The SpawnDirector has grown to ~1500+ lines and is approaching architectural complexity limits. Adding the event system increases this to ~1600 lines, mixing multiple responsibilities that should be separated for maintainability.

## Problem Statement

**Current SpawnDirector Responsibilities:**
- Core enemy spawning (waves, pooling)
- Pack formation and scaling logic
- Event spawning and completion tracking
- Zone management (cooldowns, threat escalation)
- Performance optimizations (bit-fields, object pools)

**Issues:**
- Single file approaching 1600+ lines
- Multiple unrelated responsibilities mixed together
- Difficult to test individual systems
- Hard to enable/disable event system independently
- Violates single responsibility principle

## Solution: Two-Phase Refactoring

### Phase 1: Event System Extraction (IMMEDIATE)

**Goal:** Extract all event-related logic into a separate `EventSpawnManager` class.

**Scope:**
- Move event spawning logic from SpawnDirector to EventSpawnManager
- Keep pack/wave spawning in SpawnDirector
- Maintain existing zone management interface
- Preserve all current functionality

**Implementation Plan:**

#### 1. Create EventSpawnManager Class
```gdscript
# scripts/systems/EventSpawnManager.gd
class_name EventSpawnManager
extends Node

var mastery_system: EventMasterySystem
var spawn_director: SpawnDirector  # Reference for zone access
var event_timer: float = 0.0
var next_event_delay: float = 45.0
var active_events: Array[Dictionary] = []
```

#### 2. Extract Event Logic from SpawnDirector
**Move these functions:**
- `_handle_event_spawning(dt: float)`
- `_get_available_event_zones(player_pos, map_config)`
- `_select_event_zone(available_zones, player_pos)`
- `_spawn_event_at_zone(event_def, config, zone)`
- `_spawn_event_formation(pack_size, center_pos, formation_radius, event_def)`
- `_spawn_event_enemy(position, event_def)`
- `_check_event_completion(killed_entity_id)`

**Keep these in SpawnDirector:**
- Zone management (cooldowns, threat escalation)
- Pack formation logic (reused by events)
- Core spawning infrastructure

#### 3. Update SpawnDirector Integration
```gdscript
# In SpawnDirector._ready()
func _initialize_event_system() -> void:
    event_spawn_manager = EventSpawnManager.new()
    event_spawn_manager.spawn_director = self
    add_child(event_spawn_manager)

# In SpawnDirector._handle_spawning()
if event_system_enabled and event_spawn_manager:
    event_spawn_manager.handle_event_spawning(dt)
```

#### 4. Create Public Interface for Zone Access
```gdscript
# In SpawnDirector - public methods for EventSpawnManager
func get_available_zones_for_events(player_pos: Vector2, map_config: MapConfig) -> Array[Area2D]
func set_zone_cooldown_external(zone_name: String) -> void
func escalate_zone_threat_external(zone_name: String, amount: float) -> void
func spawn_pack_formation_external(pack_size: int, center_pos: Vector2, formation_radius: float) -> void
```

### Phase 2: Further Modularization (FUTURE)

**Goal:** Continue refactoring if SpawnDirector grows beyond maintainable size.

**Potential Extractions:**
1. **PackSpawnManager** - Pack formation and scaling logic
2. **ZoneManager** - Zone cooldowns, threat escalation, distance filtering
3. **SpawnCoordinator** - High-level orchestration of all spawn systems

**Architecture Vision:**
```
SpawnCoordinator
├── WaveSpawnManager (basic enemy waves)
├── PackSpawnManager (pack formations)
├── EventSpawnManager (event system)
└── ZoneManager (shared zone logic)
```

## Benefits

### Phase 1 Benefits:
- **Reduced complexity:** SpawnDirector returns to ~1200 lines
- **Clear separation:** Events become independent system
- **Easier testing:** Event system can be tested in isolation
- **Maintainability:** Easier to understand and modify both systems
- **Feature toggles:** Event system can be disabled cleanly

### Phase 2 Benefits:
- **Highly modular:** Each system has single responsibility
- **Extensible:** Easy to add new spawn types (e.g., siege events, mini-bosses)
- **Performance:** Systems can be optimized independently
- **Team development:** Multiple developers can work on different spawn systems

## Implementation Checklist

### Phase 1 Tasks:
- [ ] Create EventSpawnManager class structure
- [ ] Move event-related variables from SpawnDirector
- [ ] Extract event spawning functions
- [ ] Create public interface for zone access
- [ ] Update SpawnDirector to use EventSpawnManager
- [ ] Test event spawning still works correctly
- [ ] Test zone cooldowns and threat escalation integration
- [ ] Verify no performance regression
- [ ] Update any direct references to SpawnDirector event logic

### Phase 2 Tasks (Future):
- [ ] Analyze SpawnDirector size after Phase 1
- [ ] Design PackSpawnManager interface
- [ ] Extract pack spawning logic if needed
- [ ] Consider ZoneManager extraction
- [ ] Implement SpawnCoordinator if multiple managers exist

## Success Criteria

### Phase 1:
- [ ] SpawnDirector reduced to ~1200 lines or less
- [ ] All event functionality preserved
- [ ] Event system can be enabled/disabled cleanly
- [ ] No performance regression in spawning systems
- [ ] Clear separation between event and pack spawning logic

### Phase 2:
- [ ] Each spawn system under 800 lines
- [ ] Clear interfaces between systems
- [ ] Easy to add new spawn types
- [ ] Systems can be tested independently

## Notes

**Architecture Principle:** Extract systems when they exceed ~1000-1200 lines or have multiple distinct responsibilities.

**Performance Consideration:** EventSpawnManager should reuse SpawnDirector's optimized zone and formation logic rather than duplicating it.

**Testing Strategy:** Event system extraction makes it much easier to create isolated tests for event spawning without needing full arena setup.

## Related Files

**Modified:**
- `scripts/systems/SpawnDirector.gd` - Event logic removal
- Event system integration in arena scenes

**Created:**
- `scripts/systems/EventSpawnManager.gd` - New event management system

**Dependencies:**
- `scripts/systems/EventMasterySystem.gd` - Used by EventSpawnManager
- `scripts/resources/EventDefinition.gd` - Event configuration
- `autoload/EventBus.gd` - Event signals