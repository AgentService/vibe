# Arena System Usage Guide - Vibe Coding Style

## 🎮 System Architecture Overview

The arena system follows vibe's **layered, signal-driven, data-first** architecture:

```
ArenaSystem (Coordinator)
├── TerrainSystem (Floor tiles)
├── ObstacleSystem (Pillars, walls, crates)  
├── InteractableSystem (Chests, doors, altars)
├── WallSystem (Boundary collision)
└── TextureThemeSystem (Visual themes)
```

## 📁 Data-Driven Configuration

### Directory Structure
```
/data/arena/
├── layouts/              # Arena definitions
│   ├── basic_arena.json  # Arena config
│   └── rooms/            # Individual rooms
│       └── combat_room_001.json
└── themes/               # Future: theme configs

/assets/sprites/          # Visual assets (optional)
├── walls/themes/{theme}/
├── terrain/themes/{theme}/
├── obstacles/themes/{theme}/
└── interactables/
```

### JSON Schema Pattern
```json
// Arena Definition
{
  "id": "dungeon_level_1", 
  "name": "Stone Dungeon",
  "start_room": "entrance_hall",
  "bounds": {"x": -400, "y": -300, "width": 800, "height": 600}
}

// Room Layout  
{
  "id": "combat_room",
  "boundaries": {"arena_size": {"x": 800, "y": 600}},
  "terrain": {"tiles": [...]},
  "obstacles": {"objects": [...]},
  "interactables": {"objects": [...]}
}
```

## 🎮 Usage Patterns

### Loading Arenas
```gdscript
# In Arena.gd _ready()
arena_system.load_arena("basic_arena")

# Or dynamically switch
arena_system.load_room("boss_chamber")
```

### Theme Switching
```gdscript
# Change visual theme
texture_theme_system.set_theme("cave")     # Brown earth
texture_theme_system.set_theme("tech")     # Blue metal  
texture_theme_system.set_theme("forest")   # Green overgrown
```

### Adding New Objects
```json
// In room JSON
"obstacles": {
  "objects": [
    {
      "id": "pillar_5",
      "type": "pillar",
      "x": 100, "y": -50,
      "size": {"width": 32, "height": 32},
      "destructible": false
    }
  ]
}
```

## 🔧 Extension Points

### New Object Types
1. **Add to JSON schemas** in room definitions
2. **Extend system handlers** in ObstacleSystem/InteractableSystem  
3. **Add texture generation** in TextureThemeSystem
4. **Update MultiMesh setup** in Arena.gd if needed

### New Themes
```gdscript
// In TextureThemeSystem.themes
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

## 🎯 Vibe Coding Principles Applied

1. **Data-Driven**: All configuration in JSON, hot-reloadable
2. **Signal-Based**: No direct node references, loose coupling  
3. **Performance-First**: MultiMesh rendering, object pooling ready
4. **Mechanics-First**: Collision working before visuals perfected
5. **Fallback Systems**: Procedural generation when assets missing
6. **Expandable Architecture**: Easy addition of new systems/content

## 🔍 Debugging Tools

```gdscript
# Enable debug output (temporary)
print("Arena loaded: ", arena_data.get("name"))
print("Wall transforms: ", wall_system.wall_transforms.size())

# Check system state
arena_system.get_arena_bounds()  # Rect2 boundaries
texture_theme_system.get_available_themes()  # ["dungeon", "cave", ...]
```

## 💡 What Works Right Now

After the latest implementation, the following features are fully operational:

- ✅ **Arena Loading**: `arena_system.load_arena("basic_arena")` loads from JSON
- ✅ **Wall Collision**: Player cannot pass through arena boundaries
- ✅ **Visual Rendering**: Procedural wall textures via MultiMesh 
- ✅ **Theme System**: Switch between dungeon/cave/tech/forest themes
- ✅ **Signal Flow**: All systems communicate via EventBus and typed signals
- ✅ **Data Configuration**: JSON-driven room layouts and arena definitions
- ✅ **Performance**: MultiMesh rendering handles hundreds of objects efficiently
- ✅ **Expandability**: Easy addition of new object types and room content

This system provides a **production-ready foundation** for complex rogue-like environments while maintaining vibe's architectural principles!