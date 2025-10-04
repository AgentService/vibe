# Tier Selection UI Integration (MVP)

**Created:** 2025-10-03
**Status:** 🔴 Blocked - Requires Task 4 (Stage Progression)
**Priority:** Medium (After Stage Progression)
**Estimated Effort:** 45 minutes - 1.5 hours (including admin panel)
**Category:** 🎮 Progression System - UI Integration
**Prerequisites:** [Task 4 - Stage Progression](4_COMBAT_stage_progression_flow.md) ← Provides tier unlocking gameplay

## 📋 Task Description

Wire up the existing tier selection UI in MapSelect to the MetaProgression backend, **plus add a ProgressionAdminPanel** for easy testing (similar to ShopAdminPanel). This makes tier unlocking UI functional after Task 4 provides the gameplay mechanics to actually unlock tiers via stage completion.

**Current State Analysis:**
- ✅ Tier UI exists in MapSelect.tscn with 4 tier checkboxes
- ✅ MetaProgressionData has tier unlock tracking fields
- ✅ MetaProgression autoload has tier management functions
- ✅ EventBus has tier progression signals
- ⚠️ MapSelect script doesn't connect checkboxes to backend
- ⚠️ Detail panel shows hardcoded data instead of real MetaProgression stats
- ⚠️ Tier unlocking doesn't work (all tiers appear locked except T1)

**Integration Requirements:**
- Wire checkbox enabled/disabled state to `MetaProgression.is_tier_unlocked()`
- Update detail panel labels with `get_deepest_stage()` and `get_run_count()`
- Pass selected tier to `SessionState.start_run()`
- Handle checkbox toggle events to track selected tier
- **Add ProgressionAdminPanel with buttons to:**
  - Unlock tiers (2, 3, 4, All)
  - Set deepest stage (1/3, 2/3, 3/3)
  - Simulate runs (add kills, increment run count)
  - Reset progression (current tier or all data)

## 🎯 Acceptance Criteria

### Core Functionality
- [ ] Tier 2-4 checkboxes disabled if not unlocked via MetaProgression
- [ ] Tier 1 always enabled (starting tier)
- [ ] Detail panel "Deepest Stage" shows real data from `MetaProgression.get_deepest_stage(tier)`
- [ ] Detail panel "Runs" count shows real data from `MetaProgression.get_run_count(map_id, tier)`
- [ ] Clicking checkbox updates `selected_tier` variable
- [ ] Only one tier checkbox can be selected at a time (radio button behavior)
- [ ] "Start Run" button passes `selected_tier` to `SessionState.start_run()`
- [ ] UI refreshes on `EventBus.tier_unlocked` signal

### UI Polish
- [ ] Deepest stage displays as "X/3" for Tier 1-3 (e.g., "2/3")
- [ ] Deepest stage displays as "Stage N" for Unlimited tier (e.g., "Stage 15")
- [ ] Disabled checkboxes visually indicate locked state
- [ ] Selected tier highlights appropriately

## 🔍 Technical Implementation

### Phase 1: Add UI Node References (5 mins)

```gdscript
# MapSelect.gd - Add @onready references
@onready var tier1_checkbox: CheckBox = $MarginContainer_CharacterSelect2/NinePatchRect/MarginContainer7/VBoxContainer3/MarginContainer3/MarginContainer/VBoxContainer/HBoxContainer/HBoxContainer/CheckBox
@onready var tier2_checkbox: CheckBox = $MarginContainer_CharacterSelect2/NinePatchRect/MarginContainer7/VBoxContainer3/MarginContainer3/MarginContainer/VBoxContainer/HBoxContainer2/HBoxContainer/CheckBox
@onready var tier3_checkbox: CheckBox = $MarginContainer_CharacterSelect2/NinePatchRect/MarginContainer7/VBoxContainer3/MarginContainer3/MarginContainer/VBoxContainer/HBoxContainer3/HBoxContainer/CheckBox
@onready var tier4_checkbox: CheckBox = $MarginContainer_CharacterSelect2/NinePatchRect/MarginContainer7/VBoxContainer3/MarginContainer3/MarginContainer/VBoxContainer/HBoxContainer4/HBoxContainer/CheckBox

# Detail panel labels
@onready var tier_label: Label = $MarginContainer_CharacterSelect2/NinePatchRect/MarginContainer7/VBoxContainer3/MarginContainer/HBoxContainer/VBoxContainer/TierLabel
@onready var runs_label: Label = $MarginContainer_CharacterSelect2/NinePatchRect/MarginContainer7/VBoxContainer3/MarginContainer/HBoxContainer/VBoxContainer/RunsLabel
@onready var deepest_stage_label: Label = $MarginContainer_CharacterSelect2/NinePatchRect/MarginContainer7/VBoxContainer3/MarginContainer2/MarginContainer/HBoxContainer/VBoxContainer2/HBoxContainer/DepthValue
```

