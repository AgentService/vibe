# Enemy Phase 2 - Task 2.3: State-Based Animation

## Overview
**Duration:** 2 hours  
**Priority:** Medium (Behavior Foundation)  
**Dependencies:** Tasks 1.1-1.3, 2.1-2.2 completed  

## Goal
Define enemy states and switch animations based on state while maintaining smooth transitions.

## What This Task Accomplishes
- ✅ Define enemy states (IDLE, MOVING, DYING)
- ✅ Switch animations based on state
- ✅ Basic state machine foundation
- ✅ Smooth animation transitions

## Files to Create/Modify

### 1. Create EnemyState.gd
**Location:** `vibe/scripts/systems/EnemyState.gd`
```gdscript
enum EnemyState {
    SPAWNING = 0,   # Enemy just spawned
    IDLE = 1,       # Enemy waiting/idle
    MOVING = 2,     # Enemy moving toward target
    ATTACKING = 3,  # Enemy attacking
    HURT = 4,       # Enemy taking damage
    DYING = 5,      # Enemy death animation
    DEAD = 6        # Enemy dead (inactive)
}

class_name EnemyStateManager

# State transition validation
static func can_transition_from(from_state: EnemyState, to_state: EnemyState) -> bool:
    match from_state:
        EnemyState.SPAWNING:
            return to_state in [EnemyState.IDLE, EnemyState.MOVING]
        EnemyState.IDLE:
            return to_state in [EnemyState.MOVING, EnemyState.ATTACKING, EnemyState.HURT, EnemyState.DYING]
        EnemyState.MOVING:
            return to_state in [EnemyState.IDLE, EnemyState.ATTACKING, EnemyState.HURT, EnemyState.DYING]
        EnemyState.ATTACKING:
            return to_state in [EnemyState.IDLE, EnemyState.MOVING, EnemyState.HURT, EnemyState.DYING]
        EnemyState.HURT:
            return to_state in [EnemyState.IDLE, EnemyState.MOVING, EnemyState.DYING]
        EnemyState.DYING:
            return to_state == EnemyState.DEAD
        EnemyState.DEAD:
            return false  # Dead is final state
        _:
            return false
```

### 2. Modify EnemyVisualSystem.gd
**Location:** `vibe/scripts/systems/EnemyVisualSystem.gd`
- Add state-based animation switching
- Handle state transitions
- Update animation data based on state

### 3. Create state_test.json
**Location:** `vibe/data/enemies/state_test.json`
```json
{
  "id": "state_test",
  "display_name": "State Test Enemy",
  "render_tier": "regular",
  "health": 20.0,
  "speed": 35.0,
  "size": {"x": 32, "y": 32},
  "collision_radius": 16.0,
  "xp_value": 3,
  "visual": {
    "sprite_sheet": "res://assets/sprites/slime_green.png",
    "frame_size": {"x": 32, "y": 32},
    "animations": {
      "idle": {"frames": [0, 1, 2, 3], "fps": 8.0},
      "move": {"frames": [4, 5, 6, 7], "fps": 12.0},
      "attack": {"frames": [8, 9, 10, 11], "fps": 15.0},
      "hurt": {"frames": [12, 13, 14, 15], "fps": 20.0},
      "death": {"frames": [16, 17, 18, 19], "fps": 12.0}
    }
  },
  "behavior": {
    "ai_type": "chase_player",
    "aggro_range": 300.0,
    "attack_range": 30.0,
    "states": {
      "idle_duration": 2.0,
      "attack_cooldown": 1.5,
      "hurt_duration": 0.5
    }
  }
}
```

## Implementation Steps

### Step 1: Create EnemyState.gd (45 min)
1. Define enemy state enum
2. Create state transition validation
3. Add helper methods for state management
4. Test state logic

### Step 2: Modify EnemyVisualSystem.gd (45 min)
1. Integrate state-based animation switching
2. Handle state transitions
3. Update animation data based on state
4. Test with state test enemy

### Step 3: Create state_test.json (15 min)
1. Create test enemy with state-based animations
2. Test JSON loading and validation
3. Verify state configuration

### Step 4: Testing & Validation (15 min)
1. Test state transitions
2. Verify animation switching
3. Check state validation
4. Validate smooth transitions

## State Machine Logic

### State Transitions
```
SPAWNING → IDLE/MOVING
IDLE → MOVING/ATTACKING/HURT/DYING
MOVING → IDLE/ATTACKING/HURT/DYING
ATTACKING → IDLE/MOVING/HURT/DYING
HURT → IDLE/MOVING/DYING
DYING → DEAD
DEAD → (final state)
```

### Animation Mapping
```gdscript
# Map states to animations
var state_animations = {
    EnemyState.IDLE: "idle",
    EnemyState.MOVING: "move",
    EnemyState.ATTACKING: "attack",
    EnemyState.HURT: "hurt",
    EnemyState.DYING: "death"
}
```

## Success Criteria
- ✅ Enemy states defined and working
- ✅ State transitions validated correctly
- ✅ Animations switch based on state
- ✅ Smooth state transitions
- ✅ Clean, maintainable state machine

## State Management Features
- **Validation** - prevent invalid state transitions
- **Persistence** - maintain state across frames
- **Transitions** - smooth animation changes
- **Debugging** - log state changes for debugging

## Performance Considerations
- **State validation** - simple enum comparisons
- **Animation switching** - minimal overhead
- **Memory usage** - only store current state
- **Update frequency** - only when state changes

## Next Task
**Task 3.1: Basic Movement Patterns** - Implement 3 basic movement patterns

## Notes
- Test all state transitions
- Validate state logic thoroughly
- Keep state machine simple
- Document state rules
- Test with various enemy types
