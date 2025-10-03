# Single-Session Run Architecture Refactoring

**Created:** 2025-09-30
**Completed:** 2025-10-01
**Status:** ✅ COMPLETED (Phases 1-9)
**Priority:** High
**Actual Effort:** 2 weeks
**Category:** 🔄 Architecture Refactoring

## Completion Summary

This task successfully refactored the progression system from character-slot-based saves to single-session runs with meta-progression. **Phases 1-9 are complete**, establishing the core architecture:

- ✅ MetaProgression autoload (Rift Fragments currency, unlocks)
- ✅ SessionState autoload (ephemeral run stats)
- ✅ LocalLeaderboard autoload (personal bests per map+tier)
- ✅ End-of-Run flow (calculate rewards → save progression)
- ✅ Item Discovery & Unlock system (MEGABONK-style 3-state progression)
- ✅ UI Template system (5 reusable menu container components)
- ✅ Old CharacterManager removed, RunManager simplified

**Remaining work extracted to new tasks:**
- Task 6: In-run item discovery flow (notifications, spawn filtering)
- Task 7: Item toggler system (disable purchased items)
- Task 8: UI progression screens polish (Option B layouts)
- Phase 10-11: Quest system + Global leaderboard (future)

## 📋 Task Description

Refactor the progression system from character-slot-based saves to single-session runs matching MEGABONK/ROR2 architecture. Simplify RunManager/CharacterManager complexity in favor of in-memory session state with permanent meta-progression unlocks only.

**Current Issues:**
- ✅ CharacterManager creates per-character save files (`user://profiles/*.tres`)
- ✅ PlayerProgression tracks level/XP per character across sessions
- ✅ Complex save/load system for mid-run persistence
- ✅ Unclear separation between session state and meta-progression

**Target Architecture:**
- ⚠️ Single-session runs (no mid-run saving, death = wipe everything)
- ⚠️ Meta-progression only: Silver currency, character unlocks, item unlocks
- ⚠️ Session state in memory only (kills, damage, level, items collected)
- ⚠️ End-of-run flow: Calculate silver → Save meta → Show stats → Leaderboard entry

## 🎯 Player Flow (Based on Design Discussion + UI Mockups)

```
Game Launch
    ↓
Main Menu
    ├── [PLAY] → Character Select → Map + Tier Selection → Arena (run starts)
    ├── [UNLOCKS] → Purchase unlocked items/characters with Rift Fragments
    ├── [QUESTS] → View active quests and progress
    ├── [SHOP] → Purchase meta-progression upgrades
    ├── [SETTINGS] (left side)
    └── [EXIT/CREDITS] (left side)

Main Menu Layout:
┌─────────────────────────────────────────────────────────┐
│ Top Left: Quest Progress (Top 4 active quests)         │
│ Top Right: Silver Balance (e.g., "Silver: 423")        │
│                                                         │
│ Left Side:          Center:         Right Side:        │
│ - Settings          - PLAY          - Leaderboard      │
│ - Exit              - UNLOCKS         * Global Top 20  │
│ - Credits           - QUESTS          * Friends Top 10 │
│                     - SHOP            * Reset Timer    │
└─────────────────────────────────────────────────────────┘

Map Selection Screen (After Character Select)
    ├── Left: Map list (Forest, etc.) with unlock conditions
    ├── Right: Selected map details
    │   ├── Tier selection (1, 2, 3) with Rift Fragment multipliers
    │   ├── Personal highscore (kills) for selected tier
    │   ├── Fastest run (time) for selected tier
    │   ├── Characters completed (icons) for selected tier
    │   └── [START RUN] button
    ↓
Arena (During Run)
    ↓ Death
End-of-Run Screen
    ├── Left Column: Damage Breakdown (abilities, DPS, levels)
    ├── Center Column: Summary (character, kills, time, level, inventory)
    ├── Right Column: Completed Quests
    ├── Bottom: [CONFIRM] + Unlocks earned + Rift Fragments gained (with tier multiplier)
    └── Leaderboard placement notification
    ↓
Return to Main Menu (session wiped)
```

## 🏗️ Architecture Design Decisions

### Decision 1: Player Flow
- **Main Menu First:** Always show main menu with [PLAY] button
- **No "Last Character" Memory:** Always show full character select screen
- **Reason:** Matches MEGABONK/ROR2, gives player moment to check quests/leaderboard

### Decision 2: Character Unlocking
- **Start:** 1-2 characters unlocked by default
- **Unlock Method:** Achievement-based (like MEGABONK)
- **Future:** Additional characters unlock via specific achievements
- **Examples:** "Kill 1000 enemies → Unlock Warrior", "Reach Stage 5 → Unlock Mage"

### Decision 3: Item Unlocking (MEGABONK-Style Discovery System)
- **Discovery Phase:** Items appear randomly in runs (not unlocked yet)
- **Purchase Phase:** After discovery, can purchase with silver to add to item pool
- **Active Phase:** Purchased items appear in future runs
- **Toggler System:** Special unlock (cost TBD) allows disabling specific items/tomes/weapons
- **Categories:** Items, Tomes, Weapons (each has separate unlock/toggle mechanics)

### Decision 4: Rift Fragments Economy
**Meta-Currency:** "Rift Fragments" (not "Silver") - mysterious crystals from the void

**Earning Rates (Simple Initial System):**
- Stage 1 completion: 10 Rift Fragments
- Stage 2 completion: 15 Rift Fragments (+50% per stage)
- Stage 3 completion: 22 Rift Fragments
- Kill count bonus: +1 Rift Fragment per 100 kills
- Survival time bonus: +1 Rift Fragment per minute
- Final Swarm survived: +10 Rift Fragments

**Unlock Costs (Placeholder - needs balancing):**
- New Character: 50-100 Rift Fragments
- New Item: 20-30 Rift Fragments
- Item Toggler Feature: 150 Rift Fragments (requires 40 item unlocks first)
- Skill Toggler Feature: 150 Rift Fragments (requires 40 skill unlocks first)
- Tome Toggler Feature: 150 Rift Fragments (requires 40 tome unlocks first)
- Extra weapon slot: 150 Rift Fragments
- Extra tome slot: 150 Rift Fragments

### Decision 5: Mid-Run Loss Handling
- **Crash/Quit:** Run lost, no silver, no stats
- **No Grace Period:** Zero tolerance for save-scumming
- **Reason:** Maintains run integrity, matches ROR2 philosophy

### Decision 6: End-of-Run Screen Layout
**Left Column: Damage Breakdown**
- List all abilities with damage dealt, DPS, ability level
- Sorted by damage contribution

