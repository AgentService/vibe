# Pattern-Event System Integration Task

**Status:** Ready for Implementation (REVISED)
**Priority:** High
**Created:** 2025-09-26 (Revised after system analysis)
**Dependencies:** Pattern placement system (✅ Complete)

## 🎯 Current State Analysis

✅ **Pattern Placement Foundation Complete**
- Pattern 0 → Decorations Layer (Y-sorted)
- Pattern 1 → Ground Decorations Layer (non-Y-sorted)
- Key 2 places both patterns at mouse position
- Proper TileMapLayer routing working

✅ **Existing Event System Architecture (DISCOVERED)**
- `EventDefinition.gd` - Already exists with comprehensive event configuration
- `EventMasterySystem.gd` - Manages passive modifiers and progression
- `BreachEventHandler.gd` - Template for event handlers (30Hz fixed-step)
- `EventInstance.gd` - Event lifecycle management
- Event types: breach, ritual, pack_hunt, boss (4 working types)
- Event configs in `/data/content/events/` (.tres files)
- Full mastery system with passive bonuses

## 🚀 Revised Goal: Pattern-Event Integration

**INTEGRATION NOT RECREATION** - Leverage existing sophisticated event system!

### 📋 Pattern-Event Bridge Components

#### **1. PatternEventConfig - Link Patterns to Events**
```gdscript
# NEW: PatternEventConfig.gd - Extends existing system
class_name PatternEventConfig extends Resource

@export var pattern_group: String # "stone_circle", "ancient_ruins"
@export var compatible_events: Array[String] # References existing EventDefinition IDs
@export var spawn_probability: float = 0.7 # Chance this pattern spawns an event
@export var max_events_per_pattern: int = 1
@export var event_weights: Dictionary = {} # event_id -> spawn_weight

# Integration with existing EventDefinition system
func get_available_events() -> Array[EventDefinition]:
    # Query EventMasterySystem for events by ID
    return EventMasterySystem.get_events_by_ids(compatible_events)
```

#### **2. PatternEventSpawner - Procedural Integration**
```gdscript
# NEW: Extends ProceduralArenaGenerator
# Hooks into existing _place_tile_patterns_in_walkable_areas()
func _place_pattern_with_event(pattern: TilePatternConfig, position: Vector2i) -> Dictionary:
    # 1. Place pattern using existing system (✅ working)
    var pattern_placed = _place_pattern_at_position(pattern, position)

    # 2. Check for event compatibility
    var pattern_event_config = _get_pattern_event_config(pattern.pattern_group)
    if not pattern_event_config:
        return pattern_placed # Just pattern, no event

    # 3. Roll for event spawn using existing mastery bonuses
    var should_spawn_event = _roll_event_spawn(pattern_event_config)
    if not should_spawn_event:
        return pattern_placed # Pattern without event

    # 4. Select event using existing EventDefinition system
    var selected_event = _select_event_for_pattern(pattern_event_config)

    # 5. Apply visual theme based on event type
    _apply_event_visual_theme(pattern_placed, selected_event)

    # 6. Queue event for spawn using EXISTING BreachEventHandler pattern
    _queue_pattern_event(selected_event, position)

    return {"pattern": pattern_placed, "event": selected_event}
```

### 🎨 Visual Theme Integration

#### **3. Leverage Existing EventDefinition.visual_config**
**REUSE EXISTING SYSTEM** - `EventDefinition.visual_config` already has:
- `ui_color` - Use for pattern tinting
- `spawn_effect` - Particle effects when event triggers
- `completion_effect` - Reward visual feedback

```gdscript
# NEW: Visual theme application
func _apply_event_visual_theme(pattern_data: Dictionary, event_def: EventDefinition):
    var event_color = event_def.get_visual_value("ui_color", Color.WHITE)
    var tint_strength = 0.3 # Subtle color overlay

    # Apply color modulation to pattern tiles
    for tile_pos in pattern_data.tile_positions:
        decorations_layer.set_cell_modulate(tile_pos, event_color.lerp(Color.WHITE, tint_strength))
```
    
### 🎲 Event System Integration

