# [SUBTASK] Ability System - Phase 1: Foundation & Infrastructure

**Parent Task:** `2_ABILITIES_system_implementation.md`
**Phase:** 1 of 4
**Status:** 📋 Not Started
**Estimated Time:** 4-6 hours

---

## 🎯 Phase Goal

Create core classes and tag system without any gameplay integration.
Validate that all foundation components load, compile, and have correct base behavior.

---

## ✅ Tasks

### Task 1.1.1: Create Tag System (~30 min)

**File:** `scripts/domain/AbilityTags.gd`

**Requirements:**
- [ ] Create file at `scripts/domain/AbilityTags.gd`
- [ ] Define ~15 StringName constants (use `&"tag"` syntax for performance)
- [ ] Add tag categories comment block
- [ ] Add helper functions:
  - `get_all_tags() -> Array[StringName]`
  - `is_valid_tag(tag: StringName) -> bool`
  - `get_tag_description(tag: StringName) -> String`
  - `get_tag_color(tag: StringName) -> Color`

**Tag Categories:**
```gdscript
# Damage categories
DAMAGE, PHYSICAL, ELEMENTAL, FIRE, COLD, LIGHTNING, POISON

# Delivery methods
PROJECTILE, AOE, MELEE, BUFF, DEBUFF, ORBIT, SUMMON

# Scaling categories
COOLDOWN, DURATION, AREA
```

**Success Criteria:**
- [ ] Can reference `AbilityTags.PROJECTILE` from any script
- [ ] All tag categories documented inline
- [ ] No syntax errors when loading in Godot

**Testing:**
Open Godot Script Editor, create test script:
```gdscript
extends Node

func _ready():
	print(AbilityTags.PROJECTILE)  # Should print: projectile
	print(AbilityTags.get_all_tags().size())  # Should print: ~15
	print(AbilityTags.is_valid_tag(&"fire"))  # Should print: true
	print(AbilityTags.is_valid_tag(&"invalid"))  # Should print: false
```

---

### Task 1.1.2: Create BaseAbility Class (~2 hours)

**File:** `scripts/resources/BaseAbility.gd`

**Requirements:**
- [ ] Create file at `scripts/resources/BaseAbility.gd`
- [ ] Extend `Resource`, class_name `BaseAbility`
- [ ] Implement all @export properties from architecture doc:
  - Core Identity (ability_id, ability_name, description, icon)
  - Progression (ability_level, max_level, scaling_per_level, level_breakpoints)
  - Tags (Array[String])
  - Base Stats (base_damage, cooldown)
  - Damage Type & Element (damage_type, inherent_element)
  - Optional Properties (projectile_*, buff_*, aoe_*, orbit_*)
  - Visual References (visual_scene, impact_effect)
- [ ] Implement `level_up(levels: int = 1)` with scaling
- [ ] Implement `_apply_breakpoint_bonus(bonus: String)`
- [ ] Implement tag helpers: `has_tag()`, `has_all_tags()`, `has_any_tag()`
- [ ] Implement `activate(player: Node2D, context: Dictionary)` stub (push_warning)
- [ ] Implement `to_dict() -> Dictionary` for debugging
- [ ] Implement `validate() -> Array[String]` for tag validation (returns error strings)
- [ ] Add comprehensive class documentation

**Success Criteria:**
- [ ] Class loads without errors in Godot
- [ ] All @export properties appear in Inspector
- [ ] `level_up()` correctly scales damage/cooldown based on tags
- [ ] `has_tag()` returns correct bool
- [ ] Tags array can contain StringName values

**Testing (Headless Script):**
Create `tests/ability_system/test_base_ability_levelup.gd`:
```gdscript
extends SceneTree

func _initialize():
	var ability = BaseAbility.new()
	ability.ability_id = "test_ability"
	ability.base_damage = 10.0
	ability.cooldown = 2.0
	ability.damage_scaling_per_level = 1.15
	ability.cooldown_scaling_per_level = 0.95
	ability.tags = [AbilityTags.DAMAGE, AbilityTags.COOLDOWN]

	print("=== BaseAbility Level-Up Test ===")
	print("Initial: damage=%.2f, cooldown=%.2f" % [ability.base_damage, ability.cooldown])

	ability.level_up(5)

	var expected_damage = 10.0 * pow(1.15, 5)  # ≈ 20.11
	var expected_cooldown = 2.0 * pow(0.95, 5)  # ≈ 1.55

	print("After 5 levels: damage=%.2f (expected: %.2f)" % [ability.base_damage, expected_damage])
	print("After 5 levels: cooldown=%.2f (expected: %.2f)" % [ability.cooldown, expected_cooldown])

	var damage_diff = abs(ability.base_damage - expected_damage)
	var cooldown_diff = abs(ability.cooldown - expected_cooldown)

	if damage_diff < 0.01 and cooldown_diff < 0.01:
		print("✓ TEST PASSED")
		quit(0)
	else:
		print("✗ TEST FAILED")
		quit(1)
```

