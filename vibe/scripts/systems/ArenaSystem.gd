extends Node

## Core arena management system that coordinates all arena-related subsystems.
## Follows the project's system architecture with data-driven configuration.

const TerrainSystem = preload("res://scripts/systems/TerrainSystem.gd")
const ObstacleSystem = preload("res://scripts/systems/ObstacleSystem.gd")
const InteractableSystem = preload("res://scripts/systems/InteractableSystem.gd")
const WallSystem = preload("res://scripts/systems/WallSystem.gd")
const RoomLoader = preload("res://scripts/systems/RoomLoader.gd")

signal arena_loaded(arena_data: Dictionary)
signal room_changed(old_room_id: String, new_room_id: String)
signal arena_object_interacted(object_type: String, object_id: String, player_id: String)

var current_arena_id: String = ""
var current_room_id: String = ""
var arena_data: Dictionary = {}

# Subsystem references - public for Arena scene connections
var terrain_system: TerrainSystem
var obstacle_system: ObstacleSystem  
var interactable_system: InteractableSystem
var wall_system: WallSystem

# Room management
var room_loader: RoomLoader
var loaded_rooms: Dictionary = {}

const ARENA_DATA_PATH: String = "res://data/arena/"

func _ready() -> void:
	_initialize_subsystems()
	_connect_signals()

func _initialize_subsystems() -> void:
	# Create subsystems in dependency order
	terrain_system = TerrainSystem.new()
	obstacle_system = ObstacleSystem.new()
	interactable_system = InteractableSystem.new()
	wall_system = WallSystem.new()
	room_loader = RoomLoader.new()
	
	# Add to tree
	add_child(terrain_system)
	add_child(obstacle_system)
	add_child(interactable_system)
	add_child(wall_system)
	add_child(room_loader)

func _connect_signals() -> void:
	# Connect subsystem signals
	terrain_system.terrain_updated.connect(_on_terrain_updated)
	obstacle_system.obstacles_updated.connect(_on_obstacles_updated)
	interactable_system.interactable_activated.connect(_on_interactable_activated)
	wall_system.walls_updated.connect(_on_walls_updated)
	room_loader.room_loaded.connect(_on_room_loaded)
	
	# Connect to global events
	PlayerState.player_position_changed.connect(_on_player_moved)

func load_arena(arena_id: String) -> bool:
	var arena_path := ARENA_DATA_PATH + "layouts/" + arena_id + ".json"
	var file := FileAccess.open(arena_path, FileAccess.READ)
	
	if not file:
		push_error("ArenaSystem: Could not load arena data: " + arena_path)
		return false
	
	var json_text := file.get_as_text()
	file.close()
	
	var json: JSON = JSON.new()
	var parse_result: Error = json.parse(json_text)
	
	if parse_result != OK:
		push_error("ArenaSystem: Invalid JSON in arena file: " + arena_path)
		return false
	
	arena_data = json.data as Dictionary
	current_arena_id = arena_id
	
	# Load initial room
	var start_room_id: String = arena_data.get("start_room", "room_001")
	load_room(start_room_id)
	
	arena_loaded.emit(arena_data)
	return true

func load_room(room_id: String) -> bool:
	if room_id == current_room_id:
		return true
	
	var old_room_id := current_room_id
	
	# Load room data
	if not room_loader.load_room(room_id):
		push_error("ArenaSystem: Failed to load room: " + room_id)
		return false
	
	var room_data := room_loader.get_room_data(room_id)
	
	# Clear current room
	_clear_current_room()
	
	# Apply room data to subsystems
	_apply_room_to_subsystems(room_data)
	
	current_room_id = room_id
	loaded_rooms[room_id] = room_data
	
	room_changed.emit(old_room_id, room_id)
	return true

func _clear_current_room() -> void:
	terrain_system.clear_terrain()
	obstacle_system.clear_obstacles()
	interactable_system.clear_interactables()
	wall_system.cleanup()

func _apply_room_to_subsystems(room_data: Dictionary) -> void:
	# Apply terrain (floors, environmental effects)
	if room_data.has("terrain"):
		terrain_system.load_terrain(room_data.terrain)
	
	# Apply obstacles (walls, pillars, barriers)
	if room_data.has("obstacles"):
		obstacle_system.load_obstacles(room_data.obstacles)
	
	# Apply interactables (doors, chests, altars)
	if room_data.has("interactables"):
		interactable_system.load_interactables(room_data.interactables)
	
	# Apply boundaries (arena walls)
	if room_data.has("boundaries"):
		wall_system.load_boundaries(room_data.boundaries)

