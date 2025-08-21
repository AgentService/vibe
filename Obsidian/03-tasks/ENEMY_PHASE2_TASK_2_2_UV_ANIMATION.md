# Enemy Phase 2 - Task 2.2: Simple UV Animation

## Overview
**Duration:** 3 hours  
**Priority:** Medium (Animation Enhancement)  
**Dependencies:** Tasks 1.1-1.3, 2.1, 2.1.5 (Sprite Preparation) completed  

## Goal
Create basic shader for UV animation and apply it to MultiMesh for smooth enemy animations using sprites prepared in Task 2.1.5.

## What This Task Accomplishes
- ✅ Basic shader for UV animation
- ✅ Animate enemy movement frames
- ✅ Keep performance with MultiMesh
- ✅ Foundation for advanced shader effects

## Files to Create/Modify

### 1. Create enemy_animation.gdshader
**Location:** `vibe/shaders/enemy_animation.gdshader`
```glsl
shader_type canvas_item;

uniform sampler2D enemy_atlas;
uniform vec2 atlas_size = vec2(2048.0, 2048.0);
uniform float frame_size = 32.0;

varying flat vec4 instance_data; // frame_x, frame_y, time, state

void vertex() {
    instance_data = INSTANCE_CUSTOM;
    // Transform based on enemy data
}

void fragment() {
    // Calculate animated UV from instance data
    vec2 frame_pos = vec2(instance_data.x, instance_data.y);
    vec2 uv_offset = frame_pos * frame_size / atlas_size;
    vec2 uv_size = vec2(frame_size) / atlas_size;
    
    vec2 animated_uv = uv_offset + (UV * uv_size);
    COLOR = texture(enemy_atlas, animated_uv);
}
```

### 2. Modify EnemyVisualSystem.gd
**Location:** `vibe/scripts/systems/EnemyVisualSystem.gd`
- Apply shader to MultiMesh
- Handle shader uniforms
- Test UV animation

### 3. Create slime_animated.json
**Location:** `vibe/data/enemies/slime_animated.json`
```json
{
  "id": "slime_animated",
  "display_name": "Animated Green Slime",
  "render_tier": "regular",
  "health": 12.0,
  "speed": 45.0,
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
    "aggro_range": 280.0,
    "attack_range": 22.0
  }
}
```

## Implementation Steps

### Prerequisites: Verify Sprite Assets (from Task 2.1.5)
1. Confirm sprite sheets are available in `vibe/assets/sprites/enemies/`
2. Verify sprite_config.json is loaded correctly
3. Test basic sprite rendering in MultiMesh

### Step 1: Create enemy_animation.gdshader (1 hour)
1. Create basic UV animation shader using sprite atlases from Task 2.1.5
2. Test shader compilation
3. Validate UV calculations with prepared sprites
4. Add error handling

### Step 2: Modify EnemyVisualSystem.gd (1 hour)
1. Apply shader to MultiMesh
2. Set shader uniforms
3. Handle shader parameters
4. Test shader integration

### Step 3: Create slime_animated.json (30 min)
1. Create animated enemy definition
2. Test JSON loading and validation
3. Verify animation data structure

### Step 4: Testing & Validation (30 min)
1. Test UV animation in MultiMesh
2. Verify frame transitions
3. Check performance impact
4. Validate animation smoothness

## Shader Implementation Details

### UV Calculation
```glsl
// Calculate frame position in atlas
vec2 frame_pos = vec2(instance_data.x, instance_data.y);

// Convert to UV coordinates
vec2 uv_offset = frame_pos * frame_size / atlas_size;
vec2 uv_size = vec2(frame_size) / atlas_size;

// Apply to current UV
vec2 animated_uv = uv_offset + (UV * uv_size);
```

### Instance Data Usage
```glsl
// instance_data.x: frame_x (0-1 normalized)
// instance_data.y: frame_y (0-1 normalized)
// instance_data.z: animation time (0-1)
// instance_data.w: state (0-1 normalized)
```

## Success Criteria
- ✅ Shader compiles and runs correctly
- ✅ UV animation working in MultiMesh
- ✅ Smooth frame transitions
- ✅ No performance regression
- ✅ Clean, maintainable shader code

## Performance Considerations
- **GPU acceleration** - shader runs on GPU
- **Minimal CPU overhead** - only uniform updates
- **Efficient UV calculations** - simple math operations
- **Texture memory** - single atlas for all enemies

## Shader Optimization
- **Pre-calculate constants** - avoid per-fragment math
- **Use flat varying** - reduce interpolation overhead
- **Minimize texture lookups** - single texture sample
- **Efficient UV math** - simple addition/multiplication

## Next Task
**Task 2.3: State-Based Animation** - Switch animations based on enemy state

## Notes
- Use sprites prepared in Task 2.1.5 for testing
- Test shader on different enemy types from sprite_config.json
- Monitor GPU performance vs Task 2.1.5 baseline
- Keep shader simple for now
- Document shader parameters
- Test with various frame sizes defined in sprite preparation

## Related Tasks
- **Previous:** Task 2.1.5 (Sprite Preparation) - sprites must be ready
- **Next:** Task 2.3 (State-Based Animation) - uses UV animation foundation
