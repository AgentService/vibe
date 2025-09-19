extends Area2D

## MasteryDevice - Interactive device for accessing the Event Mastery Tree from the hideout.
## Detects player proximity and provides interaction prompts.
## Opens the MasteryTreeUI when activated.

@onready var collision_shape: CollisionShape2D
@onready var interaction_prompt: Label

var player_in_range: bool = false
var player_reference: Node2D
var mastery_ui

# Device configuration
@export var device_display_name: String = "Event Mastery Tree"
@export var interaction_key: String = "E"

func _ready() -> void:
	_setup_collision_shape()
	_setup_visual_elements()
	_connect_area_signals()
	_find_mastery_ui()
	Logger.info("MasteryDevice initialized", "ui")

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
	interaction_prompt.text = "[" + interaction_key + "] Open " + device_display_name
	interaction_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	interaction_prompt.position = Vector2(-75, -50)  # Position above device
	interaction_prompt.visible = false
	add_child(interaction_prompt)

	# DeviceVisual already exists in scene - no need to create it programmatically

func _find_mastery_ui() -> void:
	"""Find or create the skill tree UI."""

	# Check if it's already instantiated in the scene
	var ui_nodes = get_tree().get_nodes_in_group("mastery_ui")
	if ui_nodes.size() > 0:
		mastery_ui = ui_nodes[0]
		return

	# Load and instantiate new Atlas tree scene
	var atlas_tree_scene = load("res://scenes/ui/atlas/AtlasTreeUI.tscn")
	if atlas_tree_scene:
		mastery_ui = atlas_tree_scene.instantiate()
		mastery_ui.add_to_group("mastery_ui")

		# Create a CanvasLayer to ensure UI renders on top and ignores camera positioning
		var ui_layer = CanvasLayer.new()
		ui_layer.layer = 100  # High layer to render on top
		ui_layer.add_child(mastery_ui)

		# Add to scene root - use call_deferred to avoid scene initialization conflicts
		get_tree().root.call_deferred("add_child", ui_layer)
		Logger.info("Atlas tree scene instantiated and added to CanvasLayer (deferred)", "ui")
	else:
		Logger.warn("Failed to load Atlas tree scene", "ui")

func _input(event: InputEvent) -> void:
	if not player_in_range:
		return

	if event.is_action_pressed("ui_accept") or (event is InputEventKey and event.pressed and event.keycode == KEY_E):
		_activate_mastery_device()

func _on_body_entered(body: Node2D) -> void:
	"""Called when player enters interaction range."""

	if body.is_in_group("player"):
		player_in_range = true
		player_reference = body
		interaction_prompt.visible = true
		Logger.debug("Player entered MasteryDevice range", "ui")

		# Emit interaction prompt event
		EventBus.interaction_prompt_changed.emit({
			"visible": true,
			"text": "[" + interaction_key + "] Open " + device_display_name,
			"position": global_position
		})

func _on_body_exited(body: Node2D) -> void:
	"""Called when player exits interaction range."""

	if body.is_in_group("player"):
		player_in_range = false
		player_reference = null
		interaction_prompt.visible = false
		Logger.debug("Player exited MasteryDevice range", "ui")

		# Clear interaction prompt
		EventBus.interaction_prompt_changed.emit({
			"visible": false,
			"text": "",
			"position": global_position
		})

func _activate_mastery_device() -> void:
	"""Activates the mastery device and opens the mastery tree UI."""

	Logger.info("MasteryDevice activated - opening mastery tree", "ui")

	if mastery_ui:
		mastery_ui.show_ui()
	else:
		Logger.warn("Skill tree UI not available", "ui")
		# Try to find it again
		_find_mastery_ui()
		if mastery_ui:
			mastery_ui.show_ui()

	# Hide interaction prompt immediately
	interaction_prompt.visible = false

	# Don't set player_in_range to false - they're still in range, just using UI
