extends Panel
class_name KeybindingsDisplay

## Simple keybindings display panel showing current hotkeys

@onready var bindings_container: VBoxContainer = $VBoxContainer

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_panel_style()
	_populate_bindings()
	_auto_resize_panel()

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
	_add_binding_row(grid, "Pause:", "Escape")
	
	# Debug/Cheat controls (only show in debug builds or when CheatSystem is available)
	if CheatSystem:
		# Add separator
		var separator := Control.new()
		separator.custom_minimum_size = Vector2(0, 4)
		bindings_container.add_child(separator)
		
		var debug_title := Label.new()
		debug_title.text = "[Debug]"
		debug_title.add_theme_font_size_override("font_size", 12)
		debug_title.add_theme_color_override("font_color", Color(1.0, 0.8, 0.0))  # Yellow
		bindings_container.add_child(debug_title)
		
		var debug_grid := GridContainer.new()
		debug_grid.columns = 2
		debug_grid.add_theme_constant_override("h_separation", 8)
		debug_grid.add_theme_constant_override("v_separation", 2)
		bindings_container.add_child(debug_grid)
		
		_add_binding_row(debug_grid, "Console:", "F1")
		_add_binding_row(debug_grid, "Cards:", "C")
		_add_binding_row(debug_grid, "Performance:", "F12")
		_add_binding_row(debug_grid, "God Mode:", "Ctrl+1")
		_add_binding_row(debug_grid, "Stop Spawn:", "Ctrl+2")
		_add_binding_row(debug_grid, "Silent Pause:", "F10")

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

func _auto_resize_panel() -> void:
	# Wait for next frame to ensure all nodes are properly initialized
	await get_tree().process_frame
	
	# Get the actual content size from the VBoxContainer
	if bindings_container:
		# Force a size update on the container
		bindings_container.queue_redraw()
		await get_tree().process_frame
		
		# Calculate required size with padding
		var content_size := bindings_container.get_combined_minimum_size()
		var padding := Vector2(16, 16)  # 8px margin on all sides * 2
		var required_size := content_size + padding
		
		# Store current position (top-right anchored)
		var current_right := position.x + size.x
		var current_top := position.y
		
		# Get viewport size for overflow prevention
		var viewport_size := get_viewport().get_visible_rect().size
		var max_width := viewport_size.x * 0.25  # Max 25% of screen width
		var max_height := viewport_size.y * 0.8  # Max 80% of screen height
		
		# Clamp size to prevent overflow
		required_size.x = min(required_size.x, max_width)
		required_size.y = min(required_size.y, max_height)
		
		# Update panel size to fit content
		custom_minimum_size = required_size
		size = required_size
		
		# Maintain top-right anchor by adjusting position
		position.x = current_right - size.x
		position.y = current_top
		
		# Ensure panel doesn't go off-screen
		if position.x < 0:
			position.x = 0
		if position.y + size.y > viewport_size.y:
			position.y = viewport_size.y - size.y
		
		# Enable scrolling if content is too large
		if content_size.y > max_height - padding.y:
			_enable_scrolling()
		
		if Logger.is_level_enabled(Logger.LogLevel.DEBUG):
			Logger.debug("KeybindingsDisplay auto-resized to: " + str(size), "ui")

func _enable_scrolling() -> void:
	# Convert VBoxContainer to ScrollContainer setup
	if bindings_container.get_parent() == self:
		# Remove VBoxContainer from panel
		remove_child(bindings_container)
		
		# Create ScrollContainer
		var scroll_container := ScrollContainer.new()
		scroll_container.name = "ScrollContainer"
		scroll_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		# Leave scroll bar policy as default - Godot 4.4 changed the API
		# The scroll container will handle scrolling automatically
		add_child(scroll_container)
		
		# Add VBoxContainer to ScrollContainer
		scroll_container.add_child(bindings_container)
		
		Logger.debug("KeybindingsDisplay enabled scrolling for overflow content", "ui")