**Center Column: Summary**
- Character used
- Total kills
- Time survived
- Level reached
- Inventory display:
  - Items collected
  - Tomes acquired
  - Abilities unlocked
  - Power-ups applied (specific stat increases)

**Right Column: Completed Quests**
- List of quests completed during this run
- Quest rewards earned

**Bottom Section:**
- [CONFIRM] button
- "Unlocks this run: 3" (new items/characters)
- "Rift Fragments earned: +73"
- Leaderboard placement: "Global Kills: #47"

### Decision 7: Leaderboard System
- **Current:** Local leaderboard only (stored in save file)
- **Future:** Global leaderboard (requires backend)
- **Primary Metric:** Most kills (single run)
- **Secondary Metrics:** Stage reached, survival time, highest level
- **Display:** Top 20 global, Top 10 friends, reset timer

### Decision 8: Session State Replacement
- **New Autoload:** `SessionState` (replaces RunManager complexity)
- **Responsibilities:**
  - Track session-only stats (kills, damage, time, level, XP)
  - Maintain 30Hz combat step (keep from RunManager)
  - Track items/abilities collected this run
  - Calculate silver earned at run end
- **Lifecycle:** Reset on run start, wiped on death

### Decision 9: Meta-Progression Storage
- **New Autoload:** `MetaProgression` (replaces CharacterManager)
- **Save File:** `user://meta_progression.tres` (single file)
- **Data Stored:**
  - Rift Fragments balance (int)
  - Unlocked characters (Array[String])
  - Discovered items (Array[String]) - found in runs but not purchased
  - Unlocked items (Array[String]) - purchased and appear in future runs
  - Discovered skills (Array[String]) - found in runs but not purchased
  - Unlocked skills (Array[String]) - purchased and appear in future runs
  - Discovered tomes (Array[String]) - found in runs but not purchased
  - Unlocked tomes (Array[String]) - purchased and appear in future runs
  - Achievements (Dictionary) - `{"first_boss_kill": true, ...}`
  - Toggler item enabled (bool) - special unlock (requires 40 item unlocks)
  - Toggler disabled items (Array[String]) - player-chosen exclusions
  - Toggler skill enabled (bool) - special unlock (requires 40 skill unlocks)
  - Toggler disabled skills (Array[String]) - player-chosen exclusions
  - Toggler tome enabled (bool) - special unlock (requires 40 tome unlocks)
  - Toggler disabled tomes (Array[String]) - player-chosen exclusions
- **No Career Stats:** Don't track total kills/damage across all runs
- **Personal Bests:** Separate `LocalLeaderboard` autoload

### Decision 10: Character Select Screen
**UI Elements:**
- Character portraits in 4x5 grid (20 character slots as per mockup)
- Locked characters show unlock condition ("Complete Stage 5 to unlock")
- No preview of locked character abilities (discover after unlock)
- Unlocked characters show on right panel:
  - Character name and rank
  - Passive ability description
  - Starting runs count ("0 Läufe")
  - Character-specific achievements (unlocks skins)
- Skins display at bottom (5 slots, initially locked)
- [BESTÄTIGEN] (Confirm) button to proceed to map selection

### Decision 11: Map + Tier Selection System
**Map Selection Flow:**
- After character select → Map selection screen appears
- Left panel: List of available maps (Forest initially, more unlock over time)
- Locked maps show unlock requirements (e.g., "Teleport to 2nd stage on Forest tier 2 as CL4NK")
- Right panel shows selected map details:
  - Map name, tier selection (Stufe 1/2/3)
  - Tier multipliers for Rift Fragment earnings:
    - Tier 1: 1x fragments (baseline difficulty)
    - Tier 2: 1.1x fragments (+10% difficulty, +10% rewards)
    - Tier 3: 1.2x fragments (+20% difficulty, +20% rewards)
  - Personal bests for selected tier:
    - Highscore (most kills)
    - Speedrun (fastest clear time)
  - Character completion icons (which characters beat this tier)
  - [HERAUSFORDERUNGEN] (Challenges) button (future feature)
  - [BESTÄTIGEN] (Confirm) to start run

**Tier System Design:**
- Each map has 3 tiers with increasing difficulty
- Higher tiers increase enemy stats (HP, damage, spawn rates)
- Rift Fragment multiplier incentivizes risk-taking
- Personal bests tracked separately per tier (encourages tier 1 practice before tier 3 attempts)
- Character completion tracking creates "badge collection" motivation

### Decision 12: Character Achievements & Skins
**Achievement System:**
- Each character has simple achievements (e.g., "Kill 1000 enemies", "Reach Stage 5")
- Achievements unlock skins (cosmetic only, no stat changes)
- 5 skin slots per character (1 default + 4 unlockable)
- Skins displayed on character select screen with lock icons
- **Placeholder for MVP:** Simple achievement definitions, no complex tracking yet
- **Future:** Achievement progress tracking, skin preview system

## 📊 Implementation Plan

**Approach:** Bottom-up refactoring - create new systems, migrate data, remove old systems.

**UI Strategy:** Each UI phase offers two options:
- **Option A (Recommended):** Minimal scene-based UI to test functionality (simple labels, buttons, lists)
- **Option B (Future):** Polished UI matching mockups (defer to separate UI refactor task)

**UI Implementation Approach:**
- **Use Godot MCP Tools:** Create UI scenes using MCP tools (create_scene, add_node, update_property, etc.)
- **Scene-Based Over Programmatic:** Build UI structure in .tscn files, not programmatically in GDScript
- **Rationale:** MCP tools enable rapid scene creation and visual node setup without manual .tscn editing

**Backend Priority:** Architecture (MetaProgression, SessionState, LocalLeaderboard) is the priority. Simple functional UI proves the system works. Full visual design can be tackled in a dedicated UI consistency task across the entire game.

### Phase 1: Create New Meta-Progression System (2-3 sessions)
**Goal:** Replace CharacterManager with MetaProgression autoload
**Test:** Can save/load Rift Fragments and unlocks correctly

**⏸️ CHECKPOINT:** Review MetaProgression data structure and save/load implementation before proceeding