### Phase 2: Connect Signals & Initialize (10 mins)

```gdscript
# MapSelect.gd - _ready()
func _ready() -> void:
	# Existing code...
	back_button.pressed.connect(_on_back_pressed)
	start_run_button.pressed.connect(_on_start_run_pressed)

	# Connect tier checkboxes
	tier1_checkbox.toggled.connect(_on_tier_checkbox_toggled.bind(1))
	tier2_checkbox.toggled.connect(_on_tier_checkbox_toggled.bind(2))
	tier3_checkbox.toggled.connect(_on_tier_checkbox_toggled.bind(3))
	tier4_checkbox.toggled.connect(_on_tier_checkbox_toggled.bind(4))

	# Connect to MetaProgression signals
	EventBus.tier_unlocked.connect(_on_tier_unlocked)

	# Initialize UI
	_refresh_tier_ui()
```

### Phase 3: Implement UI Update Logic (10 mins)

```gdscript
# MapSelect.gd
func _refresh_tier_ui() -> void:
	"""Update tier checkboxes and detail panel based on MetaProgression data"""
	var unlocked_tiers: int = MetaProgression.get_unlocked_tiers()

	# Update checkbox states
	tier1_checkbox.disabled = false  # Always unlocked
	tier2_checkbox.disabled = (unlocked_tiers < 2)
	tier3_checkbox.disabled = (unlocked_tiers < 3)
	tier4_checkbox.disabled = (unlocked_tiers < 4)

	# Update detail panel
	_update_detail_panel()

func _update_detail_panel() -> void:
	"""Update detail panel labels with current tier stats"""
	var tier_name := "Tier %d" % selected_tier
	tier_label.text = tier_name

	# Run count
	var run_count := MetaProgression.get_run_count(selected_map, selected_tier)
	runs_label.text = "%d Runs" % run_count

	# Deepest stage
	var deepest := MetaProgression.get_deepest_stage(selected_tier)
	if selected_tier == 4:  # Unlimited
		deepest_stage_label.text = "Stage %d" % deepest if deepest > 0 else "-"
	else:  # Tier 1-3
		deepest_stage_label.text = "%d/3" % deepest if deepest > 0 else "-"

func _on_tier_checkbox_toggled(pressed: bool, tier: int) -> void:
	"""Handle tier checkbox toggle - implement radio button behavior"""
	if not pressed:
		return  # Ignore uncheck events

	# Uncheck other checkboxes (radio button behavior)
	if tier != 1: tier1_checkbox.button_pressed = false
	if tier != 2: tier2_checkbox.button_pressed = false
	if tier != 3: tier3_checkbox.button_pressed = false
	if tier != 4: tier4_checkbox.button_pressed = false

	# Update selected tier
	selected_tier = tier

	# Refresh detail panel
	_update_detail_panel()

	Logger.info("Tier %d selected" % tier, "ui")

func _on_tier_unlocked(tier: int) -> void:
	"""Handle tier unlock event from MetaProgression"""
	Logger.info("Tier %d unlocked, refreshing UI" % tier, "ui")
	_refresh_tier_ui()
```

