# Dual Collision System Research Task

## Problem Statement

Enemies need dual collision radii:
- **Large collision**: For terrain/walls (prevents clipping into obstacles)
- **Small collision**: For other enemies/player (prevents blocking each other)

Currently enemies use single collision radius which causes either:
- Terrain clipping (if radius too small)
- Entity blocking (if radius too large)

## Research Goals

Investigate best approach for implementing dual collision in Godot 4.x for enemy entities.

## Explored Approaches

### ❌ Multiple CollisionShape2D Nodes
- **Method**: Add second CollisionShape2D to same CharacterBody2D
- **Issue**: All collision shapes share same collision_layer/collision_mask
- **Result**: Cannot differentiate between terrain vs entity collision

### 🔄 Area2D + Manual Separation (Complex)
- **Method**: Area2D for overlap detection + manual force calculations
- **Pros**: Full control over separation behavior
- **Cons**: Complex code, many signal connections, performance overhead
- **Status**: Implemented but overengineered

### 🔄 Area2D + Simple Push (Simplified)
- **Method**: Small Area2D for overlap detection + gentle push during movement
- **Pros**: Simpler than complex approach, maintains terrain collision
- **Cons**: Still requires additional collision detection

## Context7 Research Findings

### ✅ Confirmed: Collision Layer/Mask Limitations
Based on Godot 4.x documentation research:
- **Single collision_layer/collision_mask per CharacterBody2D**: Multiple CollisionShape2D nodes share the same collision settings
- **No per-shape layer control**: Cannot differentiate terrain vs entity collision within same body
- **Area2D overlap detection**: Updated once per physics step, not immediately after movement
- **Performance consideration**: `get_overlapping_bodies()` has frame-delay due to physics step timing

### ✅ Area2D Overlap Detection Patterns
Documentation reveals key performance considerations:
```gdscript
# Area2D overlap detection (official pattern)
func has_overlapping_bodies() -> bool
func get_overlapping_bodies() -> Array[Node2D]
func overlaps_body(body: Node) -> bool
```
- **Timing**: Results updated once per physics step before physics calculations
- **Performance**: Use signals instead of polling for real-time detection
- **Layer dependency**: Overlapping body's collision_layer must be in area's collision_mask

### ✅ Distance-Based Optimization Techniques
Research uncovered several optimization patterns:
- **distance_squared_to()**: Faster than distance_to() for proximity comparisons
- **Manhattan distance**: `abs(dx) + abs(dy)` - computationally cheaper than Euclidean
- **Spatial partitioning**: Navigation mesh concepts show region-based entity grouping
- **Query caching**: Cache frequently-used spatial queries to avoid rebuilding

## Remaining Research Options

### Option A: Accept Current Behavior
- **Method**: Keep single collision radius as-is
- **Trade-off**: Some entity overlap acceptable vs implementation complexity
- **Effort**: Zero
- **Performance**: Best

### Option B: Distance-Based Separation (✅ **Recommended**)
- **Method**: During movement, check distances to nearby entities manually
- **Implementation**:
  - Get all boss positions from registry
  - Use `distance_squared_to()` for performance
  - Check distances during `_update_ai()`
  - Apply small separation force if too close
- **Pros**: No additional collision shapes, simple logic, proven pattern
- **Cons**: O(n²) performance with many bosses
- **Optimization**: Use spatial partitioning or distance culling for large entity counts

### Option C: Godot Physics Layers (❌ **Confirmed Unavailable**)
- **Method**: Research if newer Godot versions support per-shape collision layers
- **Status**: ❌ **Not available in Godot 4.x** - collision layers are per-body, not per-shape
- **Fallback**: Not viable for current architecture

### Option D: Area2D + Signal-Based Detection (🔄 **Viable Alternative**)
- **Method**: Small Area2D child for entity detection using signals
- **Implementation**:
  - Add Area2D child with small collision shape
  - Connect to `body_entered`/`body_exited` signals
  - Apply gentle separation forces in signal handlers
- **Pros**: Real-time detection via signals, maintains terrain collision
- **Cons**: Additional collision detection overhead, signal management complexity

### Option E: Hybrid Bodies
- **Method**: Use RigidBody2D child with PinJoint2D for small collision
- **Complexity**: High
- **Performance**: Unknown

## Research Tasks ✅ **COMPLETED**

### 1. **Performance Analysis** ✅
   - ✅ Identified key performance patterns from Godot documentation
   - ✅ Found `distance_squared_to()` optimization for proximity checks
   - ✅ Discovered ECS patterns for spatial optimization (GECS research)

### 2. **Godot Documentation Review** ✅
   - ✅ **Confirmed**: Collision layers are per-body in Godot 4.x, not per-shape
   - ✅ **Confirmed**: Area2D overlap detection has physics-step timing constraints
   - ✅ **Found**: Signal-based detection preferred over polling for real-time response