- [ ] Create `MetaProgression` autoload (scripts/autoload/MetaProgression.gd)
- [ ] Define meta-progression data structure:
  - [ ] `rift_fragments: int` - currency balance
  - [ ] `unlocked_characters: Array[String]` - character IDs
  - [ ] `unlocked_maps: Array[String]` - map IDs (e.g., "forest", "desert")
  - [ ] `discovered_items: Array[String]` - seen but not purchased
  - [ ] `unlocked_items: Array[String]` - purchased and active
  - [ ] `discovered_skills: Array[String]` - seen but not purchased
  - [ ] `unlocked_skills: Array[String]` - purchased and active
  - [ ] `discovered_tomes: Array[String]` - seen but not purchased
  - [ ] `unlocked_tomes: Array[String]` - purchased and active
  - [ ] `achievements: Dictionary` - global achievement flags (e.g., {"first_boss_kill": true})
  - [ ] `character_achievements: Dictionary` - per-character achievements (e.g., {"fuchs": {"kills_1000": true, ...}})
  - [ ] `unlocked_skins: Dictionary` - per-character skin unlocks (e.g., {"fuchs": ["default", "blue", ...], ...})
  - [ ] `character_runs: Dictionary` - run count per character (e.g., {"fuchs": 15, ...})
  - [ ] `toggler_item_enabled: bool` - can disable items (requires 40 item unlocks)
  - [ ] `toggler_disabled_items: Array[String]` - excluded items
  - [ ] `toggler_skill_enabled: bool` - can disable skills (requires 40 skill unlocks)
  - [ ] `toggler_disabled_skills: Array[String]` - excluded skills
  - [ ] `toggler_tome_enabled: bool` - can disable tomes (requires 40 tome unlocks)
  - [ ] `toggler_disabled_tomes: Array[String]` - excluded tomes
- [ ] Implement save/load methods:
  - [ ] `save()` → writes to `user://meta_progression.tres`
  - [ ] `load()` → reads from disk on game launch
  - [ ] `reset()` → creates fresh save (first time player)
- [ ] Add Rift Fragments transaction methods:
  - [ ] `earn_rift_fragments(amount: int)` - add currency from run
  - [ ] `spend_rift_fragments(amount: int) -> bool` - purchase unlock
  - [ ] `can_afford(amount: int) -> bool` - check balance
- [ ] Add unlock methods (generic for all categories):
  - [ ] `unlock_character(id: String)` - add to unlocked_characters
  - [ ] `is_character_unlocked(id: String) -> bool` - check status
  - [ ] `discover_item(category: String, id: String)` - add to discovered_{category}
  - [ ] `unlock_item(category: String, id: String)` - move to unlocked_{category}
  - [ ] `is_item_unlocked(category: String, id: String) -> bool` - check status
  - [ ] `enable_toggler(category: String)` - unlock toggler for category
  - [ ] `toggle_item(category: String, id: String, enabled: bool)` - add/remove from disabled list
- [ ] Add EventBus signals:
  - [ ] `meta_progression_loaded` - fired after load
  - [ ] `rift_fragments_changed(new_balance: int)` - UI update
  - [ ] `item_unlocked(category: String, item_id: String)` - notification
  - [ ] `character_unlocked(character_id: String)` - notification
  - [ ] `toggler_unlocked(category: String)` - notification
- [ ] Test with isolated scene (create `tests/MetaProgression_Isolated.tscn`)

**Deliverable:** MetaProgression autoload working with save/load

---

### Phase 2: Create SessionState System (2-3 sessions)
**Goal:** Migrate stats tracking from RunManager to SessionState
**Test:** Stats track correctly during run, reset on death

**⏸️ CHECKPOINT:** Review SessionState structure and RunManager migration plan before implementing

**⚠️ Current State:** RunManager handles TWO responsibilities:
1. 30Hz fixed-step timing (KEEP - core engine feature)
2. Run statistics tracking (MIGRATE to SessionState)

**Migration Source:** See `autoload/RunManager.gd` for current implementation:
- `stats: Dictionary` - enemies_killed, total_damage_dealt, xp_gained, melee_damage_add, melee_damage_mult, etc.
- `_on_enemy_killed()` - kill tracking
- `_on_damage_dealt()` - damage tracking
- `_on_xp_gained()` - XP tracking
- **MeleeSystem Integration:** `_calculate_damage()`, `_get_effective_attack_speed()` read from RunManager.stats
- All marked with "TODO: Task 04 Phase 2 - Move to SessionState"

**Implementation Steps:**
- [ ] Create `SessionState` autoload (scripts/autoload/SessionState.gd)
- [ ] Define session-only state:
  - [ ] `current_level: int` - player level (starts at 1)
  - [ ] `current_xp: float` - XP progress (resets each run)
  - [ ] `kills: int` - enemy kill count (migrate from RunManager.stats["enemies_killed"])
  - [ ] `damage_dealt: float` - total damage output (migrate from RunManager.stats["total_damage_dealt"])
  - [ ] `time_survived: float` - seconds alive
  - [ ] `stage_reached: int` - highest stage this run
  - [ ] `current_character: String` - selected character ID
  - [ ] `current_map: String` - selected map ID (e.g., "forest")
  - [ ] `current_tier: int` - selected tier (1, 2, or 3)
  - [ ] `collected_items: Array[String]` - items found this run
  - [ ] `chosen_skills: Array[String]` - skills selected during run (eligible for unlock after)
  - [ ] `damage_breakdown: Dictionary` - per-ability stats: `{"bone": {"level": 2, "total_damage": 2016, "hit_count": 180}, ...}`
  - [ ] `player_modifiers: Dictionary` - additive/multiplicative stats (melee_damage_add, melee_damage_mult, etc.)
  - [ ] `run_start_time: float` - timestamp when run started (for time_survived calculation)
  - [ ] **Arena Progression Integration (see STAGE_PROGRESSION_VISION.md):**
    - [ ] `boss_killed: bool` - tracks if boss was defeated before timer expired
    - [ ] `boss_kill_time: float` - when boss was killed (e.g., 9:32 = 9.53 minutes)
    - [ ] `final_swarm_entered: bool` - tracks if Final Swarm was reached (10:00 timer)
    - [ ] `final_swarm_survival_time: float` - seconds survived in Final Swarm (bonus rewards)
    - [ ] `difficulty_shrines_activated: int` - count of voluntary difficulty increases
- [ ] Migrate stat tracking from RunManager:
  - [ ] Copy `_on_enemy_killed()` from RunManager → SessionState
  - [ ] Copy `_on_damage_dealt()` from RunManager → SessionState
  - [ ] Copy `_on_xp_gained()` from RunManager → SessionState
  - [ ] Copy EventBus signal connections from RunManager._ready()
  - [ ] Remove stat tracking from RunManager after migration
