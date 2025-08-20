extends Node
class_name RoomLoader

## Room loader for managing JSON-based room layouts and configurations.
## Supports both static room definitions and procedural generation.

signal room_loaded(room_id: String, room_data: Dictionary)
signal room_load_failed(room_id: String, error: String)

var loaded_rooms: Dictionary = {}
var room_cache: Dictionary = {}

const ROOMS_DATA_PATH: String = "res://data/arena/layouts/rooms/"
const ROOM_TEMPLATES_PATH: String = "res://data/arena/templates/"

func _ready() -> void:
	pass

func load_room(room_id: String) -> bool:
	# Check cache first
	if room_cache.has(room_id):
		var room_data := room_cache[room_id] as Dictionary
		loaded_rooms[room_id] = room_data
		room_loaded.emit(room_id, room_data)
		return true
	
	# Try to load from file
	var room_data := _load_room_from_file(room_id)
	if room_data.is_empty():
		# Try procedural generation
		room_data = _generate_room(room_id)
		if room_data.is_empty():
			room_load_failed.emit(room_id, "Failed to load or generate room")
			return false
	
	# Cache and store
	room_cache[room_id] = room_data
	loaded_rooms[room_id] = room_data
	
	room_loaded.emit(room_id, room_data)
	return true

func _load_room_from_file(room_id: String) -> Dictionary:
	var room_path := ROOMS_DATA_PATH + room_id + ".json"
	var file := FileAccess.open(room_path, FileAccess.READ)
	
	if not file:
		return {}
	
	var json_text := file.get_as_text()
	file.close()
	
	var json := JSON.new()
	var parse_result := json.parse(json_text)
	
	if parse_result != OK:
		push_error("RoomLoader: Invalid JSON in room file: " + room_path)
		return {}
	
	return json.data as Dictionary

func _generate_room(room_id: String) -> Dictionary:
	# Basic procedural room generation
	# This is a simple example - could be much more sophisticated
	
	var room_data := {
		"id": room_id,
		"name": "Generated Room",
		"size": {"width": 800, "height": 600},
		"generated": true,
		"boundaries": {
			"arena_size": {"x": 800, "y": 600},
			"wall_thickness": 32
		},
		"terrain": {
			"tiles": _generate_floor_tiles()
		},
		"obstacles": {
			"objects": _generate_obstacles()
		},
		"interactables": {
			"objects": _generate_interactables()
		}
	}
	
	return room_data

func _generate_floor_tiles() -> Array[Dictionary]:
	# Generate a basic floor pattern
	var tiles: Array[Dictionary] = []
	var tile_size := 32
	var room_width := 800
	var room_height := 600
	
	# Create a simple grid of floor tiles
	for x in range(-room_width/2, room_width/2, tile_size):
		for y in range(-room_height/2, room_height/2, tile_size):
			tiles.append({
				"x": x,
				"y": y,
				"type": "stone_floor",
				"rotation": 0.0
			})
	
	return tiles

func _generate_obstacles() -> Array[Dictionary]:
	# Generate some random obstacles
	var obstacles: Array[Dictionary] = []
	var obstacle_count := RNG.randi_range("arena", 3, 8)
	
	for i in range(obstacle_count):
		var x := RNG.randf_range("arena", -300, 300)
		var y := RNG.randf_range("arena", -200, 200)
		
		obstacles.append({
			"id": "gen_obstacle_" + str(i),
			"type": "pillar",
			"x": x,
			"y": y,
			"size": {"width": 24, "height": 24},
			"rotation": 0.0,
			"destructible": false
		})
	
	return obstacles

func _generate_interactables() -> Array[Dictionary]:
	# Generate some basic interactables
	var interactables: Array[Dictionary] = []
	
	# Add a chest
	interactables.append({
		"id": "gen_chest_1",
		"type": "chest",
		"x": RNG.randf_range("arena", -200, 200),
		"y": RNG.randf_range("arena", -150, 150),
		"interaction_radius": 40.0,
		"loot_table": "basic_chest",
		"can_reactivate": false
	})
	
	return interactables

func get_room_data(room_id: String) -> Dictionary:
	return loaded_rooms.get(room_id, {})

func unload_room(room_id: String) -> void:
	loaded_rooms.erase(room_id)

func preload_room(room_id: String) -> void:
	# Load room data into cache without activating
	if not room_cache.has(room_id):
		var room_data := _load_room_from_file(room_id)
		if not room_data.is_empty():
			room_cache[room_id] = room_data

func get_room_bounds(room_id: String) -> Rect2:
	var room_data := get_room_data(room_id)
	if room_data.has("size"):
		var size_data := room_data.size as Dictionary
		var width := size_data.get("width", 800) as float
		var height := size_data.get("height", 600) as float
		return Rect2(-width * 0.5, -height * 0.5, width, height)
	
	return Rect2(-400, -300, 800, 600)  # Default bounds

func validate_room_data(room_data: Dictionary) -> bool:
	# Basic room data validation
	if not room_data.has("id"):
		return false
	
	# Check required sections exist
	var required_sections := ["boundaries", "terrain", "obstacles", "interactables"]
	for section in required_sections:
		if not room_data.has(section):
			push_warning("RoomLoader: Room missing section: " + section)
	
	return true

func create_room_template(room_id: String, template_data: Dictionary) -> bool:
	# Save a room as a template for procedural generation
	var template_path := ROOM_TEMPLATES_PATH + room_id + "_template.json"
	var file := FileAccess.open(template_path, FileAccess.WRITE)
	
	if not file:
		return false
	
	var json_string := JSON.stringify(template_data, "\t")
	file.store_string(json_string)
	file.close()
	
	return true

func clear_cache() -> void:
	room_cache.clear()

func cleanup() -> void:
	loaded_rooms.clear()
	clear_cache()

func _exit_tree() -> void:
	cleanup()