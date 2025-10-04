# 2b: Combat Stage Progression Flow

**Created:** 2025-10-03
**Updated:** 2025-10-03 (Renamed from `5_PROGRESSION_stage_progression_megabonk_integration.md`)
**Status:** 🔴 Blocked - Requires Task 3 + Task 1 + Ability System (Task 2)
**Priority:** High (After Prerequisites)
**Estimated Effort:** 1-2 weeks
**Category:** 🎮 Combat Progression - Full Integration
**Prerequisites:** [Task 3 - Timing Foundation](3_COMBAT_timing_foundation.md) ← **COMPLETE THIS FIRST** + [Task 1 - Tier Selection](1_PROGRESSION_tier_selection_ui_integration_mvp.md) + Ability System (Task 2)

> ⚠️ **Dependency:** This task builds on **Task 3's timing infrastructure** (stage timer, boss spawn, Final Swarm trigger). Task 3 Phases 1-3 **must be complete** before starting this task.

**⚠️ DESIGN DECISION PENDING:**
The Final Swarm mechanic needs playtesting with the ability system before finalizing. Two possible paths:
- **Path A (Simple)**: Hard time limit per stage → auto-end → force portal progression (no Final Swarm)
- **Path B (Complex)**: Optional Final Swarm risk/reward for kill farming (documented below)

**Decision Criteria:** Test with abilities first to see if Final Swarm difficulty is challenging enough to justify the risk.

## 📋 Task Description

Implement the full MEGABONK-style stage progression system with boss-kill deadlines, portal unlocking, and optional swarm continuation. Integrates the tier system (Task 1) with time-based difficulty progression, allowing players to choose when to leave after killing the boss while enemies continue spawning.

**Goal (Builds on Task 3 Timing Foundation):**
- **Timer**: 7:00 countdown (Task 3 provides MapLevel.get_remaining_time())
- **Boss Spawn**: 2:00 elapsed / 5:00 remaining (Task 3 triggers EventBus.boss_spawn_requested)
- **Boss Kill Requirement**: Boss MUST be killed before timer expires (medium difficulty)
- **Portal Unlock**: Boss death → Portal unlocks (enemies keep spawning - Task 3 continues spawns)
- **Final Swarm Phase**: 7:00 elapsed / 0:00 timer expiration (Task 3 triggers EventBus.final_swarm_started)
- **Risk/Reward Mechanic**: Stay after portal unlocks → more XP + meta-currency + leaderboard kills
- **Meta-Currency Multiplier**: Bar appears during Final Swarm - longer survival = higher multiplier
- **Special Enemy Swarms**: Final Swarm spawns elites (Task 3 handles spawn rate escalation)
- **Player Choice**: Enter portal anytime after boss kill, or stay for Final Swarm farming

**What Task 3 Provides (Prerequisites):**
- ✅ Stage timer (7:00 countdown)
- ✅ Boss spawn timing trigger (2:00 elapsed)
- ✅ Final Swarm trigger (0:00 = timer expiration)
- ✅ Enemy stat scaling over time
- ✅ Final Swarm spawn rate escalation

**What This Task Adds:**
- Portal entity + unlocking logic
- Stage progression (1/3 → 2/3 → 3/3)
- Tier unlocking on stage 3/3 completion
- Meta-currency reward calculation
- HUD display (stage counter, timer display)
- SessionState stage tracking

**Current State Analysis:**
- ✅ Task 4 (Tier Selection MVP) provides UI foundation
- ✅ MetaProgression has tier/stage tracking
- ✅ SessionState tracks run stats
- ✅ MapLevel exists for time-based progression
- ⚠️ No boss deadline system
- ⚠️ No portal entity/system
- ⚠️ No stage transition logic
- ⚠️ No stage counter in SessionState
- ⚠️ Ability system doesn't exist (prerequisite)

**Integration Requirements:**
- Boss spawning system must trigger at configurable time
- Portal entity must unlock on boss kill but not stop spawns
- Stage completion must transition to next stage OR unlock tier
- Player death restarts from stage 1 (roguelike)
- Difficulty scaling needs ability system to be meaningful

## 🎯 Acceptance Criteria

### Core Stage Flow
- [ ] Arena timer counts DOWN from 7:00 to 0:00
- [ ] Boss spawns at configurable time (default: 5:00 remaining on timer)
- [ ] Boss MUST be killed before timer reaches 0:00
- [ ] Boss death emits `EventBus.boss_killed` signal
- [ ] Portal spawns locked at stage start
- [ ] Portal unlocks on `boss_killed` signal (visual + functional state change)
- [ ] Portal entry emits `EventBus.portal_entered` signal
- [ ] Enemy spawning continues at normal rates after boss death
- [ ] At 0:00 timer expiration → Final Swarm phase begins
- [ ] Final Swarm escalates difficulty drastically over time
- [ ] Final Swarm spawns special/elite enemy types
- [ ] Player can enter portal anytime after boss kill (before or during Final Swarm)

