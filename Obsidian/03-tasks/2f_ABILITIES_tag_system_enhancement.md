# [SUBTASK] Ability System - Phase 2f: Tag System Enhancement

**Parent Task:** `2_ABILITIES_system_implementation.md`
**Phase:** 2f (Foundation Cleanup - Future-Proofing)
**Status:** 📋 Not Started
**Estimated Time:** 45 minutes

---

## 🎯 Phase Goal

Enhance the existing AbilityTags.gd system from basic 19-tag implementation to a comprehensive, future-proof tag architecture that scales to handle complex item/tome/buff interactions across hundreds of abilities.

**Why This Matters:** As the game scales to "alot oof different items and tomes and buffs," the tag system becomes the foundation for determining which modifiers affect which abilities. A robust tag system now prevents technical debt later.

---

## ✅ Tasks

### Task 2f.1: Add Missing Tag Constants (~15 min)

**File:** `scripts/domain/AbilityTags.gd` (existing file)

**Current State:** 19 tags across 3 categories
**Target State:** 34+ tags across 6 categories

**Requirements:**
- [ ] Add **Behavior Tags** (7 new):
  ```gdscript
  const HOMING: StringName = &"homing"
  const PIERCE: StringName = &"pierce"
  const CHAIN: StringName = &"chain"
  const KNOCKBACK: StringName = &"knockback"
  const CRIT: StringName = &"crit"
  const DOT: StringName = &"dot"  # Damage over time
  const LEECH: StringName = &"leech"
  ```

- [ ] Add **Resource Tags** (3 new):
  ```gdscript
  const MANA: StringName = &"mana"
  const LIFE: StringName = &"life"
  const ENERGY: StringName = &"energy"
  ```

- [ ] Add **Element Tags** (1 new):
  ```gdscript
  const CHAOS: StringName = &"chaos"
  ```

- [ ] Add **Delivery Tags** (3 new):
  ```gdscript
  const SUMMON: StringName = &"summon"
  const TRAP: StringName = &"trap"
  const TOTEM: StringName = &"totem"
  ```

- [ ] Add **Scaling Tags** (1 new):
  ```gdscript
  const MAGNITUDE: StringName = &"magnitude"  # Generic damage scaling
  ```

**Success Criteria:**
- [ ] All new tags use StringName syntax (`&"tag"`)
- [ ] Tags organized by category with clear comment blocks
- [ ] No syntax errors when loading in Godot
- [ ] `get_all_tags()` returns 34+ tags

**Testing:**
```gdscript
extends Node

func _ready():
	print("Total tags: ", AbilityTags.get_all_tags().size())  # Should be 34+
	print("HOMING tag: ", AbilityTags.HOMING)  # Should print: homing
	print("CHAOS valid: ", AbilityTags.is_valid_tag(&"chaos"))  # Should print: true
```

---

### Task 2f.2: Implement Category Enum System (~10 min)

**File:** `scripts/domain/AbilityTags.gd`

**Requirements:**
- [ ] Create `TagCategory` enum:
  ```gdscript
  enum TagCategory {
  	DAMAGE_TYPE,   # DAMAGE, PHYSICAL
  	ELEMENT,       # FIRE, COLD, LIGHTNING, POISON, CHAOS, ELEMENTAL
  	DELIVERY,      # PROJECTILE, AOE, MELEE, BUFF, DEBUFF, ORBIT, SUMMON, TRAP, TOTEM
  	SCALING,       # COOLDOWN, DURATION, AREA, SPEED, RANGE, COUNT, MAGNITUDE
  	BEHAVIOR,      # HOMING, PIERCE, CHAIN, KNOCKBACK, CRIT, DOT, LEECH
  	RESOURCE       # MANA, LIFE, ENERGY
  }
  ```

- [ ] Create `TAG_CATEGORIES` dictionary mapping each tag to its category:
  ```gdscript
  const TAG_CATEGORIES: Dictionary = {
  	DAMAGE: TagCategory.DAMAGE_TYPE,
  	PHYSICAL: TagCategory.DAMAGE_TYPE,
  	FIRE: TagCategory.ELEMENT,
  	COLD: TagCategory.ELEMENT,
  	# ... (all 34+ tags mapped)
  }
  ```

