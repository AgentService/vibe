# 3b: Quest UI Achievement Archive

**Created:** 2025-10-03
**Updated:** 2025-10-03 (Renamed from `9_PROGRESSION_quest_ui_achievement_archive.md`)
**Status:** 🟡 Planning
**Priority:** Medium
**Estimated Effort:** 3-4 sessions
**Category:** 🎮 Quest System - UI
**Dependencies:** [Task 3a - Quest Backend](3a_QUEST_backend_and_notifications.md) (Phases 1-4 must be complete) ← **DO THIS FIRST**
**Backend Companion Task:** [Task 3a - Quest Backend](3a_QUEST_backend_and_notifications.md) ← **MUST STAY IN SYNC**

> ⚠️ **Cross-Reference:** This task handles the main menu quest log **UI only**. For the quest backend (QuestManager, tracking, rewards), see **Task 3a**. These tasks must stay synchronized - backend API changes in Task 3a require UI updates here.

## 📋 Task Description

Implement a MEGABONK-style quest log / achievement archive accessible from the main menu. Players can browse all quests, view progress, see unlock rewards, and filter by category or completion status.

**Reference:** MEGABONK Quest UI (see screenshot)
- Category tabs with progress counters (Characters 7/18, Weapons 8/22, etc.)
- Quest list with progress bars and completion checkmarks
- **Reward preview columns** showing what items/unlocks you'll earn
- Locked quests with prerequisite indicators
- Sort/filter controls (Completed checkbox)

**Current State:**
- ✅ QuestManager backend exists (Task 3 Phases 1-4)
- ✅ Quest progress tracking working
- ✅ Quest completion awards rewards
- ⚠️ No main menu quest UI exists
- ⚠️ No way to browse available quests
- ⚠️ No reward preview before completion

**Target State:**
- ✅ Main menu "QUESTS" button opens quest log
- ✅ Category tabs (Characters, Weapons, Tomes, Items, General, Challenges)
- ✅ Quest list shows all quests with progress bars
- ✅ Reward preview shows what you'll unlock
- ✅ Filter by completed/incomplete
- ✅ Locked quests show prerequisites

## 🎯 Implementation Plan

### Step 1: Create Quest Log Scene Structure (1 session)
**Goal:** Build main quest log container matching MEGABONK layout

**Layout Design (Based on MEGABONK):**
```
┌─────────────────────────────────────────────────────────┐
│ QUESTS                                      47/234  [X] │ ← Title + total progress
├─────────────────────────────────────────────────────────┤
│ ☑ Sort: Completed                                       │ ← Filter controls
├─────────────────────────────────────────────────────────┤
│ [Characters] [Weapons] [Tomes] [Items] [General] [...] │ ← Category tabs
│   7/18        8/22      5/10    15/42    6/31           │   with progress counters
├─────────────────────────────────────────────────────────┤
│ ┌─────────────────────────────────────────────────────┐ │
│ │ 💀 Kill 1000 skeletons          1000/1000  ✓   🎁🎁 │ │ ← Quest entries
│ │ 👤 Get Damage Tome to level 7     1/1     ✓   🎁   │ │
│ │ 👹 Kill 15000 Goblins         15000/15000 ✓   🎁🎁 │ │
│ │ 🗺️ Complete Forest Tier 1        1/1     ✓   🎁   │ │
│ │ 📖 Get Thorns Tome to level 9     1/1     ✓   🎁   │ │
│ │ 🐵 Find and release Monke         1/1     ✓   🎁   │ │
│ │ 🗺️ Complete Forest Tier 2        0/1        ⚙️2  │ │ ← Locked (needs 2 prereqs)
│ │ 🏆 Complete 2 Challenges          2/2     ✓   🎁   │ │
│ │ ...                                                 │ │
│ └─────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────┘
```

**Implementation:**
- [ ] Create scene: `scenes/ui/QuestLog.tscn`
  - [ ] Use `TabbedGridContainer` template (from Phase 9 UI templates)
  - [ ] Title: "QUESTS" with total progress counter (e.g., "47/234")
  - [ ] Filter section: CheckBox "Sort: Completed"
  - [ ] Category tabs: Characters, Weapons, Tomes, Items, General, Challenges, Skins
  - [ ] ScrollContainer for quest list (VBoxContainer)
  - [ ] Close button (X) top-right
- [ ] Attach script: `QuestLog.gd`
  - [ ] `_ready()` - Load all quests from QuestManager
  - [ ] `populate_category(category: String)` - Filter quests by category
  - [ ] `update_progress_counters()` - Update tab labels (e.g., "7/18")
  - [ ] `_on_filter_changed()` - Apply completed/incomplete filter