### Phase 4: Update Start Run Flow (5 mins)

```gdscript
# MapSelect.gd - _on_start_run_pressed()
func _on_start_run_pressed() -> void:
	"""Start the run with selected character, map, and tier"""
	Logger.info("Starting run: %s on %s (Tier %d)" % [selected_character, selected_map, selected_tier], "ui")

	# Increment run counter
	MetaProgression.increment_run_count(selected_map, selected_tier)

	# Start run through SessionState (with selected tier)
	if SessionState:
		SessionState.start_run(selected_character, selected_map, selected_tier)

	# Prepare context (same as before, now includes selected_tier)
	var context = {
		"character": selected_character,
		"spawn_point": "PlayerSpawnPoint",
		"source": "map_select_new",
		"tier": selected_tier,
		"character_data": {}
	}

	# Transition to arena
	if StateManager:
		StateManager.start_run(&"pathgen_arena", context)
```

### Phase 5: Add Progression Admin Panel (15-20 mins)

**Purpose:** Quick testing panel for tier/stage progression (similar to ShopAdminPanel)

**Create `scenes/ui/components/ProgressionAdminPanel.tscn` + `.gd`:**

```gdscript
# ProgressionAdminPanel.gd
extends VBoxContainer
class_name ProgressionAdminPanel
## Admin panel for testing tier/stage progression flow

@onready var unlock_tier2_button: Button = $TierUnlocks/UnlockTier2
@onready var unlock_tier3_button: Button = $TierUnlocks/UnlockTier3
@onready var unlock_tier4_button: Button = $TierUnlocks/UnlockTier4
@onready var unlock_all_tiers_button: Button = $TierUnlocks/UnlockAllTiers

@onready var set_stage1_button: Button = $StageProgress/SetStage1
@onready var set_stage2_button: Button = $StageProgress/SetStage2
@onready var set_stage3_button: Button = $StageProgress/SetStage3

@onready var add_kills_button: Button = $SimulateRun/AddKills
@onready var add_run_count_button: Button = $SimulateRun/AddRunCount

@onready var reset_all_button: Button = $ResetTools/ResetAll
@onready var reset_tier_button: Button = $ResetTools/ResetCurrentTier

var current_tier: int = 1  # Track which tier to apply actions to

func _ready() -> void:
	# Tier unlocking
	unlock_tier2_button.pressed.connect(_unlock_tier.bind(2))
	unlock_tier3_button.pressed.connect(_unlock_tier.bind(3))
	unlock_tier4_button.pressed.connect(_unlock_tier.bind(4))
	unlock_all_tiers_button.pressed.connect(_unlock_all_tiers)

	# Stage progression
	set_stage1_button.pressed.connect(_set_deepest_stage.bind(1))
	set_stage2_button.pressed.connect(_set_deepest_stage.bind(2))
	set_stage3_button.pressed.connect(_set_deepest_stage.bind(3))

	# Simulate run stats
	add_kills_button.pressed.connect(_simulate_kills)
	add_run_count_button.pressed.connect(_increment_run_count)

	# Reset tools
	reset_all_button.pressed.connect(_reset_all_progression)
	reset_tier_button.pressed.connect(_reset_current_tier)

	Logger.debug("ProgressionAdminPanel initialized", "ui")

func set_current_tier(tier: int) -> void:
	"""Set which tier admin actions apply to."""
	current_tier = tier

func _unlock_tier(tier: int) -> void:
	"""Unlock a specific tier."""
	MetaProgression.unlock_tier(tier)
	Logger.info("Admin: Unlocked Tier %d" % tier, "ui")

func _unlock_all_tiers() -> void:
	"""Unlock all tiers 2-4."""
	for tier in [2, 3, 4]:
		MetaProgression.unlock_tier(tier)
	Logger.info("Admin: Unlocked all tiers", "ui")

func _set_deepest_stage(stage: int) -> void:
	"""Set deepest stage reached for current tier."""
	MetaProgression.update_deepest_stage(current_tier, stage)
	Logger.info("Admin: Set Tier %d deepest stage to %d/3" % [current_tier, stage], "ui")

func _simulate_kills() -> void:
	"""Simulate a run with 100 kills (for leaderboard testing)."""
	var run_data = {
		"character_id": "knight",
		"stage_reached": MetaProgression.get_deepest_stage(current_tier),
		"kills": 100,
		"damage_dealt": 5000,
		"time_survived": 300.0,
		"final_swarm_entered": false,
		"rift_fragments_earned": 10 * current_tier
	}

	var rank = LocalLeaderboard.add_run("forest_arena", current_tier, run_data)
	if rank > 0:
		Logger.info("Admin: Simulated run - Rank #%d on Tier %d" % [rank, current_tier], "ui")
	else:
		Logger.info("Admin: Simulated run did not qualify for leaderboard", "ui")

func _increment_run_count() -> void:
	"""Increment run counter for current tier."""
	MetaProgression.increment_run_count("forest_arena", current_tier)
	var count = MetaProgression.get_run_count("forest_arena", current_tier)
	Logger.info("Admin: Incremented run count to %d for Tier %d" % [count, current_tier], "ui")

func _reset_all_progression() -> void:
	"""Reset all progression data (fresh player simulation)."""
	# Reset MetaProgression
	MetaProgression._data.unlocked_tiers = 1
	MetaProgression._data.tier_deepest_stage.clear()
	MetaProgression._data.map_tier_runs.clear()
	MetaProgression.save()

	# Clear LocalLeaderboard
	LocalLeaderboard.clear_all()

	Logger.warn("Admin: RESET all progression data to fresh player state", "ui")

func _reset_current_tier() -> void:
	"""Reset data for current tier only."""
	# Reset deepest stage
	if MetaProgression._data.tier_deepest_stage.has(current_tier):
		MetaProgression._data.tier_deepest_stage.erase(current_tier)

	# Reset run count
	if MetaProgression._data.map_tier_runs.has("forest_arena"):
		if MetaProgression._data.map_tier_runs["forest_arena"].has(current_tier):
			MetaProgression._data.map_tier_runs["forest_arena"].erase(current_tier)

	MetaProgression.save()

	# Clear leaderboard for this tier
	LocalLeaderboard.clear_tier("forest_arena", current_tier)

	Logger.info("Admin: Reset Tier %d data" % current_tier, "ui")
```

