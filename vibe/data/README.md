# Game Data Schemas

This directory contains JSON data files that define game balance and configuration. All game systems load their tunables from these files through the BalanceDB autoload singleton.

## Directory Structure

```
/data/
├── balance/          # Balance tunables for all game systems
│   ├── combat.json   # Combat system values
│   ├── abilities.json # Ability system configuration
│   ├── waves.json    # Wave director and enemy settings
│   └── player.json   # Player base stats
├── cards/            # Card system data
├── enemies/          # Enemy definitions and spawning
│   ├── enemy_registry.json  # Central enemy registry with spawn weights
│   └── *.json        # Individual enemy configurations
├── animations/       # Animation configurations for enemies
│   └── *_animations.json  # Frame data and timing for each enemy type
├── arena/            # Arena configuration
│   ├── layouts/      # Arena and room definitions
│   │   ├── *.json    # Arena configurations
│   │   └── rooms/    # Individual room layouts
│   ├── templates/    # Procedural generation templates
│   └── walls.json    # Legacy wall configuration (deprecated)
├── ui/               # UI component configuration
│   └── radar.json    # Enemy radar settings
└── xp_curves.json    # Experience progression curves
```

## Balance Schemas

### combat.json

Combat system balance values including collision detection, damage, and critical hit mechanics.

```json
{
  "projectile_radius": 4.0,
  "enemy_radius": 12.0,
  "base_damage": 1.0,
  "crit_chance": 0.1,
  "crit_multiplier": 2.0,
  "_schema_version": "1.0.0",
  "_description": "Combat system balance values"
}
```

**Fields:**
- `projectile_radius` (float): Collision radius for projectiles in pixels
- `enemy_radius` (float): Collision radius for enemies in pixels  
- `base_damage` (float): Base damage value applied on projectile hit
- `crit_chance` (float): Base critical hit chance (0.0-1.0)
- `crit_multiplier` (float): Damage multiplier for critical hits

### abilities.json

Ability system configuration including projectile pools, default speeds, and arena boundaries.

```json
{
  "max_projectiles": 1000,
  "projectile_speed": 300.0,
  "projectile_ttl": 3.0,
  "arena_bounds": 2000.0,
  "_schema_version": "1.0.0",
  "_description": "Ability system balance values"
}
```

**Fields:**
- `max_projectiles` (int): Maximum projectiles in object pool
- `projectile_speed` (float): Default projectile speed in pixels/second
- `projectile_ttl` (float): Default projectile time-to-live in seconds
- `arena_bounds` (float): Arena boundary distance from center for projectile cleanup

### waves.json

Wave director balance values including enemy spawning, movement, health, and arena constraints.

```json
{
  "max_enemies": 500,
  "spawn_interval": 1.0,
  "arena_center": {
    "x": 400.0,
    "y": 300.0
  },
  "spawn_radius": 600.0,
  "enemy_hp": 3.0,
  "enemy_speed_min": 60.0,
  "enemy_speed_max": 120.0,
  "spawn_count_min": 3,
  "spawn_count_max": 6,
  "arena_bounds": 1500.0,
  "target_distance": 20.0,
  "_schema_version": "1.0.0",
  "_description": "Wave director balance values"
}
```

**Fields:**
- `max_enemies` (int): Maximum enemies in object pool
- `spawn_interval` (float): Time between spawn waves in seconds
- `arena_center` (object): Center point of arena with x,y coordinates
- `spawn_radius` (float): Distance from center where enemies spawn
- `enemy_hp` (float): Base enemy health points
- `enemy_speed_min` (float): Minimum enemy movement speed
- `enemy_speed_max` (float): Maximum enemy movement speed
- `spawn_count_min` (int): Minimum enemies spawned per wave
- `spawn_count_max` (int): Maximum enemies spawned per wave
- `arena_bounds` (float): Arena boundary distance for enemy cleanup
- `target_distance` (float): Distance from target where enemies are removed

### player.json

Player base stats and multipliers for progression and upgrades.

```json
{
  "projectile_count_add": 0,
  "projectile_speed_mult": 1.0,
  "fire_rate_mult": 1.0,
  "damage_mult": 1.0,
  "_schema_version": "1.0.0",
  "_description": "Player base stats and multipliers"
}
```

**Fields:**
- `projectile_count_add` (int): Additional projectiles fired per ability use
- `projectile_speed_mult` (float): Multiplier for projectile speed
- `fire_rate_mult` (float): Multiplier for ability fire rate
- `damage_mult` (float): Multiplier for damage output

### arena/walls.json

Arena configuration including wall placement, boundaries, and collision settings.

```json
{
  "arena_size": {
    "x": 800.0,
    "y": 600.0
  },
  "wall_thickness": 32.0,
  "wall_segment_size": {
    "x": 64.0,
    "y": 32.0
  },
  "_schema_version": "1.0.0",
  "_description": "Arena wall configuration"
}
```

