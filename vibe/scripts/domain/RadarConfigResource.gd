extends Resource

class_name RadarConfigResource

## Radar configuration resource for enemy radar UI settings
## Replaces ui/radar.json with type-safe resource

@export_group("Radar Display")
@export var radar_size: Vector2 = Vector2(150, 150)
@export var radar_range: float = 1500.0

@export_group("Colors")
@export var background_color: Color = Color(0.1, 0.1, 0.2, 0.7)
@export var border_color: Color = Color(0.4, 0.4, 0.6, 1.0)
@export var player_color: Color = Color(0.2, 0.8, 0.2, 1.0)
@export var enemy_color: Color = Color(0.8, 0.2, 0.2, 1.0)

@export_group("Dot Sizes")
@export var player_dot_size: float = 4.0
@export var enemy_dot_max_size: float = 3.0
@export var enemy_dot_min_size: float = 1.5

## Get colors as dictionary for compatibility with existing radar system
func get_colors() -> Dictionary:
	return {
		"background": {"r": background_color.r, "g": background_color.g, "b": background_color.b, "a": background_color.a},
		"border": {"r": border_color.r, "g": border_color.g, "b": border_color.b, "a": border_color.a},
		"player": {"r": player_color.r, "g": player_color.g, "b": player_color.b, "a": player_color.a},
		"enemy": {"r": enemy_color.r, "g": enemy_color.g, "b": enemy_color.b, "a": enemy_color.a}
	}

## Get dot sizes as dictionary for compatibility
func get_dot_sizes() -> Dictionary:
	return {
		"player": player_dot_size,
		"enemy_max": enemy_dot_max_size,
		"enemy_min": enemy_dot_min_size
	}

## Get radar size as dictionary for compatibility  
func get_radar_size() -> Dictionary:
	return {
		"x": int(radar_size.x),
		"y": int(radar_size.y)
	}