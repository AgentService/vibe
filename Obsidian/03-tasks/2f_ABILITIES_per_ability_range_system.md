# [SUBTASK] Ability System - Per-Ability Range & Performance Optimization

**Parent Task:** `2_ABILITIES_system_implementation.md`
**Phase:** 2f (Performance & Polish - Range Optimization)
**Status:** 📋 Not Started
**Estimated Time:** 90 minutes
**Priority:** Medium (Performance Enhancement)

---

## 🎯 Phase Goal

Replace the hardcoded 800px detection range with per-ability range configuration. This enables:
- **Performance:** Close-range abilities (melee) don't scan 800px away
- **Design:** Long-range abilities can extend beyond 800px
- **Modifiers:** Tomes can increase ability range dynamically
- **Clarity:** Each ability defines its own engagement distance

---

## 📊 Current State Analysis

### Hardcoded Range Issue

**Location:** `scripts/systems/AbilityController.gd:319`

```gdscript
func _get_nearby_enemies() -> Array:
    # ... group query ...

    const DETECTION_RANGE: float = 800.0  # ❌ Hardcoded for ALL abilities

    for enemy in all_enemies:
        var distance := _player.global_position.distance_to(enemy_node.global_position)
        if distance <= DETECTION_RANGE:
            nearby_enemies.append(enemy_node)
```

**Problems:**
1. **Performance waste:** Melee abilities (200px range) scan 800px radius unnecessarily
2. **Design limitation:** Sniper abilities can't extend past 800px
3. **No modifier support:** Tomes can't increase "Range" stat
4. **One-size-fits-all:** All abilities use same detection distance

### Expected Ability Ranges

| Ability Type | Typical Range | Examples |
|--------------|---------------|----------|
| Melee | 150-250px | Sword Slash, Hammer Swing |
| Short Projectile | 400-600px | Throwing Knives, Daggers |
| Medium Projectile | 600-900px | Ranger Arrow, Fireball |
| Long Projectile | 900-1200px | Sniper Shot, Lightning Bolt |
| AOE/Pulse | 300-500px | Aura pulses, Ground slams |

---

## ✅ Tasks

### Task 2f.1: Add Range Properties to Ability Classes (~20 min)

**Files Modified:**
- `scripts/resources/abilities/DamageAbility.gd`
- `scripts/resources/abilities/ProjectileAbility.gd`

**Requirements:**

#### Step 1: Add Range to DamageAbility Base Class

**File:** `scripts/resources/abilities/DamageAbility.gd`

Add after the "Multi-Hit Properties" section:

```gdscript
# ============================================================================
# RANGE PROPERTIES
# ============================================================================

@export_group("Range")

## Base effective range in pixels (detection radius for targeting)
## This is the maximum distance at which this ability can engage enemies.
## - Melee: 150-250px
## - Short-range projectiles: 400-600px
## - Medium-range projectiles: 600-900px
## - Long-range projectiles: 900-1200px
@export_range(50.0, 2000.0, 50.0) var base_range: float = 800.0

## Final range after modifiers (computed at runtime)
## Tomes can increase this via range_multiplier
var final_range: float = 800.0
```

#### Step 2: Update DamageAbility._recalculate_final_stats()

**File:** `scripts/resources/abilities/DamageAbility.gd` (around line 170)

Add range recalculation to existing method:

```gdscript
func _recalculate_final_stats() -> void:
    # ... existing damage/cooldown recalculation ...

    # === Range Recalculation ===
    final_range = base_range

    # Apply tome/modifier range multipliers
    for modifier in _tome_modifiers:
        if "range_multiplier" in modifier and modifier.range_multiplier > 0.0:
            final_range *= modifier.range_multiplier

    # Clamp to reasonable min/max
    final_range = clampf(final_range, 50.0, 3000.0)
```

#### Step 3: Update ProjectileAbility Defaults

**File:** `scripts/resources/abilities/ProjectileAbility.gd`

Override base_range default for projectiles:

```gdscript
func _init() -> void:
    super._init()  # Initialize DamageAbility

    # Projectiles typically have longer range than melee
    if base_range == 800.0:  # Only override if using default value
        base_range = 900.0  # Projectile default

    # Ensure PROJECTILE tag is always present
    if not has_tag(AbilityTags.PROJECTILE):
        tags.append(AbilityTags.PROJECTILE)
```

**Success Criteria:**
- [ ] DamageAbility has base_range and final_range properties
- [ ] Range recalculates with tome modifiers
- [ ] ProjectileAbility defaults to 900px range
- [ ] Inspector shows range slider (50-2000px)
- [ ] Modifiers can scale final_range