### Stage Progression
- [ ] SessionState tracks `current_stage` (1/3, 2/3, 3/3)
- [ ] Portal entry advances to next stage if < 3
- [ ] Portal entry unlocks next tier if stage 3/3 complete
- [ ] Stage transition reloads arena with new procedural map
- [ ] Stage number displays in HUD ("Stage 1/3")
- [ ] Death at any point (including Final Swarm) → Results screen → Main menu
- [ ] Death means full run failure (roguelike death = game over)

### Tier Unlocking
- [ ] Completing stage 3/3 of Tier N → unlocks Tier N+1
- [ ] `MetaProgression.unlock_tier()` called on tier completion
- [ ] `EventBus.tier_unlocked` emitted
- [ ] MapSelect UI updates to show newly unlocked tier
- [ ] Player returns to MapSelect after tier completion

### UI & Feedback
- [ ] HUD shows current stage ("Stage 1/3" or "Stage 15" for Unlimited)
- [ ] HUD shows countdown timer ("5:32" remaining)
- [ ] Timer turns red/flashing when < 1:00 remaining
- [ ] Final Swarm multiplier bar appears at top-center during swarm phase
- [ ] Multiplier increases over time during Final Swarm (visual + numeric)
- [ ] Portal visual state: locked (gray) vs unlocked (green/glowing)
- [ ] Portal interaction prompt ("Press E to Continue" when unlocked)
- [ ] "Boss Killed!" message on boss death
- [ ] "Portal Unlocked!" message when portal becomes accessible
- [ ] "FINAL SWARM!" message when timer reaches 0:00
- [ ] "Stage Complete!" message on portal entry

## 🔍 Technical Implementation

### Phase 1: SessionState Stage Tracking (2-3 hours)

```gdscript
# autoload/SessionState.gd
const STAGES_PER_TIER: int = 3  # Matches MetaProgressionData.gd

var current_stage: int = 1  # 1/3, 2/3, 3/3

func start_run(character_id: String, map_id: String, tier: int) -> void:
	# Existing code...
	current_stage = 1  # Always start from stage 1
	_data.stage_reached = 1

func advance_stage() -> bool:
	"""Advance to next stage. Returns false if tier complete."""
	current_stage += 1

	# Update deepest stage for this tier
	MetaProgression.update_deepest_stage(current_tier, current_stage)

	# Check if tier complete
	if current_tier == 4:  # Unlimited tier
		return true  # Never complete, always continue

	if current_stage > STAGES_PER_TIER:
		# Tier complete!
		return false

	# More stages remaining
	_data.stage_reached = current_stage
	return true

func complete_tier() -> void:
	"""Called when all stages of a tier are finished."""
	Logger.info("Tier %d complete! Unlocking tier %d" % [current_tier, current_tier + 1], "progression")

	# Unlock next tier
	MetaProgression.unlock_tier(current_tier + 1)

	# Emit signal
	EventBus.tier_unlocked.emit(current_tier + 1)

func get_stage_display() -> String:
	"""Get display string for current stage"""
	if current_tier == 4:  # Unlimited
		return "Stage %d" % current_stage
	else:
		return "%d/%d" % [current_stage, STAGES_PER_TIER]
```

### Phase 2: Portal Entity (3-4 hours)

```gdscript
# scenes/arena/Portal.gd
extends Area2D
class_name Portal

@export var locked_texture: Texture2D
@export var unlocked_texture: Texture2D

@onready var sprite: Sprite2D = $Sprite2D
@onready var particles: GPUParticles2D = $UnlockedParticles
@onready var interaction_label: Label = $InteractionPrompt

var is_locked: bool = true
var player_in_range: bool = false

func _ready() -> void:
	# Start locked
	_set_locked_state(true)

	# Connect signals
	EventBus.boss_killed.connect(_on_boss_killed)
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

	# Hide interaction prompt initially
	interaction_label.visible = false

func _set_locked_state(locked: bool) -> void:
	is_locked = locked

	if locked:
		sprite.texture = locked_texture
		sprite.modulate = Color(0.5, 0.5, 0.5)  # Gray
		particles.emitting = false
	else:
		sprite.texture = unlocked_texture
		sprite.modulate = Color(1, 1, 1)  # Full color
		particles.emitting = true  # Green glow particles

	_update_interaction_prompt()

func _on_boss_killed(boss_id: String, position: Vector2) -> void:
	"""Boss died - unlock portal"""
	Logger.info("Boss killed, unlocking portal", "arena")
	_set_locked_state(false)

	# Visual feedback
	EventBus.notification_requested.emit("Portal Unlocked!", "success", 3.0)
	EventBus.portal_unlocked.emit()

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_in_range = true
		_update_interaction_prompt()

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_in_range = false
		_update_interaction_prompt()

func _update_interaction_prompt() -> void:
	interaction_label.visible = player_in_range and not is_locked

func _process(_delta: float) -> void:
	# Check for player interaction
	if player_in_range and not is_locked and Input.is_action_just_pressed("interact"):
		_enter_portal()

func _enter_portal() -> void:
	"""Player entered portal - trigger stage transition"""
	Logger.info("Player entered portal", "arena")

	# Emit signal
	EventBus.portal_entered.emit()

	# Portal can only be entered once
	player_in_range = false
	_update_interaction_prompt()
```

