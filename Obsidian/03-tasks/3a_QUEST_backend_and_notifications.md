# 3a: Quest System Backend & Notifications

**Created:** 2025-10-03
**Updated:** 2025-10-03 (Renamed from `3_PROGRESSION_quest_system_implementation.md`)
**Status:** 🟡 Planning
**Priority:** High
**Estimated Effort:** 3-4 weeks
**Category:** 🎮 Quest System - Backend
**Consolidated From:** Task 3 (Quest Backend) + Task 6 (In-Game Notifications)
**UI Companion Task:** [Task 3b - Quest UI Archive](3b_QUEST_ui_achievement_archive.md) ← **MUST STAY IN SYNC**

> ⚠️ **Cross-Reference:** This task handles the quest **backend and in-run notifications**. For the main menu quest log UI (MEGABONK-style achievement browser), see **Task 3b**. These tasks must stay synchronized - QuestManager API changes here require UI updates in Task 3b.

## 📋 Task Description

Implement a backend quest system that tracks player objectives, detects completion, and awards rewards (Rift Fragments, item unlocks). System must integrate with existing SessionState tracking and MetaProgression unlock system without requiring UI implementation initially.

**Current State Analysis:**
- ✅ SessionState tracks run stats (kills, damage, time, boss kills, stage progression)
- ✅ MetaProgression handles Rift Fragments currency and item unlock states
- ✅ EventBus provides signals for all relevant game events (enemy_killed, damage_dealt, etc.)
- ⚠️ No quest definition system exists
- ⚠️ No quest progress tracking system exists
- ⚠️ No quest completion detection exists
- ⚠️ Quest ↔ Item unlock relationship undefined

**Integration Requirements:**
- ✅ SessionState signals provide all tracking data needed
- ✅ MetaProgression provides unlock state management
- ✅ LocalLeaderboard provides achievement-style completion tracking
- ⚠️ Need quest definition resource format
- ⚠️ Need quest progress persistence across runs
- ⚠️ Need quest completion rewards system

## 🏗️ ARCHITECTURE DECISION REQUIRED

**Critical Question:** How do quests relate to item/skill unlocks?

### Option A: Quest-Per-Item System (MEGABONK Discovery Model)
**Structure:** Each unlockable item/skill has ONE associated quest for unlock

```
Items:
├── cheese.tres (ItemMetadata)
│   └── quest: "cheese_quest" (QuestConfig reference)
├── clover.tres (ItemMetadata)
│   └── quest: "clover_quest" (QuestConfig reference)

Quests:
├── cheese_quest.tres (QuestConfig)
│   ├── objective: "Kill 100 enemies"
│   └── reward_unlock: "cheese" (unlocks item)
├── clover_quest.tres (QuestConfig)
│   ├── objective: "Deal 10000 damage"
│   └── reward_unlock: "clover" (unlocks item)
```

**Pros:**
- ✅ Clear 1:1 relationship (quest = unlock path)
- ✅ Simple to understand ("complete quest to unlock item")
- ✅ Fits MEGABONK discovery → purchase flow (quest unlocks discovery)
- ✅ Easy to track progress per item ("50/100 enemies killed")

