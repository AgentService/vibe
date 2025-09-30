extends Node

## Fixed-Step Combat Timing Manager (30 Hz) + Run Statistics Tracking
##
## ARCHITECTURE PATTERN: Fixed-Step Game Loop with Accumulator
## ============================================================
##
## PURPOSE:
## 1. Ensures deterministic, frame-rate-independent combat timing by running game logic
##    at a fixed 30 Hz timestep, regardless of the display's refresh rate (60Hz, 144Hz, etc).
## 2. Tracks run statistics (kills, damage, XP) for end-of-run display and meta-progression.
##
## WHY 30 HZ?
## - Balance between performance and responsiveness
## - Gives systems 33.33ms per frame to execute logic
## - Smooth enough for top-down action gameplay
## - Compatible with Godot's physics tick rate
##
## ACCUMULATOR PATTERN:
## The accumulator pattern solves the "variable delta time" problem:
##
##   1. Every frame: Add frame time (delta) to accumulator
##   2. While accumulator >= COMBAT_DT (33.33ms):
##      - Emit one combat_step signal
##      - Subtract COMBAT_DT from accumulator
##   3. Leftover accumulator time carries to next frame
##
## EXAMPLE BEHAVIOR:
##   Frame 1 (60 FPS, 16.67ms delta):
##     _accumulator = 16.67ms
##     16.67ms < 33.33ms → No combat step this frame
##
##   Frame 2 (60 FPS, 16.67ms delta):
##     _accumulator = 16.67 + 16.67 = 33.34ms
##     33.34ms >= 33.33ms → Emit 1 combat step
##     _accumulator = 33.34 - 33.33 = 0.01ms (carries forward)
##
##   Frame 3 (144 FPS, 6.94ms delta):
##     _accumulator = 0.01 + 6.94 = 6.95ms
##     6.95ms < 33.33ms → No combat step this frame
##
## RESULT: Combat logic runs at exactly 30 Hz, independent of frame rate.
##
## DETERMINISM:
## - Fixed timestep (COMBAT_DT) ensures consistent physics
## - RNG seeding (run_seed) makes runs reproducible
## - Same seed + same inputs = same results (critical for replays, testing)
##
## SIGNAL EMISSION:
## Systems connect to EventBus.combat_step to run their fixed-step logic:
##   - DamageSystem: Collision detection
##   - SpawnDirector: Enemy spawning
##   - MeleeSystem: Attack cooldowns
##   - Movement: Position updates
##
## PAUSE INTEGRATION:
## - process_mode = PAUSABLE stops accumulator when game paused
## - No time accumulation during pause → freeze game state
## - Resume from exact same state when unpaused
##
## TODO: Task 04 Phase 2 - SessionState Migration
## ================================================
## This RunManager currently handles TWO responsibilities:
##   1. 30Hz fixed-step timing (KEEP - core engine feature)
##   2. Run statistics tracking (MIGRATE to SessionState)
##
## Migration Plan:
##   - Move stats Dictionary → SessionState.gd
##   - Move _on_enemy_killed() → SessionState
##   - Move _on_damage_dealt() → SessionState
##   - Move _on_xp_gained() → SessionState
##   - Keep: COMBAT_DT, _accumulator, _process(), EventBus.combat_step emission
##   - Optionally rename to "CombatClock" after migration
##
## REFERENCES:
## - Glenn Fiedler's "Fix Your Timestep" article: https://gafferongames.com/post/fix_your_timestep/
## - Godot fixed timestep docs: https://docs.godotengine.org/en/stable/tutorials/scripting/idle_and_physics_processing.html
## - ARCHITECTURE.md - Fixed-Step Combat Loop (Decision 5a)

const COMBAT_DT: float = 1.0 / 30.0  # 30 Hz fixed step (33.33ms per step)

@export var run_seed: int = 0:
	set(value):
		run_seed = value
		_seed_rng()

# TODO: Task 04 Phase 2 - Migrate to SessionState.gd
var stats: Dictionary = {}

# Accumulator stores leftover frame time between combat steps
var _accumulator: float = 0.0