### Phase 3: Arena Stage Transition (4-5 hours)

```gdscript
# scenes/arena/Arena.gd (or StateManager.gd)
func _ready() -> void:
	# Existing code...

	# Connect portal signal
	EventBus.portal_entered.connect(_on_portal_entered)

func _on_portal_entered() -> void:
	"""Handle player entering portal - stage transition or tier complete"""
	Logger.info("Portal entered - checking stage progression", "arena")

	# Try to advance stage
	var can_continue: bool = SessionState.advance_stage()

	if can_continue:
		# More stages remaining - transition to next stage
		_transition_to_next_stage()
	else:
		# Tier complete! Unlock next tier and return to map select
		SessionState.complete_tier()
		SessionState.end_run()
		StateManager.go_to_map_select()

func _transition_to_next_stage() -> void:
	"""Reload arena with new procedural map for next stage"""
	Logger.info("Transitioning to stage %d/%d" % [SessionState.current_stage, SessionState.STAGES_PER_TIER], "arena")

	# Clear current enemies and projectiles
	EntityClearingService.clear_all_entities()

	# Generate new procedural map
	if ProceduralMapManager:
		var new_map = ProceduralMapManager.generate_map(SessionState.current_map)
		# Apply new map layout...

	# Reset arena state
	_reset_arena_for_new_stage()

	# Spawn new portal (locked)
	_spawn_portal()

	# Visual feedback
	EventBus.notification_requested.emit("Stage %s" % SessionState.get_stage_display(), "info", 2.0)

func _reset_arena_for_new_stage() -> void:
	"""Reset arena systems for new stage"""
	# Reset MapLevel timer
	MapLevel.reset_level()

	# Reset spawn director
	if _spawn_director:
		_spawn_director.reset()

	# Keep player HP/stats (this is where abilities would persist)
	# Player keeps all upgrades/abilities from previous stages

func _spawn_portal() -> void:
	"""Spawn portal entity in arena"""
	var portal_scene = preload("res://scenes/arena/Portal.tscn")
	var portal = portal_scene.instantiate()

	# Position portal at designated spawn point
	var portal_spawn = get_node_or_null("PortalSpawnPoint")
	if portal_spawn:
		portal.global_position = portal_spawn.global_position
	else:
		# Fallback: center of arena
		portal.global_position = Vector2(0, 0)

	add_child(portal)
```

### Phase 4: Boss Spawn Timing (2 hours)

```gdscript
# scripts/systems/BossSpawnManager.gd
@export var boss_spawn_time: float = 300.0  # 5:00 default (configurable)

var boss_spawned: bool = false

func _ready() -> void:
	# Connect to MapLevel time updates
	EventBus.combat_step.connect(_check_boss_spawn_time)

func _check_boss_spawn_time(payload) -> void:
	"""Check if it's time to spawn boss"""
	if boss_spawned:
		return

	var elapsed_time = MapLevel.get_elapsed_time()  # Seconds since stage start

	if elapsed_time >= boss_spawn_time:
		_spawn_boss()

func _spawn_boss() -> void:
	"""Spawn the boss for this stage"""
	boss_spawned = true

	Logger.info("Boss spawn time reached (%.1fs)" % boss_spawn_time, "bosses")

	# Select boss based on tier/stage
	var boss_id = _select_boss_for_tier(SessionState.current_tier)

	# Spawn boss at designated location
	var boss_spawn_point = get_node_or_null("BossSpawnPoint")
	var spawn_pos = boss_spawn_point.global_position if boss_spawn_point else Vector2(0, 0)

	# Emit signal (existing boss spawning logic handles the rest)
	EventBus.boss_spawned.emit(boss_id, spawn_pos)

	# Visual feedback
	EventBus.notification_requested.emit("Boss Spawned!", "warning", 3.0)
```

### Phase 5: HUD Timer Display Integration (1 hour)
**Note:** Timer infrastructure provided by Task 2a - this phase only adds UI display