**Success Criteria:**
- [ ] Every tag has a category mapping
- [ ] Categories are logically organized
- [ ] Can query tag category via `TAG_CATEGORIES[AbilityTags.FIRE]`

---

### Task 2f.3: Add Tag Metadata Dictionaries (~10 min)

**File:** `scripts/domain/AbilityTags.gd`

**Requirements:**
- [ ] Create `TAG_DESCRIPTIONS` for tooltip-ready descriptions:
  ```gdscript
  const TAG_DESCRIPTIONS: Dictionary = {
  	FIRE: "Deals fire damage and can inflict burning",
  	COLD: "Deals cold damage and can chill or freeze",
  	HOMING: "Projectiles track nearby enemies",
  	PIERCE: "Projectiles pass through enemies",
  	# ... (all tags with user-friendly descriptions)
  }
  ```

- [ ] Create `TAG_COLORS` for UI color coding:
  ```gdscript
  const TAG_COLORS: Dictionary = {
  	FIRE: Color(1.0, 0.3, 0.1),       # Red-orange
  	COLD: Color(0.2, 0.6, 1.0),       # Ice blue
  	LIGHTNING: Color(0.8, 0.8, 1.0),  # Electric blue
  	POISON: Color(0.3, 0.8, 0.2),     # Toxic green
  	CHAOS: Color(0.6, 0.2, 0.8),      # Purple
  	PHYSICAL: Color(0.7, 0.7, 0.7),   # Gray
  	# ... (all tags with distinct colors)
  }
  ```

**Success Criteria:**
- [ ] All tags have descriptions for tooltips
- [ ] All element/damage tags have distinct colors
- [ ] Colors are visually distinct (accessibility-friendly)

---

### Task 2f.4: Implement Advanced Helper Functions (~10 min)

**File:** `scripts/domain/AbilityTags.gd`

**Requirements:**
- [ ] Add `format_tags_for_display(tags: Array[StringName]) -> String`:
  ```gdscript
  ## Returns UI-ready tag list with colors
  ## Example: "[color=#ff4d1a]Fire[/color], [color=#3399ff]Cold[/color]"
  static func format_tags_for_display(tags: Array[StringName]) -> String:
  	var formatted: Array[String] = []
  	for tag in tags:
  		if TAG_COLORS.has(tag):
  			var color = TAG_COLORS[tag]
  			formatted.append("[color=#%s]%s[/color]" % [color.to_html(false), tag.capitalize()])
  		else:
  			formatted.append(tag.capitalize())
  	return ", ".join(formatted)
  ```

- [ ] Add `has_all_tags(ability_tags: Array[StringName], required_tags: Array[StringName]) -> bool`:
  ```gdscript
  ## Returns true if ability has ALL required tags (AND logic)
  ## Used for strict tome applicability (e.g., requires BOTH fire AND projectile)
  static func has_all_tags(ability_tags: Array[StringName], required_tags: Array[StringName]) -> bool:
  	for tag in required_tags:
  		if not ability_tags.has(tag):
  			return false
  	return true
  ```

- [ ] Add `has_any_tag(ability_tags: Array[StringName], target_tags: Array[StringName]) -> bool`:
  ```gdscript
  ## Returns true if ability has ANY of the target tags (OR logic)
  ## Used for flexible tome applicability (current TomeModifier behavior)
  static func has_any_tag(ability_tags: Array[StringName], target_tags: Array[StringName]) -> bool:
  	for tag in target_tags:
  		if ability_tags.has(tag):
  			return true
  	return false
  ```

