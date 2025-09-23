# Research: Tileset-Based Spawn Areas Implementation

**Created:** 2025-09-22
**Status:** 🟡 Planning
**Priority:** Medium
**Estimated Effort:** 2-3 Days

## 📋 Task Description

Research and design a system to replace the current spawn circle mechanism with tileset-based spawn areas, where enemies can spawn on any valid ground tile. This follows the concept from the breach event brainstorming: "**Spawn-Areas statt Spawn-Circles:** Map-basierte erlaubte Zonen (Polygon/Bodenflächen), um Gegner nur auf „valid ground" zu spawnen."

The goal is to make spawn locations more natural and map-aware by using the actual tileset ground tiles to determine where enemies can appear, rather than arbitrary circular zones.

## 🎯 Acceptance Criteria

- [ ] Complete technical research on Godot's TileSet custom data layer system
- [ ] Design a marking system for spawnable tiles in the tileset
- [ ] Create a proof-of-concept for querying valid spawn tiles efficiently
- [ ] Document performance implications and optimization strategies
- [ ] Provide integration plan with existing breach event system
- [ ] Define backward compatibility approach with current Area2D spawn zones

## 🔍 Technical Analysis

### Affected Systems
- [x] autoload/ (EventBus for spawn events)
- [ ] scripts/systems/ (BreachEventHandler, Arena systems)
- [ ] scripts/domain/ (No changes needed)
- [x] scenes/ (Arena scenes with TileMapLayers)
- [ ] data/ (Potential tileset resource modifications)
- [ ] tests/ (New spawn validation tests)
- [ ] new system? (TileSpawnValidator system)

### Dependencies & Patterns
- **EventBus Signals:** `enemy_spawned`, `spawn_position_requested`
- **Resource Files:** Existing tileset resources in Arena scenes
- **Performance Impact:** Tile queries must be compatible with 30Hz combat step
- **Testing Strategy:** .tscn for integration tests with TileMap components

## 📊 Implementation Research Plan

### Phase 1: Godot TileSet Research
- [ ] Study TileSet custom data layers for spawn marking
- [ ] Research TileData property system for per-tile configuration
- [ ] Investigate physics layer collision detection for obstacle checking
- [ ] Document tile coordinate to world position conversion methods
- [ ] Analyze TileMap query performance characteristics

### Phase 2: Current System Analysis (COMPLETED)
- [x] Analyzed BreachEventHandler spawn logic (lines 88-356)
- [x] Identified Area2D zone system in UnderworldArena
- [x] Mapped phantom position tracking system
- [x] Located TileMapLayer nodes in Arena scenes

### Phase 3: Design Proposal
- [ ] Design custom data layer schema for spawn properties
- [ ] Create tile marking workflow for level designers
- [ ] Design efficient tile caching system for runtime queries
- [ ] Plan migration path from Area2D to tileset system
- [ ] Design API for spawn position validation

### Phase 4: Proof of Concept
- [ ] Create test tileset with spawn markings
- [ ] Implement tile query system prototype
- [ ] Benchmark performance with large tile counts
- [ ] Test integration with breach event spawning
- [ ] Validate position distribution patterns

### Phase 5: Integration Planning
- [ ] Map required changes to BreachEventHandler.gd
- [ ] Design backward compatibility layer
- [ ] Plan Arena scene migration strategy
- [ ] Document new spawn zone workflow
- [ ] Create migration checklist

## 🔗 Technical Research Findings

### Godot TileSet Capabilities

**Custom Data Layers (Key Feature)**
```gdscript
# Add custom data layer to TileSet
tileset.add_custom_data_layer()
tileset.set_custom_data_layer_name(0, "spawnable")
tileset.set_custom_data_layer_type(0, TYPE_BOOL)

# Set per-tile spawn data
tile_data.set_custom_data("spawnable", true)
```

**Efficient Tile Queries**
```gdscript
# Get all cells in a region
var used_cells = tilemap_layer.get_used_cells()
# Check specific tile properties
var tile_data = tilemap_layer.get_cell_tile_data(cell)
var is_spawnable = tile_data.get_custom_data("spawnable")
```

**Physics Layer Integration**
- Can use collision layers to detect obstacles
- `tile_data.get_collision_polygons_count()` for obstacle checking
- Combine with spawnable flag for valid positions

### Current Implementation Points

**Files Requiring Modification:**
1. `BreachEventHandler.gd:88-92` - Zone access logic
2. `BreachEventHandler.gd:124-147` - Position validation
3. `BreachEventHandler.gd:301-356` - Ring spawn calculation
4. `UnderworldArena.gd:34,153-158` - Spawn zone initialization
5. `BaseArena.gd:64-121` - Zone helper methods

**Existing TileMapLayers:**
- UnderworldArena: Ground, GroundObstacles, Walls
- Arena: Ground, GroundDetails, GroundObjects
- Currently visual-only, not integrated with spawning

## 📝 Design Proposals

### Approach 1: Custom Data Layer Marking
```gdscript
# In tileset editor, mark tiles with spawn properties
custom_data_layers = [
    "spawnable": bool,        # Can enemies spawn here?
    "spawn_weight": float,     # Relative spawn probability
    "spawn_type": String       # "normal", "boss", "elite"
]
```

