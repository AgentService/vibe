extends Panel
class_name KeybindingsComponent

## Keybindings display component showing current control scheme
## Styled to match radar panel with consistent UI theme
## Note: Extends Panel directly for background styling, implements BaseHUDComponent interface

@onready var container: VBoxContainer = $VBoxContainer
@onready var title_label: Label = $VBoxContainer/TitleLabel

# BaseHUDComponent interface implementation
@export var component_id: String = ""
@export var update_frequency: float = 0.0
@export var enable_performance_monitoring: bool = false

signal component_ready(component_id: String)
signal component_destroyed(component_id: String)

# Keybinding data
var key_bindings: Dictionary = {}
var binding_labels: Array[Label] = []

func _ready() -> void:
	if component_id.is_empty():
		component_id = "keybindings_display"
	
	_setup_component()
	_register_with_hud_manager()
	component_ready.emit(component_id)

func _exit_tree() -> void:
	_unregister_from_hud_manager()
	component_destroyed.emit(component_id)

func _setup_component() -> void:
	_load_key_bindings()
	_create_keybinding_display()
	_style_panel()

func bind_events() -> void:
	# Keybindings are static, no EventBus signals needed
	# Could add input remapping signals in future
	pass

func _register_with_hud_manager() -> void:
	if HUDManager:
		call_deferred("_do_register")

func _do_register() -> void:
	if HUDManager:
		HUDManager.register_component(component_id, self)

func _unregister_from_hud_manager() -> void:
	if HUDManager:
		HUDManager.unregister_component(component_id)

func apply_anchor_config(config: Dictionary) -> void:
	var anchor_preset: int = config.get("anchor_preset", Control.PRESET_TOP_LEFT)
	var offset: Vector2 = config.get("offset", Vector2.ZERO)
	var component_size: Vector2 = config.get("size", Vector2.ZERO)
	
	set_anchors_and_offsets_preset(anchor_preset)
	position += offset
	
	# Apply size if specified
	if component_size != Vector2.ZERO:
		custom_minimum_size = component_size
		size = component_size

func set_component_visible(visible_state: bool) -> void:
	visible = visible_state

func set_component_scale(new_scale: Vector2) -> void:
	scale = new_scale

func _style_panel() -> void:
	# Style the panel background to match radar theme
	var style_box := StyleBoxFlat.new()
	style_box.bg_color = Color(0.1, 0.1, 0.1, 0.9)  # Dark background
	style_box.border_width_left = 2
	style_box.border_width_right = 2
	style_box.border_width_top = 2
	style_box.border_width_bottom = 2
	style_box.border_color = Color(0.6, 0.5, 0.4, 1.0)  # Same border as radar
	style_box.corner_radius_top_left = 4
	style_box.corner_radius_top_right = 4
	style_box.corner_radius_bottom_left = 4
	style_box.corner_radius_bottom_right = 4
	style_box.content_margin_left = 8
	style_box.content_margin_right = 8
	style_box.content_margin_top = 8
	style_box.content_margin_bottom = 8
	
	# Apply panel style
	add_theme_stylebox_override("panel", style_box)

func _load_key_bindings() -> void:
	# Load key bindings from InputMap
	key_bindings = {
		"Movement": {
			"W": "Move Up",
			"A": "Move Left", 
			"S": "Move Down",
			"D": "Move Right"
		},
		"System": {
			"ESC": "Pause/Menu",
			"F5": "Refresh",
			"`": "Console"
		}
	}

func _create_keybinding_display() -> void:
	if not container:
		Logger.warn("KeybindingsComponent: No VBoxContainer found", "ui")
		return
		
	# Clear existing children (except title)
	for child in container.get_children():
		if child != title_label:
			child.queue_free()
	
	# Create title
	if title_label:
		title_label.text = "CONTROLS"
		title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_style_title_label(title_label)
	
	# Add movement section
	_add_section_header("Movement:")
	for key in key_bindings.Movement:
		var action = key_bindings.Movement[key]
		_add_keybinding_row(key, action)
	
	# Add spacing
	_add_spacer()
	
	# Add system section
	_add_section_header("System:")
	for key in key_bindings.System:
		var action = key_bindings.System[key]
		_add_keybinding_row(key, action)

func _add_section_header(text: String) -> void:
	var header = Label.new()
	header.text = text
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_style_section_header(header)
	container.add_child(header)

func _add_keybinding_row(key: String, action: String) -> void:
	var row = HBoxContainer.new()
	container.add_child(row)
	
	# Key label
	var key_label = Label.new()
	key_label.text = key
	key_label.custom_minimum_size.x = 30
	_style_key_label(key_label)
	row.add_child(key_label)
	
	# Separator
	var separator = Label.new()
	separator.text = ": "
	_style_text_label(separator)
	row.add_child(separator)
	
	# Action label
	var action_label = Label.new()
	action_label.text = action
	action_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_style_text_label(action_label)
	row.add_child(action_label)
	
	binding_labels.append(key_label)
	binding_labels.append(action_label)

func _add_spacer() -> void:
	var spacer = Control.new()
	spacer.custom_minimum_size.y = 8
	container.add_child(spacer)

func _style_title_label(label: Label) -> void:
	var theme = Theme.new()
	theme.set_color("font_color", "Label", Color.YELLOW)
	theme.set_constant("shadow_offset_x", "Label", 1)
	theme.set_constant("shadow_offset_y", "Label", 1)
	theme.set_color("font_shadow_color", "Label", Color.BLACK)
	label.theme = theme

func _style_section_header(label: Label) -> void:
	var theme = Theme.new()
	theme.set_color("font_color", "Label", Color.LIGHT_GRAY)
	theme.set_constant("shadow_offset_x", "Label", 1)
	theme.set_constant("shadow_offset_y", "Label", 1)
	theme.set_color("font_shadow_color", "Label", Color.BLACK)
	label.theme = theme

func _style_key_label(label: Label) -> void:
	var theme = Theme.new()
	theme.set_color("font_color", "Label", Color.WHITE)
	theme.set_constant("shadow_offset_x", "Label", 1)
	theme.set_constant("shadow_offset_y", "Label", 1)
	theme.set_color("font_shadow_color", "Label", Color.BLACK)
	label.theme = theme

func _style_text_label(label: Label) -> void:
	var theme = Theme.new()
	theme.set_color("font_color", "Label", Color.LIGHT_GRAY)
	theme.set_constant("shadow_offset_x", "Label", 1)
	theme.set_constant("shadow_offset_y", "Label", 1)
	theme.set_color("font_shadow_color", "Label", Color.BLACK)
	label.theme = theme

# Public API
func refresh_keybindings() -> void:
	"""Refresh keybinding display - useful if input map changes"""
	_load_key_bindings()
	_create_keybinding_display()
	Logger.debug("KeybindingsComponent: Refreshed keybinding display", "ui")

func set_keybindings_visible(visible: bool) -> void:
	self.visible = visible
	if visible:
		Logger.debug("KeybindingsComponent: Shown", "ui")
	else:
		Logger.debug("KeybindingsComponent: Hidden", "ui")

func get_keybinding_stats() -> Dictionary:
	return {
		"total_bindings": key_bindings.size(),
		"movement_keys": key_bindings.Movement.size() if key_bindings.has("Movement") else 0,
		"system_keys": key_bindings.System.size() if key_bindings.has("System") else 0,
		"labels_created": binding_labels.size()
	}
