extends Panel
class_name KeybindingsDisplay

## Simple keybindings display panel showing current hotkeys

@onready var bindings_container: VBoxContainer = $VBoxContainer

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_panel_style()
	_populate_bindings()

func _setup_panel_style() -> void:
	# Apply radar-style styling
	var style_box := StyleBoxFlat.new()
	style_box.bg_color = Color(0.0, 0.0, 0.0, 0.7)  # Dark background like radar
	style_box.border_width_left = 2
	style_box.border_width_right = 2
	style_box.border_width_top = 2
	style_box.border_width_bottom = 2
	style_box.border_color = Color(0.4, 0.4, 0.4, 0.9)  # Gray border like radar
	style_box.corner_radius_top_left = 4
	style_box.corner_radius_top_right = 4
	style_box.corner_radius_bottom_left = 4
	style_box.corner_radius_bottom_right = 4
	add_theme_stylebox_override("panel", style_box)
	
	# Create VBoxContainer if not in scene
	if not bindings_container:
		bindings_container = VBoxContainer.new()
		bindings_container.name = "VBoxContainer"
		add_child(bindings_container)

func _populate_bindings() -> void:
	# Clear existing content
	for child in bindings_container.get_children():
		child.queue_free()
	
	# Title
	var title_label := Label.new()
	title_label.text = "[Controls]"
	title_label.add_theme_font_size_override("font_size", 12)
	title_label.add_theme_color_override("font_color", Color.WHITE)
	bindings_container.add_child(title_label)
	
	# Add spacing
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 4)
	bindings_container.add_child(spacer)
	
	# Create table-like structure using GridContainer
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 2)
	bindings_container.add_child(grid)
	
	# Movement controls
	_add_binding_row(grid, "Move:", "WASD")
	
	# Combat controls
	_add_binding_row(grid, "Attack:", "Left Click")
	
	# System controls
	_add_binding_row(grid, "Pause:", "F10")
	_add_binding_row(grid, "FPS:", "F12")
	_add_binding_row(grid, "Theme:", "T")
	
	# Arena switching
	_add_binding_row(grid, "Arena:", "1-5")

func _add_binding_row(grid: GridContainer, action: String, key: String) -> void:
	# Action label (left column)
	var action_label := Label.new()
	action_label.text = action
	action_label.add_theme_font_size_override("font_size", 10)
	action_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	action_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	grid.add_child(action_label)
	
	# Key label (right column)
	var key_label := Label.new()
	key_label.text = key
	key_label.add_theme_font_size_override("font_size", 10)
	key_label.add_theme_color_override("font_color", Color.WHITE)
	key_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	grid.add_child(key_label)