- [ ] Add `get_common_tags(tags1: Array[StringName], tags2: Array[StringName]) -> Array[StringName]`:
  ```gdscript
  ## Returns tags present in BOTH arrays
  ## Used for comparing abilities or finding tag overlap
  static func get_common_tags(tags1: Array[StringName], tags2: Array[StringName]) -> Array[StringName]:
  	var common: Array[StringName] = []
  	for tag in tags1:
  		if tags2.has(tag):
  			common.append(tag)
  	return common
  ```

- [ ] Add `validate_tags(tags: Array[StringName]) -> Array[String]`:
  ```gdscript
  ## Returns array of error strings for invalid tags (empty = valid)
  ## Used for .tres file validation
  static func validate_tags(tags: Array[StringName]) -> Array[String]:
  	var errors: Array[String] = []
  	for tag in tags:
  		if not is_valid_tag(tag):
  			errors.append("Invalid tag: %s" % tag)
  	return errors
  ```

- [ ] Add `get_tags_by_category(category: TagCategory) -> Array[StringName]`:
  ```gdscript
  ## Returns all tags in a specific category
  ## Used for organized UI displays (e.g., "Show all element tags")
  static func get_tags_by_category(category: TagCategory) -> Array[StringName]:
  	var tags: Array[StringName] = []
  	for tag in TAG_CATEGORIES:
  		if TAG_CATEGORIES[tag] == category:
  			tags.append(tag)
  	return tags
  ```

**Success Criteria:**
- [ ] All helpers have comprehensive documentation
- [ ] `format_tags_for_display()` produces valid BBCode for RichTextLabel
- [ ] `has_all_tags()` vs `has_any_tag()` logic is clear and tested
- [ ] `validate_tags()` catches invalid tags from .tres files
- [ ] `get_tags_by_category()` returns correct tag subsets

**Testing:**
```gdscript
extends SceneTree

func _initialize():
	print("=== Tag System Enhancement Tests ===")

	# Test 1: Tag categories
	var fire_category = AbilityTags.TAG_CATEGORIES[AbilityTags.FIRE]
	assert(fire_category == AbilityTags.TagCategory.ELEMENT, "Fire should be ELEMENT category")
	print("✓ Category system OK")

	# Test 2: has_all_tags (AND logic)
	var ability_tags = [AbilityTags.FIRE, AbilityTags.PROJECTILE, AbilityTags.DAMAGE]
	var required_tags = [AbilityTags.FIRE, AbilityTags.PROJECTILE]
	assert(AbilityTags.has_all_tags(ability_tags, required_tags), "Should have all required tags")
	print("✓ has_all_tags OK")

	# Test 3: has_any_tag (OR logic)
	var tome_tags = [AbilityTags.FIRE, AbilityTags.COLD]
	assert(AbilityTags.has_any_tag(ability_tags, tome_tags), "Should match FIRE tag")
	print("✓ has_any_tag OK")

	# Test 4: Validation
	var invalid_tags = [AbilityTags.FIRE, &"invalid_tag", AbilityTags.COLD]
	var errors = AbilityTags.validate_tags(invalid_tags)
	assert(errors.size() == 1, "Should detect 1 invalid tag")
	print("✓ validate_tags OK")

	# Test 5: get_tags_by_category
	var element_tags = AbilityTags.get_tags_by_category(AbilityTags.TagCategory.ELEMENT)
	assert(element_tags.has(AbilityTags.FIRE), "Should include FIRE")
	assert(element_tags.has(AbilityTags.COLD), "Should include COLD")
	assert(not element_tags.has(AbilityTags.PROJECTILE), "Should NOT include PROJECTILE")
	print("✓ get_tags_by_category OK")

	# Test 6: Format for display
	var display_text = AbilityTags.format_tags_for_display([AbilityTags.FIRE, AbilityTags.PROJECTILE])
	assert(display_text.contains("[color="), "Should have BBCode color tags")
	print("Display text: ", display_text)
	print("✓ format_tags_for_display OK")

	print("\n✓✓✓ ALL TAG SYSTEM TESTS PASSED ✓✓✓")
	quit(0)
```

Run: `../Godot_v4.4.1-stable_win64_console.exe --headless --script tests/test_tag_system_enhancement.gd`

---

