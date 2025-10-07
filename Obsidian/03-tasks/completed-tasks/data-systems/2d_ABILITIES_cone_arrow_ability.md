# Task 2d: Add Cone Arrow Ability (Ranger Volley)

**Goal:** Create a second projectile ability that fires arrows in a fixed cone pattern (non-homing), demonstrating ability variety with minimal configuration changes.

**Status:** 📝 Not Started
**Priority:** Low (enhancement)
**Estimated Time:** 15-20 minutes
**Dependencies:** Phase 1.5 (Ability Leveling System) complete

---

## Overview

The ability system already has cone spread logic built-in (`_calculate_spread_direction()` in ProjectileAbility.gd). This task demonstrates that you can create a **completely different ability feel** by simply changing 3 fields in a new `.tres` resource file.

**Key Insight:**
- **Homing Arrows (ranger_arrow):** Arrows curve toward enemies → good for mobile enemies
- **Cone Arrows (ranger_volley):** Arrows fire straight in fixed cone → good for grouped enemies

---

## Implementation Steps

### Step 1: Create New Ability Resource (5 minutes)

Create `data/content/abilities/projectile/ranger_volley.tres`:

```tres
[gd_resource type="Resource" script_class="ProjectileAbility" load_steps=3 format=3]

[ext_resource type="Script" path="res://scripts/resources/ProjectileAbility.gd" id="1"]
[ext_resource type="PackedScene" path="res://scenes/abilities/projectiles/Arrow.tscn" id="2"]

[resource]
script = ExtResource("1")
fire_mode = 0
is_homing = false                          # ← CHANGED: Disable homing
homing_strength = 0.0                      # ← CHANGED: No curve strength
chains_to_enemies = 0
chain_radius = 20.0
pierce_count = 0
knockback_distance = 50.0
ability_id = "ranger_volley"              # ← CHANGED: Unique ID
ability_name = "Ranger Volley"             # ← CHANGED: Display name
description = "Fire a volley of arrows in a cone pattern"  # ← CHANGED: Description
ability_level = 1
max_level = 20
damage_scaling_per_level = 1.15
cooldown_scaling_per_level = 0.95
level_breakpoints = Array[int]([])
breakpoint_bonuses = Array[String]([])
tags = Array[String](["damage", "cooldown", "projectile"])
base_damage = 44.0
base_cooldown = 0.5
damage_type = "physical"
inherent_element = ""
projectile_speed = 800.0
projectile_count = 3
projectile_lifetime = 1.0
buff_duration = 5.0
buff_stat_name = ""
buff_multiplier = 1.0
aoe_radius = 100.0
aoe_duration = 0.5
orbit_radius = 80.0
orbit_rotation_speed = 3.14159
orbit_projectile_count = 3
visual_scene = ExtResource("2")
```

**Changes from `ranger_arrow.tres`:**
1. `is_homing = false` (was `true`)
2. `homing_strength = 0.0` (was `1.0`)
3. `ability_id = "ranger_volley"` (was `"ranger_arrow"`)
4. `ability_name = "Ranger Volley"` (was `"Ranger Arrow"`)
5. `description = "Fire a volley of arrows in a cone pattern"` (new)

### Step 2: Register Ability in AbilityManager (5 minutes)

Add to `autoload/AbilityManager.gd`:

```gdscript
const ABILITY_REGISTRY = {
    "ranger_arrow": preload("res://data/content/abilities/projectile/ranger_arrow.tres"),
    "ranger_volley": preload("res://data/content/abilities/projectile/ranger_volley.tres"),  # ← Add this
}
```

### Step 3: Test with Debug Keybind (5 minutes)

**Option A: Replace existing ability slot**

Modify `scenes/arena/Player.gd` test keybind:

```gdscript
func _test_equip_ability(ability_id: String) -> void:
    # Change "ranger_arrow" to "ranger_volley" in slot 0
    ability_controller.equip_ability(ability_id, 0)
```

