# Event System Implementation Prompt - Multi-Mind V1

**Reference Document:** `Obsidian/02-brainstorm/ARENA_PROGRESSION/MULTI_MIND_MAP_PROGRESSION_AND_EVENTS_V1.md`

## Implementation Overview

Implement **Phase 1 + Phase 1.5** of the Multi-Mind V1 approach: Core Event System with PoE Atlas-style Mastery Foundation (3-5 hours total).

**Key Approach:** Build PoE Atlas-style mastery system where players earn points by completing events, then spend points on passives to modify future event behavior (density, duration, rewards).

---

## Phase 1: Core Event System with Mastery Foundation (2-3 hours)

### **Goal**
Create 4 basic event types using existing SpawnDirector infrastructure + mastery point tracking foundation.

### **Event Types to Implement**
1. **Breach**: Portal-style waves of enemies emerging over time
2. **Ritual**: Defend objective while enemies attack from all sides
3. **Pack Hunt**: Elite pack (1 rare + 3-5 magic enemies) with superior rewards
4. **Boss Encounter**: Special boss mechanics with unique rewards

### **Core Architecture**

#### **1. EventMasteryTree Resource (NEW)**
```gdscript
# scripts/resources/EventMasteryTree.gd
extends Resource
class_name EventMasteryTree

@export var breach_points: int = 0
@export var ritual_points: int = 0
@export var pack_hunt_points: int = 0
@export var boss_points: int = 0

@export var allocated_passives: Dictionary = {}  # passive_id -> allocated

func is_passive_allocated(passive_id: StringName) -> bool:
    return allocated_passives.get(passive_id, false)

func can_allocate_passive(passive_id: StringName, required_points: int, event_type: StringName) -> bool:
    var available_points = get_points_for_event_type(event_type)
    return available_points >= required_points and not is_passive_allocated(passive_id)

func get_points_for_event_type(event_type: StringName) -> int:
    match event_type:
        "breach": return breach_points
        "ritual": return ritual_points
        "pack_hunt": return pack_hunt_points
        "boss": return boss_points
        _: return 0

func allocate_passive(passive_id: StringName, cost: int, event_type: StringName):
    if can_allocate_passive(passive_id, cost, event_type):
        allocated_passives[passive_id] = true
        # Deduct points logic if needed
```

#### **2. EventDefinition Resource (NEW)**
```gdscript
# scripts/resources/EventDefinition.gd
extends Resource
class_name EventDefinition

@export var id: StringName
@export var display_name: String
@export var event_type: StringName  # "breach", "ritual", "pack_hunt", "boss"
@export var duration: float = 30.0
@export var base_config: Dictionary = {
    "monster_count": 8,
    "spawn_interval": 2.0,
    "xp_multiplier": 3.0,
    "formation": "circle"
}
@export var reward_config: Dictionary = {}
@export var visual_config: Dictionary = {}
```

#### **3. EventMasterySystem (NEW)**
```gdscript
# scripts/systems/EventMasterySystem.gd
extends Node

var mastery_tree: EventMasteryTree

func _ready():
    # Load or create mastery tree
    mastery_tree = load("user://mastery_tree.tres")
    if not mastery_tree:
        mastery_tree = EventMasteryTree.new()

    EventBus.event_completed.connect(_on_event_completed)

func apply_event_modifiers(event_def: EventDefinition) -> Dictionary:
    var modified_config = event_def.base_config.duplicate()

    match event_def.event_type:
        "breach":
            if mastery_tree.is_passive_allocated("breach_density_1"):
                modified_config["monster_count"] = int(modified_config["monster_count"] * 1.25)
            if mastery_tree.is_passive_allocated("breach_duration_1"):
                modified_config["duration"] = event_def.duration + 3.0

        "ritual":
            if mastery_tree.is_passive_allocated("ritual_area_1"):
                modified_config["circle_radius"] = modified_config.get("circle_radius", 200) * 1.5
            if mastery_tree.is_passive_allocated("ritual_spawn_rate_1"):
                modified_config["spawn_interval"] -= 1.0

        "pack_hunt":
            if mastery_tree.is_passive_allocated("pack_density_1"):
                modified_config["rare_companions"] = modified_config.get("rare_companions", 3) + 1
            if mastery_tree.is_passive_allocated("pack_rewards_1"):
                modified_config["xp_multiplier"] *= 1.3

    return modified_config

func _on_event_completed(event_type: StringName, performance_data: Dictionary):
    # Award mastery points (1 per completion)
    match event_type:
        "breach": mastery_tree.breach_points += 1
        "ritual": mastery_tree.ritual_points += 1
        "pack_hunt": mastery_tree.pack_hunt_points += 1
        "boss": mastery_tree.boss_points += 1

    # Save progress
    ResourceSaver.save(mastery_tree, "user://mastery_tree.tres")

    EventBus.mastery_points_earned.emit(event_type, 1)
```

