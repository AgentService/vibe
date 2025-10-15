extends Node

## Session-only state for single-run progression (Task 04 Phase 2)
## Tracks ephemeral run stats that reset on death - no persistence across runs.
##
## Replaces RunManager's stats tracking responsibility while preserving 30Hz timing.
##
## KEY DIFFERENCES FROM OLD SYSTEM:
## - Session-only: No save/load, wipes on death
## - Separated from RunManager: RunManager only handles 30Hz timing now
## - Rift Fragments calculation: Incorporates tier multipliers and bonuses
## - Damage breakdown: Per-ability tracking for end-of-run screen

const COMBAT_DT: float = 1.0 / 30.0  # Reference to RunManager's timing

# Run lifecycle
var _run_active: bool = false
var run_start_time: float = 0.0

# Current run state
var current_character: String = ""
var current_map: String = ""
var current_tier: int = 1  # 1, 2, or 3

# Player progression (session-only)
var current_level: int = 1
var current_xp: float = 0.0
var xp_to_next_level: float = 100.0

# Run statistics
var kills: int = 0
var damage_dealt: float = 0.0
var time_survived: float = 0.0
var stage_reached: int = 1

# Collected items/skills this run
var collected_items: Array[String] = []
var chosen_skills: Array[String] = []

# Damage breakdown per ability/source
# Structure: {"ability_id": {"total_damage": int, "hit_count": int, "level": int}}
# Currently tracks by target ID (enemy_1, enemy_2, etc.)
# TODO(Ability System): Extend DamageDealtPayload with "ability_id" field for proper ability tracking
var damage_breakdown: Dictionary = {}

# Player modifiers (migrated from RunManager.stats)
var player_modifiers: Dictionary = {}

# Arena progression tracking (see STAGE_PROGRESSION_VISION.md)
var boss_killed: bool = false
var boss_kill_time: float = 0.0  # Timestamp when boss was killed
var final_swarm_entered: bool = false
var final_swarm_survival_time: float = 0.0
var difficulty_shrines_activated: int = 0

# XP curve configuration
var _max_level: int = 30
var _xp_base: float = 100.0
var _xp_multiplier: float = 1.15


func _ready() -> void:
	Logger.info("SessionState initializing", "progression")
	process_mode = Node.PROCESS_MODE_PAUSABLE  # Pause with game

	# Connect to EventBus for stat tracking
	EventBus.enemy_killed.connect(_on_enemy_killed)
	EventBus.damage_dealt.connect(_on_damage_dealt)
	EventBus.xp_gained.connect(_on_xp_gained)

	# Load player modifiers from BalanceDB
	if BalanceDB:
		BalanceDB.balance_reloaded.connect(_load_player_modifiers)
		if BalanceDB._data.has("player"):
			_load_player_modifiers()
		else:
			call_deferred("_try_load_player_modifiers")

	Logger.info("SessionState initialized", "progression")


func _exit_tree() -> void:
	# Cleanup signal connections
	if BalanceDB and BalanceDB.balance_reloaded.is_connected(_load_player_modifiers):
		BalanceDB.balance_reloaded.disconnect(_load_player_modifiers)
	if EventBus.enemy_killed.is_connected(_on_enemy_killed):
		EventBus.enemy_killed.disconnect(_on_enemy_killed)
	if EventBus.damage_dealt.is_connected(_on_damage_dealt):
		EventBus.damage_dealt.disconnect(_on_damage_dealt)
	if EventBus.xp_gained.is_connected(_on_xp_gained):
		EventBus.xp_gained.disconnect(_on_xp_gained)


func _try_load_player_modifiers() -> void:
	if BalanceDB and BalanceDB._data.has("player"):
		_load_player_modifiers()


func _load_player_modifiers() -> void:
	"""Load player stat modifiers from BalanceDB"""
	player_modifiers = {
		"projectile_count_add": BalanceDB.player.projectile_count_add,
		"projectile_speed_mult": BalanceDB.player.projectile_speed_mult,
		"fire_rate_mult": BalanceDB.player.fire_rate_mult,
		"damage_mult": BalanceDB.player.damage_mult,
		"has_projectiles": false,
		"melee_damage_add": 0.0,
		"melee_damage_mult": 1.0,
		"melee_attack_speed_add": 0.0,
		"melee_range_add": 0.0,
		"melee_cone_angle_add": 0.0,
	}
	Logger.debug("Player modifiers loaded from BalanceDB", "progression")


# ═══════════════════════════════════════════════════════════════════
# RUN LIFECYCLE
# ═══════════════════════════════════════════════════════════════════

## Starts a new run with given character, map, and tier
func start_run(character_id: String, map_id: String, tier: int) -> void:
	reset()

	current_character = character_id
	current_map = map_id
	current_tier = tier
	run_start_time = Time.get_ticks_msec() / 1000.0
	_run_active = true

	# Increment character run count in MetaProgression
	MetaProgression.increment_character_runs(character_id)

	Logger.info("Run started: %s on %s (Tier %d)" % [character_id, map_id, tier], "progression")
	EventBus.run_started.emit(character_id)