**Testing:**
```gdscript
extends SceneTree

func _initialize():
    var ability = ProjectileAbility.new()
    ability.base_range = 600.0
    ability._recalculate_final_stats()

    print("Base range: %.0f" % ability.base_range)     # 600
    print("Final range: %.0f" % ability.final_range)   # 600

    # Apply tome with 1.25x range multiplier
    var tome_modifier = TomeModifier.new()
    tome_modifier.tome_id = "tome_range"
    tome_modifier.range_multiplier = 1.25
    ability._tome_modifiers.append(tome_modifier)
    ability._recalculate_final_stats()

    print("Final range after tome: %.0f" % ability.final_range)  # 750 (600 * 1.25)

    quit(0)
```

---

### Task 2f.2: Update AbilityController to Use Per-Ability Range (~25 min)

**File:** `scripts/systems/AbilityController.gd`

**Requirements:**

#### Step 1: Replace Hardcoded Range Constant

**Before (line 319):**
```gdscript
const DETECTION_RANGE: float = 800.0  # ❌ Hardcoded
```

**After:**
```gdscript
# REMOVED: const DETECTION_RANGE (now per-ability)
```

#### Step 2: Update _get_nearby_enemies() Method

**Location:** `scripts/systems/AbilityController.gd:308-333`

**Before:**
```gdscript
func _get_nearby_enemies() -> Array:
    var tree := _player.get_tree()
    if not tree:
        return []

    var all_enemies = tree.get_nodes_in_group("targetable")
    var nearby_enemies: Array = []

    const DETECTION_RANGE: float = 800.0  # ❌ Hardcoded

    for enemy in all_enemies:
        if not is_instance_valid(enemy):
            continue

        var enemy_node := enemy as Node2D
        if not enemy_node:
            continue

        var distance := _player.global_position.distance_to(enemy_node.global_position)
        if distance <= DETECTION_RANGE:
            nearby_enemies.append(enemy_node)

    return nearby_enemies
```

**After:**
```gdscript
## Gets nearby enemies within the CURRENT ABILITY'S effective range.
## Uses the ability's final_range property for dynamic range detection.
## Falls back to 800px if ability has no range property (utility abilities).
func _get_nearby_enemies(ability: BaseAbility) -> Array:
    var tree := _player.get_tree()
    if not tree:
        return []

    var all_enemies = tree.get_nodes_in_group("targetable")
    var nearby_enemies: Array = []

    # Use ability's final_range (supports tome modifiers)
    var detection_range: float = 800.0  # Default fallback
    if ability is DamageAbility:
        detection_range = ability.final_range

    for enemy in all_enemies:
        if not is_instance_valid(enemy):
            continue

        var enemy_node := enemy as Node2D
        if not enemy_node:
            continue

        var distance := _player.global_position.distance_to(enemy_node.global_position)
        if distance <= detection_range:
            nearby_enemies.append(enemy_node)

    return nearby_enemies
```

#### Step 3: Update All Callers of _get_nearby_enemies()

**Search pattern:** `_get_nearby_enemies()`

Update calls to pass the current ability:

**Example (ProjectileAbility activation):**
```gdscript
# Before:
var nearby_enemies = _get_nearby_enemies()

# After:
var nearby_enemies = _get_nearby_enemies(ability)
```

**Success Criteria:**
- [ ] _get_nearby_enemies() accepts ability parameter
- [ ] Uses ability.final_range for detection
- [ ] Falls back to 800px for non-DamageAbility types
- [ ] All callers updated to pass current ability
- [ ] No compilation errors

**Testing:**
- Place player at world origin (0, 0)
- Spawn enemy at (500, 0) - 500px away
- Test ability with base_range = 400px → enemy NOT detected
- Test ability with base_range = 600px → enemy detected
- Apply tome with 1.25x range → 400px ability now detects (500px range)

---

### Task 2f.3: Add Range Modifier to BaseTome (~15 min)

**File:** `scripts/resources/tomes/BaseTome.gd`

**Requirements:**

Add range multiplier property after damage/cooldown modifiers:

```gdscript
@export_group("Ability Modifiers")

# ... existing damage_multiplier, cooldown_multiplier ...

## Range multiplier (1.25 = +25% effective range)
## Applies to DamageAbility.final_range
## Affects detection radius for auto-targeting
@export var range_multiplier: float = 1.0
```

Update `apply_to_ability()` method:

```gdscript
func apply_to_ability(ability: BaseAbility, stack_count: int) -> void:
    if not can_apply_to_ability(ability):
        return

    # ... existing modifier creation ...

    modifier.range_multiplier = pow(range_multiplier, stack_count)

    # ... rest of method ...
```

