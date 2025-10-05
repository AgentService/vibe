extends Control
class_name MapSelectButton

## Reusable map selection button component
##
## Usage:
##   var map_button = MapSelectButton_scene.instantiate()
##   map_button.setup("forest_arena", "Forest", "Description...", forest_icon, false)
##   map_button.pressed.connect(_on_map_selected.bind("forest_arena"))

signal pressed(map_id: String)

@export var map_id: String = ""
@export var map_name: String = "Forest"
@export var map_description: String = ""
@export var map_icon: Texture2D
@export var is_locked: bool = false

@onready var map_button: Button = %MapButton
@onready var map_icon_rect: TextureRect = %MapIcon
@onready var map_name_label: Label = %MapName
@onready var map_description_label: Label = %MapDescription
@onready var disabled_overlay: ColorRect = %DisabledOverlay

func _ready() -> void:
	# Apply exported properties
	_apply_properties()

	# Connect button press
	map_button.pressed.connect(_on_button_pressed)

func setup(p_map_id: String, p_name: String, p_description: String, p_icon: Texture2D = null, p_locked: bool = false) -> void:
	"""Configure the map button with data"""
	map_id = p_map_id
	map_name = p_name
	map_description = p_description
	map_icon = p_icon
	is_locked = p_locked

	if is_node_ready():
		_apply_properties()

func _apply_properties() -> void:
	"""Apply current property values to UI elements"""
	map_name_label.text = map_name
	map_description_label.text = map_description

	if map_icon:
		map_icon_rect.texture = map_icon

	# Handle locked state
	map_button.disabled = is_locked
	disabled_overlay.visible = is_locked

func _on_button_pressed() -> void:
	"""Emit pressed signal with map_id"""
	if not is_locked:
		pressed.emit(map_id)
		Logger.debug("Map button pressed: %s" % map_id, "ui")

func set_locked(locked: bool) -> void:
	"""Change locked state dynamically"""
	is_locked = locked
	if is_node_ready():
		map_button.disabled = is_locked
		disabled_overlay.visible = is_locked

func set_selected(selected: bool) -> void:
	"""Update button state when selected/deselected"""
	if map_button:
		if selected:
			# Apply focus style to show selection
			map_button.grab_focus()
		else:
			# Release focus when deselected
			if map_button.has_focus():
				map_button.release_focus()
