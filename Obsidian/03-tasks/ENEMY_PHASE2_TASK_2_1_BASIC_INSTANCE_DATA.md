# Enemy Phase 2 - Task 2.1: Basic Instance Data

## Overview
**Duration:** 2 hours  
**Priority:** Medium (Animation Foundation)  
**Dependencies:** Tasks 1.1, 1.2, 1.3 completed  

## Goal
Pack animation data into MultiMesh `instance_custom_data` for basic frame cycling without shaders.

## What This Task Accomplishes
- ✅ Pack frame data into instance_custom_data
- ✅ Basic frame cycling without shaders
- ✅ Test with simple 4-frame animations
- ✅ Foundation for advanced animation system

## Files to Create/Modify

### 1. Create EnemyAnimationData.gd
**Location:** `vibe/scripts/systems/EnemyAnimationData.gd`
```gdscript
class_name EnemyAnimationData

# Pack animation data into Color for instance_custom_data
static func pack_animation_data(frame_x: int, frame_y: int, anim_time: float, state: int) -> Color:
    # Pack 4 values into Color (r, g, b, a)
    # frame_x: 0-15 (4 bits), frame_y: 0-15 (4 bits)
    # anim_time: normalized 0-1 (8 bits), state: 0-3 (2 bits)
    var packed = Color(
        frame_x / 16.0,      # r: frame_x (0-1)
        frame_y / 16.0,      # g: frame_y (0-1)  
        anim_time,            # b: animation time (0-1)
        state / 4.0           # a: state (0-1)
    )
    return packed

# Unpack animation data from Color
static func unpack_animation_data(color: Color) -> Dictionary:
    return {
        "frame_x": int(color.r * 16),
        "frame_y": int(color.g * 16),
        "anim_time": color.b,
        "state": int(color.a * 4)
    }
```

### 2. Modify EnemyVisualSystem.gd
**Location:** `vibe/scripts/systems/EnemyVisualSystem.gd`
- Add animation data packing
- Set instance custom data for each enemy
- Handle frame cycling logic

### 3. Create animation_test.json
**Location:** `vibe/data/enemies/animation_test.json`
```json
{
  "id": "animation_test",
  "display_name": "Animation Test Enemy",
  "render_tier": "regular",
  "health": 15.0,
  "speed": 40.0,
  "size": {"x": 32, "y": 32},
  "collision_radius": 16.0,
  "xp_value": 2,
  "visual": {
    "sprite_sheet": "res://assets/sprites/slime_green.png",
    "frame_size": {"x": 32, "y": 32},
    "animations": {
      "idle": {"frames": [0, 1, 2, 3], "fps": 8.0},
      "move": {"frames": [4, 5, 6, 7], "fps": 12.0},
      "death": {"frames": [8, 9, 10, 11], "fps": 15.0}
    }
  },
  "behavior": {
    "ai_type": "chase_player",
    "aggro_range": 250.0,
    "attack_range": 25.0
  }
}
```

## Implementation Steps

### Step 1: Create EnemyAnimationData.gd (45 min)
1. Create packing/unpacking functions
2. Test data packing accuracy
3. Validate bit packing logic
4. Add error handling

### Step 2: Modify EnemyVisualSystem.gd (45 min)
1. Integrate animation data packing
2. Set instance custom data for enemies
3. Handle frame cycling updates
4. Test with animation test enemy

### Step 3: Create animation_test.json (15 min)
1. Create test enemy with 4-frame animations
2. Test JSON loading and validation
3. Verify animation data structure

### Step 4: Testing & Validation (15 min)
1. Test frame cycling in MultiMesh
2. Verify data packing accuracy
3. Check performance impact
4. Validate animation timing

## Animation Data Structure

### Packed Data Format
```
Color.r (frame_x): 0-15 frames (4 bits)
Color.g (frame_y): 0-15 frames (4 bits)  
Color.b (anim_time): 0-1 normalized time (8 bits)
Color.a (state): 0-3 states (2 bits)
```

### Frame Cycling Logic
```gdscript
# Update frame based on time and FPS
var current_frame = int(anim_time * fps) % frame_count
var frame_x = current_frame % grid_columns
var frame_y = current_frame / grid_columns
```

## Success Criteria
- ✅ Animation data packed correctly into instance_custom_data
- ✅ Basic frame cycling working in MultiMesh
- ✅ Test enemy animating with 4 frames
- ✅ No performance regression
- ✅ Clean, maintainable code

## Performance Considerations
- **Minimal overhead** - data packing happens once per frame
- **Efficient updates** - only update active enemies
- **Memory usage** - 4 bytes per enemy for animation data
- **CPU impact** - simple math operations, no complex calculations

## Next Task
**Task 2.2: Simple UV Animation** - Basic shader for UV animation

## Notes
- Test data packing accuracy thoroughly
- Monitor performance impact
- Keep animation logic simple
- Document data format for future reference
