extends Node

## EntitySelector - Debug entity selection system
## Handles mouse clicks to select entities for inspection and manipulation
## Integrates with EntityTracker for spatial queries and DebugManager for state

class_name EntitySelector

# Selection state
var selected_entity_id: String = ""
var hovered_entity_id: String = ""
var selection_indicator: Node2D
var hover_indicator: Node2D

# Input handling
var mouse_enabled: bool = false

signal entity_selected(entity_id: String)
signal entity_deselected()

func _ready() -> void:
	# Connect to DebugManager signals
	if DebugManager:
		DebugManager.debug_mode_toggled.connect(_on_debug_mode_toggled)
	
	# Create selection and hover indicators
	_create_selection_indicator()
	_create_hover_indicator()
	
	Logger.debug("EntitySelector initialized", "debug")

func _create_selection_indicator() -> void:
	# Create a visual indicator for the selected entity
	selection_indicator = Node2D.new()
	selection_indicator.name = "SelectionIndicator"
	add_child(selection_indicator)
	
	# Create a diamond shape with pulsing effect
	var line2d := Line2D.new()
	line2d.width = 4.0
	line2d.default_color = Color.ORANGE_RED
	line2d.closed = true
	
	# Create diamond points
	var diamond_points: PackedVector2Array = [
		Vector2(0, -45),    # Top
		Vector2(45, 0),     # Right
		Vector2(0, 45),     # Bottom
		Vector2(-45, 0)     # Left
	]
	line2d.points = diamond_points
	selection_indicator.add_child(line2d)
	
	# Add pulsing animation
	var tween := create_tween()
	tween.set_loops()
	tween.tween_property(line2d, "modulate:a", 0.5, 0.8)
	tween.tween_property(line2d, "modulate:a", 1.0, 0.8)
	
	# Hide by default
	selection_indicator.visible = false

func _create_hover_indicator() -> void:
	# Create a visual indicator for hovering over entities
	hover_indicator = Node2D.new()
	hover_indicator.name = "HoverIndicator"
	add_child(hover_indicator)
	
	# Create corner brackets for hover
	var bracket_color := Color.CYAN
	var bracket_size := 25.0
	var bracket_width := 3.0
	
	# Top-left bracket
	var tl_bracket := Line2D.new()
	tl_bracket.width = bracket_width
	tl_bracket.default_color = bracket_color
	tl_bracket.points = PackedVector2Array([
		Vector2(-bracket_size, -bracket_size/3),
		Vector2(-bracket_size, -bracket_size),
		Vector2(-bracket_size/3, -bracket_size)
	])
	hover_indicator.add_child(tl_bracket)
	
	# Top-right bracket
	var tr_bracket := Line2D.new()
	tr_bracket.width = bracket_width
	tr_bracket.default_color = bracket_color
	tr_bracket.points = PackedVector2Array([
		Vector2(bracket_size/3, -bracket_size),
		Vector2(bracket_size, -bracket_size),
		Vector2(bracket_size, -bracket_size/3)
	])
	hover_indicator.add_child(tr_bracket)
	
	# Bottom-left bracket
	var bl_bracket := Line2D.new()
	bl_bracket.width = bracket_width
	bl_bracket.default_color = bracket_color
	bl_bracket.points = PackedVector2Array([
		Vector2(-bracket_size/3, bracket_size),
		Vector2(-bracket_size, bracket_size),
		Vector2(-bracket_size, bracket_size/3)
	])
	hover_indicator.add_child(bl_bracket)
	
	# Bottom-right bracket
	var br_bracket := Line2D.new()
	br_bracket.width = bracket_width
	br_bracket.default_color = bracket_color
	br_bracket.points = PackedVector2Array([
		Vector2(bracket_size, bracket_size/3),
		Vector2(bracket_size, bracket_size),
		Vector2(bracket_size/3, bracket_size)
	])
	hover_indicator.add_child(br_bracket)
	
	# Hide by default
	hover_indicator.visible = false

func _on_debug_mode_toggled(enabled: bool) -> void:
	mouse_enabled = enabled
	
	if not enabled:
		# Clear selection when exiting debug mode
		_deselect_entity()
		Logger.debug("EntitySelector disabled", "debug")
	else:
		Logger.debug("EntitySelector enabled", "debug")

func _input(event: InputEvent) -> void:
	if not mouse_enabled:
		return
		
	# Handle mouse clicks for entity selection (Ctrl+Click only)
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		
		# Only handle Ctrl+Left Click for entity selection to avoid interfering with combat
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed and mouse_event.ctrl_pressed:
			_handle_mouse_click(mouse_event.global_position)
			get_viewport().set_input_as_handled()  # Prevent combat system from handling this click