#### **4. Leverage Existing EventMasterySystem**
**REUSE EXISTING ARCHITECTURE** - Don't recreate what exists!

```gdscript
# EXISTING: EventMasterySystem already handles:
# - Event definitions loading ✅
# - Passive modifier application ✅
# - Event configuration with mastery bonuses ✅
# - Event type management (breach, ritual, pack_hunt, boss) ✅

# NEW: Extend for pattern-event integration
func get_compatible_events_for_pattern(pattern_group: String) -> Array[EventDefinition]:
    # Query existing _event_definitions filtered by pattern compatibility
    var compatible_events: Array[EventDefinition] = []

    for event_id in _event_definitions:
        var event_def = _event_definitions[event_id]
        if _is_event_compatible_with_pattern(event_def, pattern_group):
            compatible_events.append(event_def)

    return compatible_events

func apply_pattern_event_modifiers(event_def: EventDefinition) -> EventDefinition:
    # Use EXISTING modifier system with pattern-specific bonuses
    return apply_mastery_modifiers(event_def) # ✅ Already exists!
```

#### **5. Event Spawn Integration with Existing Handlers**

**REUSE EXISTING HANDLER PATTERN** - Follow `BreachEventHandler.gd` template:

```gdscript
# NEW: PatternEventHandler.gd - Similar to BreachEventHandler
extends Node
class_name PatternEventHandler

var pattern_events: Array[PatternEventInstance] = []
var spawn_director: SpawnDirector # Inject existing dependency

func initialize(director: SpawnDirector, mastery: EventMasterySystemImpl) -> void:
    spawn_director = director
    # Connect to 30Hz fixed-step like existing handlers ✅
    EventBus.combat_step.connect(_on_combat_step)

# Use EXISTING EventInstance pattern
class PatternEventInstance extends EventInstance:
    var source_pattern: TilePatternConfig
    var pattern_position: Vector2i
    var visual_theme_applied: bool = false
```

#### **6. Accessibility Validation - REUSE EXISTING**

**LEVERAGE EXISTING SYSTEMS:**
- ✅ `SimpleTileSpawnValidator` - Already validates tile accessibility
- ✅ `generation_params.spawn_border_spacing` - Distance from boundary
- ✅ `_will_have_obstruction()` - Accessibility checking

### 🗺️ Path-Based Map Generation (NEW FEATURE)

#### **7. Extend ProceduralArenaGenerator for Linear Maps**
```gdscript
# NEW: Add to ProceduralArenaGenerator.gd
@export var generation_mode: GenerationMode = GenerationMode.CIRCULAR
@export var path_width: float = 20.0 # 20cm wide paths for linear mode
@export var path_segments: int = 5 # Number of path checkpoints

enum GenerationMode { CIRCULAR, LINEAR, BRANCHING }

func _generate_linear_arena(rng: RandomNumberGenerator) -> void:
    # Generate connected path segments instead of circular area
    # Place patterns at path checkpoints and intersections
```

### 🎯 Event Trigger Integration - REUSE EXISTING

#### **8. Leverage Existing Area2D Event Zones**
**EXISTING SYSTEM:** `EventInstance.zone: Area2D` for breach events
**NEW:** Extend for pattern events using same pattern

```gdscript
# PatternEventInstance extends existing EventInstance
# Inherits zone: Area2D for trigger detection ✅
# Reuses existing player_entered/player_exited detection ✅
# Uses existing EventBus signals for activation ✅
```

## 📝 Revised Implementation Tasks

### **Phase 1: Pattern-Event Bridge (Week 1)**
- [ ] Create `PatternEventConfig.gd` resource (NEW)
- [ ] Extend `EventMasterySystem` with pattern compatibility methods (EXTEND)
- [ ] Add pattern-event hooks to `_place_tile_patterns_in_walkable_areas()` (EXTEND)
- [ ] Create visual theming system using existing `EventDefinition.visual_config` (NEW)

