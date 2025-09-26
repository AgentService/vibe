# Tile Pattern System - README

A powerful system for placing predefined tile patterns at random locations in procedurally generated arenas, with support for pattern grouping, layer separation, and interactive testing.

## Overview

The Tile Pattern System allows you to define multi-tile formations (like ruins, clearings, decorative arrangements) in the Godot editor and have them procedurally placed in walkable areas of your arenas. Patterns can be individual or grouped together for complex formations.

## Core Components

### 1. TilePatternConfig Resource
- **Location**: `scripts/resources/TilePatternConfig.gd`
- **Purpose**: Defines individual tile patterns with placement rules
- **Configurable in**: Godot Inspector when attached to BiomeConfig

### 2. BiomeConfig Integration
- **New Property**: `tile_patterns: Array[TilePatternConfig]`
- **Purpose**: Store all patterns available for a specific biome

### 3. ProceduralArenaGenerator Integration
- **New Function**: `_place_tile_patterns_in_walkable_areas()`
- **When Called**: After stone formations, before decoration sorting
- **Purpose**: Place patterns while avoiding trees, boundaries, and existing decorations

## Pattern Configuration

### Basic Pattern Properties

```gdscript
# Pattern Identity
@export var pattern_name: String = ""           # Unique name for this pattern
@export var pattern_weight: float = 1.0         # Selection probability weight

# Placement Rules
@export var placement_chance: float = 0.3       # 30% chance to attempt placement
@export var max_instances_per_arena: int = 3    # Maximum copies per arena
@export var min_spacing_from_others: int = 10   # Distance from same pattern type
```

### Pattern Grouping (Advanced)

```gdscript
# Grouping Configuration
@export var pattern_group: String = ""                    # Group name (empty = individual)
@export var group_placement_chance: float = 0.3           # Chance to place entire group
@export var max_group_instances_per_arena: int = 1        # Max group instances
@export var is_group_leader: bool = false                 # Controls group placement timing
```

### Pattern Definition

```gdscript
# Tile Layout (Array of Dictionaries)
@export var pattern_tiles: Array[Dictionary] = [
    {"relative_pos": Vector2i(0, 0), "tile": Vector2i(6, 0)},    # Center tile
    {"relative_pos": Vector2i(-1, 0), "tile": Vector2i(9, 6)},   # Left tile
    {"relative_pos": Vector2i(1, 0), "tile": Vector2i(9, 6)},    # Right tile
    # ... more tiles
]
```

## Layer System

The pattern system works with multiple tile layers for proper rendering:

### Y-Sorted Decorations Layer
- **Purpose**: Tiles that need depth sorting with player
- **Examples**: Large flowers, standing stones, statues
- **Renders**: Behind/in front of player based on Y position

### Ground Decorations Layer (Non-Y-Sorted)
- **Purpose**: Ground-level tiles that always render behind everything
- **Examples**: Stone floors, path tiles, ground decorations
- **Renders**: Always behind player and Y-sorted objects

## Creating Patterns

### Method 1: In Code (Example Helper Functions)

```gdscript
# In TilePatternConfig.gd
func create_example_flower_circle() -> void:
    pattern_name = "Flower Circle"
    pattern_weight = 1.0
    placement_chance = 0.4
    max_instances_per_arena = 2
    min_spacing_from_others = 15

    pattern_tiles = [
        {"relative_pos": Vector2i(0, 0), "tile": Vector2i(6, 0)},      # Center flower
        {"relative_pos": Vector2i(-1, -1), "tile": Vector2i(9, 6)},    # NW stone
        {"relative_pos": Vector2i(1, -1), "tile": Vector2i(9, 6)},     # NE stone
        {"relative_pos": Vector2i(-1, 1), "tile": Vector2i(9, 6)},     # SW stone
        {"relative_pos": Vector2i(1, 1), "tile": Vector2i(9, 6)}       # SE stone
    ]
```

### Method 2: In Godot Editor

1. **Open BiomeConfig**: Load your biome configuration resource
2. **Expand Tile Patterns**: Find the `tile_patterns` array
3. **Add New Element**: Click "+" to add a TilePatternConfig
4. **Configure Pattern**:
   - Set `pattern_name` (e.g., "Stone Circle")
   - Set `pattern_weight` (higher = more likely)
   - Set `placement_chance` (0.0-1.0)
   - Set `max_instances_per_arena`
   - Configure `pattern_tiles` array with relative positions and tile coordinates

### Method 3: Using Tileset Patterns (Recommended)

You can use Godot's built-in TileMap Patterns system:

1. **Create Pattern in TileMap Editor**:
   - Paint your desired pattern in any TileMap
   - Select the tiles
   - Go to "Patterns" tab
   - Click "Add" to save the pattern

2. **Access Pattern in Code**:
   ```gdscript
   var tileset = decorations_layer.tile_set
   var pattern = tileset.get_pattern(0)  # Get first saved pattern
   decorations_layer.set_pattern(position, pattern)  # Place it
   ```

## Pattern Groups

Groups allow multiple patterns to be placed together at the same location, creating complex formations.

