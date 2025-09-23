extends Area2D

## ProceduralMapAccess - Dedicated interaction area for entering procedurally generated arenas
## Provides options for biome and size selection before generation

@onready var collision_shape: CollisionShape2D
@onready var interaction_prompt: Label

var player_in_range: bool = false
var player_reference: Node2D

# Configuration
@export var interaction_key: String = "E"
@export var default_biome: String = ""  # Empty = random
@export var default_size: String = "standard"

func _ready() -> void:
	_setup_collision_shape()
	_setup_visual_elements()
	_connect_area_signals()
	Logger.info("ProceduralMapAccess initialized", "procedural")

func _setup_collision_shape() -> void:
	"""Gets reference to existing collision shape."""
	collision_shape = $CollisionShape2D

func _connect_area_signals() -> void:
	"""Connects the Area2D signals."""
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _setup_visual_elements() -> void:
	"""Creates visual prompt for procedural map access."""

	# Create interaction prompt label
	interaction_prompt = Label.new()
	interaction_prompt.name = "InteractionPrompt"
	interaction_prompt.text = "[" + interaction_key + "] Enter Random Arena"
	interaction_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	interaction_prompt.position = Vector2(-75, -50)  # Position above device
	interaction_prompt.visible = false
	add_child(interaction_prompt)

func _input(event: InputEvent) -> void:
	if not player_in_range:
		return

	if event.is_action_pressed("ui_accept") or (event is InputEventKey and event.pressed and event.keycode == KEY_E):
		_activate_procedural_access()

func _on_body_entered(body: Node2D) -> void:
	"""Called when player enters interaction range."""

	if body.is_in_group("player"):
		player_in_range = true
		player_reference = body
		interaction_prompt.visible = true
		Logger.debug("Player entered ProceduralMapAccess range", "procedural")

		# Emit interaction prompt event
		EventBus.interaction_prompt_changed.emit({
			"visible": true,
			"text": "[" + interaction_key + "] Enter Random Arena",
			"position": global_position
		})

func _on_body_exited(body: Node2D) -> void:
	"""Called when player exits interaction range."""

	if body.is_in_group("player"):
		player_in_range = false
		player_reference = null
		interaction_prompt.visible = false
		Logger.debug("Player exited ProceduralMapAccess range", "procedural")

		# Clear interaction prompt
		EventBus.interaction_prompt_changed.emit({
			"visible": false,
			"text": "",
			"position": global_position
		})

func _activate_procedural_access() -> void:
	"""Activates procedural map generation and transitions to arena."""

	Logger.info("ProceduralMapAccess activated", "procedural")

	# Gather character data to preserve across transition
	var character_data = {}
	if player_reference and player_reference.has_method("get_character_data"):
		character_data = player_reference.get_character_data()

	# Hide interaction prompt immediately
	interaction_prompt.visible = false
	player_in_range = false

	# Generate procedural arena
	var biome_preference = default_biome if default_biome != "" else ""
	var procedural_arena = ProceduralMapManager.generate_random_arena(default_size)

	if not procedural_arena:
		Logger.error("Failed to generate procedural arena", "procedural")
		_show_generation_error()
		return

	# Transition to the generated arena
	_transition_to_procedural_arena(procedural_arena, character_data)

func _transition_to_procedural_arena(arena_scene: Node2D, character_data: Dictionary) -> void:
	"""Handle transition to the procedurally generated arena."""

	# Create context for the procedural arena
	var context = {
		"spawn_point": "PlayerSpawnPoint",
		"character_data": character_data,
		"source": "hideout_procedural_access",
		"procedural_arena": arena_scene,
		"arena_type": "procedural"
	}

	# Use StateManager to transition to procedural arena
	# We'll need to enhance StateManager to handle procedural arenas
	StateManager.start_procedural_run(arena_scene, context)

func _show_generation_error() -> void:
	"""Show error message when procedural generation fails."""

	# Create a temporary error label
	var error_label = Label.new()
	error_label.text = "Arena generation failed!"
	error_label.modulate = Color.RED
	error_label.position = Vector2(-60, -30)
	add_child(error_label)

	# Remove after 3 seconds
	var tween = create_tween()
	tween.tween_delay(3.0)
	tween.tween_callback(error_label.queue_free)

func configure_procedural_access(biome: String = "", size: String = "standard") -> void:
	"""Configure the procedural access preferences."""

	default_biome = biome
	default_size = size

	# Update prompt text to show configuration
	var biome_text = biome if biome != "" else "Random"
	var display_text = "[" + interaction_key + "] Enter " + biome_text + " Arena (" + size.capitalize() + ")"

	if interaction_prompt:
		interaction_prompt.text = display_text