### **Phase 2: Event Handler Integration (Week 1-2)**
- [ ] Create `PatternEventHandler.gd` following `BreachEventHandler` template (NEW)
- [ ] Extend `EventInstance` → `PatternEventInstance` for pattern tracking (EXTEND)
- [ ] Integrate with existing 30Hz combat step system (INTEGRATE)
- [ ] Add pattern events to existing `SpawnDirector` event handling (EXTEND)

### **Phase 3: Procedural Integration (Week 2-3)**
- [ ] Add event rolling logic to pattern placement (NEW)
- [ ] Implement pattern-based event spawn queuing (NEW)
- [ ] Add visual theme application to placed patterns (NEW)
- [ ] Integrate with existing mastery modifier system (INTEGRATE)

### **Phase 4: Advanced Features (Week 3-4)**
- [ ] Add linear/path-based generation mode to `ProceduralArenaGenerator` (NEW)
- [ ] Create event accessibility validation using existing systems (EXTEND)
- [ ] Add event-pattern debugging tools (NEW)
- [ ] Performance testing and optimization (TEST)

## 🔧 Technical Integration Points

### **EXISTING Systems to Leverage (Don't Recreate!):**
- ✅ `EventDefinition.gd` → Event configuration (ALREADY EXISTS)
- ✅ `EventMasterySystem.gd` → Event management & modifiers (ALREADY EXISTS)
- ✅ `BreachEventHandler.gd` → Event handler template (ALREADY EXISTS)
- ✅ `EventInstance.gd` → Event lifecycle management (ALREADY EXISTS)
- ✅ `SpawnDirector._handle_event_spawning()` → Event spawning logic (ALREADY EXISTS)
- ✅ `SimpleTileSpawnValidator` → Accessibility validation (ALREADY EXISTS)
- ✅ `generation_params.spawn_border_spacing` → Distance conditions (ALREADY EXISTS)
- ✅ `EventBus.combat_step` → 30Hz fixed-step system (ALREADY EXISTS)

### **NEW Components Only:**
- `PatternEventConfig.gd` (Resource) - Links patterns to existing events
- `PatternEventHandler.gd` (Handler) - Follows existing template pattern
- `PatternEventInstance` (extends EventInstance) - Adds pattern tracking
- Visual theming functions - Uses existing `EventDefinition.visual_config`
- Linear generation mode - Adds to existing `ProceduralArenaGenerator`

## 🎯 Success Criteria

1. **Designer can create patterns** → TileMap editor + existing `TilePatternConfig` system ✅
2. **Pattern-event linking** → New `PatternEventConfig` bridges patterns to existing events
3. **Event compatibility** → Patterns spawn events using existing `EventDefinition` system
4. **Visual theming works** → Pattern tiles get color-tinted based on event type
5. **Events are accessible** → Leverage existing accessibility validation systems
6. **Zone triggers activate** → Reuse existing `EventInstance.zone` Area2D system
7. **Mastery integration** → Events get bonuses from existing passive system
8. **Path-based generation** → Linear map mode with pattern-event checkpoints

## 💡 Key Architecture Decisions

**✅ CORRECT APPROACH:**
- **Integration over recreation** - Extend existing sophisticated systems
- **Pattern-Event bridge** - Link patterns to existing event types
- **Reuse existing handlers** - Follow `BreachEventHandler` template
- **Leverage existing mastery** - Use current passive bonus system
- **Minimal new components** - Only bridge components needed

**❌ AVOIDED MISTAKES:**
- ~~Creating duplicate EventDefinition system~~ (already exists!)
- ~~Building new event managers~~ (EventMasterySystem exists!)
- ~~New trigger systems~~ (EventInstance.zone exists!)
- ~~Custom modifier systems~~ (mastery modifiers exist!)

## 📊 Development Impact

**Estimated Timeline:** 3-4 weeks (reduced from 5 weeks)
**Risk Level:** Low-Medium (leveraging proven systems)
**Code Complexity:** Moderate (integration vs recreation)
**Maintenance:** Low (follows existing patterns)

---

**Next Action:** Phase 1 - Create `PatternEventConfig.gd` resource
**Integration Priority:** High (builds on existing robust foundation)
**Architecture:** Extend existing systems, don't reinvent