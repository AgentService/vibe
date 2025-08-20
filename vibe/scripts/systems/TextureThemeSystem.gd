extends Node
class_name TextureThemeSystem

## Texture theme system for managing visual asset themes across the arena.
## Supports multiple themes (dungeon, cave, tech, forest) with fallback generation.

signal theme_changed(theme_name: String)

var current_theme: String = "dungeon"
var texture_cache: Dictionary = {}

const THEME_DATA_PATH: String = "res://data/arena/themes/"
const ASSET_BASE_PATH: String = "res://assets/sprites/"

# Theme configurations
var themes: Dictionary = {
	"dungeon": {
		"name": "Stone Dungeon",
		"wall_color": Color(0.6, 0.5, 0.4, 1.0),
		"floor_color": Color(0.4, 0.4, 0.5, 1.0),
		"accent_color": Color(0.3, 0.2, 0.2, 1.0)
	},
	"cave": {
		"name": "Natural Cave",
		"wall_color": Color(0.3, 0.2, 0.1, 1.0),
		"floor_color": Color(0.2, 0.15, 0.1, 1.0),
		"accent_color": Color(0.4, 0.3, 0.2, 1.0)
	},
	"tech": {
		"name": "Tech Facility",
		"wall_color": Color(0.7, 0.7, 0.8, 1.0),
		"floor_color": Color(0.8, 0.8, 0.9, 1.0),
		"accent_color": Color(0.2, 0.6, 0.8, 1.0)
	},
	"forest": {
		"name": "Overgrown Ruins",
		"wall_color": Color(0.4, 0.6, 0.3, 1.0),
		"floor_color": Color(0.3, 0.5, 0.2, 1.0),
		"accent_color": Color(0.6, 0.4, 0.2, 1.0)
	}
}

func _ready() -> void:
	pass

func set_theme(theme_name: String) -> bool:
	if not themes.has(theme_name):
		push_warning("TextureThemeSystem: Unknown theme: " + theme_name)
		return false
	
	current_theme = theme_name
	_clear_cache()
	theme_changed.emit(theme_name)
	return true

func get_texture(object_type: String, object_subtype: String = "") -> Texture2D:
	var cache_key: String = current_theme + "_" + object_type + "_" + object_subtype
	
	if texture_cache.has(cache_key):
		return texture_cache[cache_key]
	
	# Try to load from file first
	var texture := _load_texture_from_file(object_type, object_subtype)
	
	# Generate fallback if file not found
	if not texture:
		texture = _generate_fallback_texture(object_type, object_subtype)
	
	texture_cache[cache_key] = texture
	return texture

func _load_texture_from_file(object_type: String, object_subtype: String = "") -> Texture2D:
	var paths_to_try: Array[String] = []
	
	# Try theme-specific path first
	if not object_subtype.is_empty():
		paths_to_try.append(ASSET_BASE_PATH + object_type + "/themes/" + current_theme + "/" + object_subtype + ".webp")
		paths_to_try.append(ASSET_BASE_PATH + object_type + "/themes/" + current_theme + "/" + object_subtype + ".png")
	
	# Try generic theme path
	paths_to_try.append(ASSET_BASE_PATH + object_type + "/themes/" + current_theme + "/" + object_type + ".webp")
	paths_to_try.append(ASSET_BASE_PATH + object_type + "/themes/" + current_theme + "/" + object_type + ".png")
	
	# Try base object path
	paths_to_try.append(ASSET_BASE_PATH + object_type + "/" + object_type + ".webp")
	paths_to_try.append(ASSET_BASE_PATH + object_type + "/" + object_type + ".png")
	
	for path in paths_to_try:
		var texture := load(path) as Texture2D
		if texture:
			return texture
	
	return null

func _generate_fallback_texture(object_type: String, object_subtype: String = "") -> Texture2D:
	var theme_data: Dictionary = themes.get(current_theme, themes["dungeon"])
	
	match object_type:
		"walls":
			return _generate_wall_texture(theme_data)
		"terrain":
			return _generate_terrain_texture(theme_data)
		"obstacles":
			return _generate_obstacle_texture(theme_data, object_subtype)
		"interactables":
			return _generate_interactable_texture(theme_data, object_subtype)
		_:
			return _generate_generic_texture(theme_data)

