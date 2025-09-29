# Spawnable Layer MVP/POC - Simplified Tile Placement

**Created:** 2025-01-09
**Status:** 🟡 Planning
**Priority:** High (Prerequisite for SYSTEM-1)
**Estimated Effort:** 2-3 Hours

## 📋 Task Description

Create a simplified proof-of-concept that focuses purely on correctly placing spawnable tiles during PathAwareArenaGenerator execution. This MVP eliminates EventBus complexity and focuses on the core challenge: generating valid spawn areas that respect path boundaries.

The POC will add a spawnable layer generation phase to the existing arena generation and visually demonstrate that spawnable tiles are placed in valid locations (avoiding trees/boundaries) while covering walkable areas.

## 🎯 Acceptance Criteria

- [ ] Add spawnable layer generation directly to PathAwareArenaGenerator
- [ ] Generate spawnable tiles that avoid tree boundaries
- [ ] Spawnable tiles cover walkable areas around paths
- [ ] Visual verification using green spawnable tiles
- [ ] No breaking changes to existing arena generation
- [ ] Performance measurement of tile generation time
- [ ] Simple validation that spawnable areas are accessible

## 🔍 Technical Analysis

### Simplified MVP Scope
- **Direct integration** with PathAwareArenaGenerator._generate_spawnable_areas()
- **Green tile visualization** for immediate visual feedback
- **Tree boundary avoidance** using existing tree_data
- **Path area coverage** using existing path_data
- **Grid-based sampling** for simplicity (no spatial optimization)

### Core Questions to Answer
- **Can we access tree positions** to avoid placing spawnable tiles there?
- **Can we determine walkable areas** from path corridor data?
- **Does TileMapLayer.set_cell()** work for spawnable tile placement?
- **What's the performance impact** of tile generation during arena creation?
- **How do we validate** that spawnable areas are actually walkable?

## 📊 Implementation Plan

### Phase 1: Direct Generator Integration (1.5 hours)
- [ ] Add SPAWNABLE_LAYER_NAME constant to PathAwareArenaGenerator
- [ ] Create `_generate_spawnable_areas()` method in generation sequence
- [ ] Add spawnable layer to existing layer constants and discovery
- [ ] Implement grid-based tile placement avoiding tree positions
- [ ] Use green tiles (atlas coords) for visual feedback

### Phase 2: Boundary Logic Implementation (1 hour)
- [ ] Access `current_tree_data` to get tree positions for avoidance
- [ ] Access `current_path_data` to determine walkable corridor areas
- [ ] Implement simple distance-based boundary checking
- [ ] Add logging to track tile count and generation time
- [ ] Validate spawnable tiles don't overlap with trees

### Phase 3: Visual Testing & Validation (0.5 hours)
- [ ] Test in PathAware_Forest scene to see green spawnable tiles
- [ ] Verify spawnable areas avoid tree boundaries visually
- [ ] Measure and log tile generation performance
- [ ] Document findings for full implementation approach

## 🔗 Related Files

### Will Modify:
- [ ] `scripts/systems/PathAwareArenaGenerator.gd` (add spawnable generation method)

### Will Document:
- [ ] Tile generation performance measurements
- [ ] Boundary detection approach findings
- [ ] Visual validation results and next steps

### Scene Requirements:
- [ ] Spawnable layer must exist in PathAware_Forest.tscn
- [ ] Green tiles (atlas coords) available in tileset for visibility

## 📝 Progress Notes

### 2025-01-09 - Planning
- Simplified to focus purely on tile placement during generation
- Eliminated EventBus complexity to focus on core boundary logic
- Direct integration with PathAwareArenaGenerator for immediate results

### [DATE] - POC Implementation
- [Track POC development and integration]

### [DATE] - Validation Results
- [Document findings and recommendations]

## 🚨 Risks & Considerations

### **Technical Implementation Risks:**
- **Coordinate Mapping Errors:** Must use `spawnable_layer.to_local(world_pos)` before `local_to_map()`
  - *Mitigation:* Proper world → local → tile coordinate conversion sequence
- **Data Structure Assumptions:** Assuming `current_tree_data` is `Array[Vector2]`
  - *Mitigation:* Verify data structure format during implementation, add safety checks

### **Performance & Integration Risks:**
- **Generation Time Impact:** Adding spawnable tile generation to Phase 4 might slow arena creation
  - *Mitigation:* Performance measurement, grid spacing optimization
- **Walkable Area Detection:** Using Green layer tile data for walkable validation
  - *Mitigation:* Verify Green layer coverage matches expected walkable areas

## ✅ Definition of Done

- [ ] Spawnable layer generation integrated into PathAwareArenaGenerator Phase 4
- [ ] Proper coordinate conversion: world → local → tile coordinates
- [ ] Spawnable tiles avoid tree boundaries (64px minimum distance)
- [ ] Spawnable tiles only placed on walkable areas (Green layer validation)
- [ ] Visual confirmation with green tiles showing spawnable coverage
- [ ] Performance measurement of tile generation time
- [ ] Documentation of current_tree_data and current_path_data structure validation
- [ ] No regression in existing PathAware_Forest functionality

---

## 🎯 Simplified Implementation Approach

### **Direct PathAwareArenaGenerator Integration:**

