# Stage Progression MEGABONK Integration

**Created:** 2025-10-03
**Status:** 🔴 Blocked - Requires Task 4 + Ability System
**Priority:** High (After Prerequisites)
**Estimated Effort:** 1-2 weeks
**Category:** 🎮 Progression System - Full Integration

## 📋 Task Description

Implement the full MEGABONK-style stage progression system with boss-kill deadlines, portal unlocking, and optional swarm continuation. Integrates the tier system (Task 4) with time-based difficulty progression, allowing players to choose when to leave after killing the boss while enemies continue spawning.

**Updated Goal (Per User Feedback):**
- Boss spawns at ~5:00 (configurable)
- Boss death → Portal unlocks (enemies keep spawning)
- Player chooses when to enter portal (risk vs reward)
- Entering portal → Next stage or tier complete
- Total arena time: ~7 minutes (down from 8-10)
- Swarm continues after boss death (not "Final Swarm" punishment)

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
- [ ] Arena timer counts up from 0:00 (not down from 7:00)
- [ ] Boss spawns at configurable time (default 5:00)
- [ ] Boss death emits `EventBus.boss_killed` signal
- [ ] Portal spawns locked at stage start
- [ ] Portal unlocks on `boss_killed` signal (visual + functional state change)
- [ ] Portal entry emits `EventBus.portal_entered` signal
- [ ] Enemy spawning continues after boss death (no "Final Swarm" trigger)
- [ ] Player can choose when to enter portal (stay for more kills/loot)

### Stage Progression
- [ ] SessionState tracks `current_stage` (1/3, 2/3, 3/3)
- [ ] Portal entry advances to next stage if < 3
- [ ] Portal entry unlocks next tier if stage 3/3 complete
- [ ] Stage transition reloads arena with new procedural map
- [ ] Stage number displays in HUD ("Stage 1/3")
- [ ] Death at any stage → restart from stage 1 of current tier

### Tier Unlocking
- [ ] Completing stage 3/3 of Tier N → unlocks Tier N+1
- [ ] `MetaProgression.unlock_tier()` called on tier completion
- [ ] `EventBus.tier_unlocked` emitted
- [ ] MapSelect UI updates to show newly unlocked tier
- [ ] Player returns to MapSelect after tier completion

### UI & Feedback
- [ ] HUD shows current stage ("Stage 1/3" or "Stage 15" for Unlimited)
- [ ] HUD shows timer ("5:32" elapsed time)
- [ ] Portal visual state: locked (gray) vs unlocked (green/glowing)
- [ ] Portal interaction prompt ("Press E to Continue" when unlocked)
- [ ] "Boss Killed!" message on boss death
- [ ] "Portal Unlocked!" message when portal becomes accessible
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

### Phase 5: MapLevel Timer Integration (1-2 hours)

```gdscript
# autoload/MapLevel.gd
var elapsed_time: float = 0.0

func reset_level() -> void:
	"""Reset timer for new stage"""
	current_level = 1
	elapsed_time = 0.0
	Logger.info("MapLevel reset for new stage", "arena")

func get_elapsed_time() -> float:
	"""Get total elapsed time in seconds"""
	return elapsed_time

func _on_combat_step(payload) -> void:
	"""Update timer during combat"""
	if not _is_in_arena():
		return

	elapsed_time += RunManager.COMBAT_DT

	# Existing level progression code...
```

### Phase 6: HUD Integration (2-3 hours)

```gdscript
# scenes/ui/hud/StageProgressHUD.gd
extends Control

@onready var stage_label: Label = $StageLabel
@onready var timer_label: Label = $TimerLabel

func _ready() -> void:
	# Connect to SessionState updates
	EventBus.combat_step.connect(_update_display)

	# Initial update
	_update_display(null)

func _update_display(_payload) -> void:
	# Update stage display
	stage_label.text = "Stage %s" % SessionState.get_stage_display()

	# Update timer
	var elapsed = MapLevel.get_elapsed_time()
	var minutes = int(elapsed / 60)
	var seconds = int(elapsed) % 60
	timer_label.text = "%d:%02d" % [minutes, seconds]
```

## 🔒 BLOCKED - Prerequisite Requirements

