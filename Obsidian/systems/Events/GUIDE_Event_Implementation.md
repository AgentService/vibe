# Event Implementation Guide
*Standardized framework for implementing new event types (Ritual, PackHunt, Boss, etc.)*

**Status:** ✅ Framework Ready | **Version:** v1.0 (Monitoring Template)
**Last Updated:** 2025-09-21 | **Reference Implementation:** Breach Events

---

## Quick Implementation Checklist

When implementing a new event type, follow these steps:

- [ ] **1. Create Event Handler** (`scripts/systems/events/[EventType]EventHandler.gd`)
- [ ] **2. Create Performance Monitor** (`tests/tools/monitor_[eventtype]_performance.gd`)
- [ ] **3. Update DebugConfig** (add `enable_[eventtype]_monitoring` flag)
- [ ] **4. Create Configuration Resource** (`data/balance/[eventtype]_event_config.tres`)
- [ ] **5. Add Testing Suite** (follow template pattern from `test_breach_events_focused.tscn`)
- [ ] **6. Document Architecture** (create `[EventType]-Event-System-Architecture.md`)

---

## Event System Architecture Framework

### Core Event System Components

All event systems should follow this standardized architecture:

```gdscript
# 1. Event Handler (Main Coordinator)
scripts/systems/events/[EventType]EventHandler.gd
    ├── Extends Node
    ├── Adds to group "[eventtype]_handlers"
    ├── Connects to EventBus.combat_step (30Hz)
    └── Manages event lifecycle and entity tracking

# 2. Event Instance (Individual Event State)
scripts/systems/events/[EventType]Instance.gd
    ├── Extends RefCounted or Resource
    ├── Manages single event lifecycle
    └── Tracks event-specific state and progress

# 3. Configuration Resource (Hot-Reloadable Settings)
scripts/resources/[EventType]EventConfig.gd
    ├── Extends Resource
    ├── @export parameters for hot-reload
    └── Validation methods

# 4. Performance Monitor (Reusable Template)
tests/tools/monitor_[eventtype]_performance.gd
    ├── Extends BaseEventMonitor
    ├── Event-specific metrics collection
    └── Standardized monitoring output
```

---

## Step-by-Step Implementation Guide

### Step 1: Create Event Handler

Create the main coordinator class that manages your event type:

```gdscript
# scripts/systems/events/RitualEventHandler.gd
extends Node
class_name RitualEventHandler

## Ritual Event Handler - Manages all ritual event logic
## Follows the standardized event architecture pattern

# Configuration and state
var ritual_config: RitualEventConfig
var active_rituals: Array[RitualInstance] = []
var pending_rituals: Array[RitualInstance] = []

# Dependencies (injected by SpawnDirector)
var spawn_director: SpawnDirector

func _init(injected_spawn_director: SpawnDirector = null):
    spawn_director = injected_spawn_director
    _load_configuration()

func _ready() -> void:
    # Register for monitoring detection
    add_to_group("ritual_handlers")

    # Connect to 30Hz fixed-step updates
    EventBus.combat_step.connect(_on_combat_step)

    Logger.info("RitualEventHandler initialized", "events")

func _load_configuration() -> void:
    var config_path = "res://data/balance/ritual_event_config.tres"
    ritual_config = ResourceLoader.load(config_path, "", ResourceLoader.CACHE_MODE_IGNORE)

    if not ritual_config:
        Logger.error("Failed to load ritual configuration", "events")

# Main update loop - called by EventBus.combat_step
func _on_combat_step(payload: EventBus.CombatStepPayload_Type) -> void:
    _handle_ritual_creation()
    _update_active_rituals(payload.delta_time)
    _cleanup_completed_rituals()

# API methods for monitoring
func get_active_ritual_count() -> int:
    return active_rituals.size()

func get_pending_ritual_count() -> int:
    return pending_rituals.size()

# Event-specific logic methods
func _handle_ritual_creation() -> void:
    # Implement ritual creation logic
    pass

func _update_active_rituals(delta_time: float) -> void:
    # Implement ritual update logic
    pass

func _cleanup_completed_rituals() -> void:
    # Implement ritual completion and cleanup
    pass
```

### Step 2: Create Event Instance

Define the state management for individual events:

