# Item Toggler System

**Created:** 2025-10-03
**Status:** 🟡 Planning
**Priority:** Low
**Estimated Effort:** 2-3 sessions
**Category:** 🎮 Meta-Progression
**Parent Task:** [Task 1 - Single-Session Run Refactoring](completed-tasks/1_PROGRESSION_single_session_refactoring_COMPLETED.md) (Phase 9 deferred items)
**Prerequisites:** Requires 40+ unlocks in a category before toggler becomes available

## 📋 Task Description

Implement MEGABONK-style "Toggler" system that allows players to disable specific purchased items from appearing in future runs. This enables buildcrafting by removing unwanted items from the RNG pool.

**Current State:**
- ✅ MetaProgression has `toggler_{category}_enabled` flags
- ✅ MetaProgression has `toggler_disabled_{category}` arrays
- ✅ Shop UI exists and displays unlocked items
- ⚠️ No UI to purchase/enable toggler feature
- ⚠️ No disable buttons in shop when toggler is active
- ⚠️ Item spawn system doesn't respect disabled items list

**Target State:**
- ✅ Toggler appears as purchasable unlock in shop (150 Rift Fragments, requires 40 unlocks)
- ✅ After purchase, shop items show [DISABLE]/[ENABLE] toggle buttons
- ✅ Disabled items are excluded from item spawn pool
- ✅ Disabled items appear grayed out in shop with "DISABLED" badge
- ✅ Categories: Items, Tomes, Skills (separate togglers)

## 🎯 Implementation Plan

### Step 1: Add Toggler Purchase to Shop (1 session)
**Goal:** Allow players to unlock the toggler feature per category

- [ ] Create toggler metadata resources:
  - [ ] `/data/content/meta/item_toggler.tres` (ItemMetadata with `unlock_cost: 150`)
  - [ ] `/data/content/meta/tome_toggler.tres`
  - [ ] `/data/content/meta/skill_toggler.tres`
  - [ ] `display_name: "Item Toggler"`, `description: "Allows disabling items from spawn pool. Requires 40 item unlocks."`
- [ ] Add MetaProgression unlock check:
  - [ ] `can_purchase_toggler(category: String) -> bool` - checks if 40+ unlocks exist
  - [ ] `purchase_toggler(category: String)` - sets `toggler_{category}_enabled = true`
- [ ] Update shop UI to show toggler:
  - [ ] Add "META UPGRADES" tab in shop (or append to existing tabs)
  - [ ] Show toggler with lock icon if < 40 unlocks
  - [ ] Show purchase button if >= 40 unlocks and not purchased
  - [ ] Show "OWNED" status if already purchased

**Test:** Unlock 40 items → see toggler available for purchase → buy toggler → toggler_item_enabled = true

---

### Step 2: Add Disable/Enable Buttons in Shop (1 session)
**Goal:** When toggler is active, show toggle buttons on unlocked items

- [ ] Update shop item card UI:
  - [ ] Check if `MetaProgression.toggler_{category}_enabled`
  - [ ] If enabled, show [DISABLE]/[ENABLE] button below unlock button
  - [ ] Button state depends on `MetaProgression.toggler_disabled_{category}.has(item_id)`
- [ ] Implement toggle logic:
  - [ ] `MetaProgression.toggle_item(category: String, item_id: String, enabled: bool)`
  - [ ] If `enabled = false` → add to `toggler_disabled_{category}`
  - [ ] If `enabled = true` → remove from `toggler_disabled_{category}`
  - [ ] Emit `EventBus.item_toggled` signal
  - [ ] Save MetaProgression after toggle
- [ ] Visual feedback:
  - [ ] Disabled items show grayed out with "DISABLED" badge overlay
  - [ ] Disabled items still appear in shop (just marked as inactive)

**Test:** Enable toggler → click [DISABLE] on cheese item → see it grayed out → check toggler_disabled_items contains "cheese"

---

### Step 3: Filter Spawn Pool by Disabled Items (1 session)
**Goal:** Disabled items never appear in item drops

- [ ] Update item spawn system (from Task 6):
  - [ ] After filtering by `MetaProgression.unlocked_items`
  - [ ] Further filter to exclude `MetaProgression.toggler_disabled_items`
  - [ ] Same for tomes and skills spawn systems
- [ ] Add logging:
  - [ ] `Logger.debug("Item spawn pool filtered: {active_count}/{total_count}", "items")`
  - [ ] Helps debug if spawn pool becomes too small

**Test:**
- Disable "cheese" → start run → cheese never drops
- Re-enable "cheese" → start run → cheese drops again

---

### Step 4: Add Toggler Info Panel (Optional - Polish)
**Goal:** Show summary of disabled items count