**Test:** Open quest log → see category tabs with progress counters

---

### Step 2: Create Quest Entry Row Component (1 session)
**Goal:** Reusable quest row showing icon, name, progress, rewards

**Quest Row Design:**
```
┌──────────────────────────────────────────────────┐
│ [Icon] Quest Name              Progress    [✓/⚙️] [🎁][🎁] │
│  💀   Kill 1000 skeletons   [████████] 1000/1000 ✓  🎁 🎁 │
│                                                       ↑   ↑  │
│                                                   Reward Preview
└──────────────────────────────────────────────────┘
```

**Implementation:**
- [ ] Create scene: `scenes/ui/components/QuestEntry.tscn`
  - [ ] HBoxContainer layout:
    - [ ] TextureRect for quest icon (32x32)
    - [ ] Label for quest name (e.g., "Kill 1000 skeletons")
    - [ ] ProgressBar for visual progress
    - [ ] Label for progress text (e.g., "1000/1000")
    - [ ] TextureRect for completion checkmark (✓) or lock icon (🔒)
    - [ ] Reward preview section (HBoxContainer):
      - [ ] Multiple TextureRect nodes for reward icons (🎁)
      - [ ] Show item/character/weapon icons if available
- [ ] Attach script: `QuestEntry.gd`
  - [ ] `setup(quest: QuestConfig, progress: Dictionary)` - Populate from data
  - [ ] `update_progress(current: int, target: int)` - Update progress bar
  - [ ] `show_rewards(rewards: Array[String])` - Display reward icons
  - [ ] `set_locked(prerequisites: int)` - Show lock icon + prereq count
- [ ] Visual states:
  - [ ] **Completed:** Green progress bar, checkmark icon, full color
  - [ ] **In Progress:** Blue progress bar, no checkmark, full color
  - [ ] **Locked:** Grayed out, lock icon (⚙️2 = needs 2 prereqs), no rewards shown
  - [ ] **Undiscovered:** Hidden (not shown in list)

**Test:** Instantiate quest entry with mock data → see progress bar and rewards

---

### Step 3: Wire Quest Log to QuestManager (1 session)
**Goal:** Populate quest list from QuestManager data

**QuestManager API Integration:**
```gdscript
# Query methods from Task 3
QuestManager.get_quests_by_category(category: QuestCategory) -> Array[QuestConfig]
QuestManager.get_quest_progress(quest_id: String) -> Dictionary  # {current: int, target: int, completed: bool}
QuestManager.is_quest_unlocked(quest_id: String) -> bool
QuestManager.get_visible_quests() -> Array[QuestConfig]
```

**Implementation:**
- [ ] Update `QuestLog.gd` to query QuestManager:
  - [ ] On tab click → `populate_category(category)`
  - [ ] For each quest in category:
    - [ ] Instantiate `QuestEntry.tscn`
    - [ ] Call `entry.setup(quest, QuestManager.get_quest_progress(quest.quest_id))`
    - [ ] Add to ScrollContainer
  - [ ] Filter by completion status (if "Completed" checkbox enabled)
- [ ] Connect to EventBus signals:
  - [ ] `EventBus.quest_progress_updated` → refresh quest entry progress bar
  - [ ] `EventBus.quest_completed` → update quest entry visual state
  - [ ] `EventBus.quest_unlocked` → add newly unlocked quest to list
- [ ] Update progress counters:
  - [ ] Total progress: Sum of all completed quests / total quests
  - [ ] Category progress: Completed quests in category / total in category
  - [ ] Update tab labels (e.g., "Characters 7/18")

**Test:** Open quest log → see real quest data from QuestManager → complete quest → see progress update

---

### Step 4: Implement Reward Preview Columns (1-2 sessions)
**Goal:** Show what items/unlocks you'll earn from quest (MEGABONK feature)

**Reward Preview Design:**
- Each quest shows 1-3 reward icons in right column
- Icons represent: Rift Fragments, Items, Weapons, Tomes, Characters, Skins
- Hover tooltip shows reward details (e.g., "Unlocks: Cheese (Item)")

**Implementation:**
- [ ] Add reward metadata to QuestConfig:
  - [ ] `@export var reward_icons: Array[Texture2D]` - Icons for UI preview
  - [ ] OR generate icons dynamically from `reward_unlocks` array
