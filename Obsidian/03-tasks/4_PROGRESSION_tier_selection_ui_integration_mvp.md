# Tier Selection UI Integration (MVP)

**Created:** 2025-10-03
**Status:** 🟡 Ready to Start
**Priority:** Medium
**Estimated Effort:** 30 minutes - 1 hour
**Category:** 🎮 Progression System - UI Integration

## 📋 Task Description

Wire up the existing tier selection UI in MapSelect to the MetaProgression backend. This is the minimal viable implementation to make tier unlocking functional without requiring complex stage progression systems.

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

## 📊 Testing Checklist

### Manual Testing
- [ ] Open MapSelect - Tier 1 enabled, Tier 2-4 disabled (fresh save)
- [ ] Select Tier 1 - detail panel shows "0 Runs", "-" deepest stage
- [ ] Start run, die immediately - return to MapSelect shows "1 Runs"
- [ ] Use CheatSystem to unlock Tier 2: `MetaProgression.unlock_tier(2)`
- [ ] Verify Tier 2 checkbox becomes enabled
- [ ] Select Tier 2 - detail panel updates to show Tier 2 stats
- [ ] Click Tier 1 again - Tier 2 unchecks (radio button behavior)
- [ ] Start run on Tier 2 - verify SessionState receives tier=2

### Edge Cases
- [ ] Switching tiers rapidly doesn't break UI state
- [ ] Detail panel handles missing data gracefully (shows "-")
- [ ] Tier 4 "unlimited" displays correctly ("Stage N" format)
- [ ] Run counter increments correctly per map+tier combination

## 🔗 Related Files

### Will Modify:
- [x] `scenes/ui/MapSelect.gd` - Add tier selection logic (~40 lines)

### Will NOT Modify (Already Implemented):
- [x] `scripts/resources/MetaProgressionData.gd` - Has tier tracking fields
- [x] `autoload/MetaProgression.gd` - Has tier management functions
- [x] `autoload/EventBus.gd` - Has `tier_unlocked` signal
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
- [ ] Tested manually with CheatSystem tier unlocks
- [ ] Commit ready: `feat(ui): wire tier selection to MetaProgression backend`

**Ready for Task 5:**
- [ ] Tier UI foundation complete
- [ ] Can unlock tiers manually for testing
- [ ] Stage progression can build on this foundation

---

**Next Task:** [Task 5 - Full Stage Progression Integration](5_PROGRESSION_stage_progression_megabonk_integration.md)

**Related:** [MetaProgression System](../systems/MetaProgression-System.md) | [Task 3 - Quest System](3_PROGRESSION_quest_system_backend.md)