## 📊 Phase 2f Completion Checklist

- [ ] All new tag constants added (34+ total tags)
- [ ] TagCategory enum created with 6 categories
- [ ] TAG_CATEGORIES dictionary maps all tags
- [ ] TAG_DESCRIPTIONS provides tooltip text for all tags
- [ ] TAG_COLORS provides UI colors for all tags
- [ ] 6 advanced helper functions implemented and documented
- [ ] Headless test passes all 6 validation checks
- [ ] No errors/warnings in Godot Output panel
- [ ] Existing abilities (heartseeker.tres) still work with new system
- [ ] TomeModifier.applicable_tags still works with new helpers

---

## 🔗 Integration Points

**Files That Use This System:**
- `scripts/resources/abilities/BaseAbility.gd` - `tags: Array[StringName]` property
- `scripts/resources/tomes/BaseTome.gd` - `applicable_tags: Array[StringName]` property
- `data/content/abilities/projectile/heartseeker.tres` - Contains tag arrays
- `autoload/AbilityManager.gd` - Registry filtering by tags
- `autoload/TomeManager.gd` - Tome applicability checks

**Backward Compatibility:**
- All existing tag constants remain unchanged (FIRE, PROJECTILE, etc.)
- New helpers are purely additive - old code continues to work
- Existing .tres files with tags validate correctly

---

## 🧪 Final Validation

**Create integration test:**
`tests/test_tag_system_integration.tscn`

```gdscript
extends Node

func _ready():
	print("=== Tag System Integration Test ===")

	# Load real ability .tres file
	var heartseeker = load("res://data/content/abilities/projectile/heartseeker.tres")
	assert(heartseeker != null, "Failed to load heartseeker ability")

	# Verify tags still work
	var tags = heartseeker.tags
	print("Heartseeker tags: ", tags)
	assert(AbilityTags.validate_tags(tags).is_empty(), "Heartseeker has invalid tags")

	# Test tome applicability (existing system)
	var tome_tags = [AbilityTags.PROJECTILE]
	assert(AbilityTags.has_any_tag(tags, tome_tags), "Projectile tome should apply")

	# Test category filtering (new system)
	var element_tags = AbilityTags.get_tags_by_category(AbilityTags.TagCategory.ELEMENT)
	print("Element tags available: ", element_tags)

	# Test UI formatting (new system)
	var display = AbilityTags.format_tags_for_display(tags)
	print("UI display: ", display)

	print("\n✓✓✓ INTEGRATION TEST PASSED ✓✓✓")
	get_tree().quit(0)
```

Run: `../Godot_v4.4.1-stable_win64_console.exe --headless tests/test_tag_system_integration.tscn --quit-after 1`

---

## 📝 Notes

**Why This Enhancement Matters:**
- **Scalability:** System now handles 100+ abilities with complex tag combinations
- **UI/UX:** Tag colors and descriptions ready for tooltips and ability comparisons
- **Tome System:** `has_all_tags()` vs `has_any_tag()` allows complex tome applicability rules
- **Validation:** Catches tag typos in .tres files during development
- **Future-Proof:** Category system enables "all fire abilities" or "all projectile abilities" filtering

**Design Decisions:**
- **StringName Performance:** Using `&"tag"` syntax for O(1) pointer comparison
- **OR Logic Default:** `has_any_tag()` matches current TomeModifier behavior
- **Additive Only:** No breaking changes to existing abilities/tomes
- **Category-Based:** Groups tags logically for UI organization

---

## ⏭️ Next Phase

**After Phase 2f complete → Continue with Phase 5: Clean Melee Migration**

Remaining tasks:
- Phase 5: Clean Melee Migration (~2 hours)
- Phase 6: Expand Ability Library (~4-6 hours)
- Phase 7: Level-Up Integration (~2-3 hours)
- Phase 8: Meta-Progression Integration (~3-4 hours)
- Phase 9: Visual Polish (Optional)

---

**Status:** Ready to begin Task 2f.1 (Add Missing Tag Constants)
