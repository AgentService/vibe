# New Arena Creation Guide

## 🎯 Overview

This guide shows you how to create new arenas using the **MapConfig system** based on the proven UnderworldArena implementation. Follow these steps to create fully-functional arenas with zone-based spawning and hot-reloadable configuration.

**★ Insight ─────────────────────────────────────**
- **MapConfig Pattern**: Data-driven arena configuration using .tres resources
- **Zone-Based Spawning**: Weighted spawn zones for tactical enemy placement
- **Arena Inheritance**: Extend Arena.gd for arena-specific behavior while maintaining compatibility
**─────────────────────────────────────────────────**

## 🚀 Quick Start Checklist

### Phase 1: Create Configuration
- [ ] Create MapConfig .tres file in `data/content/maps/`
- [ ] Define spawn zones with positions, radii, and weights
- [ ] Set theme tags and environmental properties

### Phase 2: Create Scene Structure
- [ ] Create arena .tscn file in `scenes/arena/`
- [ ] Add required node structure (SpawnZones, ArenaRoot, etc.)
- [ ] Create Area2D zones matching MapConfig data

### Phase 3: Implement Arena Logic
- [ ] Create arena .gd script extending Arena.gd
- [ ] Export MapConfig property for Inspector assignment
- [ ] Override methods for arena-specific behavior

### Phase 4: Integration & Testing
- [ ] Assign MapConfig to arena scene via Inspector
- [ ] Test zone spawning with F12 debug panel
- [ ] Verify logs show proper zone initialization

## 📋 Step-by-Step Implementation

### Step 1: Create MapConfig Resource

Create your arena configuration file:

**File**: `data/content/maps/forest_config.tres`

```tres
[gd_resource type="Resource" script_class="MapConfig" load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/resources/MapConfig.gd" id="1"]

[resource]
script = ExtResource("1")
map_id = &"forest_arena"
display_name = "Enchanted Forest"
description = "A mystical forest arena with ancient trees and magical clearings"

# Visual Configuration
theme_tags = Array[StringName]([&"forest", &"nature", &"magical", &"green"])
ambient_light_color = Color(0.6, 0.9, 0.6, 1)  # Green tint
ambient_light_energy = 0.4

# Gameplay Configuration
arena_bounds_radius = 550.0
spawn_radius = 450.0
player_spawn_position = Vector2(0, 0)

# Spawn Zone Definitions
spawn_zones = Array[Dictionary]([{
"name": "ancient_grove",
"position": Vector2(0, -350),
"radius": 90.0,
"weight": 1.2
}, {
"name": "mushroom_circle",
"position": Vector2(300, 200),
"radius": 70.0,
"weight": 1.0
}, {
"name": "fairy_pond",
"position": Vector2(-300, 100),
"radius": 60.0,
"weight": 0.8
}, {
"name": "treant_clearing",
"position": Vector2(0, 300),
"radius": 100.0,
"weight": 1.5
}])

# Boss spawn locations
boss_spawn_positions = Array[Vector2]([
Vector2(0, -250),    # Ancient Grove boss
Vector2(400, 0),     # Forest edge boss
Vector2(-400, 0)     # Dark woods boss
])

# Environmental Settings
max_concurrent_enemies = 45
has_environmental_hazards = true
weather_effects = Array[StringName]([&"magical_particles", &"wind_rustling"])
special_mechanics = Array[StringName]([&"healing_springs", &"entangling_vines"])

# Custom Properties
custom_properties = {
"nature_healing_rate": 2.0,
"vine_entangle_chance": 0.15,
"magical_essence_bonus": 0.25
}
```

### Step 2: Create Arena Scene Structure

**File**: `scenes/arena/ForestArena.tscn`

Create scene with this node hierarchy:

