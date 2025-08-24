# Map Definitions

Level and arena layout definitions for game environments.

## Implementation Status

**Status**: 📋 **TODO** - Not yet implemented

Current arena data exists in `/data/arena/` but will be integrated into this system.

## Planned Features

When implemented, maps will include:
- **Layout definitions** with tile/object placement
- **Spawn point configurations** for enemies and players
- **Environmental hazards** and interactive elements
- **Navigation mesh** data for AI pathfinding
- **Visual themes** and asset references
- **Difficulty scaling** properties

## Authoring Options

### Option 1: Tiled Integration
- Use **Tiled Map Editor** for visual design
- Import TMX/JSON files into Godot
- Standardized layer names:
  - `Collision` - Solid barriers
  - `Spawns_Enemy` - Enemy spawn points  
  - `Spawns_Player` - Player start positions
  - `Navigation` - Pathfinding mesh
  - `Triggers` - Interactive zones

### Option 2: Data-Driven Maps
- Pure JSON definitions for procedural generation
- Runtime instantiation of map elements
- More flexible for dynamic content

### Option 3: Hybrid Approach
- Base layouts from Tiled
- Dynamic elements via JSON overlay
- Best of both worlds

## Schema (Planned)

Maps will use Godot Resources (.tres files) following the pattern established by the enemy system:

```tres
[gd_resource type="Resource" script_class="MapType" load_steps=2 format=3]
[ext_resource type="Script" path="res://scripts/domain/MapType.gd" id="1"]
[resource]
script = ExtResource("1")
id = "basic_arena"
display_name = "Training Arena"
map_type = "arena"
width = 800
height = 600
player_spawn_x = 400.0
player_spawn_y = 300.0
enemy_spawn_zones = [Vector2(100, 100), Vector2(700, 500)]
spawn_zone_radius = 50.0
collision_layers = ["walls", "obstacles"]
theme = "dungeon"
enemy_spawn_rate_modifier = 1.0
environmental_hazards_enabled = false
```

## Integration Standards

- **Decouple spawn system** from map assets
- **Consistent metadata** for spawns, triggers, zones
- **Modular design** for easy iteration
- **Hot-reload support** for rapid development

## Related Systems (Future)

- **ContentDB**: Will load map definitions
- **Arena System**: Current arena management (will integrate)
- **Wave Director**: Uses spawn configurations
- **Navigation System**: Pathfinding integration
- **Map Editor**: Visual editing tools

## Hot-Reload

Will support **automatic hot-reload** when implemented, using Godot's native resource reloading system.

---

**Next Steps**: Choose authoring approach and define map schema