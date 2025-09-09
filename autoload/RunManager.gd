extends Node

## Manages run state and emits fixed-step combat updates at 30 Hz.
## Ensures deterministic combat timing regardless of frame rate.

const COMBAT_DT: float = 1.0 / 30.0  # 30 Hz fixed step

@export var run_seed: int = 0:
	set(value):
		run_seed = value
		_seed_rng()

var stats: Dictionary = {}

var _accumulator: float = 0.0

func _ready() -> void:
	# RunManager should pause with the game
	process_mode = Node.PROCESS_MODE_PAUSABLE
	
	if run_seed == 0:
		run_seed = int(Time.get_unix_time_from_system())
	_seed_rng()
	
	# Connect to EventBus for stat tracking
	EventBus.enemy_killed.connect(_on_enemy_killed)
	EventBus.damage_dealt.connect(_on_damage_dealt)
	EventBus.xp_gained.connect(_on_xp_gained)
	
	if BalanceDB:
		BalanceDB.balance_reloaded.connect(_load_player_stats)
		# Load stats after BalanceDB is ready
		if BalanceDB._data.has("player"):
			_load_player_stats()
		else:
			# Defer until next frame when BalanceDB is ready
			call_deferred("_try_load_player_stats")

func _exit_tree() -> void:
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
	if BalanceDB and BalanceDB._data.has("player"):
		_load_player_stats()

func _load_player_stats() -> void:
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
	# Don't accumulate time when game is paused
	if get_tree().paused:
		return
		
	_accumulator += delta
	
	while _accumulator >= COMBAT_DT:
		var payload := EventBus.CombatStepPayload_Type.new(COMBAT_DT)
		EventBus.combat_step.emit(payload)
		_accumulator -= COMBAT_DT

## Legacy method for compatibility - use PauseManager instead
func pause_game(v: bool) -> void:
	PauseManager.pause_game(v)

func _seed_rng() -> void:
	if RNG:
		RNG.seed_run(run_seed)

func _on_enemy_killed(_pos: Vector2, _xp_value: int) -> void:
	"""Track enemy kills for run statistics"""
	stats["enemies_killed"] = stats.get("enemies_killed", 0) + 1

func _on_damage_dealt(payload) -> void:
	"""Track total damage dealt for run statistics"""
	# Only track player damage, not enemy damage
	if payload.source == "player":
		stats["total_damage_dealt"] = stats.get("total_damage_dealt", 0.0) + payload.damage

func _on_xp_gained(amount: float, _new_total: float) -> void:
	"""Track total XP gained for run statistics"""
	stats["xp_gained"] = stats.get("xp_gained", 0) + int(amount)