**Success Criteria:**
- [ ] BaseTome has range_multiplier property
- [ ] range_multiplier stacks exponentially (like damage/cooldown)
- [ ] Tome modifiers include range in descriptor
- [ ] TomeModifier.gd has range_multiplier field

**Testing:**
Create test tome:
```tres
[resource]
tome_id = "tome_range"
tome_name = "Tome of Reach"
description = "Extends ability range by 25% per stack"
range_multiplier = 1.25
applicable_tags = Array[String](["projectile"])
```

Apply to 600px range ability:
- 1 stack → 750px range
- 2 stacks → 937px range
- 3 stacks → 1171px range

---

### Task 2f.4: Update Existing Ability .tres Files (~20 min)

**Files to Update:**

#### Ranger Arrow (Projectile - Medium Range)
**File:** `data/content/abilities/projectile/ranger_arrow.tres`

Add range property:
```tres
[resource]
# ... existing properties ...
base_range = 800.0  # Medium-range projectile
```

#### Future Melee Ability Example
**File:** `data/content/abilities/melee/sword_slash.tres` (create if implementing melee)

```tres
[resource]
script = ExtResource("MeleeAbility.gd")
ability_id = "sword_slash"
ability_name = "Sword Slash"
base_damage = 25.0
base_cooldown = 0.8
base_range = 200.0  # ✅ Short melee range (close-quarters only)
cone_angle = 90.0
```

#### Future Sniper Ability Example
**File:** `data/content/abilities/projectile/sniper_shot.tres`

```tres
[resource]
script = ExtResource("ProjectileAbility.gd")
ability_id = "sniper_shot"
ability_name = "Sniper Shot"
base_damage = 50.0
base_cooldown = 2.0
base_range = 1200.0  # ✅ Long-range sniper (exceeds old 800px limit)
projectile_speed = 1200.0
```

**Success Criteria:**
- [ ] All existing abilities have base_range defined
- [ ] Range values match ability archetype (melee < projectile < sniper)
- [ ] Inspector can edit range slider
- [ ] No warnings about missing range property

---

### Task 2f.5: Performance Validation & Testing (~10 min)

**Test Scenarios:**

#### Scenario 1: Melee Range Performance (200px)
**Setup:**
- Equip melee ability with base_range = 200px
- Spawn 50 enemies: 10 within 200px, 40 beyond 800px

**Expected Behavior:**
- Only 10 enemies detected (200px radius)
- Old system: 10 enemies detected (800px radius, wasted checks on 30 distant enemies)

**Performance Gain:**
- ~80% fewer distance checks for melee abilities
- Verified via Logger.debug() or profiler

#### Scenario 2: Long-Range Projectile (1200px)
**Setup:**
- Equip sniper ability with base_range = 1200px
- Spawn enemies at 900px, 1000px, 1100px

**Expected Behavior:**
- All 3 enemies detected (within 1200px)
- Old system: Only enemies within 800px detected (missed 2 targets)

**Result:**
- ✅ Long-range abilities can now exceed old 800px limit

#### Scenario 3: Range Tome Modifier
**Setup:**
- Equip 400px range ability
- Spawn enemy at 500px distance
- Apply Tome of Reach (×1.25 range)

**Expected Behavior:**
- Before tome: Enemy NOT detected (500px > 400px)
- After tome: Enemy detected (final_range = 500px)

**Result:**
- ✅ Tomes can dynamically extend ability engagement range

**Automated Test:**
```gdscript
extends SceneTree

func _initialize():
    print("=== Per-Ability Range Test ===")

    # Test 1: Melee range filters distant enemies
    var melee_ability = DamageAbility.new()
    melee_ability.base_range = 200.0
    melee_ability._recalculate_final_stats()

    assert(melee_ability.final_range == 200.0, "Melee range incorrect")
    print("✓ Melee ability has 200px range")

    # Test 2: Sniper range exceeds old 800px limit
    var sniper_ability = ProjectileAbility.new()
    sniper_ability.base_range = 1200.0
    sniper_ability._recalculate_final_stats()

    assert(sniper_ability.final_range == 1200.0, "Sniper range incorrect")
    print("✓ Sniper ability has 1200px range (exceeds old limit)")

    # Test 3: Tome modifier increases range
    var ability = ProjectileAbility.new()
    ability.base_range = 600.0

    var tome_modifier = TomeModifier.new()
    tome_modifier.tome_id = "tome_range"
    tome_modifier.range_multiplier = 1.25
    ability._tome_modifiers.append(tome_modifier)
    ability._recalculate_final_stats()

    assert(abs(ability.final_range - 750.0) < 1.0, "Range modifier failed")
    print("✓ Tome modifier scales range correctly (600 → 750)")

    print("\n✓✓✓ ALL RANGE TESTS PASSED ✓✓✓")
    quit(0)
```