### **Integration Points**

#### **4. SpawnDirector Enhancement**
```gdscript
# Modify scripts/systems/SpawnDirector.gd
# Add event spawning capabilities

var event_system_enabled: bool = false
var event_timer: float = 0.0
var next_event_delay: float = 45.0
var active_events: Array[Dictionary] = []
var mastery_system: EventMasterySystem

func _ready():
    mastery_system = EventMasterySystem.new()
    add_child(mastery_system)

func _process(dt: float):
    # Existing spawning logic...

    if event_system_enabled:
        _handle_event_spawning(dt)

func _handle_event_spawning(dt: float):
    event_timer += dt
    if event_timer >= next_event_delay:
        event_timer = 0.0
        _trigger_random_event()

func _trigger_random_event():
    var available_zones = _get_available_spawn_zones()
    if available_zones.is_empty():
        return

    var zone = available_zones[RNG.stream("events").randi() % available_zones.size()]
    var event_types = ["breach", "ritual", "pack_hunt", "boss"]
    var event_type = event_types[RNG.stream("events").randi() % event_types.size()]

    var event_def = _load_event_definition(event_type)
    var modified_config = mastery_system.apply_event_modifiers(event_def)

    _spawn_event_at_zone(event_def, modified_config, zone)

func _spawn_event_at_zone(event_def: EventDefinition, config: Dictionary, zone: Area2D):
    # Use existing pack spawning logic with event-specific parameters
    var monster_count = config.get("monster_count", 8)
    var formation = config.get("formation", "circle")

    # Apply existing pack spawning but with event rewards
    _spawn_pack_at_zone(zone, monster_count, formation)

    # Track event for completion
    active_events.append({
        "type": event_def.event_type,
        "zone": zone,
        "start_time": Time.get_time_dict_from_system(),
        "config": config
    })
```

#### **5. MapConfig Integration**
```gdscript
# Modify scripts/resources/MapConfig.gd
# Add event system configuration

@export_group("Event System")
@export var event_spawn_enabled: bool = true
@export var event_spawn_interval: float = 45.0
@export var available_events: Array[StringName] = ["breach", "ritual", "pack_hunt", "boss"]
@export var event_reward_multiplier: float = 3.0
```

#### **6. EventBus Signals**
```gdscript
# Modify autoload/EventBus.gd
# Add event and mastery signals

# Event system signals
signal event_started(event_type: StringName, zone: Area2D)
signal event_completed(event_type: StringName, performance_data: Dictionary)
signal event_failed(event_type: StringName, reason: String)

# Mastery system signals
signal mastery_points_earned(event_type: StringName, points: int)
signal passive_allocated(passive_id: StringName)
signal passive_deallocated(passive_id: StringName)
```

---

## Phase 1.5: Event Mastery Tree UI (1-2 hours)

### **Goal**
Create simple UI for viewing mastery points and allocating passives.

### **UI Architecture**

