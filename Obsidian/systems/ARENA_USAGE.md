# Arena System Usage Guide - Current Architecture

## 🎮 System Architecture Overview

The arena system follows vibe's **layered, signal-driven, data-first** architecture with **MapConfig-driven arenas**:

```
BaseArena (Core)
├── Arena.gd (Base implementation)
├── UnderworldArena.gd (Example extension)
└── YourArena.gd (New arena)

MapConfig (.tres)
├── Spawn zones with positions/weights
├── Visual theming configuration
├── Environmental effects settings
└── Hot-reloadable balance data
```

## 📁 Data-Driven Configuration

### Current Directory Structure
```
/data/content/maps/               # Arena configurations (.tres files)
├── underworld_config.tres        # Example: Underworld Arena config
├── forest_config.tres            # Future: Forest Arena
└── city_config.tres              # Future: Urban Arena

/scenes/arena/                    # Arena scene files (.tscn + .gd)
├── Arena.tscn                    # Base arena scene
├── Arena.gd                      # Base arena logic
├── UnderworldArena.tscn          # Underworld arena scene
├── UnderworldArena.gd            # Underworld-specific logic
└── YourArena.tscn               # Your new arena

/scripts/resources/               # Resource classes
└── MapConfig.gd                  # Arena configuration resource
```

### MapConfig Resource Pattern (.tres)
```gdscript
# Example: underworld_config.tres
[resource]
script = ExtResource("MapConfig.gd")
map_id = "underworld_arena"
display_name = "Underworld Arena"
arena_bounds_radius = 600.0
spawn_radius = 500.0

# Spawn zones with positions, radius, and weights
spawn_zones = [{
  "name": "north_cavern",
  "position": Vector2(0, -400),
  "radius": 80.0,
  "weight": 1.0
}, {
  "name": "center_pit",
  "position": Vector2(0, 0),
  "radius": 40.0,
  "weight": 0.5
}]

# Pack spawning configuration (required for pack system)
base_spawn_scaling = {
  "time_scaling_rate": 0.1,        # 10% scaling per minute
  "wave_scaling_rate": 0.15,       # 15% scaling per wave
  "pack_base_size_min": 5,         # Minimum enemies per pack
  "pack_base_size_max": 10,        # Maximum enemies per pack
  "max_scaling_multiplier": 2.5,   # Maximum scaling cap
  "pack_spawn_interval": 5.0      # Seconds between pack spawns
}
arena_scaling_overrides = {}       # Arena-specific overrides

# Environmental settings
theme_tags = ["underworld", "volcanic", "dark"]
ambient_light_color = Color(0.8, 0.3, 0.2, 1)
has_environmental_hazards = true
```

## 🎮 Usage Patterns

### Loading Arenas (Current Method)
```gdscript
# In Arena._ready() - MapConfig is @exported in scene
@export var map_config: MapConfig
if map_config:
    _apply_map_config()
else:
    _load_default_config()

# Override spawn position method for zone-based spawning
func get_random_spawn_position() -> Vector2:
    var selected_zone = get_weighted_spawn_zone()
    return zone_pos + random_offset_within_radius
```

### Spawn Zone Integration (SpawnDirector System)
```gdscript
# Zones are defined in MapConfig .tres files
# Arena automatically uses zones for enemy spawning
# SpawnDirector calls arena.get_random_spawn_position()
# Result: Enemies spawn in configured zones with weights

# Two spawning systems now active:
# 1. Auto spawn: Individual enemies in zones within 800px of player
# 2. Pack spawn: Enemy groups in zones within 1600px of player (60s interval)

# Debug F12 panel auto spawn respects zones automatically
# Pack spawning requires base_spawn_scaling configuration in MapConfig
```

### Creating New Arena Types
```gdscript
# 1. Extend Arena.gd (not BaseArena)
class_name MyArena extends "res://scenes/arena/Arena.gd"

# 2. Create MapConfig .tres with your zones
# 3. Override methods for arena-specific behavior
func get_random_spawn_position() -> Vector2:
    # Custom spawning logic for this arena type
```

## 🔧 Extension Points

### New Object Types
1. **Add to JSON schemas** in room definitions
2. **Extend system handlers** in arena components  
4. **Update MultiMesh setup** in Arena.gd if needed

