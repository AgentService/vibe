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

## Current Status

**✅ Folder structure created**
**⏳ Next**: Open Arena.tscn → Add TileMap → Start prototyping