**MapSelect.tscn Integration:**

Add a collapsible admin panel in MapSelect (similar to UnlockShop):
- Position in bottom-right corner or as a tab
- Only visible in debug builds or with F12 toggle
- Automatically syncs `current_tier` when player selects tier checkbox

## 📊 Testing Checklist

### Manual Testing (Core Functionality)
- [ ] Open MapSelect - Tier 1 enabled, Tier 2-4 disabled (fresh save)
- [ ] Select Tier 1 - detail panel shows "0 Runs", "-" deepest stage
- [ ] Start run, die immediately - return to MapSelect shows "1 Runs"
- [ ] Use ProgressionAdminPanel to unlock Tier 2
- [ ] Verify Tier 2 checkbox becomes enabled automatically
- [ ] Select Tier 2 - detail panel updates to show Tier 2 stats
- [ ] Click Tier 1 again - Tier 2 unchecks (radio button behavior)
- [ ] Start run on Tier 2 - verify SessionState receives tier=2

### Admin Panel Testing
- [ ] Open ProgressionAdminPanel (F12 toggle or always visible in debug)
- [ ] Click "Unlock Tier 2" → Tier 2 checkbox enables in UI
- [ ] Click "Set Stage 2/3" → Detail panel shows "2/3" for current tier
- [ ] Click "Add Run Count" → Run counter increments
- [ ] Click "Simulate Kills" → Leaderboard entry added (check Friends tab)
- [ ] Click "Reset Current Tier" → Tier data clears (deepest stage, runs)
- [ ] Click "Reset All" → Fresh player state (only Tier 1 unlocked)
- [ ] Admin panel syncs `current_tier` when tier checkbox clicked