### New Themes
```gdscript
// For future theme system
"volcano": {
  "name": "Volcanic Cavern",
  "wall_color": Color(0.8, 0.2, 0.1),
  "floor_color": Color(0.6, 0.1, 0.0), 
  "accent_color": Color(1.0, 0.4, 0.0)
}
```

### Custom Asset Pipeline
1. **Drop files** in `/assets/sprites/{type}/themes/{theme}/`
2. **Automatic fallback** to procedural if missing
3. **Power-of-2 sizes**: 32x32, 64x32 for GPU efficiency

## 🚀 Performance Patterns

### MultiMesh Rendering
- **Walls**: 60+ segments, 64x32px each
- **Terrain**: Variable tiles, 32x32px  
- **Objects**: Scalable to hundreds with object pooling
- **Textures**: Cached per theme with automatic cleanup

### Signal Communication
```gdscript
# System-to-system via signals (vibe pattern)
arena_system.walls_updated.connect(_update_wall_multimesh)
arena_system.arena_loaded.connect(_on_arena_loaded)

# Global events via EventBus
EventBus.loot_generated.emit(chest_id, "chest", loot_data)
```

## 🛠️ Troubleshooting Spawn Systems

### Common Pack Spawning Issues

1. **"Pack spawning: No arena map_config available"**
   - **Cause**: Arena scene missing `map_config` property or not loaded
   - **Fix**: Ensure arena extends Arena.gd and has `@export var map_config: MapConfig`

2. **"Pack spawning: Invalid map_config type"**
   - **Cause**: Missing `base_spawn_scaling` configuration in MapConfig .tres
   - **Fix**: Add pack spawning configuration to your MapConfig (see example above)

3. **Pack enemies not appearing on radar**
   - **Cause**: Scene-based enemies not registering with EntityTracker
   - **Fix**: Ensure scene enemies have proper EntityTracker registration in spawn flow

4. **Pack spawning not triggering**
   - **Interval**: Packs spawn every 60 seconds by default
   - **Range**: Player must be within 1600px of spawn zones
   - **Config**: Check `pack_spawn_interval` in `base_spawn_scaling`

### Migration Notes (WaveDirector → SpawnDirector)
- **API Changes**: All `WaveDirector` references updated to `SpawnDirector`
- **Method Names**: `setup_wave_director()` → `setup_spawn_director()`
- **Functionality**: All existing features preserved, pack spawning added
- **Compatibility**: Existing arena configurations remain functional

## 🏟️ Adding New Arenas (Current MapConfig System)

The current architecture uses **MapConfig resources** for data-driven arena creation:

### Step-by-Step Arena Creation

1. **Create MapConfig resource**: `data/content/maps/city_config.tres`
2. **Create arena scene**: `scenes/arena/CityArena.tscn`
3. **Create arena script**: `scenes/arena/CityArena.gd` (extends Arena.gd)

### MapConfig Resource Example
```tres
# city_config.tres
[gd_resource type="Resource" script_class="MapConfig"]
[resource]
script = ExtResource("MapConfig.gd")
map_id = "city_arena"
display_name = "Urban Battleground"
arena_bounds_radius = 700.0
spawn_radius = 600.0

# Define spawn zones for the city
spawn_zones = [{
  "name": "downtown_plaza",
  "position": Vector2(0, 0),
  "radius": 100.0,
  "weight": 1.5
}, {
  "name": "rooftop_east",
  "position": Vector2(400, -200),
  "radius": 80.0,
  "weight": 1.0
}, {
  "name": "alley_west",
  "position": Vector2(-300, 100),
  "radius": 60.0,
  "weight": 0.8
}]

theme_tags = ["urban", "modern", "destructible"]
ambient_light_color = Color(0.9, 0.9, 1.0, 1)
has_environmental_hazards = false
special_mechanics = ["building_destruction", "rooftop_access"]
```

### Arena Script Implementation
```gdscript
# CityArena.gd
class_name CityArena
extends "res://scenes/arena/Arena.gd"

@export var map_config: MapConfig

# City-specific properties
@export var building_destruction_enabled: bool = true
@export var traffic_density: float = 0.3

func _ready() -> void:
    # Apply MapConfig first
    if map_config:
        _apply_map_config()
    else:
        _load_default_city_config()

    # Call parent Arena._ready()
    super._ready()

    # City-specific setup
    _setup_urban_environment()

func _setup_urban_environment() -> void:
    Logger.info("Setting up urban environment", "arena")
    if building_destruction_enabled:
        _enable_building_destruction()

# Override for city-specific spawning logic
func get_random_spawn_position() -> Vector2:
    # Use MapConfig zones (inherited behavior)
    # Add city-specific spawn logic if needed
    return super.get_random_spawn_position()
```