**Option B: Add to second slot**

```gdscript
# Alt+1: ranger_arrow in slot 0
# Alt+2: ranger_volley in slot 1
if event.alt_pressed:
    match event.keycode:
        KEY_1: _test_equip_ability("ranger_arrow", 0)
        KEY_2: _test_equip_ability("ranger_volley", 1)  # ← Add this
```

### Step 4: Verify Behavior (5 minutes)

**Expected Behavior:**

1. **Homing Arrows (ranger_arrow):**
   - 3 arrows fire in cone
   - **Arrows curve toward closest enemy**
   - Good for hitting moving targets

2. **Cone Arrows (ranger_volley):**
   - 3 arrows fire in cone
   - **Arrows fly straight (no homing)**
   - Fixed 40-degree spread pattern
   - Good for grouped enemies or stationary targets

**Test Procedure:**
1. Spawn 3-5 enemies in front of player
2. Fire homing arrows → observe curves
3. Switch to cone arrows → observe straight lines
4. Verify both abilities use same projectile count/damage
5. Test with Tome of Multiplication → verify cone scales

---

## Technical Details

### Cone Spread Implementation (Already Built-In)

From `ProjectileAbility.gd` line 198-216:

```gdscript
func _calculate_spread_direction(base_direction: Vector2, projectile_index: int, total_projectiles: int) -> Vector2:
    if total_projectiles == 1:
        return base_direction

    # Total spread angle in radians
    const TOTAL_SPREAD_ANGLE: float = deg_to_rad(40.0)  # 40 degrees total spread

    # Calculate angle offset for this projectile
    var spread_per_projectile := TOTAL_SPREAD_ANGLE / float(total_projectiles - 1)
    var angle_offset := -TOTAL_SPREAD_ANGLE / 2.0 + (projectile_index * spread_per_projectile)

    # Get base angle and apply offset
    var base_angle := base_direction.angle()
    var final_angle := base_angle + angle_offset

    return Vector2(cos(final_angle), sin(final_angle))
```

**How It Works:**
- 3 projectiles: [-20°, 0°, +20°] from base direction
- 5 projectiles: [-20°, -10°, 0°, +10°, +20°]
- 10 projectiles: 10 evenly spaced arrows across 40° cone

**Why This Works:**
- Homing enabled → Arrows start in cone, then curve toward enemies
- Homing disabled → Arrows fire in cone and continue straight

### Fire Modes

From `ProjectileAbility.gd` line 33-36:

```gdscript
enum FireMode {
    CLOSEST_ENEMY,  ## Targets the closest enemy to player
    RANDOM          ## Fires in random direction
}
```

**Both abilities use `CLOSEST_ENEMY` mode:**
- Determines base cone direction (toward nearest enemy)
- Homing arrows: cone + continuous tracking
- Cone arrows: cone only (static direction)

---

## Design Notes

### Why This Demonstrates Good Architecture

1. **Declarative Configuration:**
   - Change 3 fields in `.tres` → completely different ability feel
   - No code changes required
   - Instant hot-reload via Godot's resource system

2. **Reusability:**
   - Same arrow visual (`Arrow.tscn`)
   - Same damage system (DamageService)
   - Same pooling system (EntityPool)
   - Same tome modifiers (damage/cooldown/projectile count)

3. **Scalability:**
   - Can create 10+ projectile variants with different configs
   - Example future variants:
     - `ranger_pierce`: `pierce_count = 3` (arrows penetrate)
     - `ranger_shotgun`: `projectile_count = 8`, `projectile_speed = 1200`, `spread = 60°`
     - `ranger_chain`: `chains_to_enemies = 2`, `chain_radius = 300`

### Gameplay Considerations

**When to Use Homing Arrows:**
- Mobile enemies (fast zombies, flying enemies)
- Single target focus
- Poor player aim (accessibility)

