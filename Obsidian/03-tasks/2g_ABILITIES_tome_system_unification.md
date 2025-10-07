# [SUBTASK] Ability System - Phase 2g: Tome System Unification

**Parent Task:** `2_ABILITIES_system_implementation.md`
**Phase:** 2g (Foundation Cleanup - Merge Shop + Gameplay Tomes)
**Status:** 📋 Not Started
**Estimated Time:** 60 minutes

---

## 🎯 Phase Goal

Unify the duplicate tome systems into a single source of truth. Currently, tomes exist in two disconnected formats:
- **`ItemMetadata`** (shop UI only) - `damage_tome.tres` with display metadata but no gameplay stats
- **`BaseTome`** (gameplay only) - `tome_damage.tres` with gameplay stats but no shop metadata

**Solution:** Extend `BaseTome` with shop metadata properties and migrate all tomes to use BaseTome exclusively.

---

## 📊 Current State Analysis

### Existing Files
```
data/content/tomes/
├── damage_tome.tres      ← ItemMetadata (shop only, DELETE after migration)
├── tome_damage.tres      ← BaseTome (gameplay only, ADD shop metadata)
├── tome_projectiles.tres ← BaseTome (gameplay only, ADD shop metadata)
├── tome_speed.tres       ← BaseTome (gameplay only, ADD shop metadata)
└── agility_tome.tres     ← ItemMetadata? (verify type)
```

### System Integration Points
**UnlockShop UI:**
- `UnlockShopScene.gd:75` - Filters `if resource is ItemMetadata` (ignores BaseTome!)
- `UnlockShop.gd:145` - Displays tome metadata for shop UI
- Expected properties: `item_id`, `display_name`, `description`, `flavor_text`, `icon`, `unlock_cost`, `rarity`, `stat_summary`

**TomeManager (Gameplay):**
- `TomeManager.gd:67` - Loads BaseTome files from `/data/content/tomes/`
- Expected properties: `tome_id`, `tome_name`, `description`, `icon`, `rarity`, `damage_multiplier`, etc.

**Problem:** Two systems load different file types from same directory → duplicates required!

---

## ✅ Tasks

### Task 2g.1: Extend BaseTome with Shop Metadata (~15 min)

**File:** `scripts/resources/tomes/BaseTome.gd`

**Requirements:**
- [ ] Add new `@export_group("Shop Metadata")` section after "Player Stat Modifiers"
- [ ] Add shop-specific properties:
  ```gdscript
  @export_group("Shop Metadata")

  ## Rift Fragments cost to unlock in shop
  @export var unlock_cost: int = 100

  ## Achievement requirement text for discovery (e.g., "Deal 10,000 total damage")
  @export_multiline var discovery_requirement: String = ""

  ## Stat summary for shop display (e.g., "+15% Damage", "+1 Projectile")
  @export var stat_summary: String = ""

  ## Flavor text for lore/immersion
  @export_multiline var flavor_text: String = ""
  ```

- [ ] Add compatibility property for UnlockShop:
  ```gdscript
  ## Compatibility alias for UnlockShop (returns tome_id)
  var item_id: String:
      get:
          return tome_id

  ## Compatibility alias for UnlockShop (returns tome_name)
  var display_name: String:
      get:
          return tome_name

  ## Compatibility property for UnlockShop (returns "tomes")
  var category: String:
      get:
          return "tomes"
  ```

- [ ] Update `validate()` method to check new properties:
  ```gdscript
  # Shop metadata validation (optional properties - warnings only)
  if unlock_cost <= 0:
      errors.append("unlock_cost should be > 0 for shop items")

  if stat_summary.is_empty():
      errors.append("stat_summary recommended for shop display")
  ```

**Success Criteria:**
- [ ] BaseTome has all properties needed by UnlockShop
- [ ] Compatibility aliases allow duck-typed property access
- [ ] No breaking changes to existing gameplay code
- [ ] All properties visible in Inspector under correct groups

