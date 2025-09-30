# Single-Session Run Architecture Refactoring

**Created:** 2025-09-30
**Status:** 🟡 Planning
**Priority:** High
**Estimated Effort:** 2-3 weeks
**Category:** 🔄 Architecture Refactoring

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

## 🎯 Player Flow (Based on Design Discussion)

```
Game Launch
    ↓
Main Menu
    ├── [PLAY] → Character Select → Arena (run starts)
    ├── [UNLOCKS] → Purchase unlocked items/characters with silver
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

Arena (During Run)
    ↓ Death
End-of-Run Screen
    ├── Left Column: Damage Breakdown (abilities, DPS, levels)
    ├── Center Column: Summary (character, kills, time, level, inventory)
    ├── Right Column: Completed Quests
    ├── Bottom: [CONFIRM] + Unlocks earned + Silver gained
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

### Decision 4: Silver Economy
**Earning Rates (Simple Initial System):**
- Stage 1 completion: 10 Silver
- Stage 2 completion: 15 Silver (+50% per stage)
- Stage 3 completion: 22 Silver
- Kill count bonus: +1 Silver per 100 kills
- Survival time bonus: +1 Silver per minute
- Final Swarm survived: +10 Silver

**Unlock Costs (Placeholder - needs balancing):**
- New Character: 50-100 Silver
- New Item: 20-30 Silver
- Toggler Feature: 150 Silver (requires 40 unlocks first)
- Extra weapon slot: 150 Silver
- Extra tome slot: 150 Silver

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
- "Silver earned: +73"
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
  - Silver balance (int)
  - Unlocked characters (Array[String])
  - Discovered items (Array[String]) - found in runs but not purchased
  - Unlocked items (Array[String]) - purchased and appear in future runs
  - Achievements (Dictionary) - `{"first_boss_kill": true, ...}`
  - Toggler enabled (bool) - special unlock
  - Toggler disabled items (Array[String]) - player-chosen exclusions
- **No Career Stats:** Don't track total kills/damage across all runs
- **Personal Bests:** Separate `LocalLeaderboard` autoload

### Decision 10: Character Select Screen
**UI Elements:**
- Character portraits in grid (unlocked vs locked states)
- Locked characters show unlock condition ("Complete Stage 5 to unlock")
- No preview of locked character abilities (discover after unlock)
- Unlocked characters show stats and abilities:
  - Health, speed, damage
  - Passive abilities
  - Starting skills
- No "random character" button

## 📊 Implementation Plan

**Approach:** Bottom-up refactoring - create new systems, migrate data, remove old systems.

### Phase 1: Create New Meta-Progression System (2-3 sessions)
**Goal:** Replace CharacterManager with MetaProgression autoload
**Test:** Can save/load silver and unlocks correctly

- [ ] Create `MetaProgression` autoload (scripts/autoload/MetaProgression.gd)
- [ ] Define meta-progression data structure:
  - [ ] `silver: int` - currency balance
  - [ ] `unlocked_characters: Array[String]` - character IDs
  - [ ] `discovered_items: Array[String]` - seen but not purchased
  - [ ] `unlocked_items: Array[String]` - purchased and active
  - [ ] `achievements: Dictionary` - achievement flags
  - [ ] `toggler_enabled: bool` - can disable items
  - [ ] `toggler_disabled_items: Array[String]` - excluded from runs
- [ ] Implement save/load methods:
  - [ ] `save()` → writes to `user://meta_progression.tres`
  - [ ] `load()` → reads from disk on game launch
  - [ ] `reset()` → creates fresh save (first time player)
- [ ] Add silver transaction methods:
  - [ ] `earn_silver(amount: int)` - add silver from run
  - [ ] `spend_silver(amount: int) -> bool` - purchase unlock
  - [ ] `can_afford(amount: int) -> bool` - check balance
- [ ] Add unlock methods:
  - [ ] `unlock_character(id: String)` - add to unlocked_characters
  - [ ] `is_character_unlocked(id: String) -> bool` - check status
  - [ ] `discover_item(id: String)` - add to discovered_items
  - [ ] `unlock_item(id: String)` - move to unlocked_items
  - [ ] `is_item_unlocked(id: String) -> bool` - check status
- [ ] Add EventBus signals:
  - [ ] `meta_progression_loaded` - fired after load
  - [ ] `silver_changed(new_balance: int)` - UI update
  - [ ] `item_unlocked(item_id: String)` - notification
  - [ ] `character_unlocked(character_id: String)` - notification
- [ ] Test with isolated scene (create `tests/MetaProgression_Isolated.tscn`)

