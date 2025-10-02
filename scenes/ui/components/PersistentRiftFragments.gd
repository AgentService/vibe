extends CanvasLayer
## Persistent Rift Fragments display - visible across all menu scenes
##
## Architecture: CanvasLayer autoload (layer 100) stays above all scenes
## Updates via MetaProgression.rift_fragments_changed signal

@onready var rift_fragments_value: Label = $MarginContainer/HBoxContainer/RiftFragmentsValue

var _visible_in_scenes: Array[String] = [
	"main_menu",
	"unlock_shop",
	"character_select",
	"map_select"
]

func _ready() -> void:
	# Start hidden
	visible = false

	# Connect to EventBus for balance updates
	if EventBus:
		EventBus.rift_fragments_changed.connect(_on_rift_fragments_changed)
		EventBus.request_enter_map.connect(_on_scene_transition)
		_update_display()
	else:
		Logger.warn("PersistentRiftFragments: EventBus not available", "ui")

	Logger.info("PersistentRiftFragments initialized", "ui")

func _update_display() -> void:
	"""Update Rift Fragments value from MetaProgression."""
	if MetaProgression:
		var balance = MetaProgression.get_rift_fragments()
		rift_fragments_value.text = str(balance)
		Logger.debug("Updated Rift Fragments display: %d" % balance, "ui")
	else:
		rift_fragments_value.text = "0"

func _on_rift_fragments_changed(new_balance: int) -> void:
	"""Handle Rift Fragments balance changes via signal."""
	rift_fragments_value.text = str(new_balance)
	Logger.debug("Rift Fragments updated to: %d" % new_balance, "ui")

func _on_scene_transition(transition_data: Dictionary) -> void:
	"""Show/hide based on target scene."""
	var map_id = transition_data.get("map_id", "")

	if map_id in _visible_in_scenes:
		visible = true
		_update_display()
	else:
		visible = false

func show_persistent_ui() -> void:
	"""Manually show the UI (called by scenes if needed)."""
	visible = true
	_update_display()

func hide_persistent_ui() -> void:
	"""Manually hide the UI."""
	visible = false
