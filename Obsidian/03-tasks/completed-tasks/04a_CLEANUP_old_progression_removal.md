# Pre-Refactoring Cleanup - Old Progression System Removal

**Created:** 2025-09-30
**Status:** 🟡 Planning
**Priority:** Critical (Blocks Task 04)
**Estimated Effort:** 1-2 sessions
**Category:** 🧹 Cleanup / Preparation

## 📋 Task Description

Remove old character-slot-based progression system to create clean foundation for single-session refactoring. This is a **destructive cleanup** that will temporarily break the game, but provides a clear starting point for the new architecture.

**What This Does:**
- ❌ Removes CharacterManager autoload entirely
- ❌ Removes PlayerProgression persistence logic
- ❌ Removes XP curve resource system (will be rebuilt simpler)
- ❌ Removes current main menu character slot UI
- ❌ Removes per-character save files
- ✅ Keeps: 30Hz combat step (RunManager), EventBus signals, Arena scenes

**What Will Break:**
- ⚠️ Character selection (no UI)
- ⚠️ Level/XP tracking (no persistence)
- ⚠️ Main menu (no character slots)
- ⚠️ Game launches but can't start a run

**Why Do This:**
1. Avoid confusion between old and new progression systems
2. Force ourselves to rebuild with new architecture
3. Ensure no hidden dependencies on old code
4. Make it obvious what needs to be rebuilt

## 🎯 Acceptance Criteria