**Deliverable:** MetaProgression autoload working with save/load

---

### Phase 2: Create SessionState System (2-3 sessions)
**Goal:** Migrate stats tracking from RunManager to SessionState
**Test:** Stats track correctly during run, reset on death

**⚠️ Current State:** RunManager handles TWO responsibilities:
1. 30Hz fixed-step timing (KEEP - core engine feature)
2. Run statistics tracking (MIGRATE to SessionState)

**Migration Source:** See `autoload/RunManager.gd` for current implementation:
- `stats: Dictionary` - enemies_killed, total_damage_dealt, xp_gained
- `_on_enemy_killed()` - kill tracking
- `_on_damage_dealt()` - damage tracking
- `_on_xp_gained()` - XP tracking
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
  - [ ] `collected_items: Array[String]` - items found this run
  - [ ] `active_abilities: Array[String]` - abilities unlocked
  - [ ] `damage_breakdown: Dictionary` - per-ability damage stats
- [ ] Migrate stat tracking from RunManager:
  - [ ] Copy `_on_enemy_killed()` from RunManager → SessionState
  - [ ] Copy `_on_damage_dealt()` from RunManager → SessionState
  - [ ] Copy `_on_xp_gained()` from RunManager → SessionState
  - [ ] Copy EventBus signal connections from RunManager._ready()
  - [ ] Remove stat tracking from RunManager after migration
- [ ] Add lifecycle methods:
  - [ ] `start_run(character_id: String)` - reset and begin
  - [ ] `end_run()` - calculate final stats and silver
  - [ ] `reset()` - wipe all session data
- [ ] Add stat tracking methods:
  - [ ] `add_kill()` - increment kills
  - [ ] `add_damage(ability_id: String, amount: float)` - track damage
  - [ ] `add_xp(amount: float)` - handle leveling (emit level_up signal)
  - [ ] `collect_item(item_id: String)` - add to inventory
- [ ] Add silver calculation:
  - [ ] `calculate_silver_earned() -> int` - based on stage, kills, time
  - [ ] Formula: base (10 per stage) + bonuses (kills/time)
- [ ] Add EventBus signals:
  - [ ] `run_started(character_id: String)` - notify systems
  - [ ] `run_ended(stats: Dictionary)` - pass final stats
  - [ ] `level_up(new_level: int)` - player leveled up
- [ ] Test with isolated scene (extend `tests/StageTimer_Isolated.tscn`)

**Post-Migration Cleanup:**
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

**Deliverable:** SessionState tracks run stats, RunManager only handles 30Hz timing, deprecated shims removed

---

### Phase 3: Create LocalLeaderboard System (1-2 sessions)
**Goal:** Track personal bests separate from meta-progression
**Test:** Top 10 runs displayed correctly

- [ ] Create `LocalLeaderboard` autoload (scripts/autoload/LocalLeaderboard.gd)
- [ ] Define leaderboard entry structure:
  ```gdscript
  class LeaderboardEntry:
      var character_id: String
      var kills: int
      var stage_reached: int
      var time_survived: float
      var level_reached: int
      var timestamp: int  # Unix timestamp
  ```
- [ ] Implement storage:
  - [ ] `entries: Array[LeaderboardEntry]` - top 20 runs
  - [ ] `save()` → writes to `user://local_leaderboard.tres`
  - [ ] `load()` → reads from disk
- [ ] Add entry management:
  - [ ] `add_entry(stats: Dictionary) -> int` - returns placement (1-20 or -1)
  - [ ] `get_top_entries(count: int) -> Array[LeaderboardEntry]` - retrieve top N
  - [ ] `get_placement(kills: int) -> int` - calculate where entry would rank
  - [ ] `_sort_entries()` - sort by kills (descending)
- [ ] Add query methods:
  - [ ] `get_personal_best_kills() -> int`
  - [ ] `get_personal_best_stage() -> int`
  - [ ] `get_personal_best_time() -> float`
- [ ] Add EventBus signal:
  - [ ] `new_personal_best(entry: LeaderboardEntry)` - UI notification
- [ ] Test with mock data

**Deliverable:** LocalLeaderboard stores and retrieves top 20 runs

---

### Phase 4: Create End-of-Run Scene (2-3 sessions)
**Goal:** Display stats, calculate rewards, save progression
**Test:** Can view stats and return to main menu

- [ ] Create `scenes/ui/EndOfRun.tscn` scene
- [ ] Implement three-column layout:
  - [ ] Left: Damage Breakdown (ScrollContainer with ability list)
  - [ ] Center: Summary (character, kills, time, level, inventory display)
  - [ ] Right: Completed Quests (quest list with checkmarks)