- [ ] Add lifecycle methods:
  - [ ] `start_run(character_id: String, map_id: String, tier: int)` - reset and begin
  - [ ] `end_run()` - calculate final stats and Rift Fragments (apply tier multiplier)
  - [ ] `reset()` - wipe all session data
- [ ] Add stat tracking methods:
  - [ ] `add_kill()` - increment kills
  - [ ] `add_damage(ability_id: String, amount: float, ability_level: int)` - track damage and update damage_breakdown
  - [ ] `add_xp(amount: float)` - handle leveling (emit level_up signal)
  - [ ] `collect_item(item_id: String)` - add to collected_items
  - [ ] `choose_skill(skill_id: String)` - add to chosen_skills (player picked during run)
  - [ ] `apply_modifier(key: String, value: float)` - update player_modifiers for combat systems
  - [ ] `get_dps_for_ability(ability_id: String) -> float` - calculate DPS: total_damage / time_survived
- [ ] Add Rift Fragments calculation:
  - [ ] `calculate_rift_fragments_earned() -> int` - based on stage, kills, time
  - [ ] Formula: base (10 per stage) + bonuses (kills/time)
- [ ] Add EventBus signals:
  - [ ] `run_started(character_id: String)` - notify systems
  - [ ] `run_ended(stats: Dictionary)` - pass final stats
  - [ ] `level_up(new_level: int)` - player leveled up
- [ ] Test with isolated scene (extend `tests/StageTimer_Isolated.tscn`)

**Post-Migration Cleanup:**
- [ ] Update MeleeSystem to use SessionState:
  - [ ] Replace `RunManager.stats.get("melee_damage_add", 0.0)` → `SessionState.player_modifiers.get("melee_damage_add", 0.0)`
  - [ ] Replace `RunManager.stats.get("melee_damage_mult", 1.0)` → `SessionState.player_modifiers.get("melee_damage_mult", 1.0)`
  - [ ] Update `_get_effective_attack_speed()`, `_get_effective_range()`, `_get_effective_cone_angle()`, `_get_effective_knockback_distance()`
  - [ ] Test melee combat still works with new SessionState modifiers
- [ ] Remove stat tracking from RunManager:
  - [ ] Delete `stats: Dictionary` variable
  - [ ] Delete `_on_enemy_killed()`, `_on_damage_dealt()`, `_on_xp_gained()` methods
  - [ ] Delete EventBus signal connections for stat tracking
  - [ ] Delete `_load_player_stats()`, `_try_load_player_stats()` methods
  - [ ] Remove BalanceDB.balance_reloaded connection for stats
  - [ ] Delete `_exit_tree()` cleanup (no longer needed)
  - [ ] Keep: COMBAT_DT, _accumulator, _process(), EventBus.combat_step emission, _seed_rng()
- [ ] Remove deprecated API shims from PlayerProgression:
  - [ ] Delete `load_from_profile()` method (deprecated shim)
  - [ ] Delete `export_state()` method (deprecated shim)
  - [ ] Delete `has_unlock()` method (deprecated shim - replaced by MetaProgression)
  - [ ] All marked with "TODO: Remove these shims in Task 04 Phase 2"
  - [ ] Verify no remaining callers exist (search codebase)
- [ ] Optionally rename RunManager → CombatClock (if desired)
- [ ] Update documentation: autoload/CLAUDE.md with SessionState patterns

**Deliverable:** SessionState tracks run stats + player modifiers, MeleeSystem uses SessionState, RunManager only handles 30Hz timing, deprecated shims removed

---

### Phase 3: Create LocalLeaderboard System (1-2 sessions)
**Goal:** Track personal bests separate from meta-progression
**Test:** Top 10 runs displayed correctly

**⏸️ CHECKPOINT:** Review LocalLeaderboard data structure before implementing

- [ ] Create `LocalLeaderboard` autoload (scripts/autoload/LocalLeaderboard.gd)
- [ ] Define leaderboard entry structure:
  ```gdscript
  class LeaderboardEntry:
      var character_id: String
      var map_id: String           # NEW: Which map was played
      var tier: int                # NEW: Which tier (1, 2, or 3)
      var kills: int
      var stage_reached: int
      var time_survived: float
      var level_reached: int
      var timestamp: int  # Unix timestamp
  ```
- [ ] Implement storage (per map + tier):
  - [ ] `entries: Dictionary` - nested: `{"forest": {"1": [Entry, ...], "2": [...], "3": [...]}, ...}`
  - [ ] `save()` → writes to `user://local_leaderboard.tres`
  - [ ] `load()` → reads from disk
- [ ] Add entry management:
  - [ ] `add_entry(stats: Dictionary) -> int` - returns placement (1-20 or -1)
  - [ ] `get_top_entries(map_id: String, tier: int, count: int) -> Array[LeaderboardEntry]` - retrieve top N for specific map+tier
  - [ ] `get_placement(map_id: String, tier: int, kills: int) -> int` - calculate where entry would rank
  - [ ] `_sort_entries()` - sort by kills (descending)
- [ ] Add query methods (per map + tier):
  - [ ] `get_personal_best_kills(map_id: String, tier: int) -> int`
  - [ ] `get_fastest_time(map_id: String, tier: int) -> float`
  - [ ] `get_completed_characters(map_id: String, tier: int) -> Array[String]` - character IDs that completed this tier
- [ ] Add EventBus signal:
  - [ ] `new_personal_best(entry: LeaderboardEntry)` - UI notification
- [ ] Test with mock data

**Deliverable:** LocalLeaderboard stores and retrieves top 20 runs

---

### Phase 4: Create End-of-Run Screen (3-4 sessions)
**Goal:** Display full stats breakdown, calculate rewards, save progression
**Test:** Can view detailed stats and return to main menu

**⏸️ CHECKPOINT:** Review three-column end-of-run layout before implementing

**⚠️ UI SCOPE NOTE:** Can implement as simple debug panel first, polish UI in separate task later
**⚠️ Core functionality:** Calculate rewards, save progression, return to menu (UI is secondary)

- [ ] **Option A: Minimal Scene-Based Panel (Recommended for MVP)**
  - [ ] Use MCP Godot tools to create `scenes/ui/EndOfRunDebug.tscn`:
    - [ ] `create_scene("res://scenes/ui/EndOfRunDebug.tscn", "Control", "EndOfRunDebug")`
    - [ ] Add VBoxContainer for layout
    - [ ] Add Label nodes for stats (Character, Kills, Time, Level, Stage Reached)
    - [ ] Add Label for Boss killed status and time
    - [ ] Add Label for Final Swarm survival time (if applicable)
    - [ ] Add Label for Rift Fragments earned (with breakdown)
    - [ ] Add Button node for [CONTINUE] → return to main menu
  - [ ] Attach `EndOfRun.gd` script to root node
  - [ ] **Skip detailed UI** (damage breakdown, inventory grid, visual polish)
  - [ ] Focus on backend: reward calculation, save progression, data flow

