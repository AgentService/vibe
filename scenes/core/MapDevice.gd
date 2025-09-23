extends Area2D

## MapDevice - Interactive portal for entering different maps/arenas from the hideout.
## Detects player proximity and provides interaction prompts.
## Emits EventBus signals for scene transitions.

@onready var collision_shape: CollisionShape2D
@onready var interaction_prompt: Label

var player_in_range: bool = false
var player_reference: Node2D

# Map device configuration
@export var map_id: StringName = &"arena"
@export var map_display_name: String = "Combat Arena"
@export var interaction_key: String = "E"
@export var spawn_point_override: String = ""

# Procedural generation settings
@export var enable_procedural_generation: bool = false
@export var procedural_biome_preference: String = ""  # Empty = random
@export var procedural_size_preference: String = "standard"  # small, standard, large

func _ready() -> void:
	_setup_collision_shape()
	_setup_visual_elements()
	_connect_area_signals()
	Logger.info("MapDevice initialized for: " + map_display_name, "mapdevice")

func _setup_collision_shape() -> void:
	"""Gets reference to existing collision shape."""

	# Get reference to existing CollisionShape2D (created in scene)
	collision_shape = $CollisionShape2D

func _connect_area_signals() -> void:
	"""Connects the Area2D signals since this node is now an Area2D."""
	
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _setup_visual_elements() -> void:
	"""Creates visual prompt and references existing device visual."""

	# Create interaction prompt label
	interaction_prompt = Label.new()
	interaction_prompt.name = "InteractionPrompt"
	interaction_prompt.text = "[" + interaction_key + "] Enter " + map_display_name
	interaction_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	interaction_prompt.position = Vector2(-75, -50)  # Position above device
	interaction_prompt.visible = false
	add_child(interaction_prompt)

	# DeviceVisual already exists in scene - no need to create it programmatically

func _input(event: InputEvent) -> void:
	if not player_in_range:
		return
		
	if event.is_action_pressed("ui_accept") or (event is InputEventKey and event.pressed and event.keycode == KEY_E):
		_activate_map_device()

func _on_body_entered(body: Node2D) -> void:
	"""Called when player enters interaction range."""
	
	if body.is_in_group("player"):
		player_in_range = true
		player_reference = body
		interaction_prompt.visible = true
		Logger.debug("Player entered MapDevice range: " + map_display_name, "mapdevice")
		
		# Emit interaction prompt event
		EventBus.interaction_prompt_changed.emit({
			"visible": true,
			"text": "[" + interaction_key + "] Enter " + map_display_name,
			"position": global_position
		})

func _on_body_exited(body: Node2D) -> void:
	"""Called when player exits interaction range."""
	
	if body.is_in_group("player"):
		player_in_range = false
		player_reference = null
		interaction_prompt.visible = false
		Logger.debug("Player exited MapDevice range: " + map_display_name, "mapdevice")
		
		# Clear interaction prompt
		EventBus.interaction_prompt_changed.emit({
			"visible": false,
			"text": "",
			"position": global_position
		})

func _activate_map_device() -> void:
	"""Activates the map device and initiates scene transition."""

	Logger.info("MapDevice activated: " + map_display_name + " (map_id: " + map_id + ")", "mapdevice")

	# Gather character data to preserve across transition
	var character_data = {}
	if player_reference and player_reference.has_method("get_character_data"):
		character_data = player_reference.get_character_data()

	# Hide interaction prompt immediately
	interaction_prompt.visible = false
	player_in_range = false

	# Handle procedural generation
	if enable_procedural_generation:
		_handle_procedural_generation(character_data)
		return

	# Prepare context for StateManager (traditional scene loading)
	var context = {
		"spawn_point": spawn_point_override if spawn_point_override != "" else "PlayerSpawnPoint",
		"character_data": character_data,
		"source": "hideout_map_device"
	}

	# Use StateManager to start run
	StateManager.start_run(map_id, context)

func set_map_config(p_map_id: StringName, p_display_name: String, p_spawn_point: String = "") -> void:
	"""Configure the map device programmatically."""
	
	map_id = p_map_id
	map_display_name = p_display_name
	spawn_point_override = p_spawn_point
	
	if interaction_prompt:
		interaction_prompt.text = "[" + interaction_key + "] Enter " + map_display_name
