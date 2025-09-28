extends Area2D

## PathGeneratorArenaAccess - Dedicated interaction area for entering PathGenerator Arena
## Provides access to the PathAwareArenaGenerator test scene with randomization on each entry

@onready var collision_shape: CollisionShape2D
@onready var interaction_prompt: Label

var player_in_range: bool = false
var player_reference: Node2D

# Configuration
@export var interaction_key: String = "E"
@export var randomize_on_entry: bool = true

func _ready() -> void:
	_setup_collision_shape()
	_setup_visual_elements()
	_connect_area_signals()
	Logger.info("PathGeneratorArenaAccess initialized", "pathgen")

func _setup_collision_shape() -> void:
	"""Gets reference to existing collision shape."""
	collision_shape = $CollisionShape2D

func _connect_area_signals() -> void:
	"""Connects the Area2D signals."""
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _setup_visual_elements() -> void:
	"""Creates visual prompt for PathGenerator arena access."""

	# Create interaction prompt label
	interaction_prompt = Label.new()
	interaction_prompt.name = "InteractionPrompt"
	interaction_prompt.text = "[" + interaction_key + "] Enter PathGenerator Arena"
	interaction_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	interaction_prompt.position = Vector2(-90, -50)  # Position above device
	interaction_prompt.visible = false

	# Style the prompt for visibility
	interaction_prompt.modulate = Color.CYAN

	add_child(interaction_prompt)

func _input(event: InputEvent) -> void:
	if not player_in_range:
		return

	if event.is_action_pressed("ui_accept") or (event is InputEventKey and event.pressed and event.keycode == KEY_E):
		_activate_pathgen_arena_access()

func _on_body_entered(body: Node2D) -> void:
	"""Called when player enters interaction range."""

	if body.is_in_group("player"):
		player_in_range = true
		player_reference = body
		interaction_prompt.visible = true
		Logger.debug("Player entered PathGeneratorArenaAccess range", "pathgen")

		# Emit interaction prompt event
		EventBus.interaction_prompt_changed.emit({
			"visible": true,
			"text": "[" + interaction_key + "] Enter PathGenerator Arena",
			"position": global_position
		})

func _on_body_exited(body: Node2D) -> void:
	"""Called when player exits interaction range."""

	if body.is_in_group("player"):
		player_in_range = false
		player_reference = null
		interaction_prompt.visible = false
		Logger.debug("Player exited PathGeneratorArenaAccess range", "pathgen")

		# Clear interaction prompt
		EventBus.interaction_prompt_changed.emit({
			"visible": false,
			"text": "",
			"position": global_position
		})

func _activate_pathgen_arena_access() -> void:
	"""Activates PathGenerator arena access and transitions to test scene."""

	Logger.info("PathGeneratorArenaAccess activated", "pathgen")

	# Gather character data to preserve across transition
	var character_data = {}
	if player_reference and player_reference.has_method("get_character_data"):
		character_data = player_reference.get_character_data()

	# Hide interaction prompt immediately
	interaction_prompt.visible = false
	player_in_range = false

	# Prepare context for PathGenerator Arena
	var pathgen_context = {
		"character_data": character_data,
		"randomize_generation": randomize_on_entry,
		"spawn_point": "PlayerSpawnPoint",  # Spawn point in PathGeneratorTest scene
		"source": "hideout_pathgen_access",
		"return_to_hideout": true
	}

	# Use StateManager to load PathGenerator Arena
	StateManager.start_run(&"pathgen_arena", pathgen_context)

func _show_generation_error() -> void:
	"""Show error message when PathGenerator arena loading fails."""

	# Create a temporary error label
	var error_label = Label.new()
	error_label.text = "PathGenerator Arena loading failed!"
	error_label.modulate = Color.RED
	error_label.position = Vector2(-80, -30)
	add_child(error_label)

	# Remove after 3 seconds
	var tween = create_tween()
	tween.tween_delay(3.0)
	tween.tween_callback(error_label.queue_free)

func configure_pathgen_access(randomize: bool = true) -> void:
	"""Configure the PathGenerator arena access settings."""

	randomize_on_entry = randomize

	# Update prompt text to show configuration
	var mode_text = "Random" if randomize else "Fixed"
	var display_text = "[" + interaction_key + "] Enter PathGenerator Arena (" + mode_text + ")"

	if interaction_prompt:
		interaction_prompt.text = display_text