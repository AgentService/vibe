extends Panel
class_name EnemyRadar

## Enemy radar showing enemy positions relative to player in wave survival gameplay.
## Uses Panel base for visible background, draws enemy dots within radar range.

var radar_size: Vector2
var radar_range: float
var background_color: Color
var border_color: Color
var player_color: Color
var enemy_color: Color
var boss_color: Color
var player_dot_size: float
var max_enemy_dot_size: float
var min_enemy_dot_size: float
var max_boss_dot_size: float
var min_boss_dot_size: float

var player_position: Vector2
var radar_entities: Array[EventBus.RadarEntity] = []

func _ready() -> void:
	_load_configuration()
	_setup_radar()
	_connect_signals()
	Logger.debug("EnemyRadar: Initialized and connected to EventBus", "radar")

func _setup_radar() -> void:
	size = radar_size
	# Panel already has background - set custom style
	var style_box := StyleBoxFlat.new()
	style_box.bg_color = background_color
	style_box.border_width_left = 2
	style_box.border_width_right = 2
	style_box.border_width_top = 2
	style_box.border_width_bottom = 2
	style_box.border_color = border_color
	style_box.corner_radius_top_left = 4
	style_box.corner_radius_top_right = 4
	style_box.corner_radius_bottom_left = 4
	style_box.corner_radius_bottom_right = 4
	add_theme_stylebox_override("panel", style_box)

func _load_configuration() -> void:
	var config: Dictionary = BalanceDB.get_ui_value("radar")
	
	# Load size
	var size_data: Dictionary = config.get("radar_size", {"x": 150, "y": 150})
	radar_size = Vector2(size_data.get("x", 150), size_data.get("y", 150))
	
	# Load range
	radar_range = config.get("radar_range", 1500.0)
	
	# Load colors
	var colors: Dictionary = config.get("colors", {})
	var bg: Dictionary = colors.get("background", {"r": 0.1, "g": 0.1, "b": 0.2, "a": 0.7})
	background_color = Color(bg.get("r", 0.1), bg.get("g", 0.1), bg.get("b", 0.2), bg.get("a", 0.7))
	
	var border: Dictionary = colors.get("border", {"r": 0.4, "g": 0.4, "b": 0.6, "a": 1.0})
	border_color = Color(border.get("r", 0.4), border.get("g", 0.4), border.get("b", 0.6), border.get("a", 1.0))
	
	var player: Dictionary = colors.get("player", {"r": 0.2, "g": 0.8, "b": 0.2, "a": 1.0})
	player_color = Color(player.get("r", 0.2), player.get("g", 0.8), player.get("b", 0.2), player.get("a", 1.0))
	
	var enemy: Dictionary = colors.get("enemy", {"r": 0.8, "g": 0.2, "b": 0.2, "a": 1.0})
	enemy_color = Color(enemy.get("r", 0.8), enemy.get("g", 0.2), enemy.get("b", 0.2), enemy.get("a", 1.0))
	
	var boss: Dictionary = colors.get("boss", {"r": 1.0, "g": 0.4, "b": 0.0, "a": 1.0})
	boss_color = Color(boss.get("r", 1.0), boss.get("g", 0.4), boss.get("b", 0.0), boss.get("a", 1.0))
	
	# Load dot sizes
	var dot_sizes: Dictionary = config.get("dot_sizes", {})
	player_dot_size = dot_sizes.get("player", 4.0)
	max_enemy_dot_size = dot_sizes.get("enemy_max", 3.0)
	min_enemy_dot_size = dot_sizes.get("enemy_min", 1.5)
	max_boss_dot_size = dot_sizes.get("boss_max", 6.0)
	min_boss_dot_size = dot_sizes.get("boss_min", 4.0)

func _connect_signals() -> void:
	# Connect to radar data updates from RadarSystem via EventBus
	if EventBus:
		EventBus.radar_data_updated.connect(_on_radar_data_updated)
	# Listen for balance data reloads
	if BalanceDB:
		BalanceDB.balance_reloaded.connect(_on_balance_reloaded)