**Testing:**
```gdscript
extends SceneTree

func _initialize():
	var tome = BaseTome.new()
	tome.tome_id = "tome_test"
	tome.tome_name = "Test Tome"
	tome.unlock_cost = 150
	tome.stat_summary = "+10% Damage"
	tome.flavor_text = "Test flavor"

	# Test compatibility aliases
	assert(tome.item_id == "tome_test", "item_id alias failed")
	assert(tome.display_name == "Test Tome", "display_name alias failed")
	assert(tome.category == "tomes", "category alias failed")

	print("✓ BaseTome shop metadata OK")
	quit(0)
```

---

### Task 2g.2: Update UnlockShop to Accept BaseTome (~10 min)

**File:** `scenes/ui/UnlockShopScene.gd`

**Requirements:**
- [ ] Update `_load_item_metadata()` type filter (line 75):
  ```gdscript
  # OLD: if resource is ItemMetadata:
  # NEW: Accept both ItemMetadata and BaseTome
  if resource is ItemMetadata or resource is BaseTome:
      # Duck typing: use item_id or tome_id
      var item_id_key: String
      if resource is BaseTome:
          item_id_key = resource.tome_id  # BaseTome uses tome_id
      else:
          item_id_key = resource.item_id  # ItemMetadata uses item_id

      item_metadata_cache[item_id_key] = resource
      Logger.debug("UnlockShopScene: Loaded item metadata: %s" % item_id_key, "ui")
  ```

- [ ] Update `_fetch_tomes_data()` to handle both types (line 107):
  ```gdscript
  func _fetch_tomes_data() -> Array[ItemMetadata]:
      var category_items: Array = []  # Untyped array to hold both types

      for item_id in item_metadata_cache.keys():
          var metadata = item_metadata_cache[item_id]

          # Check if it's a tome (BaseTome type OR ItemMetadata with category="tomes")
          var is_tome = (metadata is BaseTome) or (metadata.category == "tomes")

          if is_tome:
              category_items.append(metadata)

      # Sort by rarity (duck typing: both have .rarity)
      category_items.sort_custom(func(a, b) -> bool:
          return _get_rarity_value(a) < _get_rarity_value(b)
      )

      return category_items

  func _get_rarity_value(item) -> int:
      """Get numeric rarity value for sorting (handles both enum and string)."""
      if item.rarity is int:
          return item.rarity  # ItemMetadata.Rarity enum
      else:
          # BaseTome uses string: "common", "uncommon", "rare", etc.
          match item.rarity:
              "common": return 0
              "uncommon": return 1
              "rare": return 2
              "epic": return 3
              "legendary": return 4
              _: return 0
  ```

**Success Criteria:**
- [ ] UnlockShop loads both ItemMetadata and BaseTome files
- [ ] Tome tab displays unified tome list
- [ ] No duplicate tomes appear in shop
- [ ] Sorting works correctly for both types

---

### Task 2g.3: Update UnlockShop Display Logic (~10 min)

**File:** `scenes/ui/components/UnlockShop.gd`

**Requirements:**
- [ ] Update `_on_item_selected()` to use duck typing for property access:
  ```gdscript
  func _on_item_selected(item_card: ItemGridCell) -> void:
      # ... existing code ...

      var item = item_card.item_data
      _selected_item = item

      # Duck typing: access properties that exist on both ItemMetadata and BaseTome
      var display_name: String
      var desc: String
      var flavor: String
      var cost: int
      var stats: String
      var icon_texture: Texture2D

      if item is BaseTome:
          display_name = item.tome_name
          desc = item.description
          flavor = item.flavor_text if "flavor_text" in item else ""
          cost = item.unlock_cost if "unlock_cost" in item else 100
          stats = item.stat_summary if "stat_summary" in item else ""
          icon_texture = item.icon
      else:  # ItemMetadata
          display_name = item.display_name
          desc = item.description
          flavor = item.flavor_text
          cost = item.unlock_cost
          stats = item.stat_summary
          icon_texture = load(item.icon_path) if item.icon_path else null

      # Update UI labels
      item_name_label.text = display_name
      item_description_label.text = desc
      item_flavor_label.text = flavor
      item_stats_label.text = stats
      unlock_button.text = "Unlock (%d Fragments)" % cost

      # ... rest of function ...
  ```

