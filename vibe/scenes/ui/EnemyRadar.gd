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
var player_dot_size: float
var max_enemy_dot_size: float
var min_enemy_dot_size: float

var player_position: Vector2
var enemy_positions: Array[Vector2] = []

func _ready() -> void:
	_load_configuration()
	_setup_radar()
	_connect_signals()

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
	
	# Load dot sizes
	var dot_sizes: Dictionary = config.get("dot_sizes", {})
	player_dot_size = dot_sizes.get("player", 4.0)
	max_enemy_dot_size = dot_sizes.get("enemy_max", 3.0)
	min_enemy_dot_size = dot_sizes.get("enemy_min", 1.5)

func _connect_signals() -> void:
	# Connect to player position updates
	if PlayerState:
		PlayerState.player_position_changed.connect(_on_player_position_changed)
	# Connect to enemy updates from WaveDirector
	if EventBus:
		EventBus.combat_step.connect(_on_combat_step)
	# Listen for balance data reloads
	if BalanceDB:
		BalanceDB.balance_reloaded.connect(_on_balance_reloaded)

func _on_player_position_changed(position: Vector2) -> void:
	player_position = position
	queue_redraw()

func _on_combat_step(payload) -> void:
	# Get enemy positions from the scene
	_update_enemy_positions()
	queue_redraw()

func _update_enemy_positions() -> void:
	enemy_positions.clear()
	
	# Find the Arena node by climbing up the tree
	var current := get_parent()
	while current:
		if current.name == "Arena":
			var arena = current
			# Check if arena has wave_director property using "in" operator
			if "wave_director" in arena:
				var wave_director = arena.wave_director
				if wave_director:
					var alive_enemies: Array[EnemyEntity] = wave_director.get_alive_enemies()
					for enemy in alive_enemies:
						enemy_positions.append(enemy.pos)
			break
		current = current.get_parent()

func _draw() -> void:
	var radar_center := radar_size * 0.5
	
	# Draw player dot at center
	draw_circle(radar_center, player_dot_size, player_color)
	
	# Draw enemy dots
	for enemy_pos in enemy_positions:
		var relative_pos := enemy_pos - player_position
		var distance := relative_pos.length()
		
		# Only draw enemies within radar range
		if distance <= radar_range and distance > 0:
			var radar_pos := _world_to_radar(relative_pos)
			var dot_size := _get_enemy_dot_size(distance)
			
			# Only draw if position is within radar bounds
			if _is_within_radar_bounds(radar_pos):
				draw_circle(radar_pos, dot_size, enemy_color)

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

func _on_balance_reloaded() -> void:
	_load_configuration()
	_setup_radar()
	queue_redraw()

func _is_within_radar_bounds(pos: Vector2) -> bool:
	var margin := max_enemy_dot_size
	return pos.x >= margin and pos.x <= radar_size.x - margin and \
		   pos.y >= margin and pos.y <= radar_size.y - margin