func get_current_room_data() -> Dictionary:
	if current_room_id.is_empty():
		return {}
	return loaded_rooms.get(current_room_id, {})

func get_arena_bounds() -> Rect2:
	if arena_data.has("bounds"):
		var bounds_data := arena_data.bounds as Dictionary
		return Rect2(
			Vector2(bounds_data.get("x", -400), bounds_data.get("y", -300)),
			Vector2(bounds_data.get("width", 800), bounds_data.get("height", 600))
		)
	return Rect2(-400, -300, 800, 600)  # Default bounds

# Signal handlers
func _on_terrain_updated(terrain_transforms: Array[Transform2D]) -> void:
	# Forward to Arena scene for visual updates
	pass

func _on_obstacles_updated(obstacle_transforms: Array[Transform2D]) -> void:
	# Forward to Arena scene for visual updates
	pass

func _on_interactable_activated(interactable_id: String, interactable_type: String) -> void:
	arena_object_interacted.emit(interactable_type, interactable_id, "player")
	
	# Handle special interactions
	match interactable_type:
		"door":
			_handle_door_interaction(interactable_id)
		"chest":
			_handle_chest_interaction(interactable_id)
		"portal":
			_handle_portal_interaction(interactable_id)

func _on_walls_updated(wall_transforms: Array[Transform2D]) -> void:
	# Forward to Arena scene for visual updates
	pass

func _on_room_loaded(room_id: String, room_data: Dictionary) -> void:
	# Room data is now available for use
	pass

func _on_player_moved(position: Vector2) -> void:
	# Check for room transitions, trigger zones, etc.
	_check_room_transitions(position)

func _handle_door_interaction(door_id: String) -> void:
	var room_data := get_current_room_data()
	if not room_data.has("interactables"):
		return
	
	var interactables := room_data.interactables as Array
	for interactable in interactables:
		var data := interactable as Dictionary
		if data.get("id") == door_id and data.get("type") == "door":
			var target_room: String = data.get("target_room", "")
			if not target_room.is_empty():
				load_room(target_room)
			break

func _handle_chest_interaction(chest_id: String) -> void:
	# Emit loot generation event
	var payload := EventBus.LootGeneratedPayload.new(chest_id, "chest", {})
	EventBus.loot_generated.emit(payload)

func _handle_portal_interaction(portal_id: String) -> void:
	# Handle arena/level transitions
	var room_data := get_current_room_data()
	# Implementation depends on portal configuration
	pass

func _check_room_transitions(player_pos: Vector2) -> void:
	# Check if player has moved to a transition zone
	var room_data := get_current_room_data()
	if not room_data.has("transitions"):
		return
	
	var transitions := room_data.transitions as Array
	for transition in transitions:
		var data := transition as Dictionary
		var trigger_area: Rect2 = _parse_area(data.get("trigger_area", {}))
		
		if trigger_area.has_point(player_pos):
			var target_room: String = data.get("target_room", "")
			if not target_room.is_empty():
				load_room(target_room)
			break

func _parse_area(area_data: Dictionary) -> Rect2:
	return Rect2(
		Vector2(area_data.get("x", 0), area_data.get("y", 0)),
		Vector2(area_data.get("width", 0), area_data.get("height", 0))
	)

func cleanup() -> void:
	_clear_current_room()
	loaded_rooms.clear()
	current_arena_id = ""
	current_room_id = ""

func _exit_tree() -> void:
	cleanup()
	
	# Disconnect signals
	if terrain_system and terrain_system.terrain_updated.is_connected(_on_terrain_updated):
		terrain_system.terrain_updated.disconnect(_on_terrain_updated)
	if obstacle_system and obstacle_system.obstacles_updated.is_connected(_on_obstacles_updated):
		obstacle_system.obstacles_updated.disconnect(_on_obstacles_updated)
	if interactable_system and interactable_system.interactable_activated.is_connected(_on_interactable_activated):
		interactable_system.interactable_activated.disconnect(_on_interactable_activated)
	if wall_system and wall_system.walls_updated.is_connected(_on_walls_updated):
		wall_system.walls_updated.disconnect(_on_walls_updated)
	if room_loader and room_loader.room_loaded.is_connected(_on_room_loaded):
		room_loader.room_loaded.disconnect(_on_room_loaded)
	
	PlayerState.player_position_changed.disconnect(_on_player_moved)