**Task 2a Provides:**
- `MapLevel.get_remaining_time()` - Countdown (7:00 → 0:00)
- `MapLevel.get_elapsed_time()` - Seconds since stage start
- `MapLevel.is_timer_expired()` - Check if timer reached 7:00
- `MapLevel.reset_level()` - Reset for new stage
- `EventBus.timer_expired` - Signal when timer hits 7:00
- `EventBus.final_swarm_started` - Signal when Final Swarm begins

**This Phase Implementation:**
```gdscript
# scenes/ui/hud/StageProgressHUD.gd (Timer Display Only)
func _update_display(_payload) -> void:
	# Read timer from Task 2a's MapLevel
	var remaining = MapLevel.get_remaining_time()
	var minutes = int(remaining / 60)
	var seconds = int(remaining) % 60
	timer_label.text = "%d:%02d" % [minutes, seconds]

	# Turn red when < 1:00 remaining
	if remaining < 60.0 and remaining > 0.0:
		timer_label.add_theme_color_override("font_color", Color.RED)
	else:
		timer_label.add_theme_color_override("font_color", Color.WHITE)
```

**Implementation Steps:**
- [ ] Add timer display label to HUD
- [ ] Connect to EventBus.combat_step for updates
- [ ] Read MapLevel.get_remaining_time() (provided by Task 2a)
- [ ] Format as "M:SS" countdown display
- [ ] Turn red when < 1:00 remaining
- [ ] No timer logic implementation needed (Task 2a handles it)

### Phase 6: HUD Integration (2-3 hours)

```gdscript
# scenes/ui/hud/StageProgressHUD.gd
extends Control

@onready var stage_label: Label = $StageLabel
@onready var timer_label: Label = $TimerLabel
@onready var final_swarm_bar: ProgressBar = $FinalSwarmMultiplierBar

var in_final_swarm: bool = false
var swarm_survival_time: float = 0.0

func _ready() -> void:
	# Connect to SessionState updates
	EventBus.combat_step.connect(_update_display)
	EventBus.final_swarm_started.connect(_on_final_swarm_started)

	# Hide swarm bar initially
	final_swarm_bar.visible = false

	# Initial update
	_update_display(null)

func _update_display(_payload) -> void:
	# Update stage display
	stage_label.text = "Stage %s" % SessionState.get_stage_display()

	# Update countdown timer
	var remaining = MapLevel.get_remaining_time()
	var minutes = int(remaining / 60)
	var seconds = int(remaining) % 60
	timer_label.text = "%d:%02d" % [minutes, seconds]

	# Turn red when < 1:00 remaining
	if remaining < 60.0 and remaining > 0.0:
		timer_label.add_theme_color_override("font_color", Color.RED)
	else:
		timer_label.add_theme_color_override("font_color", Color.WHITE)

	# Update Final Swarm multiplier
	if in_final_swarm:
		swarm_survival_time += RunManager.COMBAT_DT
		var multiplier = 1.0 + (swarm_survival_time / 30.0)  # +0.033x per second
		final_swarm_bar.value = multiplier
		final_swarm_bar.tooltip_text = "Meta-Currency Multiplier: %.2fx" % multiplier

func _on_final_swarm_started() -> void:
	"""Final Swarm phase started - show multiplier bar"""
	in_final_swarm = true
	final_swarm_bar.visible = true
	swarm_survival_time = 0.0
	Logger.info("Final Swarm UI activated", "ui")
```

### Phase 7: Final Swarm Spawn Escalation (3-4 hours)

```gdscript
# scripts/systems/SpawnDirector.gd (or new FinalSwarmManager.gd)
extends Node

@export var swarm_escalation_rate: float = 0.05  # +5% spawn rate per second
@export var swarm_damage_multiplier: float = 1.5  # 1.5x damage in swarm
@export var swarm_hp_multiplier: float = 1.3  # 1.3x HP in swarm

var in_final_swarm: bool = false
var swarm_intensity: float = 1.0  # Multiplier that increases over time

func _ready() -> void:
	EventBus.final_swarm_started.connect(_on_final_swarm_started)
	EventBus.combat_step.connect(_update_swarm_intensity)

func _on_final_swarm_started() -> void:
	"""Final Swarm triggered - activate elite spawn mode"""
	in_final_swarm = true
	swarm_intensity = 1.0
	Logger.warn("Final Swarm spawning activated - elite enemies incoming!", "spawning")

	# Emit signal to spawn director to switch to elite-only spawns
	EventBus.spawn_mode_changed.emit("final_swarm")

func _update_swarm_intensity(_payload) -> void:
	"""Escalate swarm difficulty over time"""
	if not in_final_swarm:
		return

	# Increase intensity every combat step
	swarm_intensity += swarm_escalation_rate * RunManager.COMBAT_DT

	# Cap at 5x intensity (after ~80 seconds of Final Swarm)
	swarm_intensity = min(swarm_intensity, 5.0)

func get_swarm_spawn_multiplier() -> float:
	"""Get current spawn rate multiplier for Final Swarm"""
	return swarm_intensity if in_final_swarm else 1.0

func get_enemy_stat_modifiers() -> Dictionary:
	"""Get stat modifiers for enemies spawned during Final Swarm"""
	if not in_final_swarm:
		return {"hp": 1.0, "damage": 1.0}

	return {
		"hp": swarm_hp_multiplier,
		"damage": swarm_damage_multiplier,
		"speed": 1.1  # 10% faster
	}
```