### Edge Cases
- [ ] Switching tiers rapidly doesn't break UI state
- [ ] Detail panel handles missing data gracefully (shows "-")
- [ ] Tier 4 "unlimited" displays correctly ("Stage N" format)
- [ ] Run counter increments correctly per map+tier combination
- [ ] Admin panel actions immediately refresh MapSelect UI

## 🔗 Related Files

### Will Modify:
- [ ] `scenes/ui/MapSelect.gd` - Add tier selection logic (~60 lines with admin panel integration)

### Will Create:
- [ ] `scenes/ui/components/ProgressionAdminPanel.tscn` - Admin panel UI layout
- [ ] `scenes/ui/components/ProgressionAdminPanel.gd` - Admin panel logic (~100 lines)

### Will NOT Modify (Already Implemented):
- [x] `scripts/resources/MetaProgressionData.gd` - Has tier tracking fields
- [x] `autoload/MetaProgression.gd` - Has tier management functions
- [x] `autoload/EventBus.gd` - Has `tier_unlocked` signal
- [x] `autoload/LocalLeaderboard.gd` - Has leaderboard tracking
- [x] `scenes/ui/MapSelect.tscn` - UI already has checkboxes and labels

## 📝 Progress Notes

### 2025-10-03 - Task Creation
- Created MVP tier integration task
- Identified all required UI node paths
- Scoped to minimal 30-minute implementation
- Deferred stage progression to Task 5 (full MEGABONK integration)

## 🚨 Risks & Considerations

### Low Risk Implementation
- **Simple Scope**: Only wiring existing UI to existing backend
- **No New Systems**: All required infrastructure already exists
- **Quick Validation**: Can test immediately with manual tier unlocks via CheatSystem
- **Easy Rollback**: Changes confined to single script file

### Known Limitations
- **No Stage Progression**: Boss kills don't advance stages or unlock tiers yet
- **No Portal System**: Players can't progress through stages within a tier
- **Manual Unlocking**: Tiers must be unlocked via CheatSystem for testing
- **Static Difficulty**: Tier selection doesn't affect enemy difficulty yet

**Note**: These limitations are intentional - they will be addressed in Task 5 (Full Stage Progression Integration).

## ✅ Definition of Done

**MVP Tier Selection Working:**
- [ ] Tier checkboxes reflect MetaProgression unlock state
- [ ] Detail panel shows real deepest stage and run count data
- [ ] Selected tier passes to SessionState.start_run()
- [ ] Radio button behavior works (only one tier selected)
- [ ] EventBus.tier_unlocked signal updates UI
- [ ] Code follows project patterns (EventBus signals, Logger, typed GDScript)

**Admin Panel Complete:**
- [ ] ProgressionAdminPanel.tscn created with all buttons
- [ ] Unlock tier buttons (2, 3, 4, All) work correctly
- [ ] Set stage buttons (1/3, 2/3, 3/3) update deepest stage
- [ ] Simulate kills button adds leaderboard entry
- [ ] Add run count button increments per-tier counter
- [ ] Reset All button clears all progression (fresh player)
- [ ] Reset Current Tier button clears single tier data
- [ ] Admin panel syncs with tier selection UI
- [ ] All admin actions immediately refresh MapSelect detail panel

**Testing Complete:**
- [ ] Manual testing checklist passed (core + admin panel)
- [ ] Edge cases verified
- [ ] Fresh player flow tested (reset → unlock → progress)

**Commit Ready:**
- [ ] `feat(ui): add tier selection with progression admin panel`

**Ready for Task 5:**
- [ ] Tier UI foundation complete
- [ ] Can simulate entire progression flow via admin panel
- [ ] Easy to test stage progression when implemented

---

**Next Task:** [Task 5 - Full Stage Progression Integration](5_PROGRESSION_stage_progression_megabonk_integration.md)

**Related:** [MetaProgression System](../systems/MetaProgression-System.md) | [Task 3 - Quest System](3_PROGRESSION_quest_system_backend.md)