```gdscript
# scripts/systems/events/RitualInstance.gd
extends RefCounted
class_name RitualInstance

## Individual ritual event state management
## Manages lifecycle phases and ritual-specific data

enum Phase { SETUP, CHANNELING, CLIMAX, COMPLETED }

# Core state
var ritual_id: String
var center_position: Vector2
var current_phase: Phase = Phase.SETUP
var phase_timer: float = 0.0

# Ritual-specific state
var ritual_type: String
var participant_count: int = 0
var required_participants: int = 4
var ritual_power: float = 0.0

# Entity tracking
var ritual_entities: Array[Node] = []  # Altars, totems, etc.
var participant_entities: Array[Node] = []

func _init(position: Vector2, type: String):
    ritual_id = "ritual_" + str(Time.get_ticks_msec()) + "_" + str(randi())
    center_position = position
    ritual_type = type

func activate() -> void:
    current_phase = Phase.CHANNELING
    phase_timer = 0.0
    Logger.info("Ritual activated at %s" % center_position, "events")

func update_phase(delta_time: float) -> void:
    phase_timer += delta_time

    match current_phase:
        Phase.SETUP:
            _update_setup_phase()
        Phase.CHANNELING:
            _update_channeling_phase()
        Phase.CLIMAX:
            _update_climax_phase()

func is_completed() -> bool:
    return current_phase == Phase.COMPLETED

# Phase-specific update methods
func _update_setup_phase() -> void:
    # Check if ritual can begin
    if participant_count >= required_participants:
        current_phase = Phase.CHANNELING

func _update_channeling_phase() -> void:
    # Build ritual power over time
    ritual_power += 0.1 * (participant_count / float(required_participants))

    if ritual_power >= 100.0:
        current_phase = Phase.CLIMAX

func _update_climax_phase() -> void:
    # Execute ritual effects
    if phase_timer >= 3.0:  # 3 second climax
        current_phase = Phase.COMPLETED
```

### Step 3: Create Configuration Resource

Define hot-reloadable parameters:

```gdscript
# scripts/resources/RitualEventConfig.gd
extends Resource
class_name RitualEventConfig

## Hot-reloadable configuration for ritual events
## Use @export for automatic Inspector hot-reload

@export_group("Ritual Timing")
@export var setup_duration: float = 5.0
@export var max_channeling_duration: float = 30.0
@export var climax_duration: float = 3.0

@export_group("Ritual Requirements")
@export var min_participants: int = 2
@export var max_participants: int = 8
@export var ritual_radius: float = 200.0

@export_group("Spawn Parameters")
@export var altar_count: int = 4
@export var totem_spacing: float = 50.0
@export var entity_spawn_rate: float = 2.0

@export_group("Visual Effects")
@export var ritual_particle_color: Color = Color(1.0, 0.2, 0.8, 0.7)
@export var channeling_modulate: Color = Color(0.8, 0.5, 1.0, 0.9)

@export_group("Performance")
@export var max_simultaneous_rituals: int = 2
@export var min_ritual_distance: float = 300.0

func validate() -> Array[String]:
    var errors: Array[String] = []

    if setup_duration <= 0:
        errors.append("setup_duration must be positive")

    if min_participants <= 0:
        errors.append("min_participants must be positive")

    if ritual_radius <= 0:
        errors.append("ritual_radius must be positive")

    return errors
```

### Step 4: Create Performance Monitor

Use the base monitoring template:

```gdscript
# tests/tools/monitor_ritual_performance.gd
extends "res://tests/tools/monitor_event_performance_base.gd"
class_name RitualEventMonitor

## Ritual Event Performance Monitor
## Provides real-time monitoring of ritual event performance and metrics

func _init():
    event_handler_group = "ritual_handlers"
    event_type_name = "Ritual"
    handler_property_name = "ritual_handler"

func get_event_specific_data(ritual_handler) -> Dictionary:
    var data = {}

    # Basic event counts
    data["active_events"] = ritual_handler.get_active_ritual_count()
    data["pending_events"] = ritual_handler.get_pending_ritual_count()

    # Ritual-specific metrics
    if ritual_handler.has_method("get") and "active_rituals" in ritual_handler:
        var rituals = ritual_handler.active_rituals
        data["ritual_details"] = []
        data["total_participants"] = 0

        for ritual in rituals:
            data.ritual_details.append({
                "id_suffix": ritual.ritual_id.substr(-8),
                "phase": ritual.current_phase,
                "participants": ritual.participant_count,
                "power": ritual.ritual_power,
                "type": ritual.ritual_type
            })
            data.total_participants += ritual.participant_count

    # Entity tracking
    if ritual_handler.has_method("get_ritual_entities"):
        var entities = ritual_handler.get_ritual_entities()
        data["total_entities"] = entities.size()

        # Count entity types
        data["entity_breakdown"] = {}
        for entity in entities:
            var type_name = entity.get_meta("entity_type", "unknown")
            if not data.entity_breakdown.has(type_name):
                data.entity_breakdown[type_name] = 0
            data.entity_breakdown[type_name] += 1

    return data

func format_event_summary(handler_data: Dictionary) -> String:
    var summary = ""

    # Display ritual details
    if handler_data.has("ritual_details"):
        summary += "🔮 Active Rituals:\n"
        for ritual in handler_data.ritual_details:
            var phase_emoji = _get_phase_emoji(ritual.phase)
            summary += "  %s Ritual %s (%s): %.1f%% power, %d participants\n" % [
                phase_emoji,
                ritual.id_suffix,
                ritual.type,
                ritual.power,
                ritual.participants
            ]

    # Display entity breakdown
    if handler_data.has("entity_breakdown"):
        summary += "🏛️ Ritual Entities:\n"
        for entity_type in handler_data.entity_breakdown:
            summary += "  ⚱️ %s: %d active\n" % [
                entity_type.capitalize(),
                handler_data.entity_breakdown[entity_type]
            ]

    # Display participation metrics
    if handler_data.has("total_participants"):
        summary += "👥 Total Participants: %d across all rituals\n" % handler_data.total_participants

    return summary

func _get_phase_emoji(phase) -> String:
    match phase:
        0: return "⏳"  # Setup
        1: return "🔮"  # Channeling
        2: return "✨"  # Climax
        3: return "✅"  # Completed
        _: return "❓"
```