- [ ] **Option B: Full Three-Column Layout (Defer to Separate UI Task)**
  - [ ] Left column: DAMAGE breakdown (ability list, DMG/DPS columns)
  - [ ] Center column: SUMMARY (character portrait, inventory grid, stats)
  - [ ] Right column: QUESTS (placeholder for future)
  - [ ] Bottom section: Rift Fragments notification, CONFIRM button
  - [ ] **Recommendation:** Implement Option A first, upgrade to B in UI refactor task
- [ ] Implement `EndOfRun.gd` script:
  - [ ] `show_run_results(stats: Dictionary)` - populate all columns
  - [ ] `_calculate_rewards()` - Rift Fragments earned with:
    - [ ] Base fragments (per stage completion)
    - [ ] Tier multiplier (1x/1.1x/1.2x)
    - [ ] Final Swarm survival bonus (if applicable)
  - [ ] `_check_new_unlocks()` - discovered items/skills (add to MetaProgression.discovered_*)
  - [ ] `_check_character_achievements()` - check if run unlocked character achievements (kills, stages, etc.)
  - [ ] `_save_progression()` - MetaProgression.save(), LocalLeaderboard.save()
  - [ ] `_on_confirm_pressed()` - return to main menu
- [ ] Wire to SessionState:
  - [ ] Connect to `EventBus.run_ended` signal
  - [ ] Receive final stats from SessionState (damage_breakdown, kills, time, etc.)
- [ ] Skip for MVP (polish phase):
  - [ ] Fade-in animations
  - [ ] Counter animations (kills counting up)
  - [ ] Sound effects for Rift Fragments earned
  - [ ] Leaderboard placement notification (future)

**Deliverable (Option A):** Functional end-of-run flow with reward calculation and progression save (simple debug UI)
**Deliverable (Option B):** Full three-column end-of-run screen matching mockup (defer to separate UI task)

---

### Phase 5: Update Main Menu - SIMPLIFIED (1-2 sessions)
**Goal:** Add Rift Fragments display and navigation to Character Select
**Test:** Can see Rift Fragments and click Play to start run

**⏸️ CHECKPOINT:** Review main menu changes before implementing (defer full redesign to future UI task)

**⚠️ SCOPE REDUCTION:** Minimal changes for MVP, full redesign in separate future task

- [ ] Update `scenes/ui/MainMenu.tscn` with minimal changes:
  - [ ] Add Rift Fragments display (top right corner)
  - [ ] Wire [PLAY] button to Character Select (if exists) or directly to arena
  - [ ] Keep existing menu structure unchanged
- [ ] Connect Rift Fragments display:
  - [ ] Connect to MetaProgression.rift_fragments_changed signal
  - [ ] Update display when fragments change
- [ ] Skip for MVP (defer to future UI refactor):
  - [ ] Quest progress widget (no quest system yet)
  - [ ] Leaderboard widget (future)
  - [ ] UNLOCKS/QUESTS/SHOP buttons (future)
  - [ ] Full layout redesign (future)
  - [ ] Background music and ambient effects (future)

**Deliverable:** Main menu shows Rift Fragments and navigates to character select (defers full redesign to future UI task)

---

### Phase 6: Create Character Select Scene - SIMPLIFIED (1-2 sessions)
**Goal:** Select character and start run
**Test:** Can select character and start run

**⏸️ CHECKPOINT:** Review character select approach before implementing (defer full UI to future task)

**⚠️ UI SCOPE NOTE:** Minimal functional UI first, visual polish in separate UI task
**⚠️ Core functionality:** Query unlocked characters, handle selection, navigate to map select

- [ ] **Option A: Simple Scene-Based List (Recommended for MVP)**
  - [ ] Use MCP Godot tools to create `scenes/ui/CharacterSelectDebug.tscn`:
    - [ ] `create_scene("res://scenes/ui/CharacterSelectDebug.tscn", "Control", "CharacterSelectDebug")`
    - [ ] Add VBoxContainer for layout
    - [ ] Add Label for title ("Select Character")
    - [ ] Add ScrollContainer with VBoxContainer for character buttons list
    - [ ] Add Button for [BACK] → Return to main menu
  - [ ] Attach script to populate buttons dynamically:
    - [ ] Query MetaProgression for unlocked_characters
    - [ ] Create Button nodes for each character (just names, no portraits)
    - [ ] Locked characters show as disabled buttons with text label
    - [ ] Click button → SessionState.current_character = id → Go to map select

- [ ] **Option B: Grid Layout with Portraits (Defer to Separate UI Task)**
  - [ ] 4x5 character grid matching mockup
  - [ ] Character portraits, skins display, info panel
  - [ ] Animations, selection highlights
  - [ ] **Recommendation:** Implement Option A first, upgrade to B in UI refactor

**Deliverable (Option A):** Functional character selection flow (simple list UI)
**Deliverable (Option B):** Full character select screen with portraits and skins (defer to UI task)

---

### Phase 6b: Create Map + Tier Selection Screen (2-3 sessions)
**Goal:** Display map selection with tier choices and personal bests
**Test:** Can select map+tier and start run with correct difficulty/multiplier

**⏸️ CHECKPOINT:** Review map selection UI structure before implementing

**⚠️ UI SCOPE NOTE:** Can implement as simple dropdown/buttons first, polish layout in separate UI task
**⚠️ Core functionality:** Select map, select tier, display multipliers, start run

- [ ] **Option A: Simple Scene-Based Dropdown UI (Recommended for MVP)**
  - [ ] Use MCP Godot tools to create `scenes/ui/MapSelectionDebug.tscn`:
    - [ ] `create_scene("res://scenes/ui/MapSelectionDebug.tscn", "Control", "MapSelectionDebug")`
    - [ ] Add VBoxContainer for layout
    - [ ] Add Label for title ("Select Map & Tier")
    - [ ] Add HBoxContainer with Label + OptionButton for map selection
    - [ ] Add HBoxContainer with Label + three Button nodes for tier selection (1, 2, 3)
    - [ ] Add Label for personal best: "Best: [kills] kills"
    - [ ] Add HBoxContainer with [START RUN] and [BACK] buttons
  - [ ] Attach script to handle:
    - [ ] Query MetaProgression.unlocked_maps → populate OptionButton
    - [ ] Display tier multipliers next to tier buttons
    - [ ] Query LocalLeaderboard for personal bests
    - [ ] [START RUN] → SessionState.start_run(char, map, tier) → go_to_arena()
    - [ ] [BACK] → Return to character select
  - [ ] **Skip visual polish** (map thumbnails, character icons, detailed stats)