- [ ] Add info box to shop header (when toggler enabled):
  - [ ] "Items: 15/42 active (27 disabled)"
  - [ ] Click to open modal showing all disabled items
  - [ ] Bulk enable/disable buttons (future enhancement)
- [ ] Defer to Task 8 (UI Polish) if time-constrained

---

## 🔗 Integration Points

### MetaProgression API (Already Exists):
```gdscript
# Toggler storage (Phase 1)
var toggler_item_enabled: bool = false
var toggler_disabled_items: Array[String] = []
var toggler_skill_enabled: bool = false
var toggler_disabled_skills: Array[String] = []
var toggler_tome_enabled: bool = false
var toggler_disabled_tomes: Array[String] = []
```

### New MetaProgression Methods:
```gdscript
# Add to MetaProgression.gd
func can_purchase_toggler(category: String) -> bool:
    var unlock_count = unlocked_items.size() if category == "items" else \
                       unlocked_skills.size() if category == "skills" else \
                       unlocked_tomes.size()
    return unlock_count >= 40

func purchase_toggler(category: String) -> bool:
    if not can_purchase_toggler(category):
        return false
    if not can_afford(150):
        return false

    spend_rift_fragments(150)

    match category:
        "items": toggler_item_enabled = true
        "skills": toggler_skill_enabled = true
        "tomes": toggler_tome_enabled = true

    save()
    EventBus.toggler_unlocked.emit(category)
    return true

func toggle_item(category: String, item_id: String, enabled: bool) -> void:
    var disabled_list = _get_disabled_list(category)

    if enabled:
        disabled_list.erase(item_id)
    else:
        if not disabled_list.has(item_id):
            disabled_list.append(item_id)

    save()
    EventBus.item_toggled.emit(category, item_id, enabled)

func is_item_toggled_off(category: String, item_id: String) -> bool:
    var disabled_list = _get_disabled_list(category)
    return disabled_list.has(item_id)

func _get_disabled_list(category: String) -> Array[String]:
    match category:
        "items": return toggler_disabled_items
        "skills": return toggler_disabled_skills
        "tomes": return toggler_disabled_tomes
    return []
```

### EventBus Signals (Need to Add):
```gdscript
# New signals for toggler system
signal toggler_unlocked(category: String)
signal item_toggled(category: String, item_id: String, enabled: bool)
```

---

## 📝 Testing Checklist

- [ ] With < 40 unlocks → toggler shows as locked in shop
- [ ] Unlock 40th item → toggler becomes purchasable
- [ ] Purchase toggler → toggler_{category}_enabled = true
- [ ] After purchase → [DISABLE] buttons appear on unlocked items
- [ ] Click [DISABLE] on item → item appears grayed out with "DISABLED" badge
- [ ] Check MetaProgression save file → toggler_disabled_{category} contains item
- [ ] Start new run → disabled item never spawns
- [ ] Re-enable item → item spawns in future runs
- [ ] Save/load persistence → disabled items stay disabled across game restarts

---

## 🚨 Edge Cases & Considerations

### Minimum Active Pool Size
- **Issue:** What if player disables all items?
- **Solution:** Add validation - require at least 5 active items in pool (show error toast)

### Toggler per Category
- **Issue:** Purchasing item toggler doesn't unlock skill toggler
- **Solution:** Each category has separate 40-unlock requirement and 150 RF cost

### Visual Clarity
- **Issue:** Disabled items might be confused with undiscovered items
- **Solution:** Use distinct visual state (grayed + "DISABLED" badge) vs black silhouette for undiscovered

### Save File Growth
- **Issue:** Disabled lists could grow large (100+ entries)
- **Solution:** Acceptable - arrays are efficient, and 100 strings = negligible file size

---

## ✅ Definition of Done

- [ ] Toggler metadata resources created for all 3 categories
- [ ] Toggler appears in shop with 40-unlock requirement
- [ ] Purchase flow works (costs 150 RF, unlocks toggler)
- [ ] [DISABLE]/[ENABLE] buttons appear in shop when toggler active
- [ ] Disabled items show visual feedback (grayed out + badge)
- [ ] Item spawn system excludes disabled items from pool
- [ ] Toggle state persists across game restarts
- [ ] Minimum active pool validation prevents disabling all items
- [ ] All 3 categories (items, tomes, skills) support toggling

---

**Related:** [Task 1 - Phase 9](completed-tasks/1_PROGRESSION_single_session_refactoring_COMPLETED.md) | [Task 6 - Discovery Flow](6_PROGRESSION_in_run_item_discovery_flow.md) | [MetaProgression API](../../autoload/CLAUDE.md#metaprogression)