**Fields:**
- `arena_size` (object): Arena dimensions with x,y coordinates
- `wall_thickness` (float): Thickness of collision walls in pixels
- `wall_segment_size` (object): Visual wall segment dimensions

### arena/layouts/*.json

Arena configuration files defining complete arena layouts with multiple rooms.

```json
{
  "id": "basic_arena",
  "name": "Basic Combat Arena", 
  "description": "Simple rectangular arena for combat encounters",
  "start_room": "combat_room_001",
  "bounds": {"x": -400, "y": -300, "width": 800, "height": 600},
  "rooms": ["combat_room_001"],
  "_schema_version": "1.0.0"
}
```

**Fields:**
- `id` (string): Unique arena identifier
- `name` (string): Human-readable arena name
- `start_room` (string): Initial room ID to load
- `bounds` (object): Overall arena boundary rectangle
- `rooms` (array): List of room IDs in this arena

### arena/layouts/rooms/*.json

Individual room layout files with terrain, obstacles, and interactables.

```json
{
  "id": "combat_room_001",
  "name": "Basic Combat Room",
  "size": {"width": 800, "height": 600},
  "boundaries": {
    "arena_size": {"x": 800, "y": 600},
    "wall_thickness": 32,
    "wall_segment_size": {"x": 64, "y": 32}
  },
  "terrain": {
    "tiles": [{"x": 0, "y": 0, "type": "stone_floor", "rotation": 0.0}]
  },
  "obstacles": {
    "objects": [{"id": "pillar_1", "type": "pillar", "x": -200, "y": -100, "size": {"width": 24, "height": 24}}]
  },
  "interactables": {
    "objects": [{"id": "chest_1", "type": "chest", "x": 150, "y": -200, "interaction_radius": 40.0}]
  },
  "_schema_version": "1.0.0"
}
```

**Room Structure:**
- `boundaries`: Wall configuration and collision boundaries
- `terrain`: Floor tiles and environmental surfaces
- `obstacles`: Walls, pillars, destructible objects with collision
- `interactables`: Chests, doors, altars with activation zones
- `transitions`: Room change triggers and portal definitions

## Hot Reloading

The BalanceDB singleton supports hot reloading of balance data during development. Call `BalanceDB.reload_balance_data()` to refresh all values, or listen to the `balance_reloaded` signal for automatic updates.

## Fallback Values

All systems include fallback values identical to the current JSON defaults. If a JSON file is missing or malformed, the system will log warnings and continue with hardcoded fallbacks to prevent crashes.

## Schema Versioning

Each JSON file includes a `_schema_version` field for future compatibility. The `_description` field provides human-readable documentation.

## Adding New Balance Values

1. Add the new field to the appropriate JSON file
2. Update the fallback values in `BalanceDB.gd`
3. Add accessor methods if needed (e.g., `get_combat_value()`)
4. Update this README with the new field documentation
5. Update consuming systems to use the new balance values

## Adding New Enemy Types

The enemy system is fully data-driven. To add a new enemy type:

1. **Create enemy config**: Add `data/enemies/new_enemy.json` with stats and metadata
2. **Create animation config**: Add `data/animations/new_enemy_animations.json` with sprite data
3. **Add to registry**: Update `data/enemies/enemy_registry.json` with spawn weight
4. **Add sprite sheet**: Place sprite sheet texture in `assets/sprites/`
5. **Test integration**: Run `vibe/tests/simple_enemy_test.gd` to verify JSON validity

The EnemyRenderer and WaveDirector will automatically pick up new enemy types from the registry without code changes.

## Enemy System Schemas

### enemies/enemy_registry.json

Central registry for all enemy types with spawn weights and metadata. Controls which enemies can spawn and their relative frequency.

```json
{
  "_schema_version": "1.0.0",
  "_description": "Central registry for all enemy types with spawn weights and metadata",
  "enemy_types": {
    "green_slime": {
      "spawn_weight": 50,
      "config_path": "res://data/enemies/green_slime.json",
      "tier": "common",
      "behavior_type": "melee"
    },
    "purple_slime": {
      "spawn_weight": 20,
      "config_path": "res://data/enemies/purple_slime.json",
      "tier": "common", 
      "behavior_type": "tank"
    }
  },
  "wave_progression": {
    "_description": "Future feature: different enemy mixes per wave level",
    "enabled": false,
    "wave_configs": {}
  }
}
```

**Fields:**
- `enemy_types` (object): Dictionary of enemy type configurations
  - `spawn_weight` (int): Relative spawn frequency (higher = more common)
  - `config_path` (string): Path to individual enemy configuration file
  - `tier` (string): Enemy tier classification (common, rare, elite)
  - `behavior_type` (string): AI behavior pattern (melee, tank, ranged, etc.)
- `wave_progression` (object): Future feature for wave-specific enemy mixes

### enemies/*.json

Individual enemy configurations defining stats, appearance, and behavior for each enemy type.