func _generate_wall_texture(theme_data: Dictionary) -> Texture2D:
	var img := Image.create(64, 32, false, Image.FORMAT_RGBA8)
	var base_color: Color = theme_data.get("wall_color", Color.GRAY)
	var accent_color: Color = theme_data.get("accent_color", Color.DARK_GRAY)
	
	# Create brick pattern
	for x in range(64):
		for y in range(32):
			var is_border := x < 2 or x >= 62 or y < 2 or y >= 30
			var is_mortar := (x % 16 < 2) or (y % 8 < 1)
			
			if is_border:
				img.set_pixel(x, y, accent_color.darkened(0.3))
			elif is_mortar:
				img.set_pixel(x, y, base_color.lightened(0.3))
			else:
				img.set_pixel(x, y, base_color)
	
	return ImageTexture.create_from_image(img)

func _generate_terrain_texture(theme_data: Dictionary) -> Texture2D:
	var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	var base_color: Color = theme_data.get("floor_color", Color.GRAY)
	
	# Create subtle checkered pattern
	for x in range(32):
		for y in range(32):
			var checker := ((x / 8) + (y / 8)) % 2
			var color := base_color
			if checker == 0:
				color = base_color.lightened(0.1)
			else:
				color = base_color.darkened(0.1)
			
			img.set_pixel(x, y, color)
	
	return ImageTexture.create_from_image(img)

func _generate_obstacle_texture(theme_data: Dictionary, object_subtype: String) -> Texture2D:
	var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	var base_color: Color = theme_data.get("wall_color", Color.GRAY)
	
	match object_subtype:
		"pillar":
			# Create circular pillar
			var center := Vector2(16, 16)
			for x in range(32):
				for y in range(32):
					var distance := Vector2(x, y).distance_to(center)
					if distance <= 14:
						var shade := 1.0 - (distance / 14.0) * 0.3
						img.set_pixel(x, y, base_color * shade)
					else:
						img.set_pixel(x, y, Color.TRANSPARENT)
		"crate":
			# Create wooden crate
			var wood_color := Color(0.6, 0.4, 0.2, 1.0)
			for x in range(32):
				for y in range(32):
					var is_edge := x < 2 or x >= 30 or y < 2 or y >= 30
					var is_plank := (x % 8 < 1) or (y % 8 < 1)
					
					if is_edge:
						img.set_pixel(x, y, wood_color.darkened(0.4))
					elif is_plank:
						img.set_pixel(x, y, wood_color.darkened(0.2))
					else:
						img.set_pixel(x, y, wood_color)
		_:
			# Generic obstacle
			img.fill(base_color.darkened(0.2))
	
	return ImageTexture.create_from_image(img)

func _generate_interactable_texture(theme_data: Dictionary, object_subtype: String) -> Texture2D:
	var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	
	match object_subtype:
		"chest":
			# Create treasure chest
			var gold_color := Color(0.8, 0.6, 0.2, 1.0)
			var brown_color := Color(0.4, 0.2, 0.1, 1.0)
			
			for x in range(32):
				for y in range(32):
					if y < 16:  # Top half - gold
						img.set_pixel(x, y, gold_color)
					else:  # Bottom half - brown
						img.set_pixel(x, y, brown_color)
		"altar":
			# Create stone altar
			var stone_color: Color = theme_data.get("wall_color", Color.GRAY)
			for x in range(32):
				for y in range(32):
					var distance_from_center: int = abs(x - 16) + abs(y - 16)
					var shade: float = 1.0 - (distance_from_center / 32.0) * 0.3
					img.set_pixel(x, y, stone_color * shade)
		_:
			# Generic bright interactable
			img.fill(Color.YELLOW)
	
	return ImageTexture.create_from_image(img)

func _generate_generic_texture(theme_data: Dictionary) -> Texture2D:
	var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	var base_color: Color = theme_data.get("wall_color", Color.GRAY)
	img.fill(base_color)
	return ImageTexture.create_from_image(img)

func get_available_themes() -> Array[String]:
	var theme_keys: Array[String] = []
	for key in themes.keys():
		theme_keys.append(key as String)
	return theme_keys

func get_theme_display_name(theme_name: String) -> String:
	var theme_data: Dictionary = themes.get(theme_name, {})
	return theme_data.get("name", theme_name)

func cycle_theme() -> void:
	var theme_list: Array[String] = get_available_themes()
	var current_index: int = theme_list.find(current_theme)
	var next_index: int = (current_index + 1) % theme_list.size()
	var next_theme: String = theme_list[next_index]
	set_theme(next_theme)
	Logger.info("Theme cycled to: " + get_theme_display_name(next_theme), "ui")

func _clear_cache() -> void:
	texture_cache.clear()

func cleanup() -> void:
	_clear_cache()

func _exit_tree() -> void:
	cleanup()