### Task 4 - Tier Selection MVP (Must Complete First)
**Status:** Ready to Start
**Reason:** Provides tier unlock UI foundation and MetaProgression integration
**Blocking:** Cannot test tier completion flow without working tier selection

### Ability System (Critical Blocker)
**Status:** Not Started
**Reason:** Stage progression needs meaningful player power to scale against
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

### Phase 1: Foundation (Task 4 Complete) ✅
**Prerequisites:** None
**Deliverable:** Tier selection UI working

### Phase 2: Portal System (Can Start After Phase 1)
**Prerequisites:** Task 4 complete
**Deliverable:** Portal entity exists, unlocks on boss kill, players can enter

### Phase 3: Stage Tracking (Can Start After Phase 1)
**Prerequisites:** Task 4 complete
**Deliverable:** SessionState tracks stages, HUD shows progress

### Phase 4: Stage Transitions (Requires Procedural Maps)
**Prerequisites:** Portal + Stage Tracking + Map Generation
**Deliverable:** Portal entry loads new map for next stage

### Phase 5: Boss Spawn Timing (Can Start Anytime)
**Prerequisites:** None (uses existing BossSpawnManager)
**Deliverable:** Boss spawns at configurable time (~5:00)

### Phase 6: Tier Completion Flow (Requires All Above)
**Prerequisites:** All previous phases
**Deliverable:** Stage 3/3 completion unlocks next tier

### Phase 7: Ability Integration (BLOCKED - No Ability System)
**Prerequisites:** Ability system must exist first
**Deliverable:** Abilities persist across stages, loot drops work

### Phase 8: Difficulty Scaling (BLOCKED - No Ability System)
**Prerequisites:** Ability system + Player progression
**Deliverable:** Enemies scale with stage progression

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
- [ ] `autoload/SessionState.gd` - Add stage tracking (~50 lines)
- [ ] `autoload/MapLevel.gd` - Add timer reset and elapsed time tracking (~20 lines)
- [ ] `scripts/systems/BossSpawnManager.gd` - Add time-based spawning (~30 lines)
- [ ] `scenes/arena/Arena.gd` - Add portal + stage transition logic (~80 lines)
- [ ] `autoload/EventBus.gd` - Add `portal_unlocked`, `portal_entered` signals

### Will Create:
- [ ] `scenes/arena/Portal.tscn` - Portal entity with locked/unlocked states
- [ ] `scenes/arena/Portal.gd` - Portal interaction logic (~100 lines)
- [ ] `scenes/ui/hud/StageProgressHUD.tscn` - Stage + timer display
- [ ] `scenes/ui/hud/StageProgressHUD.gd` - HUD update logic (~40 lines)
- [ ] `data/balance/stage_progression.tres` - Configuration resource (future)

## ✅ Definition of Done

**MVP Stage Progression (Phases 1-6):**
- [ ] Portal spawns locked, unlocks on boss kill
- [ ] Enemy spawning continues after boss death
- [ ] Player can enter portal to advance stage
- [ ] Stage 1/3 → 2/3 → 3/3 progression works
- [ ] Stage 3/3 completion unlocks next tier
- [ ] HUD shows current stage and elapsed time
- [ ] Boss spawns at configurable time (~5:00)
- [ ] Death restarts from stage 1
- [ ] Code follows project patterns (EventBus, Logger, 30Hz fixed-step)

**Blocked Until Ability System:**
- [ ] Loot drops during stages (abilities, upgrades)
- [ ] Abilities persist across stages within run
- [ ] Difficulty scaling based on stage progression
- [ ] Risk/reward balance tuned
- [ ] Player has meaningful choices about when to leave

**Commit Ready:**
`feat(progression): implement stage progression with boss-kill portal unlocking - MEGABONK foundation (phases 1-6)`

---

**Prerequisites:** [Task 4 - Tier Selection MVP](4_PROGRESSION_tier_selection_ui_integration_mvp.md) | **Blocked By:** Ability System (Not Started)

**Related:** [MEGABONK Stage Progression Vision](../02-brainstorm/ARENA_PROGRESSION/STAGE_PROGRESSION_VISION.md) | [Task 2 - Difficulty Scaling](2_COMBAT_map_level_difficulty_scaling_integration.md)