## Ends the run and calculates final stats + Rift Fragments
func end_run() -> void:
	if not _run_active:
		Logger.warn("end_run() called but no run active", "progression")
		return

	_run_active = false

	# Calculate final time survived
	var current_time = Time.get_ticks_msec() / 1000.0
	time_survived = current_time - run_start_time

	# Calculate Rift Fragments earned
	var fragments_earned = calculate_rift_fragments_earned()

	# Award Rift Fragments
	MetaProgression.earn_rift_fragments(fragments_earned)

	# Add to leaderboard (Phase 3 will implement LocalLeaderboard)
	# LocalLeaderboard.add_entry(get_final_stats())

	# Emit run ended signal with stats
	var final_stats = get_final_stats()
	EventBus.run_ended.emit(final_stats)

	Logger.info("Run ended: %d kills, %.1fs survived, %d Rift Fragments earned" % [
		kills, time_survived, fragments_earned
	], "progression")


## Returns whether a run is currently active
func is_run_active() -> bool:
	return _run_active


## Resets all session state
func reset() -> void:
	_run_active = false
	run_start_time = 0.0

	current_character = ""
	current_map = ""
	current_tier = 1

	current_level = 1
	current_xp = 0.0
	xp_to_next_level = _calculate_xp_for_level(2)

	kills = 0
	damage_dealt = 0.0
	time_survived = 0.0
	stage_reached = 1

	collected_items.clear()
	chosen_skills.clear()
	damage_breakdown.clear()

	boss_killed = false
	boss_kill_time = 0.0
	final_swarm_entered = false
	final_swarm_survival_time = 0.0
	difficulty_shrines_activated = 0

	# Reset player modifiers to BalanceDB defaults
	_load_player_modifiers()

	Logger.debug("SessionState reset", "progression")


# ═══════════════════════════════════════════════════════════════════
# STAT TRACKING (Migrated from RunManager)
# ═══════════════════════════════════════════════════════════════════

## Tracks enemy kill (called by EventBus.enemy_killed)
func _on_enemy_killed(_pos: Vector2, _xp_value: int) -> void:
	kills += 1


## Tracks damage dealt (called by EventBus.damage_dealt)
func _on_damage_dealt(payload) -> void:
	# Only track player damage
	if payload.source == "player":
		damage_dealt += int(payload.damage)

		# Track damage breakdown by ability/source
		# For now, use target as ability identifier (will be extended when ability system is added)
		# TODO(Ability System): When DamageDealtPayload has ability_id field, use that instead of target
		var ability_id = payload.target

		if not damage_breakdown.has(ability_id):
			damage_breakdown[ability_id] = {
				"total_damage": 0,
				"hit_count": 0,
				"level": 1  # Will be populated by ability system later
			}

		damage_breakdown[ability_id]["total_damage"] += int(payload.damage)
		damage_breakdown[ability_id]["hit_count"] += 1


## Tracks XP gained (called by EventBus.xp_gained)
func _on_xp_gained(amount: float, _new_total: float) -> void:
	current_xp += amount

	# Check for level up
	while current_level < _max_level:
		var next_level_total_xp = _calculate_xp_for_level(current_level + 1)
		if current_xp < next_level_total_xp:
			break
		_level_up()


## Adds kill to counter (alternative to signal-based tracking)
func add_kill() -> void:
	kills += 1


## Adds damage to total and per-ability breakdown
func add_damage(ability_id: String, amount: float, ability_level: int) -> void:
	damage_dealt += amount

	# Update damage breakdown
	if not damage_breakdown.has(ability_id):
		damage_breakdown[ability_id] = {
			"level": ability_level,
			"total_damage": 0.0,
			"hit_count": 0
		}

	damage_breakdown[ability_id]["total_damage"] += amount
	damage_breakdown[ability_id]["hit_count"] += 1
	damage_breakdown[ability_id]["level"] = ability_level  # Update to latest level


## Adds XP and handles leveling (alternative to signal-based tracking)
func add_xp(amount: float) -> void:
	current_xp += amount
	EventBus.xp_gained.emit(amount, current_xp)

	# Check for level up
	while current_level < _max_level:
		var next_level_total_xp = _calculate_xp_for_level(current_level + 1)
		if current_xp < next_level_total_xp:
			break
		_level_up()


## Collects an item during the run
func collect_item(item_id: String) -> void:
	if item_id not in collected_items:
		collected_items.append(item_id)
		Logger.debug("Item collected: %s" % item_id, "progression")


## Chooses a skill during the run (for unlock eligibility)
func choose_skill(skill_id: String) -> void:
	if skill_id not in chosen_skills:
		chosen_skills.append(skill_id)
		Logger.debug("Skill chosen: %s" % skill_id, "progression")


