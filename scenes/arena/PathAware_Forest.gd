extends "res://scenes/arena/Arena.gd"

## PathAware_Forest - PathAware Arena Generator forest scene
## Handles arena randomization on entry from hideout and manages player spawn

@onready var arena_generator: PathAwareArenaGenerator = $PathAwareArenaGenerator
@onready var player_spawn: Marker2D = $PlayerSpawnPoint

var is_randomize_on_entry: bool = true

func _ready() -> void:
	Logger.info("PathAware_Forest scene loaded", "pathgen")

	# Call parent Arena._ready() first to setup all systems
	super._ready()

	# Check if we have context from StateManager for randomization
	_check_for_randomization_context()

	# Generate arena based on context
	_generate_arena()

	# Setup player if needed
	_setup_player_spawn()

func _check_for_randomization_context() -> void:
	"""Check StateManager context for randomization settings."""
	# In a real implementation, StateManager would pass context data
	# For now, we'll always randomize on entry from hideout

	# This would be set by StateManager context in the future
	is_randomize_on_entry = true

	Logger.debug("Randomization on entry: %s" % is_randomize_on_entry, "pathgen")

func _generate_arena() -> void:
	"""Generate the arena with optional randomization."""

	if not arena_generator:
		Logger.error("PathAwareArenaGenerator not found in scene", "pathgen")
		return

	if is_randomize_on_entry:
		# Use a new random seed for each entry
		var new_seed = randi()
		Logger.info("Generating PathGenerator Arena with new seed: %d" % new_seed, "pathgen")

		# Set randomization parameters for visual variety
		if arena_generator.tree_config:
			arena_generator.tree_config.placement_randomness = randf_range(0.3, 1.0)
			arena_generator.tree_config.max_random_offset = randi_range(16, 32)

		# Generate with new seed
		arena_generator.generation_seed = new_seed
		arena_generator.generate_path_aware_arena()
	else:
		Logger.info("Generating PathGenerator Arena with existing configuration", "pathgen")
		arena_generator.generate_path_aware_arena()

func _setup_player_spawn() -> void:
	"""Setup player spawn point for arena entry."""

	if not player_spawn:
		Logger.warn("Player spawn point 'PlayerSpawnPoint' not found", "pathgen")
		return

	# For now, we'll just log the spawn point
	# In the future, this would coordinate with player spawning system
	Logger.debug("Player spawn point ready at: %s" % player_spawn.global_position, "pathgen")


## Public interface for external randomization requests
func regenerate_arena() -> void:
	"""Regenerate the arena with new randomization - useful for testing."""

	Logger.info("Manual arena regeneration requested", "pathgen")
	is_randomize_on_entry = true
	_generate_arena()

func set_randomization_mode(randomize: bool) -> void:
	"""Set whether arena should randomize on entry."""

	is_randomize_on_entry = randomize
	Logger.debug("Randomization mode set to: %s" % randomize, "pathgen")

## Handle return to hideout
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):  # ESC key
		_return_to_hideout()

func _return_to_hideout() -> void:
	"""Return to hideout scene."""

	Logger.info("Returning to hideout from PathAware_Forest", "pathgen")
	StateManager.go_to_hideout({"source": "pathgen_arena_exit"})
