extends Node

## Manages fixed-step combat timing at 30 Hz.
## Ensures deterministic combat timing regardless of frame rate.
## TODO: New progression - Stats tracking moved to SessionState (Task 04 Phase 2)

const COMBAT_DT: float = 1.0 / 30.0  # 30 Hz fixed step

@export var run_seed: int = 0:
	set(value):
		run_seed = value
		_seed_rng()

var _accumulator: float = 0.0

func _ready() -> void:
	# RunManager should pause with the game
	process_mode = Node.PROCESS_MODE_PAUSABLE

	if run_seed == 0:
		run_seed = int(Time.get_unix_time_from_system())
	_seed_rng()

	Logger.info("RunManager initialized (30Hz timing only)", "systems")

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