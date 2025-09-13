# Maps Structure

Map organization for the vibe game. Supports both quick prototyping and systematic map creation.

## Folders

### `/tilesets/`
- Shared TileSet resources (`.tres`)
- Physics layers, collision shapes, metadata
- Examples: `dungeon_tileset.tres`, `outdoor_tileset.tres`

### `/prototypes/`
- Quick test maps created directly in Godot editor
- Fast iteration for gameplay experiments
- Save as `.tscn` scenes for immediate testing
- Examples: `test_arena_01.tscn`, `wall_test.tscn`

### `/survival/`
- Wave survival mode maps
- Focus on enemy spawn zones and player movement
- Examples: `survival_basic.tscn`, `survival_cramped.tscn`

### `/boss/`
- Boss encounter arenas
- Specialized layouts for boss mechanics
- Examples: `boss_arena_01.tscn`, `boss_circular.tscn`

### `/templates/`
- Base scenes for inheritance
- Common setup (lighting, background, etc.)
- Examples: `base_map.tscn`, `base_arena.tscn`

## Workflow

1. **Prototype**: Create directly in editor → save to `/prototypes/`
2. **Iterate**: Test gameplay, adjust collision, spawn zones
3. **Systematize**: Extract common patterns → create tilesets
4. **Organize**: Move polished maps to appropriate category folders

## TileMapLayer Convention

- **Layer 0**: Floor (visual, no collision)
- **Layer 1**: Walls (collision + visual)
- **Layer 2**: Obstacles (destructible/interactive)
- **Layer 3**: Spawn zones (metadata only)
- **Layer 4**: Special areas (buffs, hazards)

## Z-Index Standards (Rendering Order)

**Best Practice**: Simple sequential layering

```
0: Floor tiles, enemies, player (gameplay layer)
1: Walls, obstacles (collision barriers)
2: Projectiles, effects
3: Particles, UI overlays
```

**TileMapLayer Z-Index:**
- FloorLayer: z_index = 0 (same as gameplay)
- WallLayer: z_index = 1 (above gameplay)
- ObstacleLayer: z_index = 1 (above gameplay)
- SpawnZoneLayer: z_index = 0 (invisible anyway)

**MultiMesh Z-Index:**
- Enemies: z_index = 0 (gameplay layer)
- Projectiles: z_index = 2 (above walls)

## Integration

Maps load via `ArenaSystem.gd` - currently loads basic bounds from `.tres`, will be extended to load full map scenes.

### MapConfig Resource Schema

New `MapConfig.gd` resource class provides structured arena configuration:

```gdscript
# Basic Information
map_id: StringName              # Unique identifier
display_name: String            # Human-readable name
description: String             # Brief description

# Visual Configuration  
theme_tags: Array[StringName]   # Theme tags (e.g., "underworld", "forest")
ambient_light_color: Color      # Base ambient lighting
ambient_light_energy: float    # Ambient light intensity
background_music: AudioStream   # Background music

# Gameplay Configuration
arena_bounds_radius: float      # Arena boundary radius
spawn_radius: float             # Enemy spawn radius
player_spawn_position: Vector2  # Player spawn offset

# Spawning Configuration
spawn_zones: Array[Dictionary]  # Named spawn zones with weights
boss_spawn_positions: Array[Vector2]  # Boss spawn locations
max_concurrent_enemies: int     # Max enemies alive

# Environmental Effects
has_environmental_hazards: bool # Enable hazards/damage
weather_effects: Array[StringName]  # Weather effects
special_mechanics: Array[StringName]  # Special mechanics

# Future Expansion
tier_multipliers: Dictionary    # Future tier scaling
modifier_support: Array[StringName]  # Future modifier system
custom_properties: Dictionary   # Extensible custom data
```

### Example Configuration

See `underworld_config.tres` for a complete example with volcanic theme, spawn zones, and environmental hazards.

## Current Status

**✅ Folder structure created**
**✅ MapConfig resource system implemented**
**✅ UnderworldArena example created**
**⏳ Next**: Follow UNDERWORLD_SETUP_GUIDE.md to create your first custom arena