### Phase 8: Meta-Currency Reward Calculation (2 hours)

```gdscript
# autoload/SessionState.gd
var final_swarm_survival_time: float = 0.0
var boss_killed_before_timer: bool = false

func _ready() -> void:
	EventBus.final_swarm_started.connect(_on_final_swarm_started)
	EventBus.boss_killed.connect(_on_boss_killed)
	EventBus.combat_step.connect(_track_swarm_time)

func _on_boss_killed(_boss_id: String, _position: Vector2) -> void:
	"""Track if boss was killed before timer expiration"""
	if not MapLevel.is_timer_expired():
		boss_killed_before_timer = true

func _on_final_swarm_started() -> void:
	"""Start tracking Final Swarm survival time"""
	final_swarm_survival_time = 0.0

func _track_swarm_time(_payload) -> void:
	"""Track how long player survives in Final Swarm"""
	if MapLevel.in_final_swarm:
		final_swarm_survival_time += RunManager.COMBAT_DT

func calculate_meta_currency_bonus() -> int:
	"""Calculate bonus meta-currency from Final Swarm survival"""
	if final_swarm_survival_time <= 0.0:
		return 0

	# Base meta-currency from stage completion
	var base_currency = 10 * current_tier  # Tier 1=10, Tier 2=20, etc.

	# Multiplier from Final Swarm survival (+0.033x per second)
	var multiplier = 1.0 + (final_swarm_survival_time / 30.0)

	# Penalty if boss not killed before timer expiration
	if not boss_killed_before_timer:
		multiplier *= 0.5  # 50% penalty for failing boss deadline

	# Total bonus
	var total = int(base_currency * multiplier)

	Logger.info("Final Swarm bonus: %d meta-currency (%.2fx multiplier, %.1fs survival, deadline met: %s)" % [total, multiplier, final_swarm_survival_time, boss_killed_before_timer], "progression")

	return total

func end_run() -> void:
	"""End the run and calculate final rewards"""
	# Calculate Final Swarm bonus
	var swarm_bonus = calculate_meta_currency_bonus()

	# Grant meta-currency
	if swarm_bonus > 0:
		MetaProgression.add_currency(swarm_bonus)
		Logger.info("Granted %d meta-currency for Final Swarm survival" % swarm_bonus, "progression")

	# Existing end_run code...
```

### Phase 9: Boss Deadline Failure Handling (1 hour)

```gdscript
# scenes/arena/Portal.gd
func _on_boss_killed(boss_id: String, position: Vector2) -> void:
	"""Boss died - unlock portal (can happen during Final Swarm too)"""
	Logger.info("Boss killed, unlocking portal", "arena")
	_set_locked_state(false)

	# Check if boss was killed in time
	if MapLevel.is_timer_expired():
		# Boss killed during Final Swarm (comeback mechanic)
		EventBus.notification_requested.emit("Boss Defeated! Portal Unlocked! (Late)", "warning", 3.0)
	else:
		# Boss killed before timer expiration (normal flow)
		EventBus.notification_requested.emit("Portal Unlocked!", "success", 3.0)

	EventBus.portal_unlocked.emit()
```

---

## 🔀 Alternative Implementation: Path A (Simplified)

**If Phase 0 playtest determines Final Swarm is too complex or not fun enough:**

### Simplified Flow (No Final Swarm)
1. **7:00 countdown timer** per stage
2. **Boss spawns at 5:00** (2 minutes remaining)
3. **Boss must be killed** before timer reaches 0:00
4. **Boss death → Portal unlocks** (same as Path B)
5. **At 0:00 → Stage auto-ends** (forced portal entry OR run failure if boss alive)

### Simplified Implementation Changes

**Remove These Phases:**
- ❌ Phase 6: Final Swarm Timer Trigger
- ❌ Phase 7: Final Swarm Spawn Escalation
- ❌ Phase 8: Meta-Currency Multiplier
- ❌ Phase 9: Boss Deadline Failure Handling

**Add This Phase:**
- ✅ **Phase 6 (Simplified): Hard Time Limit**

