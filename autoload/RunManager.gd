extends Node

## Fixed-Step Combat Timing Manager (30 Hz)
##
## ARCHITECTURE PATTERN: Fixed-Step Game Loop with Accumulator
## ============================================================
##
## PURPOSE:
## Ensures deterministic, frame-rate-independent combat timing by running game logic
## at a fixed 30 Hz timestep, regardless of the display's refresh rate (60Hz, 144Hz, etc).
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
## HISTORICAL NOTE:
## Stats tracking (enemies_killed, damage_dealt, xp_gained) was removed in Task 04a.
## These stats now belong in SessionState autoload (Task 04 Phase 2).
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

# Accumulator stores leftover frame time between combat steps
var _accumulator: float = 0.0

func _ready() -> void:
	# RunManager should pause with the game (stops time accumulation)
	process_mode = Node.PROCESS_MODE_PAUSABLE

	# Initialize RNG with seed (0 = use system time for random seed)
	if run_seed == 0:
		run_seed = int(Time.get_unix_time_from_system())
	_seed_rng()

	Logger.info("RunManager initialized (30Hz timing only)", "systems")

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