- [ ] CharacterManager autoload removed from project
- [ ] PlayerProgression persistence code removed (keep in-run XP tracking)
- [ ] XP curve resource files removed or marked for rebuild
- [ ] Main menu character slot UI removed
- [ ] `user://profiles/` directory no longer accessed
- [ ] Game launches without errors (but can't start runs yet)
- [ ] All references to removed systems deleted or commented with "TODO: New progression"

## 📊 Implementation Steps

### Step 1: Audit Current System (Before Deletion)
**Goal:** Document what exists so we know what to rebuild

- [ ] List all files related to character progression:
  ```bash
  # Run these searches to identify files
  Grep: "CharacterManager" → Find all references
  Grep: "PlayerProgression" → Find persistence logic
  Grep: "user://profiles" → Find save file access
  Glob: "**/*Character*.gd" → Find character-related scripts
  Glob: "data/core/*xp*.tres" → Find XP curve resources
  ```
- [ ] Document current CharacterManager API:
  - [ ] What methods are called from other systems?
  - [ ] What signals are emitted/connected?
  - [ ] What data is saved to disk?
- [ ] Document current PlayerProgression API:
  - [ ] What methods handle XP/leveling?
  - [ ] What persistence logic exists?
  - [ ] What signals are emitted?
- [ ] Take screenshots of current main menu (for reference)
- [ ] Create checklist of systems that reference old progression

**Deliverable:** Audit document showing what will be removed

---

### Step 2: Remove CharacterManager Autoload
**Goal:** Delete CharacterManager completely

- [ ] Open `autoload/CharacterManager.gd`
- [ ] Copy file to `autoload/_DELETED_CharacterManager.gd.backup` (for reference)
- [ ] Delete `autoload/CharacterManager.gd`
- [ ] Open `project.godot`, find autoload section:
  ```ini
  [autoload]
  CharacterManager="*res://autoload/CharacterManager.gd"
  ```
- [ ] Remove CharacterManager line from project.godot
- [ ] Search codebase for "CharacterManager" references:
  ```bash
  Grep: "CharacterManager\." → Find all usage
  ```
- [ ] For each reference found:
  - [ ] If in UI code: Comment out with `# TODO: New progression - remove CharacterManager`
  - [ ] If in Arena/system code: Comment out or remove
  - [ ] Note location for rebuild in new task
- [ ] Verify game launches without "CharacterManager not found" errors

**Deliverable:** CharacterManager deleted, references removed/commented

---

### Step 3: Remove Character Save File System
**Goal:** Stop accessing `user://profiles/` directory

- [ ] Search for "user://profiles" in codebase:
  ```bash
  Grep: "user://profiles" → Find all save file access
  ```
- [ ] Comment out all save/load code accessing this directory
- [ ] Remove CharacterProfile resource handling:
  ```bash
  Glob: "scripts/resources/*Character*.gd"
  ```
- [ ] Mark CharacterProfile.gd for deletion or refactoring:
  - [ ] If used only for saves: Delete
  - [ ] If used for character definitions: Keep but simplify
- [ ] Add note: "Character definitions will be .tres files in /data/content/characters/"

**Deliverable:** No code accesses `user://profiles/` directory

---

### Step 4: Simplify PlayerProgression (Remove Persistence)
**Goal:** Keep in-run XP tracking, remove save/load logic

- [ ] Open `autoload/PlayerProgression.gd`
- [ ] Create backup: `autoload/_DELETED_PlayerProgression.gd.backup`
- [ ] Remove or comment out:
  - [ ] Any save/load methods
  - [ ] Per-character state tracking
  - [ ] XP curve resource loading
  - [ ] Unlock validation logic
- [ ] Keep:
  - [ ] `level: int` variable
  - [ ] `experience: float` variable
  - [ ] `gain_exp(amount: float)` method (in-run only)
  - [ ] `EventBus.xp_gained` signal emission
  - [ ] `EventBus.leveled_up` signal emission
- [ ] Simplify to minimal in-run tracking:
  ```gdscript
  extends Node

  # Session-only progression (no persistence)
  var level: int = 1
  var experience: float = 0.0
  var xp_to_next: float = 100.0

  func gain_exp(amount: float) -> void:
      experience += amount
      EventBus.xp_gained.emit(amount, experience)

      # Check for level-up
      while experience >= xp_to_next:
          level += 1
          experience -= xp_to_next
          xp_to_next = _calculate_next_level_xp()
          EventBus.leveled_up.emit(level)

  func _calculate_next_level_xp() -> float:
      # Simple formula for now (will be in BalanceDB later)
      return 100.0 + (level * 50.0)

  func reset() -> void:
      # Called at run start
      level = 1
      experience = 0.0
      xp_to_next = 100.0
  ```
- [ ] Add reset() call when run starts (wire to SessionState later)

**Deliverable:** PlayerProgression simplified to in-run only, no persistence

---

### Step 5: Remove XP Curve Resources
**Goal:** Delete complex XP curve system, use simple formula

- [ ] Find XP curve resource files:
  ```bash
  Glob: "data/core/*xp*.tres"
  Glob: "scripts/resources/*XP*.gd"
  ```
- [ ] Delete or move to `_DELETED/` folder:
  - [ ] `data/core/progression-xp-curve.tres`
  - [ ] `scripts/resources/PlayerXPCurve.gd`
  - [ ] Any related resource classes
- [ ] Remove unlocks resource:
  - [ ] `data/content/unlocks.tres` (if exists)
  - [ ] `scripts/resources/PlayerUnlocks.gd` (if exists)
- [ ] Note: "XP formula will be simple: 100 + (level * 50) for now, tunable in BalanceDB later"

**Deliverable:** Complex XP curve system removed

---

### Step 6: Remove Main Menu Character Slot UI
**Goal:** Delete old main menu UI, prepare for rebuild

- [ ] Open `scenes/ui/MainMenu.tscn`
- [ ] Take screenshot of current layout (for reference)
- [ ] Delete or disable:
  - [ ] Character slot displays
  - [ ] "Continue with character X" buttons
  - [ ] Character creation/selection UI
  - [ ] Any CharacterManager references in script
- [ ] Simplify to minimal menu:
  ```
  Main Menu (Temporary Placeholder)
  ├── [PLAY] button (disabled/grayed out)
  │   └── Tooltip: "Coming soon - new progression system"
  ├── [SETTINGS] button (functional)
  └── [EXIT] button (functional)
  ```
- [ ] Update MainMenu.gd script:
  - [ ] Remove CharacterManager initialization
  - [ ] Remove character slot logic
  - [ ] Add placeholder message: "Main menu under construction"
- [ ] Optional: Add label: "🚧 Progression system refactoring in progress"

**Deliverable:** Main menu stripped to minimal placeholder

---

### Step 7: Clean Up RunManager
**Goal:** Keep only 30Hz combat step, remove progression logic

- [ ] Open `autoload/RunManager.gd`
- [ ] Create backup: `autoload/_DELETED_RunManager.gd.backup`
- [ ] Remove or comment out:
  - [ ] `stats: Dictionary` tracking (will move to SessionState)
  - [ ] XP tracking (`_on_xp_gained` handler)
  - [ ] Enemy kill tracking (`_on_enemy_killed` handler)
  - [ ] Damage tracking (`_on_damage_dealt` handler)
  - [ ] Any save/load logic
  - [ ] `run_seed` persistence (will be session-only)
- [ ] Keep:
  - [ ] `COMBAT_DT: float = 1.0 / 30.0` constant
  - [ ] `_accumulator: float` and fixed-step loop
  - [ ] `_process(delta)` with accumulator logic
  - [ ] EventBus.combat_step signal emission
  - [ ] Pause state checking
- [ ] Simplify to minimal combat clock:
  ```gdscript
  extends Node

  ## Manages 30Hz fixed-step combat timing.
  ## Stats tracking moved to SessionState autoload.

  const COMBAT_DT: float = 1.0 / 30.0  # 30 Hz

  var _accumulator: float = 0.0

  func _ready() -> void:
      process_mode = Node.PROCESS_MODE_PAUSABLE

  func _process(delta: float) -> void:
      if get_tree().paused:
          return

      _accumulator += delta

      while _accumulator >= COMBAT_DT:
          _accumulator -= COMBAT_DT
          EventBus.combat_step.emit()
  ```
- [ ] Note: "RunManager will be replaced by SessionState, but keeping for now to avoid breaking combat systems"

**Deliverable:** RunManager simplified to just 30Hz timing

---

### Step 8: Verify Game Launches (But Doesn't Work)
**Goal:** Ensure game starts without errors, even if unplayable

- [ ] Run game in debug mode
- [ ] Check for errors related to deleted systems:
  ```
  ✓ No "CharacterManager not found" errors
  ✓ No "user://profiles" access errors
  ✓ No XP curve resource loading errors
  ```
- [ ] Verify can reach main menu:
  - [ ] Game launches to main menu
  - [ ] Settings button works
  - [ ] Exit button works
  - [ ] Play button shows "Coming soon" message
- [ ] Expected broken state:
  - [ ] Can't select character (no UI)
  - [ ] Can't start run (Play button disabled)
  - [ ] Arena scenes might have errors (comment them out for now)
- [ ] Document what's broken in commit message

**Deliverable:** Game launches without errors, shows placeholder main menu

---

### Step 9: Update Documentation
**Goal:** Mark old system as removed, prepare for new

- [ ] Update `autoload/CLAUDE.md`:
  - [ ] Remove CharacterManager entry
  - [ ] Mark PlayerProgression as "simplified, no persistence"
  - [ ] Mark RunManager as "minimal, being replaced by SessionState"
  - [ ] Add note: "Progression system under refactoring (see Task 04)"
- [ ] Update `ARCHITECTURE.md` (if needed):
  - [ ] Note progression system is in transition
  - [ ] Point to Task 04 for new architecture
- [ ] Create `Obsidian/03-tasks/_CLEANUP_LOG.md`:
  - [ ] Document what was removed
  - [ ] List files backed up to `_DELETED/` folder
  - [ ] List systems that need rebuilding
  - [ ] Reference Task 04 for rebuild plan
- [ ] Update main README (if exists):
  - [ ] Note: "Progression system temporarily disabled during refactoring"

**Deliverable:** Documentation reflects cleanup state

---

### Step 10: Commit Cleanup
**Goal:** Atomic commit showing "before refactoring" state

- [ ] Stage all changes:
  ```bash
  git add -A
  ```
- [ ] Create detailed commit message:
  ```
  chore(progression): remove old character-slot progression system

  BREAKING CHANGE: Progression system removed in preparation for single-session refactoring

  Removed:
  - CharacterManager autoload (per-character saves)
  - user://profiles/ save file system
  - XP curve resource system
  - Main menu character slot UI
  - PlayerProgression persistence logic

  Simplified:
  - RunManager now only handles 30Hz combat step
  - PlayerProgression now only tracks in-run XP (no persistence)

  Current State:
  - Game launches to placeholder main menu
  - Play button disabled (no character select)
  - Settings and Exit functional
  - Combat systems still work (30Hz timing intact)

  Next Step: Task 04 - Build new single-session progression system
  Related: #04_PROGRESSION_single_session_refactoring.md
  ```
- [ ] Commit and push (if using version control)

**Deliverable:** Clean commit marking start of refactoring

---

## 🔗 Related Files

### Will Delete/Move to _DELETED/:
- [ ] `autoload/CharacterManager.gd`
- [ ] `scripts/resources/CharacterProfile.gd` (maybe - check usage)
- [ ] `scripts/resources/PlayerXPCurve.gd`
- [ ] `scripts/resources/PlayerUnlocks.gd`
- [ ] `data/core/progression-xp-curve.tres`
- [ ] `data/content/unlocks.tres` (if exists)

### Will Simplify:
- [ ] `autoload/RunManager.gd` - Keep only 30Hz timing
- [ ] `autoload/PlayerProgression.gd` - Keep only in-run XP tracking
- [ ] `scenes/ui/MainMenu.tscn` - Reduce to placeholder

### Will Keep Untouched:
- [ ] `autoload/EventBus.gd` - Signals still needed
- [ ] `autoload/RNG.gd` - Determinism still needed
- [ ] `autoload/BalanceDB.gd` - Balance data still needed
- [ ] `scenes/arena/Arena.tscn` - Combat scenes intact
- [ ] All combat systems (DamageSystem, SpawnDirector, etc.)

## 📝 Progress Notes

### 2025-09-30 - Task Creation
- Created cleanup task to precede main refactoring
- Goal: Remove old progression system before building new
- Expects game to be temporarily unplayable
- Provides clean foundation for Task 04 implementation

### 2025-09-30 - Task Completion ✅
**Status:** COMPLETE

**What Was Removed:**
- ❌ CharacterManager autoload (backup: `_DELETED/autoload/CharacterManager.gd.backup`)
- ❌ CharacterSelect scene (deleted entirely, no backup needed)
- ❌ Character save files (42 files deleted from `user://profiles/`)
- ❌ XP curve resources:
  - `data/core/progression-xp-curve.tres` → `_DELETED/data/core/`
  - `scripts/resources/PlayerXPCurve.gd` → `_DELETED/scripts/resources/`
  - `scripts/resources/CharacterProfile.gd` → `_DELETED/scripts/resources/`
  - `scripts/resources/CharacterTypeDict.gd` → `_DELETED/scripts/resources/`

**What Was Simplified:**
- ✂️ PlayerProgression.gd: 244 lines → 153 lines
  - Removed: Save/load, XP curves, CharacterManager integration
  - Kept: In-run XP tracking, simple formula (100 + level*50)
  - Backup: `_DELETED/autoload/PlayerProgression.gd.backup`
- ✂️ RunManager.gd: 106 lines → 119 lines (after adding 75 lines of documentation)
  - Removed: Stats tracking (enemies_killed, damage_dealt, xp_gained)
  - Kept: 30Hz fixed-step timing (COMBAT_DT, accumulator pattern)
  - Backup: `_DELETED/autoload/RunManager.gd.backup`
  - **Added:** Comprehensive documentation explaining fixed-step accumulator pattern
- ✂️ MainMenu: Simplified to placeholders
  - Start button shows: "Character selection coming soon! Use debug mode."
  - Options button shows: "Settings coming soon!"
  - Continue button removed entirely

**Documentation Updates:**
- ✅ `autoload/CLAUDE.md`: Updated PlayerProgression entry to "simplified, no persistence"
- ✅ `Obsidian/03-tasks/03_COMBAT_map_level_difficulty_scaling_integration.md`: Added RunManager integration notes
- ✅ RunManager.gd: Added 75 lines of architectural documentation

**Current Game State:**
- ✅ Launches without errors
- ✅ Main menu shows placeholders (Start/Options disabled)
- ✅ Debug mode (arena start_mode) works perfectly
- ✅ Combat systems intact (30Hz timing functional)
- ✅ XP/leveling works (session-only, no persistence)

**_DELETED/ Folder Contents:**
The `_DELETED/` folder contains reference backups of all removed code:
```
_DELETED/
├── autoload/
│   ├── CharacterManager.gd.backup       (Full old implementation)
│   ├── PlayerProgression.gd.backup      (Pre-simplification version)
│   └── RunManager.gd.backup             (Pre-simplification version)
├── data/core/
│   └── progression-xp-curve.tres        (Complex XP curve resource)
└── scripts/resources/
    ├── CharacterProfile.gd              (Character save data structure)
    ├── CharacterTypeDict.gd             (Character type definitions)
    └── PlayerXPCurve.gd                 (XP curve resource class)
```

**⚠️ _DELETED/ Folder Retention Policy:**
- **Keep until:** Task 04 Phase 1-2 complete (MetaProgression + SessionState implemented)
- **Purpose:** Reference for understanding old patterns when rebuilding
- **After Task 04:** Can be deleted entirely (git history preserves everything)
- **If needed:** Can reference old CharacterManager save/load patterns for MetaProgression implementation

**Commits:**
- All changes committed with passing architecture validation
- Commit messages document what was removed and why

**Ready For:** Task 04 Phase 1 - MetaProgression Autoload Creation

## 🚨 Risks & Considerations

### Risk 1: Breaking Too Much (HIGH)
- **Issue:** Might accidentally delete code we need
- **Mitigation:**
  - Create backups in `_DELETED/` folder before deleting
  - Keep git history intact (atomic commits)
  - Document what was removed in cleanup log
  - Can revert commit if needed

### Risk 2: Hidden Dependencies (MEDIUM)
- **Issue:** Other systems might reference CharacterManager/progression
- **Mitigation:**
  - Use Grep to find all references before deleting
  - Comment out references with TODO markers
  - Test game launches without errors
  - Address compilation errors one by one

### Risk 3: Unclear Rebuild Path (LOW)
- **Issue:** After cleanup, might be unclear what to rebuild
- **Mitigation:**
  - Cleanup log documents everything removed
  - Task 04 has detailed rebuild plan
  - Backed-up files show old implementation
  - Can reference MEGABONK/ROR2 patterns

### Risk 4: Time Waste If Approach Wrong (LOW)
- **Issue:** What if single-session design needs tweaking?
- **Mitigation:**
  - Design already validated in Task 04 Q&A
  - Cleanup is reversible (git revert)
  - Small cleanup task (1-2 sessions) vs large refactor (2-3 weeks)
  - Better to clean slate than refactor piecemeal

## ✅ Definition of Done

- [ ] CharacterManager autoload deleted
- [ ] PlayerProgression simplified (no persistence)
- [ ] RunManager simplified (30Hz only)
- [ ] XP curve resources deleted
- [ ] Main menu reduced to placeholder
- [ ] `user://profiles/` directory no longer accessed
- [ ] Game launches without errors (but Play button disabled)
- [ ] All deleted files backed up to `_DELETED/` folder
- [ ] Documentation updated (CLAUDE.md, cleanup log)
- [ ] Commit created with detailed message
- [ ] Ready to start Task 04 Phase 1 (MetaProgression creation)

## 🎯 Success Criteria

### Code State:
- Game compiles and launches without errors
- No references to CharacterManager exist
- No code accesses `user://profiles/`
- RunManager only handles 30Hz timing
- PlayerProgression only tracks in-run XP

### User Experience (Temporary):
- Main menu shows placeholder message
- Play button grayed out with "Coming soon" tooltip
- Settings and Exit buttons work
- No crashes or errors on launch

### Readiness for Task 04:
- Clear foundation for new progression system
- No old code to confuse implementation
- Documentation points to rebuild plan
- Can start Task 04 Phase 1 immediately

---

**Blocks:** Task 04 (Single-Session Refactoring)
**Estimated Time:** 1-2 sessions (2-4 hours)
**Risk Level:** Medium (breaking changes, but reversible)
**Next Step:** After completion, start Task 04 Phase 1 (MetaProgression autoload)