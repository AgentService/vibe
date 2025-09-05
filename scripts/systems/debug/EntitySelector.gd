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

# Sprite effect state
var selected_sprite_effect_active: bool = false
var hovered_sprite_effect_active: bool = false
var sprite_effect_tween: Tween

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
	# Selection now handled via sprite effects rather than separate indicators
	# Keep minimal fallback indicator for entities without sprites
	selection_indicator = Node2D.new()
	selection_indicator.name = "SelectionIndicator"
	add_child(selection_indicator)
	selection_indicator.visible = false

func _create_hover_indicator() -> void:
	# Hover now handled via sprite effects rather than separate indicators
	# Keep minimal fallback indicator for entities without sprites  
	hover_indicator = Node2D.new()
	hover_indicator.name = "HoverIndicator"
	add_child(hover_indicator)
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
	# Clear previous selection effect
	if not selected_entity_id.is_empty() and selected_sprite_effect_active:
		_clear_sprite_effect(selected_entity_id, "selection")
	
	# Update selection state
	selected_entity_id = entity_id
	
	# Apply selection effect to sprite
	_apply_sprite_effect(entity_id, "selection")
	selected_sprite_effect_active = true
	
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
	
	# Clear sprite effect
	if selected_sprite_effect_active:
		_clear_sprite_effect(selected_entity_id, "selection")
		selected_sprite_effect_active = false
	
	selected_entity_id = ""
	
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
	# Clear previous hover effect
	if not hovered_entity_id.is_empty() and hovered_sprite_effect_active:
		_clear_sprite_effect(hovered_entity_id, "hover")
	
	hovered_entity_id = entity_id
	
	if entity_id.is_empty():
		hovered_sprite_effect_active = false
	else:
		# Apply hover effect to sprite
		_apply_sprite_effect(entity_id, "hover")
		hovered_sprite_effect_active = true

# ============================================================================
# SPRITE-BASED VISUAL EFFECTS
# Apply effects directly to enemy sprites rather than external indicators
# ============================================================================

func _apply_sprite_effect(entity_id: String, effect_type: String) -> void:
	Logger.debug("_apply_sprite_effect called: entity_id=%s, effect_type=%s" % [entity_id, effect_type], "debug")
	
	var entity_data := EntityTracker.get_entity(entity_id)
	if not entity_data.has("type"):
		Logger.debug("Entity data missing 'type' field for: %s" % entity_id, "debug")
		return
		
	var entity_type: String = entity_data["type"]
	Logger.debug("Entity type: %s" % entity_type, "debug")
	
	# Different approaches for different entity types
	if _is_multimesh_entity(entity_type):
		Logger.debug("Applying multimesh effect", "debug")
		_apply_multimesh_sprite_effect(entity_id, effect_type)
	elif _is_boss_entity(entity_type):
		Logger.debug("Applying boss effect", "debug")
		_apply_boss_sprite_effect(entity_id, effect_type)
	else:
		Logger.debug("Unknown entity type for sprite effects: %s" % entity_type, "debug")

func _clear_sprite_effect(entity_id: String, effect_type: String) -> void:
	var entity_data := EntityTracker.get_entity(entity_id)
	if not entity_data.has("type"):
		return
		
	var entity_type: String = entity_data["type"]
	
	if _is_multimesh_entity(entity_type):
		_clear_multimesh_sprite_effect(entity_id, effect_type)
	elif _is_boss_entity(entity_type):
		_clear_boss_sprite_effect(entity_id, effect_type)

func _is_multimesh_entity(entity_type: String) -> bool:
	# MultiMesh entities are typically swarm types
	return entity_type == "goblin"

func _is_boss_entity(entity_type: String) -> bool:
	# Boss entities are scene-based nodes
	return entity_type in ["ancient_lich", "dragon_lord"]

func _apply_multimesh_sprite_effect(entity_id: String, effect_type: String) -> void:
	# For MultiMesh entities, we'd need to modify the shader or find the specific instance
	# This is more complex and would require MultiMeshManager integration
	Logger.debug("MultiMesh sprite effect not yet implemented for: %s" % entity_id, "debug")

func _clear_multimesh_sprite_effect(entity_id: String, effect_type: String) -> void:
	# Clear MultiMesh effect
	Logger.debug("MultiMesh sprite effect clear not yet implemented for: %s" % entity_id, "debug")

func _apply_boss_sprite_effect(entity_id: String, effect_type: String) -> void:
	# For boss entities, find the actual scene node and modify its sprite
	Logger.debug("Searching for boss node with ID: %s" % entity_id, "debug")
	
	var boss_node := _find_boss_node_by_id(entity_id)
	if not boss_node:
		Logger.debug("Boss node not found for ID: %s" % entity_id, "debug")
		return
		
	Logger.debug("Found boss node: %s" % boss_node.name, "debug")
	
	var sprite := _find_sprite_in_boss(boss_node)
	if not sprite:
		Logger.debug("Sprite not found in boss node: %s" % boss_node.name, "debug")
		return
	
	Logger.debug("Found sprite: %s, applying %s effect" % [sprite.name, effect_type], "debug")
	
	# Apply effect based on type
	match effect_type:
		"hover":
			_apply_hover_effect_to_sprite(sprite)
		"selection":
			_apply_selection_effect_to_sprite(sprite)