#### **7. MasteryTreeUI Scene & Script**
```gdscript
# scripts/ui/MasteryTreeUI.gd
class_name MasteryTreeUI extends Control

@export var mastery_system: EventMasterySystem
@onready var tab_container = $TabContainer
@onready var points_labels: Dictionary = {}
@onready var passive_buttons: Dictionary = {}

var passive_definitions: Dictionary = {
    "breach_density_1": {
        "name": "Breach Density I",
        "description": "Breaches spawn 25% more monsters",
        "cost": 3,
        "event_type": "breach"
    },
    "breach_duration_1": {
        "name": "Breach Duration I",
        "description": "Breaches last 3 seconds longer",
        "cost": 2,
        "event_type": "breach"
    },
    "ritual_area_1": {
        "name": "Ritual Area I",
        "description": "Ritual circles are 50% larger",
        "cost": 2,
        "event_type": "ritual"
    }
    # Add more passive definitions...
}

func _ready():
    _setup_ui()
    _refresh_ui()

    EventBus.mastery_points_earned.connect(_on_mastery_points_earned)
    EventBus.passive_allocated.connect(_on_passive_allocated)

func _setup_ui():
    # Create tabs for each event type
    for event_type in ["breach", "ritual", "pack_hunt", "boss"]:
        var tab = _create_event_tab(event_type)
        tab_container.add_child(tab)

func _create_event_tab(event_type: String) -> Control:
    var tab = VBoxContainer.new()
    tab.name = event_type.capitalize()

    # Points display
    var points_label = Label.new()
    points_label.text = "Points: 0"
    points_labels[event_type] = points_label
    tab.add_child(points_label)

    # Passive buttons
    var passives_container = VBoxContainer.new()
    for passive_id in passive_definitions:
        var passive_def = passive_definitions[passive_id]
        if passive_def.event_type == event_type:
            var button = _create_passive_button(passive_id, passive_def)
            passives_container.add_child(button)
            passive_buttons[passive_id] = button

    tab.add_child(passives_container)
    return tab

func _create_passive_button(passive_id: StringName, passive_def: Dictionary) -> Button:
    var button = Button.new()
    button.text = "%s (%d pts)\n%s" % [passive_def.name, passive_def.cost, passive_def.description]
    button.pressed.connect(_on_passive_button_pressed.bind(passive_id))
    return button

func _on_passive_button_pressed(passive_id: StringName):
    var passive_def = passive_definitions[passive_id]

    if mastery_system.mastery_tree.can_allocate_passive(passive_id, passive_def.cost, passive_def.event_type):
        mastery_system.mastery_tree.allocate_passive(passive_id, passive_def.cost, passive_def.event_type)
        EventBus.passive_allocated.emit(passive_id)
        _refresh_ui()

func _refresh_ui():
    # Update point displays
    for event_type in points_labels:
        var points = mastery_system.mastery_tree.get_points_for_event_type(event_type)
        points_labels[event_type].text = "Points: %d" % points

    # Update passive button states
    for passive_id in passive_buttons:
        var button = passive_buttons[passive_id]
        var passive_def = passive_definitions[passive_id]
        var allocated = mastery_system.mastery_tree.is_passive_allocated(passive_id)
        var can_allocate = mastery_system.mastery_tree.can_allocate_passive(passive_id, passive_def.cost, passive_def.event_type)

        button.disabled = allocated or not can_allocate
        button.modulate = Color.WHITE if can_allocate else Color.GRAY

func _on_mastery_points_earned(event_type: StringName, points: int):
    _refresh_ui()

func _on_passive_allocated(passive_id: StringName):
    _refresh_ui()
```

---

## Implementation Checklist

### **Phase 1 - Core Event System (2-3 hours)**
- [ ] Create EventMasteryTree resource with point tracking
- [ ] Create EventDefinition resource for data-driven events
- [ ] Create EventMasterySystem for modifier application
- [ ] Modify SpawnDirector to support event spawning with modifiers
- [ ] Add event configuration to MapConfig
- [ ] Add event/mastery signals to EventBus
- [ ] Create basic event .tres files (breach, ritual, pack_hunt, boss)
- [ ] Test event spawning and mastery point earning

### **Phase 1.5 - Mastery Tree UI (1-2 hours)**
- [ ] Create MasteryTreeUI scene with tab container
- [ ] Implement passive allocation/deallocation logic
- [ ] Add visual feedback for allocated/available/locked passives
- [ ] Test UI integration with mastery system
- [ ] Add respec functionality for testing

### **Integration Testing**
- [ ] Events spawn every 30-60 seconds using existing zones
- [ ] Mastery points earned correctly (1 per event completion)
- [ ] Allocated passives modify event behavior (density, duration, rewards)
- [ ] UI reflects current mastery state accurately
- [ ] No interference with existing auto/pack spawning

---

## Key Files to Create/Modify

### **New Files**
- `scripts/resources/EventMasteryTree.gd`
- `scripts/systems/EventMasterySystem.gd`
- `scripts/resources/EventDefinition.gd`
- `scenes/ui/MasteryTreeUI.tscn`
- `scripts/ui/MasteryTreeUI.gd`
- `data/content/events/breach_basic.tres`
- `data/content/events/ritual_basic.tres`
- `data/content/events/pack_hunt_basic.tres`
- `data/content/events/boss_basic.tres`

### **Modified Files**
- `scripts/systems/SpawnDirector.gd` - Add event spawning
- `scripts/resources/MapConfig.gd` - Add event configuration
- `autoload/EventBus.gd` - Add event/mastery signals

---

## Success Criteria

### **Functional Requirements**
- 4 event types spawn and complete successfully
- Mastery points earned and tracked per event type
- Passive allocation affects event behavior visibly
- Simple UI allows point spending and shows progression
- Events provide superior rewards vs baseline spawning

### **Technical Requirements**
- Builds on existing SpawnDirector architecture
- Uses typed GDScript and follows CLAUDE.md conventions
- All data configurable via .tres resources
- Proper signal-based communication via EventBus
- No performance regression in combat systems

### **User Experience**
- Clear visual feedback when earning mastery points
- Understandable passive descriptions and effects
- Immediate satisfaction from event completion
- Strategic choice in passive allocation
- Progression feeling meaningful and impactful

---

**Start with Phase 1, then immediately implement Phase 1.5 for complete foundation. This gives you the full PoE Atlas-style progression system in just 3-5 hours total.**