- [ ] **Option B: Two-Panel Layout Matching Mockup (Defer to Separate UI Task)**
  - [ ] Left panel: Map list with thumbnails
  - [ ] Right panel: Tier selection, personal bests, character completion icons
  - [ ] Challenge button, detailed tier descriptions
  - [ ] **Recommendation:** Implement Option A first, upgrade to B in UI refactor

**Deliverable (Option A):** Functional map+tier selection flow (simple dropdown UI)
**Deliverable (Option B):** Full two-panel layout matching mockup (defer to UI task)

---

### Phase 7: Migrate Existing Systems (2-3 sessions)
**Goal:** Update Arena, DamageSystem, etc. to use SessionState for progression tracking
**Test:** Full run works end-to-end (char select → arena → death → end screen)

**⏸️ CHECKPOINT:** Review system migration plan and verify all SessionState integrations before cleanup

**NOTE:** Tier difficulty scaling and arena progression mechanics (boss spawning, Final Swarm) are handled by Task 2 (COMBAT_map_level_difficulty_scaling_integration.md). This phase focuses on SESSION/META progression integration only.

- [ ] Update Arena.gd:
  - [ ] Remove references to old RunManager stats
  - [ ] Connect to SessionState for stat tracking (kills, damage, time)
  - [ ] Remove character save/load logic
  - [ ] **SessionState Integration Only:**
    - [ ] Read SessionState.current_tier for UI display (actual scaling in Task 2)
    - [ ] Track SessionState.boss_killed when boss dies (progression mechanics in Task 2)
    - [ ] Track SessionState.boss_kill_time timestamp
    - [ ] Track SessionState.final_swarm_entered when triggered (mechanics in Task 2)
    - [ ] Track SessionState.final_swarm_survival_time
    - [ ] Track SessionState.difficulty_shrines_activated (shrine system in Task 2)
- [ ] Update DamageSystem.gd:
  - [ ] Emit damage to SessionState.add_damage()
  - [ ] Track kills via SessionState.add_kill()
- [ ] Update PlayerProgression.gd:
  - [ ] Use SessionState for level/XP (not persistent)
  - [ ] Remove per-character progression logic
  - [ ] Connect to SessionState.level_up signal
- [ ] Update death handling:
  - [ ] On player death → SessionState.end_run()
  - [ ] Calculate Rift Fragments with tier multiplier (tier 1: 1x, tier 2: 1.1x, tier 3: 1.2x)
  - [ ] Trigger EventBus.run_ended with stats
  - [ ] Show EndOfRun scene
- [ ] Update quest system (if exists):
  - [ ] Track quest progress via SessionState events
  - [ ] Check quest completion in SessionState.end_run()
- [ ] Update item collection:
  - [ ] On item drop → SessionState.collect_item(item_id)
  - [ ] Check MetaProgression.unlocked_items for availability
  - [ ] Emit MetaProgression.discover_item() for new items

**Deliverable:** Full run loop works (select → play → die → rewards → menu)

---

### Phase 8: Remove Old Systems (1-2 sessions)
**Goal:** Clean up CharacterManager, old RunManager code
**Test:** Game still works without old files

**⏸️ CHECKPOINT:** Verify game runs successfully with new systems before deleting old code

- [x] Remove CharacterManager autoload:
  - [x] Delete `autoload/CharacterManager.gd` (removed in Phase 1)
  - [x] Remove from project.godot autoload section (removed in Phase 1)
  - [x] Remove references in other scripts (cleaned up in Phases 1-6)
- [x] Add leaderboard display to MainMenu:
  - [x] Add LeaderboardPanel MarginContainer on right side (300x600 panel)
  - [x] Display personal bests for each character (highest kill count across all maps/tiers)
  - [x] Update display when new runs complete (EventBus.leaderboard_updated signal)
- [x] Simplify RunManager:
  - [x] Remove save/load logic (already done in Phase 2)
  - [x] Remove per-character state tracking (already done in Phase 2)
  - [x] Keep only 30Hz combat step + RNG seeding (verified complete)
  - [x] Consider renaming to `CombatClock` (decided to keep RunManager name - still manages run timing + seeding)
- [x] Delete old save files:
  - [x] Remove `user://profiles/` directory handling (no active code references found)
  - [x] Keep only `user://meta_progression.tres` (MetaProgression autoload)
  - [x] Keep only `user://local_leaderboard.tres` (LocalLeaderboard autoload)
- [x] Update CharacterProfile resource:
  - [x] Remove if no longer needed (moved to _DELETED, removed leftover .uid file)
  - [x] Or simplify to just character definition (not save data) (no longer used)
- [x] Update autoload/CLAUDE.md:
  - [x] Document new SessionState autoload (added with full API examples)
  - [x] Document new MetaProgression autoload (added with currency management patterns)
  - [x] Document new LocalLeaderboard autoload (added with personal best tracking)
  - [x] Remove CharacterManager patterns (documented removal, added architecture notes)

**Deliverable:** Codebase cleaned of old progression system ✅

---

### Phase 9: Item Discovery & Unlock System ✅ COMPLETED (3-4 sessions)
**Goal:** MEGABONK-style item discovery and purchase flow
**Test:** Items discovered in run can be purchased in shop

**✅ Completed:**
- [x] Add item metadata resource:
  - [x] Create `ItemMetadata.gd` Resource class (scripts/resources/)
  - [x] Define: item_id, display_name, description, unlock_cost, rarity, stat_summary
  - [x] Create `/data/content/items/*.tres` files (cheese, clover, feather, lucky_coin, rabbits_foot)
  - [x] Create `/data/content/tomes/*.tres` files (damage_tome, agility_tome)
  - [x] Create `/data/content/skills/*.tres` files (dash)