```
ForestArena (Node2D) [Script: ForestArena.gd]
├── SpawnZones (Node2D)                    # Spawn zone container
│   ├── AncientGrove (Area2D)              # Zone 1: Ancient Grove
│   │   └── CollisionShape2D               # CircleShape2D (radius: 90)
│   ├── MushroomCircle (Area2D)            # Zone 2: Mushroom Circle
│   │   └── CollisionShape2D               # CircleShape2D (radius: 70)
│   ├── FairyPond (Area2D)                 # Zone 3: Fairy Pond
│   │   └── CollisionShape2D               # CircleShape2D (radius: 60)
│   └── TreantClearing (Area2D)            # Zone 4: Treant Clearing
│       └── CollisionShape2D               # CircleShape2D (radius: 100)
├── ArenaRoot (Node2D)                     # Enemy spawn parent
├── VisualEnvironment (Node2D)             # Visual decoration
│   ├── Trees (Node2D)                     # Tree sprites
│   ├── GroundLayer (Node2D)               # Ground textures
│   └── EffectsLayer (Node2D)              # Particle effects
├── PlayerSpawnPoint (Marker2D)            # Player start position
└── EnvironmentalSounds (AudioStreamPlayer2D) # Ambient forest sounds
```

**Zone Positioning Tips:**
- Position Area2D nodes to match MapConfig spawn_zones positions exactly
- Set CollisionShape2D radius to match MapConfig radius values
- Use Marker2D nodes as visual guides during scene creation

### Step 3: Implement Arena Script

**File**: `scenes/arena/ForestArena.gd`

```gdscript
class_name ForestArena
extends "res://scenes/arena/Arena.gd"

## Enchanted forest arena with nature-themed mechanics
## Extends Arena with forest-specific environmental effects and spawning

@export var map_config: MapConfig ## Forest arena configuration
	set(value):
		map_config = value
		if is_node_ready():
			_apply_map_config()

@export_group("Forest Atmosphere")
## Enable magical particle effects
@export var enable_magical_particles: bool = true
## Enable wind sound effects
@export var enable_wind_sounds: bool = true
## Intensity of nature ambiance
@export var nature_ambiance_intensity: float = 1.0

@export_group("Environmental Mechanics")
## Enable healing springs in certain zones
@export var enable_healing_springs: bool = true
## Enable vine entanglement mechanics
@export var enable_vine_entanglement: bool = false
## Nature healing rate per second
@export var nature_healing_rate: float = 2.0

# Visual effects nodes (set up in scene)
@onready var ambient_light: CanvasModulate = get_node_or_null("CanvasModulate")
@onready var magical_particles: GPUParticles2D = get_node_or_null("VisualEnvironment/EffectsLayer/MagicalParticles")
@onready var wind_sounds: AudioStreamPlayer2D = get_node_or_null("EnvironmentalSounds")

# Spawn zone management (inherited from Arena.gd pattern)
@onready var spawn_zones_container: Node2D = $SpawnZones
var _spawn_zone_areas: Array[Area2D] = []

func _ready() -> void:
	Logger.info("=== FORESTARENA._READY() STARTING ===", "debug")

	# Apply forest-specific configuration first
	if map_config:
		_apply_map_config()
	else:
		# Load default forest config if none assigned
		_load_default_config()

	# Call parent Arena initialization (this does the heavy lifting)
	super._ready()

	# Setup forest-specific atmosphere after Arena systems are ready
	_setup_forest_atmosphere()

	# Initialize spawn zones for efficient access
	_initialize_spawn_zones()

	Logger.info("ForestArena initialization complete: %s" %
		(map_config.display_name if map_config else "Default Forest"), "arena")

func _load_default_config() -> void:
	"""Load default forest configuration if no MapConfig assigned"""
	var default_config = load("res://data/content/maps/forest_config.tres")
	if default_config:
		map_config = default_config
		Logger.info("Loaded default forest config", "arena")
	else:
		Logger.warn("No default forest config found", "arena")

func _apply_map_config() -> void:
	"""Apply MapConfig settings to forest arena"""
	if not map_config:
		return

	# Apply basic arena settings
	if map_config.custom_properties.has("nature_healing_rate"):
		nature_healing_rate = map_config.custom_properties.nature_healing_rate

	if map_config.custom_properties.has("magical_essence_bonus"):
		# Apply magical essence bonus (future enhancement)
		pass

	# Apply ambient lighting
	if ambient_light:
		ambient_light.color = map_config.ambient_light_color

	Logger.debug("Applied map config: %s" % map_config.display_name, "arena")

func _setup_forest_atmosphere() -> void:
	"""Configure forest-specific visual and audio atmosphere"""

	# Setup magical particle effects
	if magical_particles and enable_magical_particles:
		magical_particles.emitting = true
		Logger.debug("Magical particles enabled", "arena")

	# Setup ambient wind sounds
	if wind_sounds and enable_wind_sounds:
		wind_sounds.volume_db = -10.0 + (nature_ambiance_intensity * 5.0)
		wind_sounds.play()
		Logger.debug("Wind sounds enabled", "arena")

## Override spawn radius from map config
func get_spawn_radius() -> float:
	if map_config:
		return map_config.spawn_radius
	return 450.0  # Default forest spawn radius

## Override arena bounds from map config
func get_arena_bounds() -> float:
	if map_config:
		return map_config.arena_bounds_radius
	return 550.0  # Default forest bounds

## Get spawn zones for enemy spawning
func get_spawn_zones() -> Array[Dictionary]:
	if map_config:
		return map_config.spawn_zones
	return []

## Get random spawn zone weighted by spawn zone weights
func get_weighted_spawn_zone() -> Dictionary:
	if map_config:
		return map_config.get_weighted_spawn_zone()
	return {}

## Override spawn position to use forest zones instead of simple radius
func get_random_spawn_position() -> Vector2:
	# If no config zones, fall back to parent radius-based spawning
	if not map_config or map_config.spawn_zones.is_empty():
		# Fallback to simple radius spawning
		var angle := randf() * TAU
		var distance := randf() * get_spawn_radius()
		return Vector2(cos(angle), sin(angle)) * distance

	# Use weighted zone selection from MapConfig
	var selected_zone_data = get_weighted_spawn_zone()
	if selected_zone_data.is_empty():
		# Fallback if zone selection fails
		var angle := randf() * TAU
		var distance := randf() * get_spawn_radius()
		return Vector2(cos(angle), sin(angle)) * distance

	# Generate random position within selected zone
	var zone_pos = selected_zone_data.get("position", Vector2.ZERO)
	var zone_radius = selected_zone_data.get("radius", 50.0)

	var angle = randf() * TAU
	var distance = randf() * zone_radius
	return zone_pos + Vector2(cos(angle), sin(angle)) * distance

## Initialize spawn zone cache for efficient access
func _initialize_spawn_zones() -> void:
	if spawn_zones_container:
		for child in spawn_zones_container.get_children():
			if child is Area2D:
				_spawn_zone_areas.append(child)
		Logger.debug("Initialized %d spawn zones" % _spawn_zone_areas.size(), "arena")

## Get arena theme tags for future modifier/effect systems
func get_theme_tags() -> Array[StringName]:
	if map_config:
		return map_config.theme_tags
	return [&"forest"]

## Check if arena has environmental hazards
func has_environmental_hazards() -> bool:
	if map_config:
		return map_config.has_environmental_hazards
	return enable_healing_springs

## Future method for nature healing application
func _apply_nature_healing_to_entity(entity_id: EntityId) -> void:
	"""Apply nature healing to entity (future environmental effect system)"""
	if not enable_healing_springs:
		return

	# Future implementation would integrate with DamageService
	Logger.debug("Nature healing applied to entity: %s" % entity_id, "arena")
```