```gdscript
# autoload/MapLevel.gd
func _on_combat_step(payload) -> void:
	"""Update timer during combat"""
	if not _is_in_arena():
		return

	elapsed_time += RunManager.COMBAT_DT

	# Check for hard time limit
	if elapsed_time >= STAGE_TIME_LIMIT:
		_trigger_stage_timeout()

func _trigger_stage_timeout() -> void:
	"""Timer expired - force stage end"""
	Logger.warn("Stage time limit reached!", "arena")

	# Check if boss was killed
	if _is_boss_alive():
		# Boss still alive → run failure
		EventBus.run_failed.emit("Time Limit Exceeded")
		SessionState.end_run()
	else:
		# Boss dead → auto-portal to next stage
		EventBus.notification_requested.emit("Time Limit! Auto-advancing...", "warning", 2.0)
		EventBus.portal_entered.emit()  # Force portal entry
```

**Benefits of Path A:**
- ✅ Simpler to implement (~30% less code)
- ✅ Faster to ship (no Final Swarm tuning needed)
- ✅ Clearer progression pacing (no decision paralysis at portal)
- ✅ Forces players through stages efficiently

**Drawbacks of Path A:**
- ❌ No optional risk/reward mechanic
- ❌ No meta-currency farming multiplier
- ❌ Less skill expression (can't "greed" for more kills)
- ❌ Leaderboards purely depend on Unlimited tier farming

---

## 🔒 BLOCKED - Prerequisite Requirements

### Task 4 - Tier Selection MVP (Must Complete First)
**Status:** Ready to Start
**Reason:** Provides tier unlock UI foundation and MetaProgression integration
**Blocking:** Cannot test tier completion flow without working tier selection

### Ability System (Critical Blocker - HIGHEST PRIORITY)
**Status:** Not Started
**Reason:** Cannot validate Final Swarm design without abilities to test difficulty
**Impact:**
- Without abilities, stages feel identical (no progression)
- No reason to stay after boss kill (no loot/upgrades to collect)
- Difficulty scaling meaningless without player power curve
- Risk/reward balance doesn't work (no "reward" for taking risks)

**Required Ability System Features:**
- [ ] Ability pickup/discovery during runs
- [ ] Ability upgrading system
- [ ] Persistent abilities across stages within a run
- [ ] Scaling effects tied to difficulty/stage progression
- [ ] Loot drops from enemies (abilities, upgrades, items)

### Player Progression System (High Priority Blocker)
**Status:** Not Started
**Reason:** Need power scaling to justify difficulty progression
**Required Features:**
- [ ] In-run XP and leveling
- [ ] Stat upgrades (HP, damage, speed)
- [ ] Resource management (mana, energy, etc.)
- [ ] Defensive stats (armor, resistance)

### Procedural Map Generation (Medium Priority)
**Status:** Partial (forest biome exists)
**Reason:** Stage transitions need new map layouts
**Required Features:**
- [ ] Multiple map variants per biome
- [ ] Stage-specific layouts
- [ ] Portal spawn point designation
- [ ] Boss spawn point designation

## 📊 Implementation Phases

### Phase 0: Design Validation (REQUIRED FIRST) 🔴
**Prerequisites:** Ability system complete
**Deliverable:** Playtest to determine Final Swarm viability
**Actions:**
1. Implement basic ability system
2. Manually trigger Final Swarm conditions in Arena
3. Test if difficulty escalation is fun/challenging with abilities
4. Measure if kill farming during Final Swarm is worth the death risk
5. **Decision**: Keep Final Swarm (Phases 1-10) OR switch to hard time limit (simplified Path A)

**Key Questions to Answer:**
- Is Final Swarm difficult enough to feel risky with abilities?
- Do players have meaningful choices about when to leave?
- Does kill farming in Final Swarm feel rewarding vs just portaling to next stage?
- Would leaderboards work better with Unlimited tier only, or across all tiers?

### Phase 1: Foundation (Task 4 Complete) ✅
**Prerequisites:** None
**Deliverable:** Tier selection UI working

### Phase 2: Portal System (Can Start After Phase 1)
**Prerequisites:** Task 4 complete
**Deliverable:** Portal entity exists, unlocks on boss kill, players can enter

### Phase 3: Stage Tracking (Can Start After Phase 1)
**Prerequisites:** Task 4 complete
**Deliverable:** SessionState tracks stages, HUD shows countdown timer

### Phase 4: Stage Transitions (Requires Procedural Maps)
**Prerequisites:** Portal + Stage Tracking + Map Generation
**Deliverable:** Portal entry loads new map for next stage

### Phase 5: Boss Spawn Timing (Can Start Anytime)
**Prerequisites:** None (uses existing BossSpawnManager)
**Deliverable:** Boss spawns at 5:00 (configurable countdown time)

### Phase 6: Final Swarm Timer Trigger (Can Start After Phase 3)
**Prerequisites:** MapLevel countdown timer
**Deliverable:** At 0:00 timer expiration, Final Swarm phase begins

### Phase 7: Final Swarm Spawn Escalation (Can Start After Phase 6)
**Prerequisites:** Final Swarm trigger working
**Deliverable:** Elite enemy spawns increase over time, stat modifiers applied

### Phase 8: Meta-Currency Multiplier (Can Start After Phase 7)
**Prerequisites:** Final Swarm system
**Deliverable:** Survival time calculates meta-currency bonus, multiplier UI shows

### Phase 9: Boss Deadline Failure Handling (Can Start After Phase 6)
**Prerequisites:** Final Swarm trigger + Boss spawning
**Deliverable:** Boss can be killed during Final Swarm (comeback mechanic), portal unlocks with penalty

### Phase 10: Tier Completion Flow (Requires Phases 2-5)
**Prerequisites:** Portal + Stage Tracking + Boss Spawning
**Deliverable:** Stage 3/3 completion unlocks next tier

### Phase 11: Ability Integration (BLOCKED - No Ability System)
**Prerequisites:** Ability system must exist first
**Deliverable:** Abilities persist across stages, loot drops work

### Phase 12: Advanced Difficulty Scaling (BLOCKED - No Ability System)
**Prerequisites:** Ability system + Player progression
**Deliverable:** Enemies scale with stage progression, balanced against player power

## 📝 Configuration

### BalanceDB Integration (Future)
```gdscript
# data/balance/stage_progression.tres
class_name StageProgressionConfig extends Resource

@export var stages_per_tier: int = 3
@export var boss_spawn_time: float = 300.0  # 5:00
@export var total_arena_time: float = 420.0  # 7:00 total
@export var stage_time_multiplier: float = 1.0  # Scale time per stage

# Difficulty progression (requires ability system)
@export var enemy_hp_per_stage: float = 0.15  # +15% HP per stage
@export var enemy_damage_per_stage: float = 0.10  # +10% damage per stage
```

## 🔗 Related Files

### Will Modify:
- [ ] `autoload/SessionState.gd` - Add stage tracking + Final Swarm rewards (~80 lines)
- [ ] `autoload/MapLevel.gd` - Add countdown timer + Final Swarm trigger (~40 lines)
- [ ] `scripts/systems/BossSpawnManager.gd` - Add time-based spawning (~30 lines)
- [ ] `scenes/arena/Arena.gd` - Add portal + stage transition logic (~80 lines)
- [ ] `autoload/EventBus.gd` - Add `portal_unlocked`, `portal_entered`, `final_swarm_started`, `spawn_mode_changed` signals
- [ ] `scripts/systems/SpawnDirector.gd` - Add Final Swarm escalation (~60 lines)

### Will Create:
- [ ] `scenes/arena/Portal.tscn` - Portal entity with locked/unlocked states
- [ ] `scenes/arena/Portal.gd` - Portal interaction logic (~100 lines)
- [ ] `scenes/ui/hud/StageProgressHUD.tscn` - Stage + countdown timer + multiplier bar
- [ ] `scenes/ui/hud/StageProgressHUD.gd` - HUD update logic with Final Swarm multiplier (~60 lines)
- [ ] `scripts/systems/FinalSwarmManager.gd` - Final Swarm escalation logic (~80 lines) (optional separate file)
- [ ] `data/balance/stage_progression.tres` - Configuration resource (future)

## ✅ Definition of Done

**MVP Stage Progression (Phases 1-10):**
- [ ] Portal spawns locked, unlocks on boss kill
- [ ] Enemy spawning continues at normal rates after boss death
- [ ] Player can enter portal to advance stage
- [ ] Stage 1/3 → 2/3 → 3/3 progression works
- [ ] Stage 3/3 completion unlocks next tier
- [ ] HUD shows current stage and countdown timer (7:00 → 0:00)
- [ ] Boss spawns at configurable time (default: 5:00 remaining)
- [ ] Final Swarm triggers at 0:00 timer expiration
- [ ] Final Swarm escalates spawn rates over time
- [ ] Final Swarm spawns elite/special enemy types
- [ ] Meta-currency multiplier calculates from Final Swarm survival time
- [ ] Multiplier UI bar displays at top-center during Final Swarm
- [ ] Death restarts from stage 1
- [ ] Timer turns red when < 1:00 remaining
- [ ] Code follows project patterns (EventBus, Logger, 30Hz fixed-step)

**Boss Kill Failure Case:**
- [ ] If boss not killed before 0:00 → Final Swarm starts
- [ ] Portal remains locked if boss never killed
- [ ] Player must kill boss DURING Final Swarm to unlock portal
- [ ] This creates high-pressure comeback mechanic

**Death & Run End:**
- [ ] Death at any point (normal spawns, boss fight, Final Swarm) → end run immediately
- [ ] Show results screen with stats (kills, time survived, meta-currency earned)
- [ ] Grant meta-currency earned (including any Final Swarm bonuses accumulated before death)
- [ ] Return to main menu (standard roguelike death = game over)
- [ ] No checkpoints, no continues - death means full run restart

**Leaderboard Integration (Already Implemented ✅):**
- ✅ `LocalLeaderboard.gd` already tracks kills per map+tier
- ✅ UI displays top 10 runs by kill count (Friends tab in MainMenu)
- ✅ SessionState auto-submits runs to LocalLeaderboard on `end_run()`
- ✅ Leaderboard sorts by `rift_fragments_earned` (primary), then `stage_reached` (secondary)
- ✅ Tracks: character_id, kills, stage_reached, time_survived, final_swarm_entered, rift_fragments_earned
- [ ] **Note:** Global online leaderboards deferred to separate future task

**Blocked Until Design Validation (Phase 0):**
- [ ] **DECISION**: Keep Final Swarm (complex) OR use hard time limit (simple)?
- [ ] Playtest with abilities to determine which path to take
- [ ] Tune Final Swarm difficulty if keeping it
- [ ] Verify `final_swarm_entered` field in LocalLeaderboard gets populated correctly

**If Keeping Final Swarm (Path B):**
- [ ] Loot drops during stages (abilities, upgrades)
- [ ] Abilities persist across stages within run
- [ ] Final Swarm difficulty scaled to ability power
- [ ] Meta-currency multiplier tuned to feel rewarding

**If Using Hard Time Limit (Path A - Simplified):**
- [ ] Remove Phases 6-9 (Final Swarm system)
- [ ] Add hard time limit → auto-end stage → force portal entry
- [ ] Simpler implementation, faster to ship

**Commit Ready (If Path B):**
`feat(progression): implement full MEGABONK stage progression with Final Swarm mechanics (phases 1-10)`

**Commit Ready (If Path A):**
`feat(progression): implement stage progression with boss-kill portal unlocking (phases 1-5, simplified)`

---

**Prerequisites:** [Task 2a - Timing Foundation (REQUIRED)](2a_COMBAT_timing_foundation.md) ← **COMPLETE THIS FIRST** | [Task 4 - Tier Selection MVP](4_PROGRESSION_tier_selection_ui_integration_mvp.md) | **Blocked By:** Ability System (Not Started)

**Related:** [MEGABONK Stage Progression Vision](../02-brainstorm/ARENA_PROGRESSION/STAGE_PROGRESSION_VISION.md) | [Task 2a - Timing Foundation (DEPENDENCY)](2a_COMBAT_timing_foundation.md)

---

## 🔗 Task 2a Dependency (Timing Foundation)

**This task REQUIRES Task 2a Phases 1-3 to be complete first.** Task 2a provides the timing engine, this task adds the progression flow on top.

### What Task 2a Provides (Prerequisites):
- ✅ MapLevel.get_elapsed_time() - Seconds since stage start
- ✅ MapLevel.get_remaining_time() - Countdown (7:00 → 0:00)
- ✅ MapLevel.is_timer_expired() - Check if timer reached 7:00
- ✅ MapLevel.reset_level() - Reset for new stage
- ✅ MapLevel.get_difficulty_coefficient() - Current difficulty
- ✅ EventBus.timer_expired - Signal when 7:00 elapsed
- ✅ EventBus.boss_spawn_requested - Signal at 2:00 elapsed
- ✅ EventBus.final_swarm_started - Signal when Final Swarm begins
- ✅ Enemy stat scaling during Final Swarm (HP/damage multipliers)
- ✅ Spawn rate escalation during Final Swarm (3x → 5x → 9x)

### What This Task Adds (Progression Flow):
- Portal entity (locked/unlocked states)
- Portal unlocking on boss kill (EventBus.boss_killed listener)
- Portal entry handling (stage transition or tier completion)
- Stage tracking in SessionState (1/3, 2/3, 3/3)
- Tier unlocking on stage 3/3 completion
- Meta-currency reward calculation (Final Swarm survival bonus)
- HUD display (stage counter, timer display using Task 2's API)
- Arena reset for new stage (calls MapLevel.reset_level())

### Shared Configuration:
Both tasks must use these values:
- `STAGE_DURATION = 420.0` (7:00 total)
- `BOSS_SPAWN_TIME = 120.0` (2:00 elapsed = 5:00 remaining)
- `FINAL_SWARM_TRIGGER = 420.0` (7:00 elapsed = 0:00 remaining)