```gdscript
# Add to PathAwareArenaGenerator.gd - no separate class needed

const SPAWNABLE_LAYER_NAME = "SpawnableAreas"  # New layer for spawnable tiles
const SPAWNABLE_TILE_SOURCE_ID = 0
const SPAWNABLE_TILE_ATLAS_COORDS = Vector2i(1, 1)  # Green tile for visibility

func generate_path_aware_arena():
    # ... existing generation logic ...

    # Phase 4: Generate tiles (arena base, ground corridors, trees, and spawnable areas)
    _generate_arena_base()
    _generate_ground_tiles()
    _generate_boundary_trees()
    _generate_spawnable_areas()  # NEW - after all other tiles are placed

    Logger.info("🛤️ Path-aware arena generation completed!", "pathgen")

func _generate_spawnable_areas():
    """Generate spawnable tiles that avoid tree boundaries - Phase 4 integration"""
    var start_time = Time.get_ticks_msec()

    var spawnable_layer = _find_layer_node(SPAWNABLE_LAYER_NAME)
    if not spawnable_layer:
        Logger.warn("Spawnable layer not found: %s" % SPAWNABLE_LAYER_NAME, "pathgen")
        return

    # Clear any existing spawnable tiles
    spawnable_layer.clear()

    var spawnable_count = 0
    var grid_spacing = 48  # Sample every 48 pixels
    var min_tree_distance = 64  # Stay away from trees

    # Get arena bounds from current generation
    var arena_bounds = _get_arena_bounds()

    # Sample grid positions across arena - work in world space, convert to tile space
    var y = arena_bounds.position.y
    while y <= arena_bounds.position.y + arena_bounds.size.y:
        var x = arena_bounds.position.x
        while x <= arena_bounds.position.x + arena_bounds.size.x:
            var world_pos = Vector2(x, y)

            # Check if position is valid for spawning
            if _is_valid_spawn_position(world_pos, min_tree_distance):
                # Convert world position to layer-local space, then to tile coordinates
                var local_pos = spawnable_layer.to_local(world_pos)
                var tile_coords = spawnable_layer.local_to_map(local_pos)
                spawnable_layer.set_cell(tile_coords, SPAWNABLE_TILE_SOURCE_ID, SPAWNABLE_TILE_ATLAS_COORDS)
                spawnable_count += 1

            x += grid_spacing
        y += grid_spacing

    var generation_time = Time.get_ticks_msec() - start_time
    Logger.info("Generated %d spawnable tiles in %.1f ms" % [spawnable_count, generation_time], "pathgen")

func _is_valid_spawn_position(world_pos: Vector2, min_tree_distance: float) -> bool:
    """Check if a world position is valid for spawning (avoiding trees and checking walkable areas)"""

    # Check distance to all trees (current_tree_data is Array[Vector2])
    for tree_pos in current_tree_data:
        if world_pos.distance_to(tree_pos) < min_tree_distance:
            return false

    # Check if position is within walkable areas by verifying it's on ground tiles
    # Use existing Green layer to determine walkable areas
    var green_layer = _find_layer_node(GROUND_LAYER_NAME)
    if green_layer and green_layer is TileMapLayer:
        var local_pos = green_layer.to_local(world_pos)
        var tile_coords = green_layer.local_to_map(local_pos)
        var tile_data = green_layer.get_cell_tile_data(tile_coords)

        # If there's no ground tile at this position, it's not walkable
        if not tile_data:
            return false

    return true

func _get_arena_bounds() -> Rect2:
    """Get the bounds of the current arena for spawnable area generation"""
    # Use existing arena bounds or calculate from path data
    var bounds = Rect2(-600, -600, 1200, 1200)  # Default bounds

    if not current_path_data.is_empty():
        var points = current_path_data.get("points", [])
        if not points.is_empty():
            # Calculate bounds from path points with padding
            var min_x = INF
            var max_x = -INF
            var min_y = INF
            var max_y = -INF

            for point in points:
                var pos = point if point is Vector2 else point.position
                min_x = min(min_x, pos.x)
                max_x = max(max_x, pos.x)
                min_y = min(min_y, pos.y)
                max_y = max(max_y, pos.y)

            var padding = 200  # Add padding around paths
            bounds = Rect2(min_x - padding, min_y - padding,
                          (max_x - min_x) + (padding * 2),
                          (max_y - min_y) + (padding * 2))

    return bounds
```

### **Scene Setup Requirements:**

1. **Add Spawnable Layer to PathAware_Forest.tscn:**
   - Create new TileMapLayer node named "SpawnableAreas"
   - Use same TileSet as other layers
   - Configure with green tiles for visibility

2. **Verify Tileset:**
   - Ensure green tile available at atlas coords Vector2i(1, 1)
   - Or adjust SPAWNABLE_TILE_ATLAS_COORDS to match available green tile

---

## 🎯 Success Metrics for POC

### **Core Functionality Validation:**
- [ ] Spawnable tiles generated successfully in Phase 4 of arena generation
- [ ] Green tiles visible showing spawnable areas avoiding tree boundaries
- [ ] Walkable area validation working (spawnable tiles only on Green layer)
- [ ] Coordinate conversion working correctly (no offset tile placement errors)
- [ ] Generation time measured and acceptable (<500ms for typical arena)

### **Data Structure Validation:**
- [ ] `current_tree_data` structure confirmed as Array[Vector2]
- [ ] `current_path_data` accessibility verified during generation
- [ ] Green layer tile data accessible for walkable area validation
- [ ] SpawnableAreas layer discoverable via `_find_layer_node()`

### **Integration Success:**
- [ ] No breaking changes to existing arena generation sequence
- [ ] Clear visual feedback of spawnable vs non-spawnable areas
- [ ] Documented approach ready for full SYSTEM-1 implementation
- [ ] Performance characteristics understood for scaling decisions

---

*This POC will provide confidence and validation for the full SYSTEM-1 spawnable layer implementation, ensuring we understand the integration points and performance characteristics before committing to the complete system.*