**Cons:**
- ❌ Many quests needed (100+ items = 100+ quests)
- ❌ Repetitive quest design risk ("kill X enemies" x 50)
- ❌ No multi-item reward quests (can't unlock multiple items from one quest)

---

### Option B: Independent Quest Pool System (Achievement Model)
**Structure:** Quests are separate entities that reward arbitrary unlocks

```
Quests:
├── first_blood.tres (QuestConfig)
│   ├── objective: "Kill your first enemy"
│   └── rewards: [10 Rift Fragments, unlock "cheese"]
├── slayer.tres (QuestConfig)
│   ├── objective: "Kill 1000 enemies total"
│   └── rewards: [50 Rift Fragments, unlock "clover", unlock "lucky_coin"]
├── survivor.tres (QuestConfig)
│   ├── objective: "Survive 10 minutes in a single run"
│   └── rewards: [25 Rift Fragments]

Items:
├── cheese.tres (ItemMetadata)
│   └── unlock_condition: "Complete quest: first_blood" (display only)
├── clover.tres (ItemMetadata)
│   └── unlock_condition: "Complete quest: slayer" (display only)
```

**Pros:**
- ✅ Flexible rewards (multiple items, fragments, cosmetics)
- ✅ Natural achievement system (milestones feel meaningful)
- ✅ Fewer quests needed (multi-reward quests reduce total count)
- ✅ Can reward non-item unlocks (characters, maps, cosmetics)

**Cons:**
- ❌ Harder to find "which quest unlocks this item?" (reverse lookup)
- ❌ More complex quest definition (arrays of rewards)
- ❌ UI complexity (showing multiple unlocks from one quest)

---

### Option C: Category-Based Quest Trees (Progression Path Model)
**Structure:** Quest categories unlock groups of related items progressively

```
Quest Categories:
├── offensive_items/ (QuestCategory)
│   ├── tier_1_quest.tres → unlocks [cheese, clover, lucky_coin]
│   ├── tier_2_quest.tres → unlocks [damage_ring, crit_gem]
│   └── tier_3_quest.tres → unlocks [legendary_sword]
├── defensive_items/ (QuestCategory)
│   ├── tier_1_quest.tres → unlocks [leather_armor, health_potion]
│   └── tier_2_quest.tres → unlocks [plate_armor, shield]
├── abilities/ (QuestCategory)
│   ├── basic_skills.tres → unlocks [dash, jump, slam]
│   └── advanced_skills.tres → unlocks [teleport, invuln]

Items:
├── cheese.tres (ItemMetadata)
│   └── unlock_category: "offensive_items/tier_1"
```

**Pros:**
- ✅ Natural progression gating (unlock tier 1 before tier 2)
- ✅ Fewer quests than Option A (categories instead of per-item)
- ✅ Clear item organization (offensive/defensive/utility)
- ✅ Batch unlocks feel rewarding ("unlocked 5 new items!")

**Cons:**
- ❌ Less granular control (can't unlock single items individually)
- ❌ Rigid structure (hard to add "special" quests outside tree)
- ❌ Discovery flow broken (find item in run, but can't unlock individually)

---

### Option D: Hybrid System (Quest Pool + Discovery Flags)
**Structure:** Combines MEGABONK discovery with flexible quest rewards

```
Discovery Flow:
1. Find item in run → MetaProgression.discover_item("cheese")
2. Item appears in shop as DISCOVERED (greyscale, locked)
3. Complete quest → Item becomes UNLOCKED (can purchase or auto-unlocked)

Quests:
├── achievement_quests/
│   ├── first_blood.tres → rewards [unlock "cheese", unlock "clover"]
│   ├── slayer.tres → rewards [unlock tier_2_offensive_items category]
│   └── survivor.tres → rewards [50 Rift Fragments]
├── item_unlock_quests/
│   ├── cheese_unlock.tres → rewards [unlock "cheese" only]
│   └── clover_unlock.tres → rewards [unlock "clover" only]

Items:
├── cheese.tres (ItemMetadata)
│   └── unlock_methods: ["quest: first_blood", "quest: cheese_unlock"]
```

**Pros:**
- ✅ Flexibility (multiple unlock paths for same item)
- ✅ Preserves MEGABONK discovery flow (find → see → unlock)
- ✅ Achievement quests still work (multi-reward quests)
- ✅ Granular control (can unlock individually OR via batches)

**Cons:**
- ❌ Most complex to implement (multiple unlock paths)
- ❌ Hardest to balance (too many unlock options?)
- ❌ UI complexity (showing multiple unlock methods)

---

## 🎯 RECOMMENDATION: Option B (Independent Quest Pool)

**Reasoning:**
1. **Fits existing progression:** MetaProgression already has discovery/unlock separation
2. **Natural achievements:** Quests feel like milestones, not chores
3. **Flexible rewards:** Can unlock items, characters, maps, Rift Fragments
4. **Scalable:** Easy to add new quests without touching item definitions
5. **UI-friendly:** Quest log shows clear objectives and rewards

**Migration Path:**
- Phase 1: Core quest system (Option B)
- Phase 2: (Optional) Add per-item unlock quests if needed (hybrid Option D)
- Phase 3: UI shows "Complete quest X to unlock this item"

**Example Quest Progression:**
```gdscript
# Early quests (first 10 minutes of gameplay)
"first_blood"      → Kill 1 enemy        → 10 Rift Fragments + unlock "cheese"
"survivor_5min"    → Survive 5 minutes   → 15 Rift Fragments + unlock "clover"
"damage_dealer"    → Deal 5000 damage    → 20 Rift Fragments + unlock "feather"

# Mid-game quests (first few runs)
"slayer"           → Kill 500 enemies    → 50 Rift Fragments + unlock "lucky_coin"
"boss_killer"      → Kill first boss     → 75 Rift Fragments + unlock "damage_tome"
"stage_2_clear"    → Reach stage 2       → 100 Rift Fragments + unlock "rabbits_foot"

# Long-term quests (across many runs)
"veteran"          → Complete 50 runs    → 200 Rift Fragments + unlock character
"legendary_slayer" → Kill 10000 enemies  → 500 Rift Fragments + unlock legendary_item
```

---

## 📊 Implementation Plan (Option B)

### Phase 1: Core Quest Definition System (1-2 sessions)
**Goal:** Define quest structure and resource format
**Test:** Can load quest definitions from .tres files

- [ ] Create `QuestConfig` resource class (scripts/resources/QuestConfig.gd)
- [ ] Define quest structure:
  ```gdscript
  class_name QuestConfig extends Resource

  @export var quest_id: String                  # Unique ID (e.g., "first_blood")
  @export var display_name: String              # UI display (e.g., "First Blood")
  @export_multiline var description: String     # Quest description
  @export var category: String                  # "combat", "survival", "exploration"

  # Objectives (multiple conditions, ALL must be met)
  @export var objective_type: ObjectiveType     # KILL_ENEMIES, SURVIVE_TIME, etc.
  @export var objective_target: int             # Target value (e.g., 100 enemies)
  @export var objective_cumulative: bool        # Across all runs (true) or single run (false)

  # Rewards
  @export var reward_rift_fragments: int        # Rift Fragments awarded
  @export var reward_unlocks: Array[String]     # Item/character IDs to unlock
  @export var reward_discover: Array[String]    # Item IDs to discover (not unlock)

  # Metadata
  @export var icon: Texture2D                   # Quest icon
  @export var unlock_condition: String          # Prerequisites (optional)
  ```
- [ ] Define objective types enum:
  ```gdscript
  enum ObjectiveType {
      KILL_ENEMIES,           # Total enemies killed
      DEAL_DAMAGE,            # Total damage dealt
      SURVIVE_TIME,           # Time survived (seconds)
      REACH_STAGE,            # Stage number reached
      KILL_BOSS,              # Boss kills
      COLLECT_ITEMS,          # Items collected
      COMPLETE_RUNS,          # Runs completed
      EARN_FRAGMENTS,         # Rift Fragments earned
      CUSTOM                  # Custom condition (script-based)
  }
  ```
- [ ] Create example quest files in `/data/content/quests/`:
  - [ ] `first_blood.tres` (Kill 1 enemy → 10 fragments + cheese unlock)
  - [ ] `slayer.tres` (Kill 500 enemies → 50 fragments + lucky_coin unlock)
  - [ ] `survivor.tres` (Survive 5 minutes → 25 fragments)
  - [ ] `boss_killer.tres` (Kill first boss → 75 fragments + damage_tome unlock)
- [ ] Add quest loading to ContentDB (if exists) or create QuestDB autoload
- [ ] Test: Load all quest .tres files, validate structure

**Deliverable:** Quest definition system with example quests

---

### Phase 2: Quest Progress Tracking (2-3 sessions)
**Goal:** Track quest progress via SessionState signals
**Test:** Quest progress updates correctly during runs

- [ ] Create `QuestManager` autoload (autoload/QuestManager.gd)
- [ ] Define quest progress structure:
  ```gdscript
  # Persistent quest progress (saved to user://quest_progress.tres)
  var quest_progress: Dictionary = {}
  # Structure: {"quest_id": {"progress": int, "completed": bool, "completion_time": int}}
  ```
- [ ] Implement progress tracking methods:
  - [ ] `load_quests()` - Load all QuestConfig files from /data/content/quests/
  - [ ] `get_quest_progress(quest_id: String) -> Dictionary` - Current progress
  - [ ] `is_quest_completed(quest_id: String) -> bool` - Completion status
  - [ ] `get_active_quests() -> Array[QuestConfig]` - Non-completed quests
  - [ ] `get_completed_quests() -> Array[QuestConfig]` - Completed quests
- [ ] Connect to SessionState/EventBus signals for tracking:
  - [ ] `EventBus.enemy_killed` → increment KILL_ENEMIES progress
  - [ ] `EventBus.damage_dealt` → increment DEAL_DAMAGE progress
  - [ ] `EventBus.run_ended` → check SURVIVE_TIME, REACH_STAGE, COMPLETE_RUNS
  - [ ] `EventBus.boss_killed` → increment KILL_BOSS progress
  - [ ] Custom tracking for COLLECT_ITEMS, EARN_FRAGMENTS
- [ ] Implement cumulative vs single-run tracking:
  - [ ] Cumulative quests: Persist progress across runs (quest_progress.tres)
  - [ ] Single-run quests: Check SessionState stats on run_ended
- [ ] Implement save/load for quest progress:
  - [ ] `save_progress()` → writes to `user://quest_progress.tres`
  - [ ] `load_progress()` → reads from disk on game launch
- [ ] Add EventBus signals:
  - [ ] `quest_progress_updated(quest_id: String, current: int, target: int)`
  - [ ] `quest_completed(quest_id: String, rewards: Dictionary)`
- [ ] Test with accelerated quest objectives (kill 5 enemies instead of 500)

**Deliverable:** Quest progress tracks correctly, persists across runs

---

### Phase 3: Quest Completion & Rewards (1-2 sessions)
**Goal:** Detect completion, award rewards, integrate with MetaProgression
**Test:** Completing quest awards Rift Fragments and unlocks items

- [ ] Implement completion detection:
  - [ ] `_check_quest_completion(quest: QuestConfig)` - Compare progress to target
  - [ ] Call on every progress update (EventBus signals)
  - [ ] Emit `EventBus.quest_completed` when threshold reached
- [ ] Implement reward distribution:
  - [ ] `_award_quest_rewards(quest: QuestConfig)` - Process rewards
  - [ ] Award Rift Fragments: `MetaProgression.earn_rift_fragments(amount)`
  - [ ] Unlock items: `MetaProgression.unlock_item("items", item_id)` for each
  - [ ] Discover items: `MetaProgression.discover_item("items", item_id)` for each
  - [ ] Mark quest as completed in quest_progress
- [ ] Add reward preview methods:
  - [ ] `get_quest_rewards(quest_id: String) -> Dictionary` - Preview rewards
  - [ ] Returns: `{"rift_fragments": int, "unlocks": Array[String], "discovers": Array[String]}`
- [ ] Integrate with MetaProgression signals:
  - [ ] Quest completion triggers `MetaProgression.item_unlocked` signals
  - [ ] UI can listen to these signals for unlock notifications
- [ ] Add completion timestamp tracking:
  - [ ] Record `completion_time: int` (Unix timestamp) in quest_progress
  - [ ] Enables "recently completed" sorting in UI
- [ ] Test reward flow:
  - [ ] Complete quest → Rift Fragments awarded correctly
  - [ ] Complete quest → Item appears as unlocked in MetaProgression
  - [ ] Verify MetaProgression.save() called after rewards

**Deliverable:** Quest completion awards rewards and integrates with MetaProgression

---

### Phase 4: Quest Unlock Conditions & Dependencies (1-2 sessions)
**Goal:** Support quest prerequisites (unlock quest B after completing quest A)
**Test:** Quest dependencies enforce correct unlock order

- [ ] Add prerequisite system to QuestConfig:
  - [ ] `@export var prerequisite_quests: Array[String]` - Quest IDs required
  - [ ] `@export var unlock_level: int` - Player level requirement (optional)
  - [ ] `@export var unlock_stage: int` - Stage reached requirement (optional)
- [ ] Implement unlock condition checking:
  - [ ] `is_quest_unlocked(quest_id: String) -> bool` - Check prerequisites
  - [ ] Check all prerequisite quests are completed
  - [ ] Check player meets level/stage requirements
- [ ] Update `get_active_quests()` to filter by unlock status:
  - [ ] Only return quests that are unlocked and not completed
- [ ] Add quest visibility system:
  - [ ] `get_visible_quests() -> Array[QuestConfig]` - Unlocked quests
  - [ ] `get_locked_quests() -> Array[QuestConfig]` - Visible but locked
  - [ ] `get_hidden_quests() -> Array[QuestConfig]` - Not yet revealed
- [ ] Create quest progression chains:
  - [ ] Example: "first_blood" → "slayer" → "legendary_slayer"
  - [ ] Example: "survivor_5min" → "survivor_10min" → "survivor_final_swarm"
- [ ] Test dependency enforcement:
  - [ ] Quest B doesn't appear until Quest A completed
  - [ ] Quest C requires player level 10

**Deliverable:** Quest unlock dependencies working correctly

---

### Phase 5: Advanced Quest Types & Custom Conditions (2-3 sessions)
**Goal:** Support complex quest objectives beyond simple counters
**Test:** Custom quest conditions work (e.g., "Kill boss without taking damage")

- [ ] Implement multi-objective quests:
  - [ ] `@export var objectives: Array[QuestObjective]` - Multiple conditions
  - [ ] All objectives must be completed for quest completion
  - [ ] Example: "Kill 100 enemies AND survive 10 minutes"
- [ ] Add custom condition support:
  - [ ] `@export var custom_script: GDScript` - Optional script for complex logic
  - [ ] Script interface: `func check_condition(session_stats: Dictionary) -> bool`
  - [ ] Example: "Kill boss in under 2 minutes" (needs script logic)
- [ ] Implement quest objective resource:
  ```gdscript
  class_name QuestObjective extends Resource

  @export var objective_type: QuestConfig.ObjectiveType
  @export var target_value: int
  @export var current_value: int
  @export_multiline var description: String
  ```
- [ ] Add objective-specific tracking:
  - [ ] Track progress for each objective independently
  - [ ] Quest completes only when ALL objectives met
- [ ] Create complex quest examples:
  - [ ] "Perfect Boss" → Kill boss without taking damage
  - [ ] "Speed Runner" → Reach stage 3 in under 15 minutes
  - [ ] "Glass Cannon" → Deal 50000 damage while under 50% HP
- [ ] Add quest hints/tips system:
  - [ ] `@export_multiline var hint: String` - Strategy suggestions
  - [ ] Display in UI when quest selected
- [ ] Test custom condition quests with isolated test scene

**Deliverable:** Complex quest objectives working (multi-objective, custom scripts)

---

### Phase 6: Quest Categories & Organization (1 session)
**Goal:** Organize quests by category for UI display
**Test:** Can query quests by category (combat, survival, exploration)

- [ ] Define quest categories enum:
  ```gdscript
  enum QuestCategory {
      COMBAT,        # Kill enemies, deal damage, defeat bosses
      SURVIVAL,      # Survive time, reach stages, avoid damage
      EXPLORATION,   # Discover items, visit areas, collect items
      PROGRESSION,   # Complete runs, earn fragments, level up
      ACHIEVEMENT,   # Special challenges, perfect runs, speed runs
      DAILY,         # Daily rotating quests (future)
      WEEKLY         # Weekly rotating quests (future)
  }
  ```
- [ ] Add category to QuestConfig:
  - [ ] `@export var category: QuestCategory` - Quest category
- [ ] Implement category filtering:
  - [ ] `get_quests_by_category(category: QuestCategory) -> Array[QuestConfig]`
  - [ ] Filter active quests by category
- [ ] Add category-specific icons/colors:
  - [ ] Combat: Red sword icon
  - [ ] Survival: Green shield icon
  - [ ] Exploration: Blue compass icon
  - [ ] Progression: Purple star icon
  - [ ] Achievement: Gold trophy icon
- [ ] Create quest distribution across categories:
  - [ ] 40% Combat quests (kill enemies, defeat bosses)
  - [ ] 30% Survival quests (survive time, reach stages)
  - [ ] 20% Progression quests (complete runs, earn fragments)
  - [ ] 10% Achievement quests (perfect runs, special challenges)
- [ ] Test category filtering for UI display

**Deliverable:** Quest categories working, quests organized by type

---

### Phase 7: Quest Analytics & Balancing (1-2 sessions)
**Goal:** Track quest completion rates for balancing
**Test:** Can query completion statistics

- [ ] Add analytics tracking:
  - [ ] `quest_attempts: Dictionary` - How many runs attempted quest
  - [ ] `quest_completions: Dictionary` - How many times completed
  - [ ] `average_completion_time: Dictionary` - Average time to complete
- [ ] Implement analytics methods:
  - [ ] `get_quest_completion_rate(quest_id: String) -> float` - 0.0-1.0
  - [ ] `get_most_completed_quests(count: int) -> Array[String]` - Top quests
  - [ ] `get_least_completed_quests(count: int) -> Array[String]` - Hardest quests
- [ ] Add difficulty rating system:
  - [ ] `@export var difficulty: int` - 1-5 stars
  - [ ] Based on objective target and type
  - [ ] Can be adjusted based on analytics
- [ ] Create balancing tools:
  - [ ] Export quest statistics to CSV for analysis
  - [ ] Identify quests with <10% completion rate (too hard)
  - [ ] Identify quests with >90% completion rate (too easy)
- [ ] Add CheatSystem debug commands:
  - [ ] `complete_quest <quest_id>` - Force quest completion
  - [ ] `reset_quest <quest_id>` - Reset quest progress
  - [ ] `quest_stats` - Show completion rates
  - [ ] `unlock_all_quests` - Bypass prerequisites

**Deliverable:** Quest analytics tracking for balancing decisions

---

### Phase 8: In-Game Quest Completion Notifications (2 sessions)
**Goal:** Show popup when quest completes mid-run
**Source:** Consolidated from Task 6

**Notification Design:**
```
┌─────────────────────────────────┐
│ ⭐ QUEST COMPLETED! ⭐           │
├─────────────────────────────────┤
│ "First Blood"                   │
│ Kill your first enemy           │
│                                 │
│ REWARDS:                        │
│ + 10 Rift Fragments             │
│ + Unlocked: Cheese (Item)       │
└─────────────────────────────────┘
```

**Implementation:**
- [ ] Create notification scene: `scenes/ui/hud/QuestCompletionNotification.tscn`
  - [ ] Panel background (semi-transparent dark)
  - [ ] Title label: "QUEST COMPLETED!"
  - [ ] Quest name + description labels
  - [ ] Rewards section (Rift Fragments + unlocked items)
  - [ ] Auto-dismiss after 5 seconds OR click to dismiss
  - [ ] Fade-in animation (Tween)
- [ ] Attach script: `QuestCompletionNotification.gd`
  - [ ] `show_quest_completion(quest: QuestConfig, rewards: Dictionary)`
  - [ ] Populate from QuestConfig data
  - [ ] Auto-dismiss timer
- [ ] Wire to QuestManager:
  - [ ] HUD/Arena listens for `EventBus.quest_completed`
  - [ ] Instantiate notification on signal
  - [ ] Queue system for multiple simultaneous completions
  - [ ] Position: top-center or right-side panel (CanvasLayer)
- [ ] Test: Complete 2 quests quickly → notifications queue correctly

**Deliverable:** In-game quest completion notifications working

---

### Phase 9: End-of-Run Quest Summary Integration (1-2 sessions)
**Goal:** Display completed quests on end-of-run screen (right column)
**Source:** Consolidated from Task 6

**End-of-Run Right Column Layout:**
```
┌──────────────────────────────┐
│ COMPLETED QUESTS             │
├──────────────────────────────┤
│ ⭐ First Blood               │
│    + 10 Fragments            │
│    + Unlocked: Cheese        │
│                              │
│ ⭐ Damage Dealer             │
│    + 20 Fragments            │
│    + Unlocked: Feather       │
│                              │
│ Total Quest Rewards:         │
│ + 30 Rift Fragments          │
│ + 2 Items Unlocked           │
└──────────────────────────────┘
```

**Implementation:**
- [ ] Update SessionState to track completed quests:
  - [ ] `completed_quests_this_run: Array[String]` - Quest IDs
  - [ ] `add_completed_quest(quest_id: String)` - Called by QuestManager
  - [ ] Included in `get_final_stats()`
  - [ ] Cleared in `reset()`
- [ ] Update `EndOfRun.gd` to display completed quests:
  - [ ] Query `SessionState.completed_quests_this_run`
  - [ ] Load QuestConfig for each quest ID
  - [ ] Display quest name + rewards
  - [ ] Show totals (fragments + unlocks)
  - [ ] Simple VBoxContainer list (defer polish to Task 8)
- [ ] Add visual elements:
  - [ ] Quest icons (if available)
  - [ ] Reward icons (fragments, items)
- [ ] Test: Complete run with 2 quests → end screen shows both

**Deliverable:** End-of-run screen displays completed quests with rewards

---

## 🔗 Related Files

### Will Create:
- [ ] `scripts/resources/QuestConfig.gd` - Quest definition resource class
- [ ] `scripts/resources/QuestObjective.gd` - Quest objective sub-resource
- [ ] `autoload/QuestManager.gd` - Quest tracking and completion system
- [ ] `data/content/quests/*.tres` - Individual quest definitions
- [ ] `user://quest_progress.tres` - Persistent quest progress save file

### Will Modify:
- [ ] `autoload/EventBus.gd` - Add quest-related signals
- [ ] `autoload/SessionState.gd` - Track completed quests this run
- [ ] `autoload/MetaProgression.gd` - Integration with quest rewards
- [ ] `data/content/items/*.tres` - Add unlock_condition display text (optional)
- [ ] `project.godot` - Add QuestManager to autoload list

### Documentation Updates Needed:
- [ ] `autoload/CLAUDE.md` - QuestManager patterns and integration
- [ ] `scripts/resources/CLAUDE.md` - QuestConfig resource structure
- [ ] `data/content/README.md` - Quest definition schema
- [ ] Create `Obsidian/systems/Quest-System.md` - Complete system documentation

---

## 🚨 Risks & Considerations

### Balancing Risk (HIGH)
- **Issue:** Quest objectives too easy/hard without playtesting
- **Mitigation:** Start conservative (low targets), use analytics to adjust, CheatSystem debug tools

### Scope Creep Risk (MEDIUM)
- **Issue:** Daily/weekly quests, quest chains, complex conditions add complexity
- **Mitigation:** Phase 1-4 for MVP (simple quests), Phase 5-7 for advanced features

### Performance Risk (LOW)
- **Issue:** Checking 100+ quests on every enemy_killed signal
- **Mitigation:** Only check active quests, cache completion status, batch updates

### Save File Corruption Risk (MEDIUM)
- **Issue:** Quest progress save file corruption loses player progress
- **Mitigation:** Backup system (keep last 3 saves), validation on load, graceful fallback

---

## ✅ Definition of Done

**Core Backend (Phases 1-4):**
- [ ] QuestConfig resource class implemented with all fields
- [ ] QuestManager autoload tracks progress correctly
- [ ] Quest completion awards Rift Fragments and unlocks items
- [ ] Quest progress persists across runs (quest_progress.tres)
- [ ] Quest prerequisites enforce unlock order correctly
- [ ] Example quests created (10+ quests across categories)
- [ ] Integration with SessionState and MetaProgression verified
- [ ] CheatSystem debug commands working (complete_quest, reset_quest, etc.)

**Advanced Backend Features (Phases 5-7):**
- [ ] Multi-objective quests working (AND conditions)
- [ ] Custom condition scripts supported (complex logic)
- [ ] Quest categories organized (combat, survival, exploration, etc.)
- [ ] Quest analytics tracking completion rates
- [ ] Balancing tools export statistics for analysis

**In-Game Notifications (Phases 8-9):**
- [ ] Quest completion notification popup appears mid-run
- [ ] Notification shows quest name, rewards (fragments + unlocks)
- [ ] Notification queue system handles multiple completions
- [ ] SessionState tracks completed_quests_this_run
- [ ] End-of-run screen displays completed quests with rewards
- [ ] End-of-run shows total quest rewards (fragments + unlocks)

**Cross-Task Integration:**
- [ ] **Task 9 Synchronization:** QuestManager API documented for UI integration
- [ ] **Task 9 Synchronization:** Quest categories match UI tabs (Characters, Weapons, Tomes, Items, General, Challenges)
- [ ] **Task 9 Synchronization:** QuestConfig includes all fields needed for UI display (icon, category, rewards preview)

**Documentation & Testing:**
- [ ] autoload/CLAUDE.md updated with QuestManager patterns
- [ ] Quest definition schema documented in data/content/README.md
- [ ] Quest system documentation created in Obsidian/systems/
- [ ] CHANGELOG.md updated with quest system summary
- [ ] Commit ready: `feat(progression): implement quest system with in-game notifications and reward integration`

---

## 🎯 Success Metrics

### Functional Validation:
- Quest progress tracks correctly via SessionState signals
- Quest completion awards Rift Fragments to MetaProgression
- Quest completion unlocks items in MetaProgression
- Quest prerequisites prevent premature unlock
- Quest progress persists across game restarts

### Code Quality:
- QuestManager integrates with EventBus patterns (typed signals)
- Quest definitions follow resource-based pattern (hot-reloadable)
- No UI dependencies (backend only, UI can be added later)
- Performance impact <1ms per combat step for quest checking

### Player Experience:
- Clear progression path (complete quests → earn fragments → unlock items)
- Quest objectives feel achievable (not too grindy)
- Quest rewards feel meaningful (tangible unlocks, not just fragments)
- Quest variety across categories (combat, survival, progression)

---

## 📝 Progress Notes

### 2025-10-03 - Initial Planning
- Created task structure based on Option B (Independent Quest Pool)
- Defined 8 implementation phases (1-4 core, 5-7 advanced, 8 UI integration)
- Architecture decision: Quest-based unlocks with flexible rewards
- Estimated 2-3 weeks for full implementation (Phases 1-7)
- Backend-first approach: No UI required for initial implementation

---

**Related:** [Task 1 - Progression Refactoring](completed-tasks/1_PROGRESSION_single_session_refactoring_COMPLETED.md) | [Task 9 - Quest UI (MUST SYNC)](9_PROGRESSION_quest_ui_achievement_archive.md) | [MetaProgression System](../systems/Meta-Progression-System.md) | [SessionState Architecture](../../autoload/CLAUDE.md#progression-autoloads-task-04---megabonkror2-architecture)

---

## 🔄 Task 9 Synchronization Requirements

**IMPORTANT:** This task (backend + notifications) must stay synchronized with **Task 9 (Quest UI / Achievement Archive)**. Any changes to the following require UI updates:

### QuestConfig Structure Changes:
- Adding/removing fields → Update UI display logic
- Category enum changes → Update UI tabs
- Reward structure changes → Update reward preview columns

### QuestManager API Changes:
- New query methods → Update UI data fetching
- Signal payload changes → Update UI signal handlers
- Progress tracking changes → Update progress bars

### Quest Category Definitions:
Must match MEGABONK tabs exactly:
1. **Characters** - Character unlock quests
2. **Weapons** - Weapon unlock quests
3. **Tomes** - Tome unlock quests
4. **Items** - Item unlock quests
5. **General** - Generic progression quests
6. **Challenges** - Special achievement quests
7. **Skins** - Cosmetic unlock quests (future)

**Before implementing:** Check Task 9 to ensure UI design is compatible with backend changes.