- [ ] Update `QuestEntry.gd`:
  - [ ] `show_rewards(rewards: Array[String])` implementation:
    - [ ] For each reward ID in `quest.reward_unlocks`:
      - [ ] Load item/character metadata (ItemMetadata, CharacterMetadata)
      - [ ] Display icon (if available) or placeholder (🎁)
    - [ ] Add Rift Fragments icon if `quest.reward_rift_fragments > 0`
  - [ ] Add hover tooltips:
    - [ ] On reward icon hover → show tooltip: "Unlocks: Cheese (Item) + 10 Rift Fragments"
- [ ] Reward icon types:
  - [ ] 💎 Rift Fragments icon
  - [ ] 🧀 Item icon (from ItemMetadata)
  - [ ] ⚔️ Weapon icon (from WeaponMetadata - future)
  - [ ] 📖 Tome icon (from TomeMetadata)
  - [ ] 👤 Character icon (from CharacterMetadata - future)
  - [ ] 🎨 Skin icon (future)

**Test:** Quest entry shows 2-3 reward icons → hover → see tooltip with details

---

### Step 5: Implement Quest Filtering & Sorting (1 session)
**Goal:** Filter by completed/incomplete, sort by various criteria

**Filter Options (MEGABONK-style):**
- **Completed checkbox:** Show only completed quests (or hide them)
- **Future:** Sort by progress %, alphabetical, reward type

**Implementation:**
- [ ] Add filter controls to QuestLog.gd:
  - [ ] CheckBox: "Sort: Completed"
    - [ ] When checked → show only completed quests
    - [ ] When unchecked → show all quests (or only incomplete - TBD)
  - [ ] Future: OptionButton for sort order (Progress, Name, Category)
- [ ] Filter logic:
  - [ ] `apply_filters()` - Re-populate quest list based on current filters
  - [ ] `_on_completed_filter_changed()` - Rebuild list
- [ ] Sorting logic:
  - [ ] By default: Quest ID order (definition order in files)
  - [ ] Future: Sort by `quest.difficulty`, `progress_percentage`, `alphabetical`

**Test:** Check "Completed" filter → see only completed quests → uncheck → see all quests

---

### Step 6: Add Quest Detail Panel (Optional - Polish)
**Goal:** Click quest to show detailed description, objectives, rewards

**Detail Panel Design:**
```
┌────────────────────────────────┐
│ Kill 1000 Skeletons            │
├────────────────────────────────┤
│ "Defeat 1000 skeleton enemies  │
│  across all runs to unlock     │
│  the Cheese item."             │
│                                │
│ OBJECTIVES:                    │
│ • Kill 1000 enemies [✓]        │
│                                │
│ REWARDS:                       │
│ • 10 Rift Fragments            │
│ • Cheese (Item)                │
│                                │
│ PROGRESS: 1000/1000 (100%)     │
│ STATUS: Completed ✓            │
└────────────────────────────────┘
```

**Implementation:**
- [ ] Create side panel: `QuestDetailPanel` (right side of quest log)
- [ ] On quest entry click → `show_quest_details(quest: QuestConfig)`
- [ ] Display:
  - [ ] Quest name + description
  - [ ] Objectives list (multi-objective quests)
  - [ ] Rewards breakdown (fragments + unlocks)
  - [ ] Progress percentage
  - [ ] Status (Locked, In Progress, Completed)
- [ ] Defer to UI polish if time-constrained

**Test:** Click quest → see detail panel with full info

---

## 🔗 Integration Points

### QuestManager API (from Task 3):
```gdscript
# Quest queries
QuestManager.get_all_quests() -> Array[QuestConfig]
QuestManager.get_quests_by_category(category: QuestCategory) -> Array[QuestConfig]
QuestManager.get_active_quests() -> Array[QuestConfig]  # Not completed
QuestManager.get_completed_quests() -> Array[QuestConfig]
QuestManager.get_visible_quests() -> Array[QuestConfig]  # Unlocked, not hidden
QuestManager.get_locked_quests() -> Array[QuestConfig]  # Visible but locked

# Quest progress
QuestManager.get_quest_progress(quest_id: String) -> Dictionary
# Returns: {"progress": int, "target": int, "completed": bool}

QuestManager.is_quest_completed(quest_id: String) -> bool
QuestManager.is_quest_unlocked(quest_id: String) -> bool

# Quest rewards
QuestManager.get_quest_rewards(quest_id: String) -> Dictionary
# Returns: {"rift_fragments": int, "unlocks": Array[String], "discovers": Array[String]}
```

### EventBus Signals (from Task 3):
```gdscript
# Listen for quest updates
signal quest_progress_updated(quest_id: String, current: int, target: int)
signal quest_completed(quest_id: String, rewards: Dictionary)
signal quest_unlocked(quest_id: String)  # Prerequisites met
```