### Step 5: Update DebugConfig Integration

The DebugConfig flags are already in place. For your new event type, you just need to:

1. **Enable monitoring in config/debug.tres:**
```tres
enable_ritual_monitoring = true
event_monitor_interval = 5.0
```

2. **BaseArena automatically creates monitors** for any enabled event type - no additional code needed!

### Step 6: Create Testing Suite

Follow the comprehensive testing template from Breach events:

```gdscript
# tests/test_ritual_events_focused.tscn/gd
extends Node2D

## Focused Ritual Event Testing
## Tests core ritual mechanics independently of complex dependencies

const TEST_SEED = 12345
const RITUAL_POSITIONS = [Vector2(200, 200), Vector2(500, 200)]

var test_results: Dictionary = {}
var ritual_handler: RitualEventHandler

func _ready():
    print("=== FOCUSED RITUAL EVENT TEST ===")
    _setup_test_environment()
    await _run_tests()
    _report_results()

    if DisplayServer.get_name() == "headless":
        get_tree().quit()

func _run_tests() -> void:
    await _test_ritual_lifecycle()
    await _test_multi_ritual_independence()
    await _test_configuration_validation()

# Implement specific test methods for your event type
```

---

## Event System Integration Points

### EventBus Integration

All event systems should emit standardized signals:

```gdscript
# Event lifecycle signals
EventBus.event_started.emit("ritual", ritual_instance)
EventBus.event_completed.emit("ritual", completion_data)

# Event-specific signals
EventBus.ritual_phase_changed.emit(ritual_id, new_phase)
EventBus.ritual_participant_joined.emit(ritual_id, participant_entity)
```

### SpawnDirector Coordination

Event handlers depend on SpawnDirector for:

```gdscript
# Arena access
var arena_scene = spawn_director._get_arena_scene()

# Entity spawning
var entity = spawn_director._spawn_from_config_v2(entity_config, position)

# Zone validation
var zones = arena_scene._spawn_zone_areas
```

### 30Hz Fixed-Step Integration

All event handlers should use EventBus.combat_step for deterministic updates:

```gdscript
func _on_combat_step(payload: EventBus.CombatStepPayload_Type) -> void:
    var delta_time = payload.delta_time  # Always 1/30 = 0.0333...
    _update_event_logic(delta_time)
```

---

## Performance Optimization Guidelines

### Entity Management

- **Use object pools** for frequently created/destroyed entities
- **Implement zero-allocation tracking** where possible (see BreachEnemyTracker)
- **Batch entity operations** within 30Hz fixed-step updates

### Memory Efficiency

- **Pre-allocate entity arrays** with known maximum sizes
- **Use mark-for-removal patterns** instead of immediate deletions
- **Implement capacity monitoring** with early warnings

### Visual Effects

- **Use object pools** for particle effects and temporary visuals
- **Batch visual updates** with the fixed-step system
- **Implement LOD systems** for complex visual effects

---

## Monitoring System Benefits

The BaseEventMonitor template provides:

✅ **Standardized Output Format**: Consistent monitoring across all event types
✅ **Automatic Handler Detection**: Multi-path finding (arena, SpawnDirector, groups)
✅ **Hot-Reload Integration**: DebugConfig flags for runtime enable/disable
✅ **Extensible Design**: Add new event types without modifying BaseArena
✅ **Performance Metrics**: Built-in 30Hz integration and efficiency tracking

### Example Monitoring Output

```
=== RITUAL OPTIMIZATION STATUS ===
✅ Arena found: UnderworldArena
✅ Ritual event system detected!
📊 Active rituals: 2, Pending: 1
🔮 Active Rituals:
  🔮 Ritual a7b8c9d2 (summoning): 75.5% power, 6 participants
  ✨ Ritual e4f5a6b7 (binding): 98.2% power, 4 participants
🏛️ Ritual Entities:
  ⚱️ Altar: 8 active
  ⚱️ Totem: 12 active
👥 Total Participants: 10 across all rituals

📡 30Hz Integration Status:
✅ EventBus.combat_step connected for fixed-step updates
🎯 Update frequency: 30Hz (vs 60Hz frame rate)
⚡ Performance improvement: ~50% reduction in update frequency

🚀 Optimization Status: ACTIVE AND WORKING
```

---

## Common Implementation Patterns

### Entity Ownership Tracking

```gdscript
# Mark entities as belonging to specific events
entity.set_meta("event_owner", event_instance.event_id)
entity.set_meta("event_type", "ritual")
entity.add_to_group("ritual_entities")
```

### Event Cleanup

```gdscript
func _cleanup_completed_event(event_instance) -> void:
    # Clean up entities with visual effects
    for entity in event_instance.entities:
        if entity and is_instance_valid(entity):
            _dissolve_entity_with_effect(entity)

    # Emit completion signal with performance data
    var completion_data = {
        "duration": event_instance.get_total_duration(),
        "entities_spawned": event_instance.entities.size(),
        "event_type": event_instance.event_type
    }
    EventBus.event_completed.emit("ritual", completion_data)
```

### Hot-Reload Configuration

```gdscript
func _load_configuration() -> void:
    var config_path = "res://data/balance/ritual_event_config.tres"

    # Use CACHE_MODE_IGNORE for hot-reload
    ritual_config = ResourceLoader.load(
        config_path,
        "",
        ResourceLoader.CACHE_MODE_IGNORE
    )

    # Validate configuration
    var errors = ritual_config.validate()
    if not errors.is_empty():
        Logger.warn("Ritual config validation failed: %s" % errors, "events")
```

---

## Architecture Quality Standards

When implementing event systems, ensure:

- ✅ **Deterministic Behavior**: Use seeded RNG and fixed-step updates
- ✅ **Hot-Reload Support**: Configuration resources with validation
- ✅ **EventBus Integration**: Typed signal payloads for cross-system communication
- ✅ **Performance Monitoring**: BaseEventMonitor implementation
- ✅ **Testing Coverage**: Core logic, performance, and integration tests
- ✅ **Documentation**: Architecture documentation following this template

---

## Troubleshooting Guide

### Common Issues

1. **Event handler not found by monitoring**
   - Ensure `add_to_group("[eventtype]_handlers")` in `_ready()`
   - Check handler property name matches monitoring configuration

2. **30Hz updates not working**
   - Verify `EventBus.combat_step.connect(_on_combat_step)` connection
   - Check payload parameter type: `EventBus.CombatStepPayload_Type`

3. **Configuration not hot-reloading**
   - Use `ResourceLoader.CACHE_MODE_IGNORE` for development
   - Verify `@export` parameters in configuration resource

4. **Performance issues**
   - Implement object pooling for frequently created entities
   - Use batch operations in fixed-step updates
   - Monitor capacity usage and implement early warnings

### Debug Logging

Use consistent logging categories:

```gdscript
Logger.info("Ritual activated at position %s" % position, "events")
Logger.debug("Phase transition: %s -> %s" % [old_phase, new_phase], "events")
Logger.warn("Ritual capacity approaching limit: %d/%d" % [count, max], "events")
```

---

## Related Documentation

- **[Breach Event Architecture](Breach-Event-System-Architecture.md)**: Reference implementation
- **[EventBus System](EventBus-System.md)**: Signal contracts and payloads
- **[Testing Framework](../tests/CLAUDE.md)**: Test patterns and execution
- **[Performance Optimization](Performance-Optimization-System.md)**: System-wide optimization

---

*This guide provides the standardized framework for implementing new event types. Use the Breach Event System as a reference implementation, and follow the monitoring template for consistent performance tracking across all event systems.*