func _ready() -> void:
	# RunManager should pause with the game (stops time accumulation)
	process_mode = Node.PROCESS_MODE_PAUSABLE

	# Initialize RNG with seed (0 = use system time for random seed)
	if run_seed == 0:
		run_seed = int(Time.get_unix_time_from_system())
	_seed_rng()

	# TODO: Task 04 Phase 2 - Move to SessionState
	# Connect to EventBus for stat tracking
	EventBus.enemy_killed.connect(_on_enemy_killed)
	EventBus.damage_dealt.connect(_on_damage_dealt)
	EventBus.xp_gained.connect(_on_xp_gained)

	# TODO: Task 04 Phase 2 - Move to SessionState
	if BalanceDB:
		BalanceDB.balance_reloaded.connect(_load_player_stats)
		# Load stats after BalanceDB is ready
		if BalanceDB._data.has("player"):
			_load_player_stats()
		else:
			# Defer until next frame when BalanceDB is ready
			call_deferred("_try_load_player_stats")

	Logger.info("RunManager initialized (30Hz timing + stats tracking)", "systems")

func _exit_tree() -> void:
	# TODO: Task 04 Phase 2 - Move to SessionState
	# Cleanup signal connections
	if BalanceDB and BalanceDB.balance_reloaded.is_connected(_load_player_stats):
		BalanceDB.balance_reloaded.disconnect(_load_player_stats)
	if EventBus.enemy_killed.is_connected(_on_enemy_killed):
		EventBus.enemy_killed.disconnect(_on_enemy_killed)
	if EventBus.damage_dealt.is_connected(_on_damage_dealt):
		EventBus.damage_dealt.disconnect(_on_damage_dealt)
	if EventBus.xp_gained.is_connected(_on_xp_gained):
		EventBus.xp_gained.disconnect(_on_xp_gained)

func _try_load_player_stats() -> void:
	# TODO: Task 04 Phase 2 - Move to SessionState
	if BalanceDB and BalanceDB._data.has("player"):
		_load_player_stats()

func _load_player_stats() -> void:
	# TODO: Task 04 Phase 2 - Move to SessionState
	stats = {
		"projectile_count_add": BalanceDB.get_player_value("projectile_count_add"),
		"projectile_speed_mult": BalanceDB.get_player_value("projectile_speed_mult"),
		"fire_rate_mult": BalanceDB.get_player_value("fire_rate_mult"),
		"damage_mult": BalanceDB.get_player_value("damage_mult"),
		"has_projectiles": false,
		"level": 1,
		"melee_damage_add": 0.0,
		"enemies_killed": 0,
		"total_damage_dealt": 0.0,
		"xp_gained": 0,
		"melee_attack_speed_add": 0.0,
		"melee_range_add": 0.0,
		"melee_cone_angle_add": 0.0,
		"melee_damage_mult": 1.0
	}
	Logger.info("Reloaded player stats", "player")

func _process(delta: float) -> void:
	## Fixed-step accumulator loop
	## Runs multiple combat steps if frame took longer than COMBAT_DT
	## Runs zero steps if frame was too fast (accumulator carries forward)

	# Don't accumulate time when game is paused
	if get_tree().paused:
		return

	# Add frame time to accumulator
	_accumulator += delta

	# Process as many fixed steps as accumulated time allows
	while _accumulator >= COMBAT_DT:
		# Create typed payload with fixed timestep
		var payload := EventBus.CombatStepPayload_Type.new(COMBAT_DT)

		# Emit combat step - all systems process this at exactly 30 Hz
		EventBus.combat_step.emit(payload)

		# Subtract one fixed step from accumulator
		_accumulator -= COMBAT_DT

## Legacy method for compatibility - use PauseManager instead
func pause_game(v: bool) -> void:
	PauseManager.pause_game(v)

func _seed_rng() -> void:
	if RNG:
		RNG.seed_run(run_seed)

## TODO: Task 04 Phase 2 - Move to SessionState
func _on_enemy_killed(_pos: Vector2, _xp_value: int) -> void:
	"""Track enemy kills for run statistics"""
	stats["enemies_killed"] = stats.get("enemies_killed", 0) + 1

## TODO: Task 04 Phase 2 - Move to SessionState
func _on_damage_dealt(payload) -> void:
	"""Track total damage dealt for run statistics"""
	# Only track player damage, not enemy damage
	if payload.source == "player":
		stats["total_damage_dealt"] = stats.get("total_damage_dealt", 0.0) + payload.damage

## TODO: Task 04 Phase 2 - Move to SessionState
func _on_xp_gained(amount: float, _new_total: float) -> void:
	"""Track total XP gained for run statistics"""
	stats["xp_gained"] = stats.get("xp_gained", 0) + int(amount)