- [ ] Add bottom section:
  - [ ] "Unlocks this run: X" label
  - [ ] "Silver earned: +Y" label
  - [ ] [CONFIRM] button
- [ ] Implement `EndOfRun.gd` script:
  - [ ] `show_run_results(stats: Dictionary)` - populate UI
  - [ ] `_calculate_rewards()` - silver earned, achievements unlocked
  - [ ] `_check_new_unlocks()` - discovered items, character achievements
  - [ ] `_save_progression()` - MetaProgression.save(), LocalLeaderboard.save()
  - [ ] `_on_confirm_pressed()` - return to main menu
- [ ] Add leaderboard placement notification:
  - [ ] Query LocalLeaderboard for placement
  - [ ] Display popup: "Global Kills: #47" (local for now)
- [ ] Wire to SessionState:
  - [ ] Connect to `EventBus.run_ended` signal
  - [ ] Receive final stats from SessionState
- [ ] Add animations/polish:
  - [ ] Fade in effect
  - [ ] Counter animations (kills counting up)
  - [ ] Sound effects for silver earned

**Deliverable:** Complete end-of-run screen with rewards and leaderboard placement

---

### Phase 5: Update Main Menu (2-3 sessions)
**Goal:** Implement main menu layout with all sections
**Test:** Can navigate to Play, Unlocks, Quests, Shop

- [ ] Update `scenes/ui/MainMenu.tscn` with new layout
- [ ] Implement layout sections:
  - [ ] Top Left: Quest Progress widget (top 4 quests)
  - [ ] Top Right: Silver Balance display
  - [ ] Center: Main buttons (PLAY, UNLOCKS, QUESTS, SHOP)
  - [ ] Left Side: Settings, Exit, Credits buttons
  - [ ] Right Side: Leaderboard widget (top 20, reset timer placeholder)
- [ ] Create quest progress widget:
  - [ ] Query quest system (future) for top 4 active quests
  - [ ] Display progress bars (e.g., "Kill 100 enemies: 47/100")
  - [ ] Placeholder for now ("No active quests")
- [ ] Create leaderboard widget:
  - [ ] Query LocalLeaderboard for top 20 entries
  - [ ] Display in scrollable list (character, kills, stage)
  - [ ] Show reset timer placeholder ("Next reset: TBD")
  - [ ] Tabs: [Global] [Friends] (friends grayed out for future)
- [ ] Update silver display:
  - [ ] Connect to MetaProgression.silver_changed signal
  - [ ] Animate when silver updates
- [ ] Wire button actions:
  - [ ] PLAY → Go to Character Select
  - [ ] UNLOCKS → Open unlocks shop (future scene)
  - [ ] QUESTS → Open quest log (future scene)
  - [ ] SHOP → Open meta-progression shop (future scene)
  - [ ] SETTINGS → Open settings menu (existing)
  - [ ] EXIT → Quit game
  - [ ] CREDITS → Show credits (future scene)
- [ ] Add background music and ambient effects

**Deliverable:** Functional main menu with all navigation points

---

### Phase 6: Create Character Select Scene (2-3 sessions)
**Goal:** Display unlocked/locked characters with stats
**Test:** Can select character and start run

- [ ] Create `scenes/ui/CharacterSelect.tscn` scene
- [ ] Implement character grid layout:
  - [ ] Query MetaProgression for unlocked_characters
  - [ ] Display character portraits (3x2 grid or scrollable)
  - [ ] Show locked state (grayed out) with unlock condition
  - [ ] Show unlocked state (clickable) with [SELECT] button
- [ ] Create character info panel (right side):
  - [ ] Character name and portrait
  - [ ] Stats display (Health, Speed, Damage)
  - [ ] Passive abilities description
  - [ ] Starting skills list
  - [ ] Only show for unlocked characters
- [ ] Implement unlock condition display:
  - [ ] Locked characters show text: "Complete Stage 5 to unlock"
  - [ ] Or: "50 Silver to unlock" (if purchasable)
  - [ ] No preview of abilities for locked characters
- [ ] Wire selection logic:
  - [ ] Click character → Update info panel
  - [ ] [SELECT] button → Start run with character
  - [ ] SessionState.start_run(character_id)
  - [ ] StateManager.go_to_arena()
- [ ] Add [BACK] button → Return to main menu
- [ ] Add animations (character portraits, selection highlight)

**Deliverable:** Character select screen with lock/unlock states

---

### Phase 7: Migrate Existing Systems (2-3 sessions)
**Goal:** Update Arena, DamageSystem, etc. to use SessionState
**Test:** Full run works end-to-end (char select → arena → death → end screen)