### Step 4: Scene Configuration via Inspector

1. **Open ForestArena.tscn in Godot**
2. **Select root ForestArena node**
3. **In Inspector, assign Map Config property**:
   - Click dropdown next to "Map Config"
   - Choose "Load" → Navigate to `data/content/maps/forest_config.tres`
   - Assign the resource

4. **Configure Area2D zones**:
   - Select each Area2D in SpawnZones
   - Position them to match MapConfig coordinates:
     - AncientGrove: Position (0, -350)
     - MushroomCircle: Position (300, 200)
     - FairyPond: Position (-300, 100)
     - TreantClearing: Position (0, 300)
   - Set CollisionShape2D radius to match MapConfig values

### Step 5: Integration with Game Systems

Your arena automatically integrates with:

**WaveDirector Integration:**
```gdscript
# WaveDirector calls your arena's method automatically:
var spawn_pos = current_scene.get_random_spawn_position()
# This uses your forest zones with weighted selection!
```

**Debug Panel Integration:**
- F12 → Enable Auto Spawn uses your zones automatically
- Manual spawn buttons respect your arena bounds
- Performance stats monitor your zone spawning

**StateManager Integration:**
```gdscript
# Load via debug config
arena_selection = "Enchanted Forest"

# Or programmatically
StateManager.go_to_arena("forest_arena")
```

## 🧪 Testing Your Arena