- [x] Create Unlocks Shop UI integrated into MainMenu:
  - [x] Added 4th screen to MainMenu.tscn (UnlocksShopContainer)
  - [x] Changed to 3-state item progression (UNDISCOVERED → DISCOVERED → UNLOCKED)
  - [x] Icon-based shop cards (80x80px) with state visualization:
    - [x] UNLOCKED: Full color icon with rarity tint
    - [x] UNDISCOVERED: Black silhouette with ❓ fallback
    - [x] DISCOVERED: Greyscale with 90% dim overlay + cost display
  - [x] Grid layout (8 columns) for compact item display
  - [x] Details panel (70/30 split) shows:
    - [x] Left: Name, description, stats, flavor text
    - [x] Right: Quest progress (undiscovered) OR unlock button (discovered)
  - [x] Category tabs: [ITEMS] [TOMES] [SKILLS]
  - [x] Dynamic item loading from `/data/content/{category}/*.tres`
  - [x] Rarity system (Common, Uncommon, Rare, Epic, Legendary) with color coding
- [x] Implement unlock purchase:
  - [x] Check MetaProgression.can_afford(cost)
  - [x] On purchase: MetaProgression.spend_rift_fragments() + unlock_item()
  - [x] Move from discovered_items to unlocked_items
  - [x] Deduct Rift Fragments
  - [x] Shop refreshes immediately after purchase
  - [x] Signal-based updates (EventBus.item_unlocked, rift_fragments_changed)
- [x] Add persistent UI improvements:
  - [x] Persistent Rift Fragments display (top-right, always visible)
  - [x] Mystical portal background image
  - [x] Semi-transparent dark backgrounds on all containers (CharSelect, MapSelect, Shop)
  - [x] Proper padding/margins via MarginContainer
  - [x] MainMenu leaderboard panel showing personal bests per character
- [x] Add debug commands for testing:
  - [x] `discover_item <category> <item_id>` - Simulate finding item
  - [x] `give_fragments <amount>` - Award Rift Fragments
  - [x] `progression_info` - Show current state
- [x] Create testing guide: Obsidian/systems/Item-Discovery-Testing-Guide.md

**🎨 UI Architecture Enhancement:**
- [x] Created 5 reusable menu container templates:
  - [x] `BaseMenuContainer` - Border + background foundation
  - [x] `TitledMenuContainer` - Adds title section
  - [x] `GridMenuContainer` - Adds scrollable grid
  - [x] `GridWithDetailsContainer` - Adds toggleable details panel
  - [x] `TabbedGridContainer` - Adds tab navigation
- [x] All templates have consistent styling (dark blue bg, 8px corners, 20px padding)
- [x] Full @export property control for customization
- [x] Comprehensive usage guide: `scenes/ui/components/MENU_CONTAINERS_GUIDE.md`
- [x] Refactor plan created: `Obsidian/03-tasks/UI_CONTAINER_SCENES_REFACTOR.md`
  - [x] Details 8 container scenes to build (CharacterSelect, MapSelect, etc.)
  - [x] Complete integration strategy for MainMenu
  - [x] Migration from manual Panel/VBoxContainer to template instances

**⏭️ Deferred to Future Phases:**
- [ ] Create item discovery flow:
  - [ ] When item drops in run, check if already unlocked
  - [ ] If new: MetaProgression.discover_item(item_id)
  - [ ] Show "New Item Discovered!" notification in-game
  - [ ] Item appears in end-of-run summary (ResultsScreen)
- [ ] Update item spawning in runs:
  - [ ] Only spawn items from MetaProgression.unlocked_items pool
  - [ ] Unlocked items appear in RNG drop tables
- [ ] Create Toggler system (requires 40 unlocks):
  - [ ] Add "Toggler" unlock in shop (cost TBD)
  - [ ] When toggler_enabled = true, show [DISABLE] buttons in shop
  - [ ] Disabled items added to toggler_disabled_{category}
  - [ ] Disabled items excluded from drop tables
  - [ ] Categories: Items, Tomes, Skills (separate toggle lists)

**Deliverable:** Full item discovery → purchase → unlock flow working

---

### Phase 10: Quest System Integration (3-4 sessions) - FUTURE
**Goal:** Quest tracking and rewards
**Note:** Deferred for now, placeholder UI exists

- [ ] Define quest structure (future task)
- [ ] Implement quest progress tracking
- [ ] Add quest completion rewards (silver, unlocks)
- [ ] Wire to main menu quest widget
- [ ] Create quest log scene

**Deliverable:** Quest system functional (future)

---

### Phase 11: Global Leaderboard (Backend Required) - FUTURE
**Goal:** Online leaderboard integration
**Note:** Start with local, add global later

- [ ] Design backend API (future task)
- [ ] Implement leaderboard submission
- [ ] Add friends list integration
- [ ] Update leaderboard widget to query online

**Deliverable:** Global leaderboard working (future)

---

## 🔗 Related Files

### Will Remove:
- [ ] `autoload/CharacterManager.gd` - replaced by MetaProgression
- [ ] `user://profiles/*.tres` - no more per-character saves
- [ ] Complex RunManager save/load logic

### Will Create:
- [ ] `autoload/MetaProgression.gd` - permanent unlocks and silver
- [ ] `autoload/SessionState.gd` - session-only run stats
- [ ] `autoload/LocalLeaderboard.gd` - personal best tracking
- [ ] `scenes/ui/EndOfRun.tscn` - post-death stats screen
- [ ] `scenes/ui/CharacterSelect.tscn` - character selection
- [ ] `scenes/ui/UnlocksShop.tscn` - item unlock shop
- [ ] `user://meta_progression.tres` - single save file
- [ ] `user://local_leaderboard.tres` - top 20 runs

### Will Modify:
- [ ] `scenes/ui/MainMenu.tscn` - new layout with quest/leaderboard widgets
- [ ] `scenes/arena/Arena.tscn` - remove old progression hooks
- [ ] `autoload/RunManager.gd` - simplify to 30Hz timer only
- [ ] `autoload/PlayerProgression.gd` - use SessionState not persistent
- [ ] `autoload/EventBus.gd` - add new signals (run_started, run_ended, etc.)
- [ ] `autoload/CLAUDE.md` - document new architecture

## 📝 Progress Notes

### 2025-10-01 - Phase 9 Completion + UI Template System
**Shop Foundation & Leaderboard Integration:**
- ✅ Completed MEGABONK-style 3-state item progression system
- ✅ Icon-based shop with state visualization (black silhouette → greyscale → full color)
- ✅ 70/30 split details panel with quest/unlock context switching
- ✅ Dynamic item loading from `/data/content/{category}/*.tres` files
- ✅ Rarity system implementation with color coding
- ✅ Persistent Rift Fragments display (top-right, always visible across all menu states)
- ✅ Mystical portal background with semi-transparent container backgrounds
- ✅ MainMenu leaderboard panel showing personal bests per character
- ✅ Full signal-based updates (EventBus integration)