Run: `../Godot_v4.4.1-stable_win64_console.exe --headless --script tests/test_ability_range.gd`

---

## 📊 Phase 2f Completion Checklist

- [ ] DamageAbility has base_range and final_range properties
- [ ] Range recalculates with tome modifiers
- [ ] AbilityController uses ability.final_range (not hardcoded 800px)
- [ ] BaseTome has range_multiplier property
- [ ] All existing ability .tres files have base_range defined
- [ ] Melee abilities use 150-250px range (performance gain)
- [ ] Long-range abilities can exceed 1000px (design flexibility)
- [ ] Tome of Reach created and tested (×1.25 range per stack)
- [ ] Automated test passes (melee, sniper, tome modifier)
- [ ] No compilation errors or warnings

---

## 🎯 Performance Impact Analysis

### Before (Hardcoded 800px)
**Melee Ability (200px effective range):**
- Scans 800px radius (2010 px² area)
- Checks 50 enemies (10 relevant, 40 irrelevant)
- **80% wasted distance checks**

**Sniper Ability (1200px desired range):**
- Limited to 800px radius
- **Cannot target enemies beyond 800px**

### After (Per-Ability Range)
**Melee Ability (200px final_range):**
- Scans 200px radius (502 px² area)
- Checks 10 enemies (all relevant)
- **0% wasted checks** ✅

**Sniper Ability (1200px final_range):**
- Scans 1200px radius (4524 px² area)
- **Can target all enemies within design range** ✅

**Performance Gain:**
- **Melee abilities:** ~80% fewer enemy checks per frame
- **Long-range abilities:** +50% engagement radius
- **Design flexibility:** Range modifiers via tomes

---

## 🔗 Integration Points

**Files Modified:**
- `scripts/resources/abilities/DamageAbility.gd` - Add base_range/final_range properties
- `scripts/resources/abilities/ProjectileAbility.gd` - Override range default
- `scripts/systems/AbilityController.gd` - Use per-ability range for detection
- `scripts/resources/tomes/BaseTome.gd` - Add range_multiplier modifier
- `data/content/abilities/projectile/ranger_arrow.tres` - Set base_range = 800px

**Files Created:**
- `data/content/tomes/tome_range.tres` - Tome of Reach (×1.25 range)
- `tests/test_ability_range.gd` - Automated range system test

**Backward Compatibility:**
- ✅ Existing abilities default to 800px if base_range not set
- ✅ Non-DamageAbility types (utility) use 800px fallback
- ✅ No breaking changes to ability activation flow

---

## 📝 Notes

**Design Decisions:**
- **Range as DamageAbility property** - All damage-dealing abilities need targeting range
- **final_range computed property** - Consistent with final_damage/final_cooldown pattern
- **Fallback to 800px** - Maintains backward compatibility for utility abilities
- **Exponential stacking** - Tome range modifiers stack like damage (pow() pattern)

**Future Enhancements:**
- **Minimum range** - Sniper abilities can't fire at close range (base_min_range)
- **Range breakpoints** - Level 10 grants +20% range bonus
- **Visual indicators** - Show ability range circles in debug overlay
- **Range types** - Detection range vs projectile travel range (separate concerns)

**Performance Monitoring:**
```gdscript
# Add to AbilityController for performance tracking
var _last_range_scan_time_us: int = 0

func _get_nearby_enemies(ability: BaseAbility) -> Array:
    var start_time = Time.get_ticks_usec()

    # ... existing detection logic ...

    _last_range_scan_time_us = Time.get_ticks_usec() - start_time
    if _last_range_scan_time_us > 500:  # >0.5ms warning
        Logger.warn("Slow range scan: %d μs" % _last_range_scan_time_us, "performance")

    return nearby_enemies
```

---

## ⏭️ Next Phase

**After Phase 2f complete → Continue with remaining ability system tasks**

Remaining tasks:
- ✅ Phase 2a-2d: Foundation, Integration, Vertical Slice, Tome Validation (COMPLETE - archived)
- ✅ Phase 2e: Visual Effects POC (ongoing)
- ✅ Phase 2f: Per-Ability Range System (current)
- ❌ Phase 2g: Tome System Unification (~60 min)
- ❌ Phase 5: Clean Melee Migration (~2 hours)
- ❌ Phase 6: Expand Ability Library (~4-6 hours)

---

**Status:** Ready to begin Task 2f.1 (Add Range Properties to Ability Classes)
