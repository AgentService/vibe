# TODO: Upgrade Enemy Tiers to JSON-Based Animation

## Status: Ready to Implement
**Priority**: Medium  
**Estimated Time**: 1-2 hours  
**Dependencies**: SWARM tier JSON system (✅ Complete)

## Overview
Convert REGULAR, ELITE, and BOSS enemy tiers from hardcoded animation to JSON-based system, following the proven SWARM tier implementation.

## Current State
- ✅ **SWARM tier**: JSON-based animation (`swarm_enemy_animations.json`)
- ❌ **REGULAR tier**: Hardcoded frames 16-31, 0.1s duration
- ❌ **ELITE tier**: Hardcoded frames 16-31, 0.1s duration  
- ❌ **BOSS tier**: Hardcoded frames 16-31, 0.1s duration

## Implementation Tasks

### 1. Create Animation JSON Files
**Files to create:**
- `vibe/data/animations/regular_enemy_animations.json`
- `vibe/data/animations/elite_enemy_animations.json`  
- `vibe/data/animations/boss_enemy_animations.json`

**Template structure** (based on working SWARM system):
```json
{
  "sprite_sheet": "res://assets/sprites/knight.png",
  "frame_size": { "width": 32, "height": 32 },
  "grid": { "columns": 8, "rows": 8 },
  "animations": {
    "run": {
      "frames": [16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31],
      "duration": 0.1,
      "loop": true
    }
  }
}
```

### 2. Add Variables to Arena.gd
**Pattern**: Follow SWARM tier implementation in `Arena.gd:38-43`

Add for each tier:
```gdscript
# REGULAR JSON-based animation
var regular_animations: Dictionary = {}
var regular_run_textures: Array[ImageTexture] = []
var regular_current_frame: int = 0
var regular_frame_timer: float = 0.0
var regular_frame_duration: float = 0.1

# ELITE JSON-based animation  
var elite_animations: Dictionary = {}
var elite_run_textures: Array[ImageTexture] = []
var elite_current_frame: int = 0
var elite_frame_timer: float = 0.0
var elite_frame_duration: float = 0.1

# BOSS JSON-based animation
var boss_animations: Dictionary = {}
var boss_run_textures: Array[ImageTexture] = []
var boss_current_frame: int = 0
var boss_frame_timer: float = 0.0
var boss_frame_duration: float = 0.1
```

### 3. Create Loading Functions
**Pattern**: Follow `_load_swarm_animations()` and `_create_swarm_textures()`

Add functions:
- `_load_regular_animations()`
- `_create_regular_textures()`
- `_load_elite_animations()`
- `_create_elite_textures()`
- `_load_boss_animations()`
- `_create_boss_textures()`

### 4. Update MultiMesh Setup
**Location**: `Arena.gd:_setup_tier_multimeshes()`

**Current SWARM pattern** (lines 289-294):
```gdscript
if not swarm_run_textures.is_empty():
    mm_enemies_swarm.texture = swarm_run_textures[0]
    Logger.info("SWARM tier using JSON-based animation", "enemies")
else:
    mm_enemies_swarm.texture = knight_run_textures[0]
    Logger.info("SWARM tier using hardcoded animation (fallback)", "enemies")
```

Apply same pattern to REGULAR, ELITE, BOSS tiers.

### 5. Update Animation Functions
**Location**: `Arena.gd:_animate_other_tiers()`

**Current approach**: Single function handles all non-SWARM tiers  
**New approach**: Separate functions per tier (like `_animate_swarm_tier()`)

Create:
- `_animate_regular_tier(delta: float)`
- `_animate_elite_tier(delta: float)`  
- `_animate_boss_tier(delta: float)`

### 6. Update Function Calls
**Location**: `Arena.gd:194` - Add loading calls
```gdscript
_load_swarm_animations()     # ✅ Existing
_load_regular_animations()   # ➕ Add
_load_elite_animations()     # ➕ Add  
_load_boss_animations()      # ➕ Add
```

**Location**: `Arena.gd:_animate_enemy_frames()` - Update animation calls
```gdscript
func _animate_enemy_frames(delta: float) -> void:
    _animate_swarm_tier(delta)      # ✅ Existing
    _animate_regular_tier(delta)    # ➕ Add
    _animate_elite_tier(delta)      # ➕ Add
    _animate_boss_tier(delta)       # ➕ Add
```

## Benefits After Implementation
- ✅ **Consistency**: All enemy tiers use same JSON system as player
- ✅ **Flexibility**: Each tier can have different animation timing
- ✅ **Hot-reload**: Animation tweaks without code changes
- ✅ **Maintainability**: Animation data separate from logic
- ✅ **Extensibility**: Easy to add death/hit animations per tier

## Testing Checklist
- [ ] All 4 enemy tiers spawn with animations
- [ ] Each tier maintains distinct colors and sizes  
- [ ] Performance remains smooth
- [ ] JSON loading error handling works
- [ ] Fallback to hardcoded animation if JSON fails

## Files to Modify
- `vibe/scenes/arena/Arena.gd` (main implementation)
- `vibe/data/animations/regular_enemy_animations.json` (new)
- `vibe/data/animations/elite_enemy_animations.json` (new)  
- `vibe/data/animations/boss_enemy_animations.json` (new)

## Success Criteria
Game runs with all enemy tiers using JSON-based animations, maintaining current visual distinctions and performance.