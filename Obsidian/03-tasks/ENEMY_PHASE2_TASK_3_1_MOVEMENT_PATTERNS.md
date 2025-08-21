# Enemy Phase 2 - Task 3.1: Basic Movement Patterns

## Overview
**Duration:** 3 hours  
**Priority:** Medium (AI Foundation)  
**Dependencies:** Tasks 1.1-1.3, 2.1-2.3 completed  

## Goal
Implement 3 basic movement patterns and apply them based on enemy type for varied enemy behavior.

## What This Task Accomplishes
- ✅ Implement 3 basic patterns: direct, zigzag, circle
- ✅ Apply patterns based on enemy type
- ✅ Test with simple enemies
- ✅ Foundation for advanced AI behaviors

## Files to Create/Modify

### 1. Create EnemyMovement.gd
**Location:** `vibe/scripts/systems/EnemyMovement.gd`
```gdscript
class_name EnemyMovement

enum MovementPattern {
    DIRECT_CHASE,    # Move directly toward target
    ZIGZAG_CHASE,    # Erratic movement toward target
    CIRCLE_STRAFE    # Orbit around target
}

# Direct chase - straight line to target
static func direct_chase(enemy_pos: Vector2, target_pos: Vector2, speed: float) -> Vector2:
    var direction = (target_pos - enemy_pos).normalized()
    return direction * speed

# Zigzag chase - erratic movement toward target
static func zigzag_chase(enemy_pos: Vector2, target_pos: Vector2, speed: float, time: float, zigzag_frequency: float = 2.0) -> Vector2:
    var base_direction = (target_pos - enemy_pos).normalized()
    var perpendicular = Vector2(-base_direction.y, base_direction.x)
    var zigzag_offset = sin(time * zigzag_frequency) * 0.3
    var final_direction = (base_direction + perpendicular * zigzag_offset).normalized()
    return final_direction * speed

# Circle strafe - orbit around target
static func circle_strafe(enemy_pos: Vector2, target_pos: Vector2, speed: float, time: float, orbit_radius: float = 100.0) -> Vector2:
    var to_target = target_pos - enemy_pos
    var distance = to_target.length()
    
    if distance < orbit_radius:
        # Move away to maintain orbit distance
        var direction = (enemy_pos - target_pos).normalized()
        return direction * speed
    else:
        # Orbit around target
        var angle = atan2(to_target.y, to_target.x) + time * 1.0
        var orbit_pos = target_pos + Vector2(cos(angle), sin(angle)) * orbit_radius
        var direction = (orbit_pos - enemy_pos).normalized()
        return direction * speed
```

### 2. Modify EnemyBehaviorSystem.gd
**Location:** `vibe/scripts/systems/EnemyBehaviorSystem.gd`
- Integrate movement patterns
- Apply patterns based on enemy type
- Handle pattern switching

### 3. Create movement_test.json
**Location:** `vibe/data/enemies/movement_test.json`
```json
{
  "id": "movement_test",
  "display_name": "Movement Test Enemy",
  "render_tier": "regular",
  "health": 18.0,
  "speed": 50.0,
  "size": {"x": 32, "y": 32},
  "collision_radius": 16.0,
  "xp_value": 2,
  "behavior": {
    "ai_type": "chase_player",
    "aggro_range": 350.0,
    "attack_range": 25.0,
    "movement_pattern": "zigzag_chase",
    "movement_params": {
      "zigzag_frequency": 2.5,
      "zigzag_amplitude": 0.4
    }
  }
}
```

## Implementation Steps

### Step 1: Create EnemyMovement.gd (1 hour)
1. Implement 3 movement patterns
2. Test pattern calculations
3. Add parameter validation
4. Optimize performance

### Step 2: Modify EnemyBehaviorSystem.gd (1 hour)
1. Integrate movement patterns
2. Apply patterns based on enemy type
3. Handle pattern switching
4. Test pattern integration

### Step 3: Create movement_test.json (30 min)
1. Create test enemy with movement pattern
2. Test JSON loading and validation
3. Verify movement configuration

### Step 4: Testing & Validation (30 min)
1. Test all movement patterns
2. Verify pattern switching
3. Check performance impact
4. Validate movement behavior

## Movement Pattern Details

### Direct Chase
- **Behavior**: Move straight toward target
- **Use case**: Basic enemies, fast movement
- **Parameters**: None (simple)
- **Performance**: Minimal overhead

### Zigzag Chase
- **Behavior**: Erratic movement toward target
- **Use case**: Evasive enemies, harder to hit
- **Parameters**: frequency, amplitude
- **Performance**: Sine calculation per frame

### Circle Strafe
- **Behavior**: Orbit around target
- **Use case**: Ranged enemies, tactical positioning
- **Parameters**: orbit_radius, orbit_speed
- **Performance**: Trigonometry per frame

## Success Criteria
- ✅ 3 movement patterns implemented and working
- ✅ Patterns apply based on enemy type
- ✅ Smooth pattern transitions
- ✅ No performance regression
- ✅ Clean, maintainable movement code

## Performance Considerations
- **Pattern calculations** - minimize per-frame math
- **Parameter validation** - cache validated values
- **Pattern switching** - smooth transitions
- **Memory usage** - efficient parameter storage

## Movement Parameters
- **Zigzag**: frequency (speed), amplitude (intensity)
- **Circle**: radius (distance), speed (orbit rate)
- **Direct**: no parameters (base behavior)

## Next Task
**Task 3.2: Formation Basics** - Basic formation spawning and group coordination

## Notes
- Test patterns with different enemy types
- Monitor performance impact
- Keep patterns simple for now
- Document pattern parameters
- Test pattern transitions