### Basic Functionality Test
1. **Open ForestArena.tscn and play scene**
2. **Check console logs for**:
   ```
   [INFO:ARENA] ForestArena initialization complete: Enchanted Forest
   [DEBUG:ARENA] Initialized 4 spawn zones
   [DEBUG:ARENA] Applied map config: Enchanted Forest
   ```

### Spawn Zone Test
1. **Enable F12 debug panel**
2. **Click "Auto Spawn" toggle**
3. **Verify enemies spawn in your 4 zones**:
   - Ancient Grove (north)
   - Mushroom Circle (southeast)
   - Fairy Pond (southwest)
   - Treant Clearing (south)

### Hot-Reload Test
1. **Edit forest_config.tres**:
   - Change spawn zone weights
   - Modify arena bounds or spawn radius
2. **Press F5 in game**
3. **Verify changes take effect without restart**

## 🎨 Visual Enhancements

### Adding Visual Decoration
```gdscript
# In _setup_forest_atmosphere():
func _setup_forest_decoration() -> void:
    # Add tree sprites around zones
    for zone in _spawn_zone_areas:
        _add_trees_around_zone(zone)

    # Add ground textures
    _setup_forest_ground_textures()

    # Add ambient lighting effects
    _setup_magical_ambient_lighting()
```

### Environmental Effects
```gdscript
# Add to forest arena for immersion:
@export var healing_spring_positions: Array[Vector2] = []
@export var entangling_vine_areas: Array[Area2D] = []

func _on_player_entered_healing_area(area: Area2D) -> void:
    # Apply healing over time
    EventBus.environmental_effect_triggered.emit("healing_spring", area.global_position)
```

## 🔄 Advanced Patterns

### Arena-Specific Spawn Logic
```gdscript
# Override for more complex spawning:
func get_random_spawn_position() -> Vector2:
    var base_pos = super.get_random_spawn_position()

    # Forest-specific modifications:
    # - Avoid spawning in healing springs
    # - Prefer spawning near trees
    # - Apply forest-specific spawn rules

    return _apply_forest_spawn_modifiers(base_pos)
```

### Custom Zone Weights Based on Game State
```gdscript
func get_weighted_spawn_zone() -> Dictionary:
    if not map_config:
        return {}

    # Modify weights based on game progression
    var modified_zones = map_config.spawn_zones.duplicate()

    # Example: Increase ancient grove spawning at night
    if GameTime.is_night():
        for zone in modified_zones:
            if zone.name == "ancient_grove":
                zone.weight *= 1.5

    return _select_weighted_zone(modified_zones)
```

### Integration with Future Systems
```gdscript
# Prepare for future enhancements:
func get_zone_difficulty_modifier(zone_name: String) -> float:
    match zone_name:
        "ancient_grove": return 1.2  # Harder enemies
        "fairy_pond": return 0.8     # Easier enemies
        _: return 1.0

func get_zone_special_effects(zone_name: String) -> Array[StringName]:
    match zone_name:
        "ancient_grove": return [&"nature_resist", &"entangle"]
        "mushroom_circle": return [&"poison_clouds"]
        "fairy_pond": return [&"healing_aura"]
        "treant_clearing": return [&"root_snare"]
        _: return []
```

## 🚀 Next Steps

After creating your basic arena:

1. **Add Environmental Hazards**: Implement healing springs, entangling vines
2. **Create Arena Variants**: Day/night versions, seasonal variations
3. **Add Boss Integration**: Special boss spawn logic for forest themes
4. **Performance Optimization**: LOD systems for distant visual effects
5. **Audio Integration**: Dynamic music based on zone player is in

## 📚 References

- **Working Example**: `scenes/arena/UnderworldArena.tscn` + `UnderworldArena.gd`
- **Resource Reference**: `scripts/resources/MapConfig.gd`
- **System Integration**: `scripts/systems/WaveDirector.gd` (spawning integration)
- **Updated Documentation**: `ARENA_USAGE.md` (current patterns and debugging)

**★ Success Criteria ─────────────────────────────────────**
- ✅ Enemies spawn in your configured zones (not random radius)
- ✅ F12 auto spawn works immediately without additional setup
- ✅ Arena loads via debug config or scene transition
- ✅ Hot-reload (F5) applies .tres changes without restart
- ✅ Logs show proper zone initialization and configuration loading
**─────────────────────────────────────────────────**