- [ ] Update Arena.gd:
  - [ ] Remove references to old RunManager stats
  - [ ] Connect to SessionState for stat tracking
  - [ ] Remove character save/load logic
- [ ] Update DamageSystem.gd:
  - [ ] Emit damage to SessionState.add_damage()
  - [ ] Track kills via SessionState.add_kill()
- [ ] Update PlayerProgression.gd:
  - [ ] Use SessionState for level/XP (not persistent)
  - [ ] Remove per-character progression logic
  - [ ] Connect to SessionState.level_up signal
- [ ] Update death handling:
  - [ ] On player death → SessionState.end_run()
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

- [ ] Remove CharacterManager autoload:
  - [ ] Delete `autoload/CharacterManager.gd`
  - [ ] Remove from project.godot autoload section
  - [ ] Remove references in other scripts
- [ ] Simplify RunManager:
  - [ ] Remove save/load logic
  - [ ] Remove per-character state tracking
  - [ ] Keep only 30Hz combat step (or move to SessionState)
  - [ ] Consider renaming to `CombatClock` if only timing remains
- [ ] Delete old save files:
  - [ ] Remove `user://profiles/` directory handling
  - [ ] Keep only `user://meta_progression.tres`
  - [ ] Keep only `user://local_leaderboard.tres`
- [ ] Update CharacterProfile resource:
  - [ ] Remove if no longer needed
  - [ ] Or simplify to just character definition (not save data)
- [ ] Update autoload/CLAUDE.md:
  - [ ] Document new SessionState autoload
  - [ ] Document new MetaProgression autoload
  - [ ] Document new LocalLeaderboard autoload
  - [ ] Remove CharacterManager patterns

**Deliverable:** Codebase cleaned of old progression system

---

### Phase 9: Item Discovery & Unlock System (3-4 sessions)
**Goal:** MEGABONK-style item discovery and purchase flow
**Test:** Items discovered in run can be purchased in shop

- [ ] Create item discovery flow:
  - [ ] When item drops in run, check if already unlocked
  - [ ] If new: MetaProgression.discover_item(item_id)
  - [ ] Show "New Item Discovered!" notification in-game
  - [ ] Item appears in end-of-run summary
- [ ] Create Unlocks Shop scene (`scenes/ui/UnlocksShop.tscn`):
  - [ ] Display discovered_items (not yet purchased)
  - [ ] Show item icon, name, description, cost
  - [ ] [UNLOCK] button (costs silver)
  - [ ] Filter tabs: [Items] [Tomes] [Weapons]
- [ ] Implement unlock purchase:
  - [ ] Check MetaProgression.can_afford(cost)
  - [ ] On purchase: MetaProgression.unlock_item(item_id)
  - [ ] Move from discovered_items to unlocked_items
  - [ ] Deduct silver
  - [ ] Show "Item Unlocked!" notification
- [ ] Update item spawning in runs:
  - [ ] Only spawn items from MetaProgression.unlocked_items pool
  - [ ] Unlocked items appear in RNG drop tables
- [ ] Create Toggler system:
  - [ ] Add "Toggler" unlock in shop (150 Silver, requires 40 unlocks)
  - [ ] When toggler_enabled = true, show [DISABLE] buttons in shop
  - [ ] Disabled items added to toggler_disabled_items
  - [ ] Disabled items excluded from drop tables
  - [ ] Categories: Items, Tomes, Weapons (separate toggle lists)
- [ ] Add item metadata resource:
  - [ ] Create `/data/content/items/*.tres` files
  - [ ] Define: id, name, description, cost, category, rarity
  - [ ] Load in MetaProgression for shop display

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

- [ ] MetaProgression autoload saves/loads correctly
- [ ] SessionState tracks run stats and emits 30Hz combat step
- [ ] LocalLeaderboard stores top 20 runs
- [ ] End-of-run screen displays all stats correctly
- [ ] Main menu shows quest widget, leaderboard, silver balance
- [ ] Character select shows lock/unlock states with conditions
- [ ] Full run loop works: char select → arena → death → end screen → menu
- [ ] Item discovery → purchase flow working (discovered items in shop)
- [ ] Toggler system functional (can disable unlocked items)
- [ ] Old CharacterManager removed, no more per-character saves
- [ ] Single save file: `user://meta_progression.tres`
- [ ] Documentation updated: autoload/CLAUDE.md with new patterns
- [ ] CHANGELOG.md updated with refactoring summary
- [ ] Commit ready: `refactor(progression): single-session runs with meta-progression unlocks`

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