Run with: `../Godot_v4.4.1-stable_win64_console.exe --headless --script tests/ability_system/test_base_ability_levelup.gd`

---

### Task 1.1.3: Create ProjectileAbility Subclass (~1 hour)

**File:** `scripts/resources/ProjectileAbility.gd`

**Requirements:**
- [ ] Create file at `scripts/resources/ProjectileAbility.gd`
- [ ] Extend `BaseAbility`, class_name `ProjectileAbility`
- [ ] Add projectile-specific @export properties:
  - `fire_pattern` (enum: forward, spread, circle, targeted)
  - `spread_angle` (float)
  - `is_homing` (bool)
  - `homing_strength` (float)
  - `projectile_lifetime` (float)
  - `chains_to_enemies` (int)
  - `chain_radius` (float)
- [ ] Override `activate()` to emit `EventBus.ability_projectile_requested`
- [ ] Implement fire patterns: `_fire_forward()`, `_fire_spread()`, `_fire_circle()`, `_fire_targeted()`
- [ ] Implement `_create_projectile_data()` to build payload dictionary
- [ ] Ensure projectile abilities have required tags (PROJECTILE, COOLDOWN, DAMAGE)
- [ ] Add comprehensive documentation

**Success Criteria:**
- [ ] Class extends BaseAbility correctly
- [ ] Inspector shows inherited + projectile-specific properties
- [ ] `activate()` emits signal with correct payload structure
- [ ] Fire patterns calculate correct directions

**Testing:**
Create test scene with ProjectileAbility instance, call `activate()`, verify:
- Signal emitted with correct payload keys
- `_fire_spread()` creates correct angle offsets
- `_fire_circle()` distributes projectiles evenly (360° / projectile_count)

---

### Task 1.1.4: Create BaseTome Class (~30 min)

**File:** `scripts/resources/BaseTome.gd`

**Requirements:**
- [ ] Create file at `scripts/resources/BaseTome.gd`
- [ ] Extend `Resource`, class_name `BaseTome`
- [ ] Implement all @export properties from architecture doc:
  - Core Identity (tome_id, tome_name, description, icon, rarity)
  - Stacking (stack_limit)
  - Applicability (applicable_tags)
  - Ability Modifiers (damage_multiplier, cooldown_multiplier, projectile_count_bonus, etc.)
  - Player Stat Modifiers (movement_speed_multiplier, max_hp_bonus, luck_bonus, xp_gain_multiplier)
- [ ] Implement `can_apply_to_ability(ability: BaseAbility) -> bool`
  - Return true if applicable_tags is EMPTY (global modifier)
  - Return true if ability has ANY of the required tags
- [ ] Implement `apply_to_ability(ability: BaseAbility, stack_count: int)`
  - Multiplicative scaling: `pow(multiplier, stack_count)`
  - Additive bonuses: `bonus * stack_count`
- [ ] Implement `apply_to_player(player: Node2D, stack_count: int)`
  - Apply movement speed, HP, luck, XP multipliers
- [ ] Add comprehensive documentation

**Success Criteria:**
- [ ] Tag matching works correctly (ANY logic for applicable_tags)
- [ ] Stat modifications apply correctly (additive vs multiplicative)
- [ ] Can stack multiple tomes on same ability
- [ ] Empty applicable_tags applies to ALL abilities

**Testing:**
```gdscript
extends SceneTree

func _initialize():
	var ability = BaseAbility.new()
	ability.tags = [AbilityTags.PROJECTILE, AbilityTags.DAMAGE]
	ability.base_damage = 10.0
	ability.cooldown = 1.0

	var tome = BaseTome.new()
	tome.tome_id = "test_tome"
	tome.applicable_tags = [AbilityTags.PROJECTILE]
	tome.damage_multiplier = 1.25
	tome.cooldown_multiplier = 0.9

	print("=== BaseTome Application Test ===")
	print("Before: damage=%.2f, cooldown=%.2f" % [ability.base_damage, ability.cooldown])

	tome.apply_to_ability(ability, 1)

	print("After 1 stack: damage=%.2f, cooldown=%.2f" % [ability.base_damage, ability.cooldown])
	# Expected: damage=12.5 (10 * 1.25), cooldown=0.9 (1.0 * 0.9)

	tome.apply_to_ability(ability, 2)

	print("After 2 stacks: damage=%.2f, cooldown=%.2f" % [ability.base_damage, ability.cooldown])
	# Expected: damage=15.625 (10 * 1.25^2), cooldown=0.81 (1.0 * 0.9^2)

	quit(0)
```