### Example: Ruin Site Group

```gdscript
# Pattern 1: Base Foundation (Group Leader)
pattern_name = "Ruin Foundation"
pattern_group = "ancient_ruins"
is_group_leader = true
group_placement_chance = 0.2
max_group_instances_per_arena = 1

# Pattern 2: Scattered Stones
pattern_name = "Ruin Stones"
pattern_group = "ancient_ruins"  # Same group
is_group_leader = false          # Not the leader

# Pattern 3: Overgrown Vegetation
pattern_name = "Ruin Vegetation"
pattern_group = "ancient_ruins"  # Same group
is_group_leader = false          # Not the leader
```

**Result**: All three patterns placed together when the group leader's placement chance succeeds.

## Interactive Testing System

Debug and test your patterns using keyboard shortcuts:

### Testing Controls

| Key | Function | Description |
|-----|----------|-------------|
| **F6** | Regenerate Arena | Generate new arena with current patterns |
| **1** | Test at Mouse | Analyze pattern placement feasibility at mouse position |
| **2** | Place Test Pattern | Actually place tileset patterns at mouse position |
| **3** | Clear Test Patterns | Remove all manually placed test patterns |

### Testing Workflow

1. **Position Mouse**: Move to desired test location
2. **Analyze**: Press `1` to see placement analysis
3. **Place**: Press `2` to place actual pattern
4. **Clear**: Press `3` to clean up and try again

### Test Output Example

```
📊 Pattern Placement Test Results at (45, 32):
  ✅ 🎲 Flower Circle: 5 tiles
  ❌ ⏭️ Stone Path: 6 tiles
    - Failed placement chance roll (50.0% chance)
  ✅ 🎲 GROUP: Ancient Ruins: 3 patterns, 15 total tiles
📈 Summary: 2/3 patterns can be placed at this location
```

**Icons**:
- ✅/❌ = Can/Cannot place
- 🎲/⏭️ = Passed/Failed chance roll

## Performance Considerations

The pattern system is optimized for performance:

### Collision Detection
- **Boundary checking**: Patterns avoid trees and boundaries
- **Spacing enforcement**: Minimum distance between pattern instances
- **Arena bounds**: Patterns stay within walkable areas

### Placement Limits
- **Instance caps**: Prevent pattern over-spawning
- **Attempt limits**: Avoid infinite placement loops
- **Group coordination**: Efficient multi-pattern placement

### Memory Usage
- **Lightweight configs**: Pattern definitions are small Resource objects
- **Lazy evaluation**: Only processes valid patterns
- **Efficient bounds checking**: Uses Rect2i math for collision detection

## Integration with Existing Systems

### Street Generation
- **Order**: Patterns placed after stone streets
- **Compatibility**: Patterns avoid street tiles
- **Theme tracking**: Patterns integrate with decoration theme system

### Decoration Themes
- **Coexistence**: Works alongside existing themed decoration system
- **Layer separation**: Patterns can target specific tile layers
- **Y-sorting**: Respects existing depth sorting rules

## Troubleshooting

### Common Issues

**Patterns not appearing:**
- Check `placement_chance` isn't too low
- Verify `max_instances_per_arena` isn't 0
- Ensure pattern tiles are valid tile coordinates
- Check arena has enough walkable space

**Patterns overlapping:**
- Increase `min_spacing_from_others`
- Reduce pattern density
- Check pattern bounds calculations

**Performance issues:**
- Limit pattern complexity (tiles per pattern)
- Reduce number of patterns per biome
- Lower placement chances for expensive patterns

### Debugging Tools

Use the interactive testing system:

```gdscript
# In console or connected debugger
get_pattern_testing_help()  # Returns help text
test_pattern_placement_interactive()  # Test at mouse position
```

### Logging

The system logs placement activity:

```
🎨 Placed 3 tile patterns (1 groups) with 18 total tiles
✨ Successfully placed pattern group 'ancient_ruins' with 3 patterns at (67, 45)
⚠️ Failed to place pattern group 'stone_circle' after 15 attempts
```

## Example Biome Configuration

See `data/content/biome_with_patterns_example.tres` for a complete example configuration with:

- Individual flower circle pattern
- Stone path pattern
- Proper tile coordinate mapping
- Balanced placement chances

## Best Practices

1. **Start Simple**: Begin with individual patterns before using groups
2. **Test Thoroughly**: Use interactive testing before finalizing patterns
3. **Balance Chance**: Set placement chances between 0.2-0.5 for good variety
4. **Mind Spacing**: Use adequate `min_spacing_from_others` to avoid clustering
5. **Layer Awareness**: Choose appropriate layers (Y-sorted vs ground)
6. **Performance**: Keep patterns under 10 tiles each for best performance
7. **Visual Harmony**: Ensure pattern tiles fit your biome's aesthetic

## Future Enhancements

Potential system expansions:
- **Conditional patterns**: Patterns that depend on nearby features
- **Rotation support**: Automatic pattern rotation for variety
- **Size scaling**: Dynamic pattern scaling based on arena size
- **Weighted positioning**: Prefer certain arena areas for specific patterns