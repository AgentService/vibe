# Enemy Phase 2 - Task 2.1.5: Sprite Preparation

## Overview
**Duration:** 1-2 hours  
**Priority:** High (Animation Foundation)  
**Dependencies:** Task 2.1 (Basic Instance Data) completed  

## Goal
Prepare and integrate sprite assets for enemy animations before implementing UV animation shaders.

## What This Task Accomplishes
- ✅ Gather/create sprite sheets for enemy types
- ✅ Test sprite integration with existing MultiMesh system
- ✅ Create sprite atlases with proper sizing
- ✅ Verify sprite loading and basic rendering
- ✅ Foundation ready for UV animation implementation

## Files to Create/Modify

### 1. Create sprite assets directory structure
**Location:** `vibe/assets/sprites/enemies/`
```
enemies/
├── slime_green_32x32.png      # 4x3 grid: idle(4), move(4), death(4)
├── grunt_basic_48x48.png      # 4x3 grid: idle(4), move(4), death(4)
├── archer_skeleton_32x32.png  # 4x4 grid: idle(4), move(4), attack(4), death(4)
└── README.md                  # Sprite format documentation
```

### 2. Create sprite_config.json
**Location:** `vibe/data/enemies/sprite_config.json`
```json
{
  "atlas_settings": {
    "default_frame_size": {"x": 32, "y": 32},
    "atlas_max_size": {"x": 2048, "y": 2048},
    "sprite_formats": ["PNG"],
    "animation_fps": {
      "idle": 8.0,
      "move": 12.0,
      "attack": 15.0,
      "death": 10.0
    }
  },
  "sprite_requirements": {
    "swarm_enemies": {
      "max_size": {"x": 24, "y": 24},
      "required_animations": ["idle", "move", "death"]
    },
    "regular_enemies": {
      "max_size": {"x": 48, "y": 48},
      "required_animations": ["idle", "move", "death"]
    },
    "elite_enemies": {
      "max_size": {"x": 64, "y": 64},
      "required_animations": ["idle", "move", "attack", "death"]
    },
    "boss_enemies": {
      "min_size": {"x": 80, "y": 80},
      "required_animations": ["idle", "move", "attack", "special", "death"]
    }
  }
}
```

### 3. Update existing enemy JSON files
**Files:** `slime_green.json`, `grunt_basic.json`, `archer_skeleton.json`
- Add sprite_sheet path
- Add animation frame data
- Keep existing functionality intact

### 4. Create SpriteTestSystem.gd
**Location:** `vibe/scripts/systems/SpriteTestSystem.gd`
```gdscript
extends Node
class_name SpriteTestSystem

## Test system for verifying sprite integration before UV animation

func test_sprite_loading() -> bool:
    # Test sprite resource loading
    # Verify frame data
    # Check MultiMesh compatibility
    return true

func test_basic_sprite_rendering() -> bool:
    # Test sprites in MultiMesh without animation
    # Verify performance with sprite textures
    return true
```

## Implementation Steps

### Step 1: Create sprite asset structure (30 min)
1. Create directory structure for sprite assets
2. Document sprite format requirements
3. Create placeholder sprites or gather existing assets
4. Test sprite loading in Godot

### Step 2: Create sprite_config.json (15 min)
1. Define sprite configuration schema
2. Set animation frame rates
3. Define size requirements per tier
4. Test JSON loading

### Step 3: Update existing enemy JSONs (20 min)
1. Add sprite_sheet field to slime_green.json
2. Add animation frame data
3. Update other enemy files
4. Test backwards compatibility

### Step 4: Create SpriteTestSystem.gd (30 min)
1. Create basic sprite testing system
2. Test sprite loading functionality
3. Verify MultiMesh integration
4. Test performance with sprites vs colored shapes

### Step 5: Integration testing (15 min)
1. Test sprites render in existing MultiMesh
2. Verify performance is maintained
3. Check that colored fallback still works
4. Validate sprite data structure

## Sprite Asset Requirements

### File Format Standards
- **Format:** PNG with transparency
- **Bit depth:** 32-bit RGBA
- **Compression:** Lossless
- **Naming:** `{enemy_type}_{size}x{size}.png`

### Animation Grid Layout
```
Frame Layout (4x3 grid example):
[0][1][2][3]  ← Idle animation (frames 0-3)
[4][5][6][7]  ← Move animation (frames 4-7)  
[8][9][10][11] ← Death animation (frames 8-11)
```

### Size Guidelines
- **SWARM (24x24):** Simple, minimal detail
- **REGULAR (32x32):** Standard detail level
- **ELITE (48x48):** Enhanced detail, effects
- **BOSS (64x64+):** High detail, unique design

## Testing Checklist
- [ ] Sprites load correctly via ResourceLoader
- [ ] MultiMesh accepts sprite textures
- [ ] Performance maintained with textured rendering
- [ ] Animation frame data validates correctly
- [ ] Fallback to colored shapes works if sprites missing
- [ ] Proper error handling for missing sprites

## Success Criteria
- ✅ Sprite assets created and properly formatted
- ✅ Sprite loading system working
- ✅ MultiMesh renders sprites correctly
- ✅ No performance regression from colored shapes
- ✅ Clean sprite configuration system
- ✅ Ready for UV animation shader implementation

## Performance Considerations
- **Texture memory:** Keep sprite sheets optimized
- **MultiMesh compatibility:** Ensure sprites work with instancing
- **Fallback system:** Colored shapes if sprites fail to load
- **Loading time:** Minimize resource loading overhead

## Next Task
**Task 2.2: Simple UV Animation** - Implement shader-based UV animation using prepared sprites

## Notes
- Test sprites with current MultiMesh system first
- Keep colored shape fallback for development
- Document any sprite format discoveries
- Consider sprite atlas optimization for later
- Verify Godot import settings for pixel art