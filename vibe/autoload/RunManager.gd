extends Node

## Manages run state and emits fixed-step combat updates at 30 Hz.
## Ensures deterministic combat timing regardless of frame rate.

const COMBAT_DT: float = 1.0 / 30.0  # 30 Hz fixed step

@export var seed: int = 0:
	set(value):
		seed = value
		_seed_rng()

var stats: Dictionary = {}

var _accumulator: float = 0.0

func _ready() -> void:
	# RunManager should pause with the game
	process_mode = Node.PROCESS_MODE_PAUSABLE
	
	if seed == 0:
		seed = int(Time.get_unix_time_from_system())
	_seed_rng()
	if BalanceDB:
		BalanceDB.balance_reloaded.connect(_load_player_stats)
		# Load stats after BalanceDB is ready
		if BalanceDB._data.has("player"):
			_load_player_stats()
		else:
			# Defer until next frame when BalanceDB is ready
			call_deferred("_try_load_player_stats")

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
		"melee_damage_mult": 1.0
	}
	Logger.info("Reloaded player stats", "player")

func _process(delta: float) -> void:
	# Don't accumulate time when game is paused
	if get_tree().paused:
		return
		
	_accumulator += delta
	
	while _accumulator >= COMBAT_DT:
		var payload := EventBus.CombatStepPayload.new(COMBAT_DT)
		EventBus.combat_step.emit(payload)
		_accumulator -= COMBAT_DT

## Legacy method for compatibility - use PauseManager instead
func pause_game(v: bool) -> void:
	PauseManager.pause_game(v)

func _seed_rng() -> void:
	if RNG:
		RNG.seed_run(seed)