func _handle_mouse_click(screen_pos: Vector2) -> void:
	# Convert screen position to world position
	var world_pos := _screen_to_world(screen_pos)
	
	# Query EntityTracker for entities at this position
	var entity_id := _get_entity_at_position(world_pos)
	
	if entity_id.is_empty():
		# Clicked on empty space - deselect
		_deselect_entity()
	else:
		# Clicked on entity - select it
		_select_entity(entity_id, world_pos)

func _screen_to_world(screen_pos: Vector2) -> Vector2:
	# Get the current viewport and camera
	var viewport := get_viewport()
	if not viewport:
		return screen_pos
	
	var camera := viewport.get_camera_2d()
	if not camera:
		return screen_pos
	
	# Convert screen coordinates to world coordinates using Godot's built-in method
	return camera.get_global_mouse_position()

func _get_entity_at_position(world_pos: Vector2) -> String:
	# Use EntityTracker to find entities within click radius
	var click_radius := 40.0  # Generous click area for both MultiMesh and boss entities
	var nearby_entities := EntityTracker.get_entities_in_radius(world_pos, click_radius)
	
	if nearby_entities.is_empty():
		return ""
	
	# Find the closest entity to the click point
	var closest_entity_id: String = ""
	var closest_distance := INF
	
	for entity_id in nearby_entities:
		var entity_data := EntityTracker.get_entity(entity_id)
		if not entity_data.has("pos"):
			continue
			
		var entity_pos: Vector2 = entity_data["pos"]
		var distance := world_pos.distance_to(entity_pos)
		
		if distance < closest_distance:
			closest_distance = distance
			closest_entity_id = entity_id
	
	return closest_entity_id

func _select_entity(entity_id: String, world_pos: Vector2) -> void:
	# Update selection state
	selected_entity_id = entity_id
	
	# Get entity data for positioning indicator
	var entity_data := EntityTracker.get_entity(entity_id)
	if entity_data.has("pos"):
		var entity_pos: Vector2 = entity_data["pos"]
		selection_indicator.global_position = entity_pos
		selection_indicator.visible = true
	
	# Emit selection signals
	entity_selected.emit(entity_id)
	
	# Notify DebugManager
	if DebugManager:
		DebugManager.select_entity(entity_id)
	
	Logger.debug("Selected entity: %s at %s" % [entity_id, world_pos], "debug")

func _deselect_entity() -> void:
	if selected_entity_id.is_empty():
		return
		
	var old_entity_id := selected_entity_id
	selected_entity_id = ""
	
	# Hide selection indicator
	selection_indicator.visible = false
	
	# Emit deselection signals
	entity_deselected.emit()
	
	# Notify DebugManager
	if DebugManager:
		DebugManager.select_entity("")
	
	Logger.debug("Deselected entity: %s" % old_entity_id, "debug")

func get_selected_entity_id() -> String:
	return selected_entity_id

func is_entity_selected() -> bool:
	return not selected_entity_id.is_empty()

# Update indicators and handle hover detection
func _process(_delta: float) -> void:
	if not mouse_enabled:
		return
	
	# Handle hover detection on mouse movement
	_update_hover_detection()
	
	# Update selection indicator position to follow the selected entity
	if not selected_entity_id.is_empty():
		var entity_data := EntityTracker.get_entity(selected_entity_id)
		if entity_data.has("pos"):
			var entity_pos: Vector2 = entity_data["pos"]
			selection_indicator.global_position = entity_pos
		else:
			# Entity no longer exists - deselect
			_deselect_entity()

func _update_hover_detection() -> void:
	# Get current mouse position in world coordinates directly
	var camera := get_viewport().get_camera_2d()
	if not camera:
		return
		
	var mouse_world_pos := camera.get_global_mouse_position()
	
	# Check for entity under cursor
	var entity_under_cursor := _get_entity_at_position(mouse_world_pos)
	
	# Update hover state
	if entity_under_cursor != hovered_entity_id:
		_set_hovered_entity(entity_under_cursor)

func _set_hovered_entity(entity_id: String) -> void:
	hovered_entity_id = entity_id
	
	if entity_id.is_empty():
		# No entity hovered - hide hover indicator
		hover_indicator.visible = false
	else:
		# Entity hovered - show hover indicator
		var entity_data := EntityTracker.get_entity(entity_id)
		if entity_data.has("pos"):
			var entity_pos: Vector2 = entity_data["pos"]
			hover_indicator.global_position = entity_pos
			hover_indicator.visible = true