## Applies a modifier to player stats
func apply_modifier(key: String, value: float) -> void:
	player_modifiers[key] = value
	Logger.debug("Modifier applied: %s = %.2f" % [key, value], "progression")


## Gets DPS for a specific ability
func get_dps_for_ability(ability_id: String) -> float:
	if not damage_breakdown.has(ability_id):
		return 0.0

	if time_survived <= 0.0:
		return 0.0

	var ability_data = damage_breakdown[ability_id]
	return ability_data["total_damage"] / time_survived


## Gets damage breakdown sorted by total damage (descending)
## Returns Array[Dictionary] with ability_id added to each entry
func get_sorted_damage_breakdown() -> Array[Dictionary]:
	var sorted_breakdown: Array[Dictionary] = []

	for ability_id in damage_breakdown.keys():
		var entry = damage_breakdown[ability_id].duplicate()
		entry["ability_id"] = ability_id
		entry["dps"] = get_dps_for_ability(ability_id)
		sorted_breakdown.append(entry)

	# Sort by total damage descending
	sorted_breakdown.sort_custom(func(a, b): return a["total_damage"] > b["total_damage"])

	return sorted_breakdown


# ═══════════════════════════════════════════════════════════════════
# LEVELING SYSTEM (Session-Only)
# ═══════════════════════════════════════════════════════════════════

func _level_up() -> void:
	var prev_level = current_level
	current_level += 1

	# Update XP threshold for next level
	xp_to_next_level = _calculate_xp_for_level(current_level + 1)

	Logger.info("Player leveled up: %d → %d" % [prev_level, current_level], "progression")
	EventBus.session_level_up.emit(current_level)


func _calculate_xp_for_level(target_level: int) -> float:
	"""Calculate total XP required to reach target level"""
	if target_level <= 1:
		return 0.0

	var total_xp: float = 0.0
	for level in range(1, target_level):
		total_xp += _xp_base * pow(_xp_multiplier, level - 1)

	return total_xp


# ═══════════════════════════════════════════════════════════════════
# RIFT FRAGMENTS CALCULATION
# ═══════════════════════════════════════════════════════════════════

## Calculates Rift Fragments earned based on run performance
func calculate_rift_fragments_earned() -> int:
	var base_fragments: int = 0

	# Base fragments per stage completion
	base_fragments += stage_reached * 10

	# Kill count bonus: +1 per 100 kills
	base_fragments += int(kills / 100.0)

	# Survival time bonus: +1 per minute
	base_fragments += int(time_survived / 60.0)

	# Final Swarm survival bonus: +10 if survived/entered
	if final_swarm_entered:
		base_fragments += 10

	# Apply tier multiplier
	var tier_multiplier: float = 1.0
	match current_tier:
		1:
			tier_multiplier = 1.0
		2:
			tier_multiplier = 1.1  # +10% for tier 2
		3:
			tier_multiplier = 1.2  # +20% for tier 3

	var final_fragments = int(base_fragments * tier_multiplier)

	Logger.debug("Rift Fragments calculation: base=%d, tier_mult=%.1f, final=%d" % [
		base_fragments, tier_multiplier, final_fragments
	], "progression")

	return final_fragments


# ═══════════════════════════════════════════════════════════════════
# FINAL STATS EXPORT
# ═══════════════════════════════════════════════════════════════════

## Gets final stats for end-of-run screen and leaderboard
func get_final_stats() -> Dictionary:
	return {
		"character_id": current_character,
		"map_id": current_map,
		"tier": current_tier,
		"kills": kills,
		"damage_dealt": damage_dealt,
		"time_survived": time_survived,
		"stage_reached": stage_reached,
		"level_reached": current_level,
		"collected_items": collected_items.duplicate(),
		"chosen_skills": chosen_skills.duplicate(),
		"damage_breakdown": damage_breakdown.duplicate(),
		"boss_killed": boss_killed,
		"boss_kill_time": boss_kill_time,
		"final_swarm_entered": final_swarm_entered,
		"final_swarm_survival_time": final_swarm_survival_time,
		"difficulty_shrines_activated": difficulty_shrines_activated,
		"rift_fragments_earned": calculate_rift_fragments_earned()
	}


## Gets current progression state for UI display
func get_progression_state() -> Dictionary:
	var current_level_xp = current_xp
	if current_level > 1:
		current_level_xp -= _calculate_xp_for_level(current_level)

	var xp_required_for_current_level = _calculate_xp_for_level(current_level + 1) - _calculate_xp_for_level(current_level)

	return {
		"level": current_level,
		"exp": int(current_level_xp),
		"xp_to_next": int(xp_required_for_current_level),
		"total_for_level": int(xp_required_for_current_level),
		"max_level_reached": current_level >= _max_level
	}