---

### Task 1.1.5: Add EventBus Signals (~15 min)

**File:** `autoload/EventBus.gd` (existing file)

**Requirements:**
- [ ] Open `autoload/EventBus.gd`
- [ ] Add ability-related signals:
  ```gdscript
  # === Ability System ===
  signal ability_activated(ability_id: String)
  signal ability_projectile_requested(projectile_data: Dictionary)
  signal ability_acquired(ability_id: String, slot: int)
  signal ability_leveled_up(ability_id: String, new_level: int)

  # === Tome System ===
  signal tome_acquired(tome_id: String, stack_count: int)

  # === Gold Economy (for future chest system) ===
  signal gold_gained(amount: int, source: String)
  signal gold_spent(amount: int, purpose: String)

  # === Chest System (for future) ===
  signal chest_spawned(chest_position: Vector2, is_free: bool)
  signal chest_opened(chest_cost: int, is_free: bool)
  signal item_acquired(item_id: String, rarity: String)
  ```
- [ ] Verify no syntax errors

**Success Criteria:**
- [ ] All signals defined with typed parameters
- [ ] No syntax errors in EventBus
- [ ] Can emit signals from other scripts

**Testing:**
```gdscript
extends Node

func _ready():
	EventBus.ability_activated.connect(_on_ability_activated)
	EventBus.ability_activated.emit("test_ability")

func _on_ability_activated(ability_id: String):
	print("Ability activated: ", ability_id)  # Should print: test_ability
```

---

## 📊 Phase 1.1 Completion Checklist

- [ ] All foundation classes load without errors
- [ ] Tag system accessible globally (`AbilityTags.PROJECTILE` works)
- [ ] BaseAbility level-up math validated (headless test passes)
- [ ] ProjectileAbility can emit activation signal
- [ ] BaseTome tag matching + stat modification works
- [ ] EventBus signals defined
- [ ] All code documented with class comments
- [ ] No errors/warnings in Godot Output panel

---

## 🧪 Final Validation (End of Phase 1.1)

**Create integration test scene:**
`tests/ability_system/Phase1_Foundation_Test.tscn`

Add script:
```gdscript
extends Node

func _ready():
	print("=== Phase 1.1 Foundation Validation ===")

	# Test 1: Tags
	assert(AbilityTags.PROJECTILE == &"projectile", "Tag constant failed")
	print("✓ Tag system OK")

	# Test 2: BaseAbility
	var ability = BaseAbility.new()
	ability.tags = [AbilityTags.DAMAGE]
	ability.base_damage = 10.0
	ability.damage_scaling_per_level = 1.15
	ability.level_up(1)
	assert(abs(ability.base_damage - 11.5) < 0.01, "Level-up scaling failed")
	print("✓ BaseAbility OK")

	# Test 3: ProjectileAbility
	var proj_ability = ProjectileAbility.new()
	assert(proj_ability.has_tag(AbilityTags.PROJECTILE), "ProjectileAbility missing tag")
	print("✓ ProjectileAbility OK")

	# Test 4: BaseTome
	var tome = BaseTome.new()
	tome.applicable_tags = [AbilityTags.PROJECTILE]
	tome.damage_multiplier = 1.25
	tome.apply_to_ability(proj_ability, 1)
	print("✓ BaseTome OK")

	# Test 5: EventBus signals
	EventBus.ability_activated.emit("test")
	print("✓ EventBus signals OK")

	print("\n✓✓✓ ALL PHASE 1.1 TESTS PASSED ✓✓✓")
	get_tree().quit(0)
```

Run: `../Godot_v4.4.1-stable_win64_console.exe --headless tests/ability_system/Phase1_Foundation_Test.tscn --quit-after 1`

---

## 📝 Notes

- If any test fails, fix before moving to Phase 1.2
- Commit after each task with conventional prefix: `feat: add BaseAbility class`
- Update CHANGELOG.md at end of phase
- Document any deviations from architecture in this file

---

## ⏭️ Next Phase

**After Phase 1.1 complete → `2b_ABILITIES_phase2_integration.md`**

---

**Status:** Ready to begin Task 1.1.1 (Tag System)
