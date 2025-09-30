extends PanelContainer
class_name ItemGridCell

## Grid cell component for item unlock screen
## Shows locked/discovered/unlocked states with visual feedback

enum ItemState {
	LOCKED,      # Not yet discovered (gray silhouette, no info)
	DISCOVERED,  # Found in run (colored, can purchase)
	UNLOCKED     # Purchased (fully visible)
}

signal item_clicked(item_metadata: ItemMetadata)

var item_metadata: ItemMetadata
var item_state: ItemState = ItemState.LOCKED
var can_afford: bool = false

var texture_rect: TextureRect
var name_label: Label
var cost_label: Label
var lock_icon: Label

var _is_ready: bool = false

func _ready() -> void:
	# Get node references first
	texture_rect = $MarginContainer/VBox/TextureRect
	name_label = $MarginContainer/VBox/NameLabel
	cost_label = $MarginContainer/VBox/CostLabel
	lock_icon = $MarginContainer/VBox/LockIcon

	# Connect signals
	gui_input.connect(_on_gui_input)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)

	# Set fixed size (80x100 cells for 10 per row)
	custom_minimum_size = Vector2(80, 100)

	_is_ready = true

	# Update visuals if setup() was called before _ready()
	if item_metadata:
		_update_visuals()

func setup(metadata: ItemMetadata, state: ItemState, affordable: bool) -> void:
	"""Configure cell with item data and state."""
	item_metadata = metadata
	item_state = state
	can_afford = affordable

	# Only update visuals if _ready() has been called
	if _is_ready:
		_update_visuals()

func _update_visuals() -> void:
	"""Update cell appearance based on state."""
	match item_state:
		ItemState.LOCKED:
			_show_locked_state()
		ItemState.DISCOVERED:
			_show_discovered_state()
		ItemState.UNLOCKED:
			_show_unlocked_state()

func _show_locked_state() -> void:
	"""Gray silhouette, no details."""
	modulate = Color(0.3, 0.3, 0.3, 1.0)
	lock_icon.visible = true
	lock_icon.text = "🔒"
	name_label.text = "???"
	cost_label.visible = false
	texture_rect.visible = false
	mouse_default_cursor_shape = Control.CURSOR_ARROW

func _show_discovered_state() -> void:
	"""Colored border, shows info, clickable."""
	modulate = Color(1.0, 1.0, 1.0, 1.0)
	lock_icon.visible = false
	name_label.text = item_metadata.display_name
	cost_label.visible = true
	cost_label.text = "%d 💎" % item_metadata.unlock_cost

	# Color based on affordability
	if can_afford:
		cost_label.modulate = Color(0.6, 1.0, 0.6)  # Green
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	else:
		cost_label.modulate = Color(1.0, 0.4, 0.4)  # Red
		mouse_default_cursor_shape = Control.CURSOR_FORBIDDEN

	# Load icon if available
	if not item_metadata.icon_path.is_empty() and ResourceLoader.exists(item_metadata.icon_path):
		texture_rect.texture = load(item_metadata.icon_path)
		texture_rect.visible = true
	else:
		texture_rect.visible = false

	# Apply rarity border color
	_apply_rarity_border()

func _show_unlocked_state() -> void:
	"""Fully visible, no cost label."""
	modulate = Color(1.0, 1.0, 1.0, 1.0)
	lock_icon.visible = false
	name_label.text = item_metadata.display_name
	cost_label.visible = false
	mouse_default_cursor_shape = Control.CURSOR_ARROW

	# Load icon
	if not item_metadata.icon_path.is_empty() and ResourceLoader.exists(item_metadata.icon_path):
		texture_rect.texture = load(item_metadata.icon_path)
		texture_rect.visible = true
	else:
		texture_rect.visible = false

	# Apply rarity border
	_apply_rarity_border()

func _apply_rarity_border() -> void:
	"""Apply border color based on rarity."""
	var border_color: Color
	match item_metadata.rarity:
		"Common":
			border_color = Color(0.7, 0.7, 0.7)
		"Uncommon":
			border_color = Color(0.3, 1.0, 0.3)
		"Rare":
			border_color = Color(0.3, 0.5, 1.0)
		"Epic":
			border_color = Color(0.7, 0.3, 1.0)
		"Legendary":
			border_color = Color(1.0, 0.5, 0.0)
		_:
			border_color = Color(0.5, 0.5, 0.5)

	# Apply border via modulate (simplified approach)
	self_modulate = border_color

func _on_gui_input(event: InputEvent) -> void:
	"""Handle click events."""
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		# Only emit if discovered (can purchase)
		if item_state == ItemState.DISCOVERED and can_afford:
			item_clicked.emit(item_metadata)
			accept_event()

func _on_mouse_entered() -> void:
	"""Hover effect."""
	if item_state == ItemState.DISCOVERED:
		scale = Vector2(1.05, 1.05)

func _on_mouse_exited() -> void:
	"""Reset hover effect."""
	scale = Vector2(1.0, 1.0)
