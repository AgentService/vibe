class_name RadarComponent
extends BaseHUDComponent

## Enemy radar component showing enemy positions relative to player
## Optimized for performance with configurable range and visual customization

# Radar configuration
var radar_size: Vector2 = Vector2(150, 150)
var radar_range: float = 1500.0
var background_color: Color = Color(0.1, 0.1, 0.2, 0.7)
var border_color: Color = Color(0.4, 0.4, 0.6, 1.0)
var player_color: Color = Color(0.2, 0.8, 0.2, 1.0)
var enemy_color: Color = Color(0.8, 0.2, 0.2, 1.0)
var boss_color: Color = Color(1.0, 0.4, 0.0, 1.0)

# Dot sizes
var player_dot_size: float = 4.0
var max_enemy_dot_size: float = 3.0
var min_enemy_dot_size: float = 1.5
var max_boss_dot_size: float = 6.0
var min_boss_dot_size: float = 4.0

# Internal state
var player_position: Vector2
var radar_entities: Array[EventBus.RadarEntity] = []
var _panel_background: Panel
var radar_system_indicator: String = ""

# Performance optimization
var _last_entity_count: int = 0
var _should_redraw: bool = false

func _init() -> void:
	super._init()
	component_id = "radar"
	update_frequency = 30.0  # 30 FPS for radar updates

func _setup_component() -> void:
	# Create panel background
	_panel_background = Panel.new()
	_panel_background.name = "RadarBackground"
	_panel_background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_panel_background)
	
	# Load configuration
	_load_configuration()
	_setup_radar_display()
	_connect_radar_signals()

func _update_component(delta: float) -> void:
	# Only redraw if entities have changed or we need to update
	if _should_redraw:
		queue_redraw()
		_should_redraw = false

func _cleanup_component() -> void:
	# Cleanup radar-specific resources
	radar_entities.clear()

func _setup_radar_display() -> void:
	custom_minimum_size = radar_size
	size = radar_size
	
	# Setup panel background styling
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
	
	_panel_background.add_theme_stylebox_override("panel", style_box)

func _load_configuration() -> void:
	var config: Dictionary = BalanceDB.get_ui_value("radar")
	
	# Detect which radar system is active
	var use_new_system: bool = config.get("use_new_radar_system", true)
	radar_system_indicator = "NEW" if use_new_system else "OLD"
	
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

func _connect_radar_signals() -> void:
	# Connect to radar data updates from RadarSystem via EventBus
	if EventBus:
		connect_to_signal(EventBus.radar_data_updated, _on_radar_data_updated)
	
	# Listen for balance data reloads
	if BalanceDB:
		connect_to_signal(BalanceDB.balance_reloaded, _on_balance_reloaded)

func _on_radar_data_updated(entities: Array, player_pos: Vector2) -> void:
	# Performance optimization: Skip radar updates if disabled
	if DebugManager and DebugManager.is_radar_disabled():
		return
	
	# Update radar data
	radar_entities.assign(entities)  # Use assign for typed array conversion
	player_position = player_pos
	
	# Check if we need to redraw (entity count changed or position significantly changed)
	if entities.size() != _last_entity_count:
		_should_redraw = true
		_last_entity_count = entities.size()
	else:
		_should_redraw = true  # For now, always redraw when data updates
	
	Logger.debug("Radar updated: %d entities" % entities.size(), "ui")

func _draw() -> void:
	# Performance optimization: Skip drawing if radar is disabled
	if DebugManager and DebugManager.is_radar_disabled():
		return
	
	var radar_center := radar_size * 0.5
	
	# Draw system indicator in top-left corner
	if not radar_system_indicator.is_empty():
		var indicator_color = Color.YELLOW if radar_system_indicator == "NEW" else Color.CYAN
		draw_string(get_theme_default_font(), Vector2(4, 12), radar_system_indicator, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, indicator_color)
	
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

func _draw_boss_indicator(pos: Vector2, dot_size: float, color: Color) -> void:
	# Draw boss as a distinctive shape - diamond/star pattern
	# First draw the main circle
	draw_circle(pos, dot_size, color)
	
	# Draw a smaller inner circle with slightly darker shade
	var inner_color = Color(color.r * 0.7, color.g * 0.7, color.b * 0.7, color.a)
	draw_circle(pos, dot_size * 0.6, inner_color)
	
	# Draw diamond points around the boss indicator
	var points = PackedVector2Array()
	points.append(pos + Vector2(0, -dot_size * 1.2))     # Top point
	points.append(pos + Vector2(dot_size * 1.2, 0))      # Right point  
	points.append(pos + Vector2(0, dot_size * 1.2))      # Bottom point
	points.append(pos + Vector2(-dot_size * 1.2, 0))     # Left point
	
	# Draw diamond outline
	for i in range(points.size()):
		var next_i = (i + 1) % points.size()
		draw_line(points[i], points[next_i], color, 1.0)

func _is_within_radar_bounds(pos: Vector2) -> bool:
	var margin: float = max(max_enemy_dot_size, max_boss_dot_size) * 1.5  # Account for boss diamond points
	return pos.x >= margin and pos.x <= radar_size.x - margin and \
		   pos.y >= margin and pos.y <= radar_size.y - margin

func _on_balance_reloaded() -> void:
	_load_configuration()
	_setup_radar_display()
	_should_redraw = true

# Public API for HUD customization
func set_radar_range(new_range: float) -> void:
	radar_range = max(100.0, new_range)
	_should_redraw = true

func set_radar_size(new_size: Vector2) -> void:
	radar_size = Vector2(max(50, new_size.x), max(50, new_size.y))
	custom_minimum_size = radar_size
	size = radar_size
	_setup_radar_display()
	_should_redraw = true

func get_radar_stats() -> Dictionary:
	return {
		"visible_entities": radar_entities.size(),
		"radar_range": radar_range,
		"radar_size": radar_size,
		"system_type": radar_system_indicator
	}