### Approach 2: Tile Caching System
```gdscript
# Cache valid spawn tiles at scene load
class SpawnTileCache:
    var valid_tiles: Array[Vector2i] = []
    var weighted_tiles: Dictionary = {}  # tile -> weight

    func build_cache(tilemap: TileMapLayer):
        for cell in tilemap.get_used_cells():
            var data = tilemap.get_cell_tile_data(cell)
            if data.get_custom_data("spawnable"):
                valid_tiles.append(cell)
```

### Approach 3: Hybrid System
- Keep Area2D for spawn zone boundaries
- Use tileset for fine-grained position validation
- Best of both worlds: designer control + natural placement

## 🚨 Performance Considerations

### Challenges
- **Tile Count**: Large maps may have thousands of tiles
- **Runtime Queries**: Checking tiles during combat could impact 30Hz step
- **Memory Usage**: Caching all valid tiles uses memory

### Optimization Strategies
1. **Pre-calculation**: Cache valid spawn tiles at scene load
2. **Spatial Indexing**: Use quadtree for efficient tile lookups
3. **Lazy Loading**: Only query tiles within breach radius
4. **Batch Processing**: Group spawn position calculations
5. **LOD System**: Use simplified queries for distant breaches

## 📚 Godot Documentation References

### Key APIs Discovered
- `TileSet.add_custom_data_layer()` - Add spawn marking layer
- `TileData.set_custom_data()` - Mark individual tiles
- `TileMapLayer.get_used_cells()` - Query all tiles
- `TileMapLayer.get_cell_tile_data()` - Get tile properties
- `TileMapLayer.local_to_map()` - World to tile conversion
- `TileMapLayer.map_to_local()` - Tile to world conversion

### Performance Notes from Docs
- Tile queries are O(1) for specific positions
- `get_used_cells()` returns cached array (fast)
- Custom data layers have minimal memory overhead
- Physics layers can be queried efficiently

## 🔧 Prototype Implementation Plan

### Step 1: Tileset Preparation
```gdscript
# Add to existing tileset resource
extends TileSet

func _ready():
    add_custom_data_layer()
    set_custom_data_layer_name(0, "spawnable")
    set_custom_data_layer_type(0, TYPE_BOOL)

    add_custom_data_layer()
    set_custom_data_layer_name(1, "spawn_weight")
    set_custom_data_layer_type(1, TYPE_FLOAT)
```

### Step 2: Spawn Validator System
```gdscript
# New system: scripts/systems/tile_spawn_validator.gd
extends Node

var spawn_cache: Dictionary = {}  # arena_id -> valid_tiles

func cache_arena_spawn_tiles(arena: Node, tilemap: TileMapLayer):
    var valid_tiles = []
    for cell in tilemap.get_used_cells():
        var data = tilemap.get_cell_tile_data(cell)
        if data and data.get_custom_data("spawnable"):
            valid_tiles.append(tilemap.map_to_local(cell))
    spawn_cache[arena.get_instance_id()] = valid_tiles

func get_random_spawn_position(arena: Node, near: Vector2, radius: float) -> Vector2:
    var cached = spawn_cache.get(arena.get_instance_id(), [])
    var valid_in_radius = cached.filter(func(pos):
        return pos.distance_to(near) <= radius
    )
    if valid_in_radius.is_empty():
        return Vector2.ZERO
    return valid_in_radius[RNG.stream("spawn").randi() % valid_in_radius.size()]
```

### Step 3: Integration with BreachEventHandler
```gdscript
# Modify BreachEventHandler.gd
func _find_valid_spawn_position(breach_event: EventInstance) -> Vector2:
    # New tileset-based approach
    if arena_scene.has_method("get_spawn_tilemap"):
        var tilemap = arena_scene.get_spawn_tilemap()
        return TileSpawnValidator.get_random_spawn_position(
            arena_scene,
            breach_event.center_position,
            breach_event.current_radius
        )

    # Fallback to current Area2D system
    return _find_area2d_spawn_position(breach_event)
```

## ✅ Definition of Done

- [ ] Research document completed with all findings
- [ ] Prototype code demonstrating tileset spawn marking
- [ ] Performance benchmarks documented
- [ ] Integration plan approved
- [ ] Migration guide for existing arenas created
- [ ] Test plan for spawn distribution validation
- [ ] Backward compatibility confirmed
- [ ] Technical review completed

## 🔗 Related Documents

- [Breach Event Summary](../02-brainstorm/car-topics/breach_summary.md)
- [Current Breach Implementation](../../scripts/systems/events/breach_event_handler.gd)
- [Arena Architecture](../systems/Arena-Architecture.md)

## 📈 Success Metrics

- Spawn position calculation < 1ms per enemy
- Memory overhead < 1MB for spawn cache
- Even distribution across valid tiles
- No spawning in walls or obstacles
- Smooth migration from Area2D system

## 🎮 Next Steps After Research

1. **Approval**: Review findings with team
2. **Prototype**: Build minimal working example
3. **Testing**: Validate performance and distribution
4. **Implementation**: Full system integration
5. **Migration**: Convert existing arenas
6. **Documentation**: Update CLAUDE.md files