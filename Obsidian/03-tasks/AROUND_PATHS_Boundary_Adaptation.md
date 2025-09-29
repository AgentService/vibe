# AROUND_PATHS Boundary Adaptation Task

## Problem Statement
The current AROUND_PATHS spawn markers extend beyond the actual walkable boundaries into forest areas because they only check distance from paths, not the generated tree boundaries. Green dots appear in areas where trees are placed, making spawn positions invalid.

## Current Implementation Issues
- `_get_around_path_positions()` uses fixed arena bounds without boundary awareness
- Grid sampling (96px) across `path_snapshot.total_arena_bounds`
- Only filters by `min_distance_from_path` (80px) but ignores tree/boundary tiles
- Results in green dots appearing in forest areas outside actual walkable space

## Proposed Solution: Adaptive Boundary Detection

### Phase 1: Capture Boundary Data During Generation
**File:** `PathAwareArenaGenerator.gd`
**Method:** `generate_path_aware_arena()`

1. **Snapshot Green Layer Tiles**: After tree generation, capture walkable tiles
   ```gdscript
   # After tree generation completes
   var green_layer = get_node("Green")
   var walkable_tiles = green_layer.get_used_cells()

   # Store in path snapshot for boundary checking
   path_snapshot.walkable_tiles = walkable_tiles
   path_snapshot.tile_size = 48  # Forest tileset tile size
   ```

2. **Capture Tree Boundary Tiles** (Optional enhancement):
   ```gdscript
   var trees_layer = get_node("YSort_Objects/Trees2")
   var tree_tiles = trees_layer.get_used_cells()
   path_snapshot.tree_tiles = tree_tiles
   ```

### Phase 2: Add Boundary Validation to PathAwareMapConfig
**File:** `PathAwareMapConfig.gd`

1. **Extend PathAwarePathSnapshot** with boundary data:
   ```gdscript
   class_name PathAwarePathSnapshot
   extends Resource

   # Existing properties...
   @export var walkable_tiles: Array[Vector2i] = []
   @export var tree_tiles: Array[Vector2i] = []  # Optional
   @export var tile_size: int = 48

   func world_to_tile(world_pos: Vector2) -> Vector2i:
       return Vector2i(int(world_pos.x / tile_size), int(world_pos.y / tile_size))

   func is_walkable_tile(world_pos: Vector2) -> bool:
       var tile_coord = world_to_tile(world_pos)
       return walkable_tiles.has(tile_coord)
   ```

2. **Add boundary validation function**:
   ```gdscript
   func _is_position_on_walkable_ground(world_pos: Vector2) -> bool:
       if not path_snapshot:
           return false

       # Must be on a green tile that was generated
       if not path_snapshot.is_walkable_tile(world_pos):
           return false

       # Optional: Explicit tree tile rejection
       if path_snapshot.tree_tiles.size() > 0:
           var tile_coord = path_snapshot.world_to_tile(world_pos)
           if path_snapshot.tree_tiles.has(tile_coord):
               return false

       return true
   ```

3. **Update grid sampling in `_get_around_path_positions()`**:
   ```gdscript
   func _get_around_path_positions() -> Array:
       var positions: Array = []
       if not path_snapshot:
           return positions

       var arena_bounds = path_snapshot.total_arena_bounds
       var sample_spacing = 96.0
       var min_distance_from_path = 80.0

       var y = arena_bounds.position.y
       while y <= arena_bounds.position.y + arena_bounds.size.y:
           var x = arena_bounds.position.x
           while x <= arena_bounds.position.x + arena_bounds.size.x:
               var test_position = Vector2(x, y)

               # Existing path distance check + NEW boundary check
               if _is_position_away_from_paths(test_position, min_distance_from_path) and \
                  _is_position_on_walkable_ground(test_position):
                   positions.append(test_position)

               x += sample_spacing
           y += sample_spacing

       return positions
   ```

### Phase 3: Update Debug Renderer Integration
**File:** `PathAwareDebugRenderer.gd`

Update `_create_around_path_markers()` to use the improved boundary-aware logic:
```gdscript
# The existing temporary PathAwareMapConfig approach will automatically
# benefit from the improved _get_around_path_positions() logic
```

## Benefits
- **Fully Adaptive**: Works with any randomly generated arena shape/size
- **No Hard-coded Pixels**: Uses actual generated tile data, not fixed buffers
- **Consistent**: Debug markers match actual spawn positions exactly
- **Efficient**: Single boundary check per position, no complex distance calculations
- **Future-proof**: Foundation for additional spatial filtering (clearings, corridors)

## Implementation Steps
1. [ ] Extend `PathAwarePathSnapshot` with walkable_tiles array and helper methods
2. [ ] Modify `PathAwareArenaGenerator.generate_path_aware_arena()` to capture Green layer tiles
3. [ ] Add `_is_position_on_walkable_ground()` validation function to `PathAwareMapConfig`
4. [ ] Update `_get_around_path_positions()` to include boundary checking
5. [ ] Test with multiple random seeds to verify adaptive behavior
6. [ ] Optional: Add tree tile exclusion for enhanced accuracy

## Testing Criteria
- [ ] Green dots only appear within generated walkable areas
- [ ] Different seeds produce different but valid boundary constraints
- [ ] No green dots appear in forest/tree areas
- [ ] Performance remains acceptable (boundary check should be O(1) hash lookup)
- [ ] Debug visualization matches actual spawn system behavior

## Future Enhancements
- **Corridor Distance Validation**: Add path corridor width checking for tighter control
- **Clearing Integration**: Prefer positions within defined clearing areas
- **Distance Fields**: Pre-calculate distance maps for more sophisticated spawn placement
- **Multi-layer Validation**: Check multiple tile layers for complex terrain rules

---
**Priority**: High - Fixes incorrect spawn position visualization and ensures spawn system accuracy
**Estimated Effort**: Medium - Requires coordination between generator and spawn config systems
**Dependencies**: None - can be implemented with existing path generation system