func _clear_boss_sprite_effect(entity_id: String, effect_type: String) -> void:
	var boss_node := _find_boss_node_by_id(entity_id)
	if not boss_node:
		return
		
	var sprite := _find_sprite_in_boss(boss_node)
	if not sprite:
		return
	
	# Clear effect
	_clear_effect_from_sprite(sprite)

func _find_boss_node_by_id(entity_id: String) -> Node:
	# Search the scene tree for a boss node with matching entity ID
	var scene_tree := get_tree()
	if not scene_tree:
		return null
		
	var current_scene := scene_tree.current_scene
	if not current_scene:
		return null
	
	# Look for boss nodes (they typically have recognizable names or are in groups)
	return _search_for_boss_recursive(current_scene, entity_id)

func _search_for_boss_recursive(node: Node, target_id: String) -> Node:
	# Check if this node might be our boss
	if _node_matches_boss_id(node, target_id):
		return node
	
	# Search children recursively
	for child in node.get_children():
		var result := _search_for_boss_recursive(child, target_id)
		if result:
			return result
	
	return null

func _node_matches_boss_id(node: Node, target_id: String) -> bool:
	# Boss nodes might have the entity_id in their name or as a property
	if node.name.contains(target_id):
		return true
	
	# Check if node has an entity_id property/metadata
	if node.has_method("get_entity_id"):
		return node.get_entity_id() == target_id
	
	# Check for boss types by name (AncientLich, DragonLord, etc.)
	if node.name.contains("Lich") or node.name.contains("Dragon") or node.name.contains("Boss"):
		# Verify position match as additional verification
		var entity_data := EntityTracker.get_entity(target_id)
		if entity_data.has("pos"):
			var entity_pos: Vector2 = entity_data["pos"]
			var node_pos: Vector2 = node.global_position
			var distance := entity_pos.distance_to(node_pos)
			# If positions are close (within 50 pixels), it's likely a match
			if distance < 50.0:
				return true
	
	# Check groups
	if node.is_in_group("bosses"):
		return true
	
	return false

func _find_sprite_in_boss(boss_node: Node) -> Node:
	# Look for Sprite2D or AnimatedSprite2D in the boss node
	if boss_node is Sprite2D or boss_node is AnimatedSprite2D:
		return boss_node
	
	# Search children for sprite nodes
	for child in boss_node.get_children():
		if child is Sprite2D or child is AnimatedSprite2D:
			return child
		
		# Recursively search deeper if needed
		var sprite := _find_sprite_in_boss(child)
		if sprite:
			return sprite
	
	return null

func _apply_hover_effect_to_sprite(sprite: Node) -> void:
	if sprite is Sprite2D:
		var sprite2d := sprite as Sprite2D
		sprite2d.modulate = Color(1.2, 1.2, 1.4, 1.0)  # Slightly bright blue tint
	elif sprite is AnimatedSprite2D:
		var animated_sprite := sprite as AnimatedSprite2D
		animated_sprite.modulate = Color(1.2, 1.2, 1.4, 1.0)

func _apply_selection_effect_to_sprite(sprite: Node) -> void:
	if sprite is Sprite2D:
		var sprite2d := sprite as Sprite2D
		
		# Create pulsing effect
		if sprite_effect_tween:
			sprite_effect_tween.kill()
		
		sprite_effect_tween = create_tween()
		sprite_effect_tween.set_loops()
		sprite_effect_tween.tween_property(sprite2d, "modulate", Color(1.5, 1.0, 1.0, 1.0), 0.8)  # Red tint
		sprite_effect_tween.tween_property(sprite2d, "modulate", Color(1.8, 1.2, 1.2, 1.0), 0.8)  # Brighter red
		
	elif sprite is AnimatedSprite2D:
		var animated_sprite := sprite as AnimatedSprite2D
		
		if sprite_effect_tween:
			sprite_effect_tween.kill()
		
		sprite_effect_tween = create_tween()
		sprite_effect_tween.set_loops()
		sprite_effect_tween.tween_property(animated_sprite, "modulate", Color(1.5, 1.0, 1.0, 1.0), 0.8)
		sprite_effect_tween.tween_property(animated_sprite, "modulate", Color(1.8, 1.2, 1.2, 1.0), 0.8)

func _clear_effect_from_sprite(sprite: Node) -> void:
	if sprite_effect_tween:
		sprite_effect_tween.kill()
		sprite_effect_tween = null
	
	if sprite is Sprite2D:
		var sprite2d := sprite as Sprite2D
		sprite2d.modulate = Color(1.0, 1.0, 1.0, 1.0)  # Reset to normal
	elif sprite is AnimatedSprite2D:
		var animated_sprite := sprite as AnimatedSprite2D
		animated_sprite.modulate = Color(1.0, 1.0, 1.0, 1.0)