**When to Use Cone Arrows:**
- Grouped enemies (swarms)
- Stationary targets (bosses during phases)
- Predictable enemy paths
- Higher skill ceiling (requires positioning)

**Balancing:**
- Cone arrows could have higher base damage (+10%) to compensate for no homing
- Or faster cooldown (0.4s vs 0.5s)
- Or more pierce (1 vs 0)

---

## Future Extensions (Not Required)

### Configurable Cone Angle

Add to `ProjectileAbility.gd`:

```gdscript
@export var cone_spread_angle: float = 40.0  # Degrees

func _calculate_spread_direction(...) -> Vector2:
    var TOTAL_SPREAD_ANGLE: float = deg_to_rad(cone_spread_angle)  # Use export
```

**Use Cases:**
- Tight cone (15°) for sniper-like precision
- Wide cone (90°) for shotgun-like coverage

### Fire Mode: Mouse Direction

```gdscript
enum FireMode {
    CLOSEST_ENEMY,
    RANDOM,
    MOUSE_DIRECTION  # ← New mode
}

func _determine_firing_direction(player: Node2D, context: Dictionary) -> Vector2:
    match fire_mode:
        FireMode.MOUSE_DIRECTION:
            return (player.get_global_mouse_position() - player.global_position).normalized()
```

**Benefit:** Player-controlled cone direction (twin-stick shooter feel)

---

## Testing Checklist

- [ ] Cone arrows fire straight (no homing curve)
- [ ] 3 arrows spread across 40-degree cone
- [ ] Cone direction targets closest enemy
- [ ] Damage identical to homing arrows (44.0 base)
- [ ] Overkill prevention works (arrows skip dead targets)
- [ ] Tome of Multiplication scales projectile count (3 → 8 with 5 stacks)
- [ ] Tome of Power scales damage (44 → 66 with 1 stack at 1.5x)
- [ ] Cooldown respects 0.5s base
- [ ] Ability levels up correctly (Ctrl+2 keybind if in slot 1)

---

## Success Criteria

✅ **ranger_volley.tres** created with `is_homing = false`
✅ Ability registered in AbilityManager
✅ Cone arrows fire straight (no curve)
✅ Visual difference clear from homing arrows
✅ All tome modifiers apply correctly
✅ Overkill prevention works (skip dead targets)

---

## Commit Message Template

```
feat(abilities): add Ranger Volley cone arrow ability

OVERVIEW:
Created second projectile ability demonstrating ability variety through
simple configuration changes. Cone arrows fire straight in 40° spread
vs homing arrows that curve toward enemies.

CHANGES:
- Created ranger_volley.tres with is_homing=false, homing_strength=0.0
- Registered in AbilityManager.ABILITY_REGISTRY
- Added test keybind (Alt+2) for second ability slot

ARCHITECTURE:
- Reuses existing cone spread system (_calculate_spread_direction)
- Same visual/pooling/damage as ranger_arrow
- Demonstrates declarative ability creation (3 field changes)

FILES CREATED:
- data/content/abilities/projectile/ranger_volley.tres

FILES MODIFIED:
- autoload/AbilityManager.gd (added registry entry)
- scenes/arena/Player.gd (added Alt+2 test keybind)

TESTING:
- Verified straight-line firing (no homing curve)
- Verified 40° cone spread with 3 projectiles
- Verified tome modifiers apply correctly
- Verified overkill prevention works

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>
```

---

## Estimated Time Breakdown

| Task | Time |
|------|------|
| Create ranger_volley.tres | 5 min |
| Register in AbilityManager | 2 min |
| Add test keybind | 3 min |
| Test and verify behavior | 5 min |
| Document findings | 5 min |
| **Total** | **~20 min** |

---

**Parent Tasks:** [2_ABILITIES_system_implementation.md](2_ABILITIES_system_implementation.md)
**Related:** Phase 1.5 (Ability Leveling System), Phase 1.4 (Tome Validation)