- [ ] Update `_populate_grid()` for icon handling:
  ```gdscript
  func _create_item_card(item_data: Variant) -> ItemGridCell:
      # ... existing code ...

      # Duck-typed icon access
      var icon_texture: Texture2D
      if item_data is BaseTome:
          icon_texture = item_data.icon  # Direct Texture2D reference
      else:  # ItemMetadata
          icon_texture = load(item_data.icon_path) if item_data.icon_path else null

      card.setup(item_data, icon_texture, unlock_state)

      # ... rest of function ...
  ```

**Success Criteria:**
- [ ] Shop displays BaseTome items with correct name, description, flavor text
- [ ] Icons display correctly for both ItemMetadata and BaseTome
- [ ] Unlock button shows correct Rift Fragment cost
- [ ] Stat summary displays correctly ("+15% Damage", "+1 Projectile")

---

### Task 2g.4: Migrate Tome Files (~20 min)

**File Modifications:**

#### Step 1: Update tome_damage.tres (add shop metadata)

**File:** `data/content/tomes/tome_damage.tres`

**Requirements:**
- [ ] Add icon ExtResource:
  ```tres
  [ext_resource type="Texture2D" uid="uid://u1phiu54p6t0" path="res://assets/ui/tomes/icons/mb (1).png" id="1_fcnhg"]
  ```

- [ ] Add shop metadata properties to [resource] section:
  ```tres
  [resource]
  script = ExtResource("1")
  tome_id = "tome_damage"
  tome_name = "Tome of Power"
  description = "A tome of destructive power that increases your damage output"
  flavor_text = "Knowledge is power, and power is destruction."
  icon = ExtResource("1_fcnhg")
  rarity = "common"
  unlock_cost = 100
  discovery_requirement = "Deal 10,000 total damage"
  stat_summary = "+15% Damage per stack"
  stack_limit = 10
  applicable_tags = Array[String]([])
  damage_multiplier = 1.15
  # ... rest of existing properties ...
  ```

#### Step 2: Update tome_projectiles.tres (add shop metadata)

**File:** `data/content/tomes/tome_projectiles.tres`

**Requirements:**
- [ ] Icon already exists (mb (2).png) - verify ExtResource ID
- [ ] Add shop metadata:
  ```tres
  tome_id = "tome_projectiles"
  tome_name = "Tome of Multiplication"
  description = "Add +1 projectile per stack. Stacks additively."
  flavor_text = "One becomes many. Many become unstoppable."
  icon = ExtResource("1_sobp6")  # Already exists
  rarity = "common"
  unlock_cost = 150
  discovery_requirement = "Fire 1,000 projectiles"
  stat_summary = "+1 Projectile per stack"
  # ... existing properties ...
  ```

#### Step 3: Update tome_speed.tres (add shop metadata)

**File:** `data/content/tomes/tome_speed.tres`

**Requirements:**
- [ ] Read file to check current state
- [ ] Add icon ExtResource (choose from mb (3).png or similar)
- [ ] Add shop metadata:
  ```tres
  unlock_cost = 120
  discovery_requirement = "Move 100,000 units"
  stat_summary = "+10% Projectile Speed per stack"
  flavor_text = "Swift as the wind, deadly as the storm."
  ```

#### Step 4: Update agility_tome.tres (check type and migrate if needed)

**File:** `data/content/tomes/agility_tome.tres`

**Requirements:**
- [ ] Read file to determine type (ItemMetadata or BaseTome)
- [ ] If ItemMetadata: Convert to BaseTome format
- [ ] If BaseTome: Add missing shop metadata
- [ ] Rename to follow convention: `tome_agility.tres`

#### Step 5: Delete duplicate damage_tome.tres

**File:** `data/content/tomes/damage_tome.tres`

