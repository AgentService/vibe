extends Node

## Fixed-Step Combat Timing Manager - Godot Native Implementation
## ============================================================
##
## PURPOSE:
## Ensures deterministic, frame-rate-independent combat timing by running game logic
## at a fixed timestep using Godot's built-in _physics_process().
##
## NOTE: Run statistics tracking has been migrated to SessionState autoload (Task 04 Phase 2).
##
## ARCHITECTURE PATTERN: Godot Physics Process
## ============================================
##
## This system uses Godot's native _physics_process() for fixed-step timing instead of
## a custom accumulator. This provides:
##
## - **Automatic fixed timestep**: Godot handles the timing internally (C++ optimized)
## - **Physics interpolation**: Set physics_interpolation=true for smooth rendering
## - **Simple implementation**: No manual accumulator management needed
## - **Engine integration**: Works seamlessly with CharacterBody2D, RigidBody2D, etc.
##
## CONFIGURATION (project.godot):
## - common/physics_ticks_per_second: Controls fixed timestep rate (60 Hz recommended)
## - common/physics_interpolation: Smooths rendering between physics steps (true)
##
## WHY GODOT NATIVE?
## - Simpler code (no custom accumulator, no manual interpolation)
## - Better performance (C++ implementation vs GDScript)
## - Automatic physics interpolation (no position tracking needed)
## - No need for deterministic replay or rollback netcode
##
## SIGNAL EMISSION:
## Systems connect to EventBus.combat_step to run their fixed-step logic:
##   - DamageSystem: Collision detection
##   - SpawnDirector: Enemy spawning
##   - MeleeSystem: Attack cooldowns
##   - Movement: Position updates
##
## DETERMINISM:
## - Fixed timestep ensures consistent physics behavior
## - RNG seeding (run_seed) makes runs reproducible for testing
## - Same seed + same inputs = same results
##
## PAUSE INTEGRATION:
## - process_mode = PAUSABLE stops physics processing when game paused
## - No time accumulation during pause → freeze game state
## - Resume from exact same state when unpaused
##
## REFERENCES:
## - Godot fixed timestep docs: https://docs.godotengine.org/en/stable/tutorials/scripting/idle_and_physics_processing.html
## - Godot physics interpolation: https://docs.godotengine.org/en/stable/tutorials/physics/interpolation/physics_interpolation.html
## - ARCHITECTURE.md - Fixed-Step Combat Loop (Decision 5a)

@export var run_seed: int = 0:
	set(value):
		run_seed = value
		_seed_rng()

func _ready() -> void:
	# RunManager should pause with the game (stops time accumulation)
	process_mode = Node.PROCESS_MODE_PAUSABLE

	# Initialize RNG with seed (0 = use system time for random seed)
	if run_seed == 0:
		run_seed = int(Time.get_unix_time_from_system())
	_seed_rng()

	Logger.info("RunManager initialized (using Godot physics_process)", "systems")


## Godot's Built-in Physics Process (ACTIVE)
## ================================================================
## Uses Godot's optimized _physics_process() for fixed timestep combat.
##
## Benefits:
## - Engine-optimized C++ implementation (faster than GDScript accumulator)
## - Automatic physics interpolation via physics_interpolation=true
## - Simple, maintainable code
## - Easy tuning via project.godot settings
##
## Configuration in project.godot:
##   [physics]
##   common/physics_ticks_per_second=30       # Physics tick rate
##   common/physics_interpolation=true        # Smooth rendering
##
## Physics Interpolation:
## - Godot automatically interpolates transforms between physics ticks
## - Works on local transforms in 2D (preserves scene tree pivots)
## - No manual position tracking needed
## - Call reset_physics_interpolation() when teleporting entities
##
func _physics_process(delta: float) -> void:
	# Godot's built-in fixed timestep
	# delta is always constant (e.g., 0.033s for 30Hz)
	# Interpolation handled automatically by engine

	# Create typed payload with Godot's fixed physics delta
	var payload := EventBus.CombatStepPayload_Type.new(delta)

	# Emit combat step - all systems process at physics tick rate
	EventBus.combat_step.emit(payload)

## Legacy method for compatibility - use PauseManager instead
func pause_game(v: bool) -> void:
	PauseManager.pause_game(v)

func _seed_rng() -> void:
	if RNG:
		RNG.seed_run(run_seed)