### Scene Structure (Required Nodes)
```
CityArena (script: CityArena.gd)
├── SpawnZones (Node2D)                    # Container for zone visualization
│   ├── DowntownPlaza (Area2D)            # Zone 1
│   ├── RooftopEast (Area2D)              # Zone 2
│   └── AlleyWest (Area2D)                # Zone 3
├── ArenaRoot (Node2D)                    # Enemy spawn parent
├── Ground (Node2D)                       # Visual ground layer
├── Buildings (Node2D)                    # Building decoration
└── PlayerSpawnPoint (Marker2D)           # Player start position
```

### Integration with Game Systems

Your new arena automatically works with:
- ✅ **Zone-based spawning** - Uses MapConfig spawn zones
- ✅ **Auto spawn system** - F12 debug panel works immediately
- ✅ **WaveDirector integration** - Calls your get_random_spawn_position()
- ✅ **Hot-reload support** - Edit .tres file and press F5
- ✅ **StateManager** - Proper scene transitions

### Loading Your Arena

```gdscript
# Via debug config (config/debug.tres)
arena_selection = "City Arena"

# Via scene transition
SceneTransitionManager.load_scene("res://scenes/arena/CityArena.tscn")

# Via StateManager API
StateManager.go_to_arena("city_arena")
```

### Testing Your Arena

1. **MCP Integration**: Use `mcp__godot-mcp__open_scene` to load CityArena.tscn
2. **Direct testing**: Play scene from Godot editor
3. **Auto spawn testing**: F12 → Enable Auto Spawn (uses your zones)
4. **Log verification**: Check for "Initialized X spawn zones" in arena logs

## 🎯 Vibe Coding Principles Applied

1. **Data-Driven**: All configuration in .tres resources, hot-reloadable with F5
2. **Signal-Based**: Loose coupling via EventBus, no direct node references
3. **Performance-First**: Zone-based spawning, scene-based enemy rendering
4. **Mechanics-First**: Spawning logic working before complex visuals
5. **MapConfig Pattern**: Reusable resource system for arena configuration
6. **Expandable Architecture**: Easy addition of new arena types via inheritance
7. **Zone-Restricted Spawning**: Player proximity-based spawning for better gameplay

## 🔍 Debugging Tools

```gdscript
# Arena debugging (arena category logging)
Logger.debug("Initialized %d spawn zones" % zones.size(), "arena")
Logger.info("Arena loaded: %s" % map_config.display_name, "arena")

# F12 Debug Panel
# - Auto Spawn: Tests zone-restricted spawning
# - Enemy spawn buttons: Manual testing
# - Performance stats: Monitor spawn performance

# Check arena state
get_spawn_zones()  # Array[Dictionary] of zone data
get_random_spawn_position()  # Vector2 within zones
get_weighted_spawn_zone()  # Dictionary of selected zone
```

## 💡 What Works Right Now

After the latest MapConfig implementation, these features are fully operational:

- ✅ **Zone-Based Spawning**: Enemies spawn in configured zones with weights
- ✅ **MapConfig Integration**: .tres files drive arena configuration
- ✅ **Auto Spawn Zones**: F12 debug panel auto spawn respects zones
- ✅ **Hot-Reload Support**: Edit .tres files and press F5 to reload
- ✅ **Visual Zone Markers**: Area2D nodes show zones in editor
- ✅ **Weighted Selection**: Different zones have different spawn probabilities
- ✅ **Backward Compatibility**: Works with existing Arena.gd inheritance
- ✅ **MCP Integration**: Direct arena editing via Godot MCP tools
- ✅ **Progressive Enhancement**: Easy to add new features per arena type

This system provides a **production-ready foundation** for zone-controlled spawning while maintaining vibe's data-driven architectural principles!

## 🚀 Next Steps

**Immediate Opportunities:**
1. **Range-Based Spawning**: Only spawn in zones near the player
2. **Dynamic Monster Packs**: Pre-spawn groups of enemies in zones
3. **Progressive Scaling**: Increase spawn rates/counts with game progression
4. **Environmental Hazards**: Zone-specific damage/effects integration

**See Also:** `NEW_ARENA_CREATION_GUIDE.md` for step-by-step arena creation workflow