**Requirements:**
- [ ] Verify tome_damage.tres has all metadata from damage_tome.tres
- [ ] Delete damage_tome.tres (ItemMetadata duplicate)

**Success Criteria:**
- [ ] All tome files use BaseTome format
- [ ] All tomes have shop metadata (unlock_cost, stat_summary, flavor_text, icon)
- [ ] All tomes follow naming convention: `tome_<name>.tres`
- [ ] No ItemMetadata tome files remain (except for actual items category)
- [ ] Icons linked correctly via ExtResource

**File Summary After Migration:**
```
data/content/tomes/
├── tome_damage.tres       ← Unified (shop + gameplay)
├── tome_projectiles.tres  ← Unified (shop + gameplay)
├── tome_speed.tres        ← Unified (shop + gameplay)
└── tome_agility.tres      ← Unified (renamed from agility_tome.tres)
```

---

### Task 2g.5: Verification & Testing (~5 min)

**Manual Testing:**

1. **UnlockShop UI Test:**
   - [ ] Open UnlockShopScene (via MainMenu → Unlocks)
   - [ ] Navigate to "Tomes" tab
   - [ ] Verify all 4 tomes display with icons
   - [ ] Click each tome, verify details panel shows:
     - Correct name
     - Full description
     - Flavor text
     - Stat summary ("+15% Damage", etc.)
     - Unlock cost (100-150 Rift Fragments)
   - [ ] Verify no duplicate tomes appear

2. **TomeManager Test:**
   - [ ] Add debug logging to TomeManager._load_tome_from_file():
     ```gdscript
     Logger.info("TomeManager loaded: %s (%s) - %s" % [tome_id, category, tome.tome_name], "tomes")
     ```
   - [ ] Run game, check logs for successful tome loading
   - [ ] Verify all 4 tomes loaded by TomeManager
   - [ ] Check no error messages about missing properties

3. **Gameplay Integration Test:**
   - [ ] Start arena run
   - [ ] Level up and select tome upgrade (if available in level-up flow)
   - [ ] Verify tome modifiers apply correctly (damage increase, projectile count)
   - [ ] Check no errors in console related to tome application

**Automated Test (Optional):**

Create `tests/test_tome_unification.gd`:
```gdscript
extends SceneTree

func _initialize():
	print("=== Tome System Unification Test ===")

	# Test 1: BaseTome has shop metadata
	var tome = BaseTome.new()
	tome.tome_id = "test"
	tome.tome_name = "Test"
	tome.unlock_cost = 100
	tome.stat_summary = "Test"
	tome.flavor_text = "Test"

	assert(tome.item_id == "test", "item_id alias failed")
	assert(tome.display_name == "Test", "display_name alias failed")
	assert(tome.category == "tomes", "category failed")
	print("✓ BaseTome compatibility aliases OK")

	# Test 2: Load actual tome files
	var tome_damage = load("res://data/content/tomes/tome_damage.tres") as BaseTome
	assert(tome_damage != null, "tome_damage.tres not found")
	assert(tome_damage.unlock_cost > 0, "tome_damage missing unlock_cost")
	assert(not tome_damage.stat_summary.is_empty(), "tome_damage missing stat_summary")
	assert(tome_damage.damage_multiplier > 1.0, "tome_damage missing gameplay stat")
	print("✓ tome_damage.tres unified OK")

	var tome_projectiles = load("res://data/content/tomes/tome_projectiles.tres") as BaseTome
	assert(tome_projectiles != null, "tome_projectiles.tres not found")
	assert(tome_projectiles.unlock_cost > 0, "tome_projectiles missing unlock_cost")
	assert(tome_projectiles.projectile_count_bonus > 0, "tome_projectiles missing gameplay stat")
	print("✓ tome_projectiles.tres unified OK")

	# Test 3: Verify old duplicate deleted
	var duplicate_exists = ResourceLoader.exists("res://data/content/tomes/damage_tome.tres")
	assert(not duplicate_exists, "damage_tome.tres duplicate still exists!")
	print("✓ Duplicate damage_tome.tres removed")

	print("\n✓✓✓ ALL TOME UNIFICATION TESTS PASSED ✓✓✓")
	quit(0)
```