```json
{
  "id": "purple_slime",
  "display_name": "Purple Slime",
  "animation_config": "res://data/animations/purple_slime_animations.json",
  "size": {
    "width": 24,
    "height": 24
  },
  "stats": {
    "hp": 5.0,
    "speed_min": 40.0,
    "speed_max": 80.0
  },
  "render_tier": 1,
  "_schema_version": "1.0.0",
  "_description": "Tank-type enemy with higher HP but slower movement speed"
}
```

**Fields:**
- `id` (string): Unique enemy type identifier
- `display_name` (string): Human-readable name for UI/debug
- `animation_config` (string): Path to animation configuration file
- `size` (object): Enemy collision and render dimensions
- `stats` (object): Combat and movement statistics
  - `hp` (float): Enemy health points
  - `speed_min` (float): Minimum movement speed in pixels/second
  - `speed_max` (float): Maximum movement speed in pixels/second
- `render_tier` (int): Rendering priority tier (1-4, higher = more detailed)

### animations/*_animations.json

Animation configurations linking sprite sheets to frame sequences and timing data.

```json
{
  "sprite_sheet": "res://assets/sprites/slime_purple.png",
  "frame_size": {
    "width": 24,
    "height": 24
  },
  "grid": {
    "columns": 4,
    "rows": 3
  },
  "animations": {
    "idle": {
      "frames": [1, 2, 3, 4],
      "duration": 1.2,
      "loop": true
    },
    "walk": {
      "frames": [5, 6, 7, 8],
      "duration": 0.08,
      "loop": true
    },
    "hit": {
      "frames": [9, 10, 11, 12],
      "duration": 1,
      "loop": false
    }
  }
}
```

**Fields:**
- `sprite_sheet` (string): Path to sprite sheet texture file
- `frame_size` (object): Individual frame dimensions in pixels
- `grid` (object): Sprite sheet grid layout
  - `columns` (int): Number of frames per row
  - `rows` (int): Number of rows in sprite sheet
- `animations` (object): Animation state definitions
  - `frames` (array): Frame indices to use for this animation
  - `duration` (float): Time per frame in seconds
  - `loop` (boolean): Whether animation should loop continuously

### ui/radar.json

Enemy radar UI configuration including visual appearance, range, and dot sizing for gameplay balance.

```json
{
  "radar_size": {"x": 150, "y": 150},
  "radar_range": 1500.0,
  "colors": {
    "background": {"r": 0.1, "g": 0.1, "b": 0.2, "a": 0.7},
    "border": {"r": 0.4, "g": 0.4, "b": 0.6, "a": 1.0},
    "player": {"r": 0.2, "g": 0.8, "b": 0.2, "a": 1.0},
    "enemy": {"r": 0.8, "g": 0.2, "b": 0.2, "a": 1.0}
  },
  "dot_sizes": {
    "player": 4.0,
    "enemy_max": 3.0,
    "enemy_min": 1.5
  },
  "_schema_version": "1.0.0",
  "_description": "Enemy radar UI configuration"
}
```

**Fields:**
- `radar_size` (object): Radar panel dimensions with x,y pixel values
- `radar_range` (float): Detection range for enemies in world pixels
- `colors` (object): RGBA color values for all radar elements
  - `background`: Radar panel background color
  - `border`: Radar panel border color
  - `player`: Player dot color
  - `enemy`: Enemy dot color
- `dot_sizes` (object): Dot size configuration in pixels
  - `player`: Player indicator dot size
  - `enemy_max`: Maximum enemy dot size (close enemies)
  - `enemy_min`: Minimum enemy dot size (distant enemies)

### enemies/*.json

Enemy type definitions for the data-driven spawning system. Each file defines a unique enemy variant with visual, behavioral, and balance properties.

```json
{
  "id": "slime_green",
  "display_name": "Green Slime",
  "health": 10.0,
  "speed": 50.0,
  "size": {"x": 28, "y": 28},
  "collision_radius": 14.0,
  "xp_value": 2,
  "spawn_weight": 0.3,
  "visual": {
    "color": {"r": 0.2, "g": 0.8, "b": 0.2, "a": 1.0},
    "shape": "circle"
  },
  "behavior": {
    "ai_type": "chase_player",
    "aggro_range": 250.0
  }
}
```

**Fields:**
- `id` (string): Unique enemy type identifier
- `display_name` (string): Human-readable enemy name
- `health` (float): Enemy health points
- `speed` (float): Movement speed in pixels/second
- `size` (object): Enemy size with x,y dimensions in pixels
- `collision_radius` (float): Collision detection radius in pixels
- `xp_value` (int): Experience points awarded when killed
- `spawn_weight` (float): Relative spawn probability (0.0-1.0)
- `visual` (object): Visual appearance configuration
  - `color` (object): RGBA color values (0.0-1.0)
  - `shape` (string): Visual shape ("square", "circle")
- `behavior` (object): AI behavior configuration
  - `ai_type` (string): AI pattern ("chase_player", "flee_player")
  - `aggro_range` (float): Detection range in pixels