### 3. **Alternative Architecture Analysis** ✅
   - ✅ **ECS Patterns**: GECS research revealed spatial query optimization techniques
   - ✅ **Distance Optimization**: Manhattan distance and caching strategies identified
   - ✅ **Entity Management**: Batch operations and query specificity for performance

### 4. **Best Practices Documentation** ✅
   - ✅ **Distance-based separation**: Proven pattern with optimization strategies
   - ✅ **Signal-based detection**: Real-time alternative to polling approaches
   - ✅ **Spatial partitioning**: Region-based grouping for large entity counts

## Decision Criteria

- **Performance**: Must maintain 60fps with 50+ enemies
- **Complexity**: Prefer simple solutions that are maintainable
- **Visual Quality**: Minimal entity overlap, smooth separation
- **Architecture Fit**: Should align with existing data-oriented enemy system

## **FINAL RECOMMENDATIONS** 🎯

### **Primary Recommendation: Option B - Distance-Based Separation**

Based on comprehensive Context7 research, the distance-based approach is the optimal solution:

**Implementation Strategy:**
```gdscript
# Gentle distance-based separation (minimal forces)
const SEPARATION_RADIUS: float = 32.0      # Only separate when very close
const SEPARATION_STRENGTH: float = 15.0    # Very weak force (pixels/second)
const MIN_SEPARATION_DISTANCE: float = 24.0 # Start separating at this distance

func apply_gentle_entity_separation(entity_pos: Vector2, other_positions: Array[Vector2]) -> Vector2:
    var separation_force = Vector2.ZERO
    var min_distance_sq = MIN_SEPARATION_DISTANCE * MIN_SEPARATION_DISTANCE

    for other_pos in other_positions:
        var distance_sq = entity_pos.distance_squared_to(other_pos)

        # Only apply force when very close
        if distance_sq < min_distance_sq and distance_sq > 1.0:  # Avoid division by zero
            var distance = sqrt(distance_sq)
            var direction = (entity_pos - other_pos) / distance  # Normalized

            # Exponential falloff - very gentle at edge, stronger when overlapping
            var strength_ratio = 1.0 - (distance / MIN_SEPARATION_DISTANCE)
            var force_magnitude = SEPARATION_STRENGTH * strength_ratio * strength_ratio

            separation_force += direction * force_magnitude

    return separation_force

# Integration with existing collision system
func _physics_process(delta):
    # 1. Normal AI movement (unchanged)
    velocity = calculate_ai_movement() * speed

    # 2. Add very gentle separation (barely noticeable)
    var other_positions = get_nearby_enemy_positions()
    var separation = apply_gentle_entity_separation(global_position, other_positions)
    velocity += separation * delta  # Very small influence

    # 3. Godot physics handles terrain/wall collision (unchanged)
    move_and_slide()  # Still prevents wall clipping!
```

**Performance Optimizations:**
- Use `distance_squared_to()` instead of `distance_to()`
- Only calculate separation when entities are very close (< 32 pixels)
- Exponential falloff prevents excessive separation forces
- Cache entity positions per physics frame
- Consider spatial partitioning for 100+ entities

**Key Design Principles:**
- **Minimal Forces**: 15 pixels/second base strength - barely noticeable
- **Close Range Only**: Only activates within 24-32 pixel radius
- **Exponential Falloff**: Gentle at edges, stronger when overlapping
- **Additive System**: Works alongside existing wall/terrain collision
- **Performance Conscious**: Avoids expensive calculations unless necessary

### **Alternative: Option D - Signal-Based Area2D**

For real-time separation requirements:
- Add small Area2D child to enemies
- Use `body_entered`/`body_exited` signals
- Apply separation in signal handlers
- More responsive but higher overhead

## Next Steps

1. **✅ READY**: Implement gentle distance-based separation in enemy system
2. **✅ READY**: Use very conservative parameters (15 px/sec strength, 24px range)
3. **✅ READY**: Integrate with existing `_physics_process()` before `move_and_slide()`
4. **✅ READY**: Test with multiple bosses and tune for natural feel

## Implementation Notes

**Start Ultra-Conservative:**
- Begin with `SEPARATION_STRENGTH = 8.0` (almost imperceptible)
- Only increase if overlap is still problematic
- Aim for "natural personal space" rather than obvious pushing
- Preserve existing terrain collision behavior completely

**Integration Point:**
- Add separation calculation between AI movement and `move_and_slide()`
- Existing collision detection remains unchanged
- Wall/terrain collision still takes priority over separation forces

## Notes

- Current system uses scene-based bosses (CharacterBody2D)
- Enemies have existing CollisionShape2D for terrain
- Game uses data-oriented approach for enemy management
- Performance is critical due to potential high enemy counts

---
**Created**: [Current Date]
**Priority**: Medium
**Estimated Effort**: 2-4 hours research + 1-2 hours implementation
**Dependencies**: None