### QuestConfig Structure (from Task 3 Phase 1):
```gdscript
class_name QuestConfig extends Resource

@export var quest_id: String
@export var display_name: String
@export_multiline var description: String
@export var category: QuestCategory  # CHARACTERS, WEAPONS, TOMES, ITEMS, GENERAL, CHALLENGES, SKINS

@export var objective_type: ObjectiveType
@export var objective_target: int
@export var objective_cumulative: bool  # Across all runs

@export var reward_rift_fragments: int
@export var reward_unlocks: Array[String]  # Item/character IDs

@export var icon: Texture2D
@export var prerequisite_quests: Array[String]  # Required quests
```

---

## 📝 Testing Checklist

- [ ] Open quest log from main menu → see category tabs
- [ ] Click category tab → see quests filtered by category
- [ ] Progress counters match actual quest completion (e.g., "7/18")
- [ ] Quest entry shows correct progress bar (current/target)
- [ ] Completed quests show checkmark icon
- [ ] Locked quests show lock icon + prerequisite count
- [ ] Reward preview shows 1-3 icons per quest
- [ ] Hover reward icon → see tooltip with details
- [ ] Check "Completed" filter → see only completed quests
- [ ] Complete quest mid-run → quest log updates in real-time
- [ ] Quest log reflects QuestManager state correctly
- [ ] Close quest log → return to main menu

---

## 🚨 Edge Cases & Considerations

### Missing Quest Icons
- **Issue:** QuestConfig might not have icon texture
- **Solution:** Use placeholder icon (📜) or category icon (⚔️ for weapons, etc.)

### Reward Icon Loading
- **Issue:** Reward unlocks reference items that might not have icons yet
- **Solution:** Use generic reward icon (🎁) as fallback

### Quest List Performance
- **Issue:** 200+ quests in list could cause lag
- **Solution:** Only instantiate visible quest entries (virtual scrolling if needed)

### Progress Update Race Conditions
- **Issue:** Quest completes while quest log is open
- **Solution:** Connect to `EventBus.quest_completed` → refresh entry immediately

### Category Tab Overflow
- **Issue:** 7 categories might not fit on screen width
- **Solution:** Use TabContainer with scroll buttons OR abbreviate tab names

---

## ✅ Definition of Done

- [ ] Quest log scene accessible from main menu
- [ ] Category tabs display with progress counters (e.g., "7/18")
- [ ] Quest list shows all quests for selected category
- [ ] Quest entries display: icon, name, progress bar, completion status
- [ ] Reward preview shows 1-3 icons per quest
- [ ] Reward tooltips show unlock details
- [ ] Completed filter works (show/hide completed quests)
- [ ] Locked quests show prerequisite count
- [ ] Real-time updates when quest progresses (EventBus integration)
- [ ] Quest log syncs with QuestManager state
- [ ] Visual states: completed (green ✓), in-progress (blue), locked (gray 🔒)

**Cross-Task Integration:**
- [ ] **Task 3 Synchronization:** Quest categories match backend enum exactly
- [ ] **Task 3 Synchronization:** QuestManager API calls work correctly
- [ ] **Task 3 Synchronization:** EventBus signals update UI in real-time
- [ ] **Task 3 Synchronization:** QuestConfig fields provide all data needed for UI

---

## 🔄 Task 3 Synchronization Requirements

**IMPORTANT:** This task (quest UI) must stay synchronized with **Task 3 (Quest System Backend)**. Any backend changes require UI updates:

### Backend API Changes (Task 3):
- **QuestManager query methods** → Update UI data fetching logic
- **EventBus signal payloads** → Update signal handler parameters
- **QuestConfig structure** → Update QuestEntry display fields

### Quest Category Changes (Task 3 Phase 6):
Must match exactly:
1. **CHARACTERS** → "Characters" tab
2. **WEAPONS** → "Weapons" tab
3. **TOMES** → "Tomes" tab
4. **ITEMS** → "Items" tab
5. **GENERAL** → "General" tab
6. **CHALLENGES** → "Challenges" tab
7. **SKINS** → "Skins" tab (future)

### Reward Structure Changes (Task 3 Phase 3):
- **reward_rift_fragments** → Display Rift Fragments icon
- **reward_unlocks** → Display item/character icons
- **reward_discovers** → Display "?" icon for undiscovered items

**Before implementing UI:** Verify Task 3 Phase 1-4 complete and API stable.

---

**Related:** [Task 3 - Quest System Backend (MUST SYNC)](3_PROGRESSION_quest_system_implementation.md) | [Task 8 - UI Polish](8_UI_progression_screens_polish.md) | [MEGABONK Quest Reference](../02-brainstorm/MEGABONK-quest-system-reference.png)