Run: `../Godot_v4.4.1-stable_win64_console.exe --headless --script tests/test_tome_unification.gd`

---

## 📊 Phase 2g Completion Checklist

- [ ] BaseTome.gd extended with shop metadata properties
- [ ] BaseTome has compatibility aliases (item_id, display_name, category)
- [ ] UnlockShopScene.gd accepts both ItemMetadata and BaseTome
- [ ] UnlockShop.gd uses duck typing for property access
- [ ] tome_damage.tres has shop metadata (icon, unlock_cost, flavor_text, stat_summary)
- [ ] tome_projectiles.tres has shop metadata
- [ ] tome_speed.tres has shop metadata
- [ ] agility_tome.tres migrated and renamed to tome_agility.tres
- [ ] damage_tome.tres duplicate deleted
- [ ] All tomes follow `tome_<name>.tres` naming convention
- [ ] UnlockShop displays all tomes correctly
- [ ] TomeManager loads all tomes without errors
- [ ] No duplicate tomes in shop UI
- [ ] Gameplay tome modifiers still apply correctly
- [ ] All tests pass (manual + optional automated)

---

## 🔗 Integration Points

**Files Modified:**
- `scripts/resources/tomes/BaseTome.gd` - Add shop metadata properties + compatibility aliases
- `scenes/ui/UnlockShopScene.gd` - Accept BaseTome in type filter
- `scenes/ui/components/UnlockShop.gd` - Duck typing for display logic
- `data/content/tomes/tome_damage.tres` - Add shop metadata
- `data/content/tomes/tome_projectiles.tres` - Add shop metadata
- `data/content/tomes/tome_speed.tres` - Add shop metadata
- `data/content/tomes/agility_tome.tres` - Rename to tome_agility.tres, verify format

**Files Deleted:**
- `data/content/tomes/damage_tome.tres` - Duplicate removed

**Backward Compatibility:**
- ✅ Existing TomeManager code unchanged (BaseTome compatibility)
- ✅ Existing tome gameplay logic unchanged
- ✅ UnlockShop now handles both types (gradual migration)

---

## 📝 Notes

**Why This Matters:**
- **Single Source of Truth:** Each tome defined once, not twice
- **Consistency:** Same file used by shop UI and gameplay systems
- **Maintainability:** Adding new tomes requires only one .tres file
- **Type Safety:** Eventually migrate all to BaseTome, remove ItemMetadata for tomes
- **Future-Proof:** Scales to 50+ tomes without duplicate management overhead

**Design Decisions:**
- **Duck Typing Approach:** Allows gradual migration without breaking existing ItemMetadata items
- **Compatibility Aliases:** `item_id`, `display_name`, `category` properties make BaseTome drop-in compatible with UnlockShop
- **Optional Shop Metadata:** Tomes can exist without shop metadata (for testing/future dynamic tomes)
- **Naming Convention:** `tome_<name>.tres` matches ability naming (`ability_<name>.tres` pattern from Phase 2a)

**Future Enhancements:**
- Create TomeMetadata wrapper if ItemMetadata and BaseTome diverge further
- Add `@tool` script to BaseTome for Inspector preview of stat_summary
- Auto-generate stat_summary from damage_multiplier/projectile_count_bonus

---

## ⏭️ Next Phase

**After Phase 2g complete → Continue with Phase 5: Clean Melee Migration**

Remaining ability system tasks:
- ✅ Phase 2f: Tag System Enhancement (previous)
- ✅ Phase 2g: Tome System Unification (current)
- ❌ Phase 5: Clean Melee Migration (~2 hours)
- ❌ Phase 6: Expand Ability Library (~4-6 hours)
- ❌ Phase 7: Level-Up Integration (~2-3 hours)
- ❌ Phase 8: Meta-Progression Integration (~3-4 hours)

---

**Status:** Ready to begin Task 2g.1 (Extend BaseTome with Shop Metadata)