func _on_radar_data_updated(entities: Array, player_pos: Vector2) -> void:
	# Update radar data from RadarSystem via EventBus
	radar_entities.assign(entities)  # Use assign for typed array conversion
	player_position = player_pos
	
	# Count different entity types for logging
	var enemy_count := 0
	var boss_count := 0
	for entity in radar_entities:
		if entity.type == "enemy":
			enemy_count += 1
		elif entity.type == "boss":
			boss_count += 1
	
	Logger.debug("EnemyRadar: Received radar data - %d enemies, %d bosses at player pos %s" % [enemy_count, boss_count, player_pos], "radar")
	queue_redraw()

func _draw() -> void:
	var radar_center := radar_size * 0.5
	
	# Draw player dot at center
	draw_circle(radar_center, player_dot_size, player_color)
	
	# Draw entity dots (enemies and bosses)
	for entity in radar_entities:
		var relative_pos := entity.pos - player_position
		var distance := relative_pos.length()
		
		# Only draw entities within radar range
		if distance <= radar_range and distance > 0:
			var radar_pos := _world_to_radar(relative_pos)
			var dot_size: float
			var dot_color: Color
			
			# Choose size and color based on entity type
			if entity.type == "boss":
				dot_size = _get_boss_dot_size(distance)
				dot_color = boss_color
			else:  # Default to enemy
				dot_size = _get_enemy_dot_size(distance)
				dot_color = enemy_color
			
			# Only draw if position is within radar bounds
			if _is_within_radar_bounds(radar_pos):
				# Draw special indicator for bosses
				if entity.type == "boss":
					_draw_boss_indicator(radar_pos, dot_size, dot_color)
				else:
					draw_circle(radar_pos, dot_size, dot_color)

func _world_to_radar(relative_pos: Vector2) -> Vector2:
	# Convert world relative position to radar coordinates
	var radar_center := radar_size * 0.5
	var scale_factor := (radar_size.x * 0.4) / radar_range  # Use 80% of radar for full range
	
	var radar_offset := relative_pos * scale_factor
	return radar_center + radar_offset

func _get_enemy_dot_size(distance: float) -> float:
	# Closer enemies = larger dots
	var distance_factor := 1.0 - (distance / radar_range)
	return lerp(min_enemy_dot_size, max_enemy_dot_size, distance_factor)

func _get_boss_dot_size(distance: float) -> float:
	# Closer bosses = larger dots, but bosses are always larger than regular enemies
	var distance_factor := 1.0 - (distance / radar_range)
	return lerp(min_boss_dot_size, max_boss_dot_size, distance_factor)

func _draw_boss_indicator(pos: Vector2, size: float, color: Color) -> void:
	# Draw boss as a distinctive shape - diamond/star pattern
	# First draw the main circle
	draw_circle(pos, size, color)
	
	# Draw a smaller inner circle with slightly darker shade
	var inner_color = Color(color.r * 0.7, color.g * 0.7, color.b * 0.7, color.a)
	draw_circle(pos, size * 0.6, inner_color)
	
	# Draw diamond points around the boss indicator
	var diamond_size = size * 0.3
	var points = PackedVector2Array()
	points.append(pos + Vector2(0, -size * 1.2))     # Top point
	points.append(pos + Vector2(size * 1.2, 0))      # Right point  
	points.append(pos + Vector2(0, size * 1.2))      # Bottom point
	points.append(pos + Vector2(-size * 1.2, 0))     # Left point
	
	# Draw diamond outline
	for i in range(points.size()):
		var next_i = (i + 1) % points.size()
		draw_line(points[i], points[next_i], color, 1.0)

func _on_balance_reloaded() -> void:
	_load_configuration()
	_setup_radar()
	queue_redraw()

func _is_within_radar_bounds(pos: Vector2) -> bool:
	var margin: float = max(max_enemy_dot_size, max_boss_dot_size) * 1.5  # Account for boss diamond points
	return pos.x >= margin and pos.x <= radar_size.x - margin and \
		   pos.y >= margin and pos.y <= radar_size.y - margin