**UI Architecture Enhancement:**
- ✅ Created 5 reusable menu container templates (Base → Titled → Grid → GridWithDetails → Tabbed)
- ✅ Established consistent styling system (dark blue bg, 8px corners, 20px padding)
- ✅ Comprehensive template usage guide created (`MENU_CONTAINERS_GUIDE.md`)
- ✅ Complete refactor plan documented (`UI_CONTAINER_SCENES_REFACTOR.md`)
  - 8 container scenes to build (CharacterSelect, MapSelect, UnlocksShop, etc.)
  - Integration strategy for migrating MainMenu to template instances
  - End-to-end container replacement workflow

**Next Session Priority:**
- Option 1: Migrate existing MainMenu containers to use new template system
- Option 2: Continue with in-run item discovery flow (notifications, end-of-run display)
- Option 3: Implement Toggler system (requires 40 unlocks first)

### 2025-09-30 - Design Discussion & Planning
- Conducted Q&A session to clarify architecture decisions
- Confirmed main menu layout (quest widget, leaderboard, silver display)
- Confirmed item unlock system (MEGABONK discovery → purchase flow)
- Confirmed leaderboard: local now, global later
- Confirmed end-of-run screen three-column layout
- Confirmed character select shows unlock conditions
- Created implementation plan with 11 phases
- Estimated 2-3 weeks total effort

## 🚨 Risks & Considerations

### Data Migration Risk (MEDIUM)
- **Issue:** Existing players have character saves that will be obsolete
- **Mitigation:**
  - Create migration script to convert old saves to MetaProgression format
  - Extract silver equivalent from old progression
  - Mark all old-save characters as unlocked
  - Communicate change to players (if already released)

### Save File Corruption Risk (LOW)
- **Issue:** Single save file = total loss if corrupted
- **Mitigation:**
  - Implement automatic backups (keep last 3 saves)
  - Validate save file on load (detect corruption early)
  - Graceful fallback to fresh save if corrupted

### Balance Risk (HIGH)
- **Issue:** Silver economy needs extensive playtesting
- **Mitigation:**
  - Start conservative (slow unlocks)
  - Monitor player progression rates
  - Adjust via BalanceDB hot-reload
  - Add CheatSystem commands for testing (give_silver, unlock_all)

### Scope Creep Risk (MEDIUM)
- **Issue:** Quest system and global leaderboard add complexity
- **Mitigation:**
  - Defer to Phases 10-11 (clearly marked FUTURE)
  - Focus on Phases 1-9 for MVP
  - Placeholder UI prevents future rework

## ✅ Definition of Done

### Completed (Phases 1-9):
- [x] MetaProgression autoload saves/loads correctly
- [x] SessionState tracks run stats (30Hz combat step moved to RunManager)
- [x] LocalLeaderboard stores top 20 runs (per map+tier)
- [x] End-of-run screen displays stats (Option A - minimal debug UI)
- [x] Main menu shows leaderboard and Rift Fragments balance
- [x] Character select shows lock/unlock states (Option A - simple list)
- [x] Full run loop works: char select → arena → death → end screen → menu
- [x] Item discovery → purchase flow working (shop with 3-state progression)
- [x] Old CharacterManager removed, no more per-character saves
- [x] Single save file: `user://meta_progression.tres`
- [x] Documentation updated: autoload/CLAUDE.md with new patterns
- [x] UI template system created (5 reusable menu containers)

### Deferred to New Tasks:
- [ ] In-run item discovery flow (Task 6: notifications, spawn filtering)
- [ ] Toggler system functional (Task 7: disable purchased items)
- [ ] UI polish - Option B layouts (Task 8: three-column EndOfRun, grid CharacterSelect, two-panel MapSelect)
- [ ] Quest system integration (Phase 10 - future task)
- [ ] Global leaderboard (Phase 11 - future task)

## 🎯 Success Metrics

### Functional Validation:
- Can complete full run from character select to end screen
- Silver balance persists across game restarts
- Leaderboard shows top 20 runs correctly
- Unlocked items appear in future runs
- Discovered items show in shop after run

### Code Quality:
- No references to old CharacterManager remain
- SessionState clearly separated from MetaProgression
- All progression state either ephemeral (SessionState) or persistent (MetaProgression)
- No mid-run save/load logic exists

### Player Experience:
- Clear progression path (earn silver → unlock items → stronger runs)
- End-of-run screen provides satisfying feedback
- Leaderboard placement motivates replayability
- Item discovery creates "unlock collection" motivation

---

## 📦 Task 04a Cleanup - _DELETED/ Folder Reference

**Context:** Task 04a removed the old character-slot-based progression system. All deleted code was backed up to `_DELETED/` folder for reference during Task 04 rebuild.

**_DELETED/ Folder Contents:**
```
_DELETED/
├── autoload/
│   ├── CharacterManager.gd.backup       (Full old implementation - save/load patterns)
│   ├── PlayerProgression.gd.backup      (Pre-simplification version - XP curve logic)
│   └── RunManager.gd.backup             (Pre-simplification version - stats tracking)
├── data/core/
│   └── progression-xp-curve.tres        (Complex XP curve resource)
└── scripts/resources/
    ├── CharacterProfile.gd              (Character save data structure)
    ├── CharacterTypeDict.gd             (Character type definitions)
    └── PlayerXPCurve.gd                 (XP curve resource class)
```

**⚠️ Retention Policy:**
- **Keep until:** Phase 1-2 complete (MetaProgression + SessionState implemented)
- **Purpose:** Reference old CharacterManager save/load patterns when building MetaProgression
- **After Task 04:** Delete entire `_DELETED/` folder (git history preserves everything)
- **Key Reference:** `CharacterManager.gd.backup` shows how old save/load system worked

**Useful References from _DELETED/:**
- **MetaProgression save/load:** See `CharacterManager.gd.backup` lines 45-120 (save/load methods)
- **XP curve logic:** See `PlayerProgression.gd.backup` lines 78-156 (if needed for balancing)
- **Character data structure:** See `CharacterProfile.gd` (fields to migrate to new system)

---

**Related:** [Stage Progression Vision](../02-brainstorm/ARENA_PROGRESSION/STAGE_PROGRESSION_VISION.md) | [Difficulty Scaling Task](03_COMBAT_map_level_difficulty_scaling_integration.md) | [Task 04a Cleanup](completed-tasks/04a_CLEANUP_old_progression_removal.md)