class_name HUDConfigResource
extends Resource

## Simplified configuration resource for HUD component settings
## Performance and visibility settings only - positioning done in editor

@export var component_visibility: Dictionary = {}
@export var hud_theme_name: String = "default"

# Performance settings
@export var max_fps_updates_per_second: float = 2.0
@export var performance_monitoring_enabled: bool = true
@export var animation_budget_ms: float = 2.0

func _init() -> void:
	_setup_default_visibility()

func _setup_default_visibility() -> void:
	# Default component visibility settings
	component_visibility = {
		"health_bar": true,
		"level_label": true,
		"xp_bar": true,
		"radar": true,
		"keybindings": true,
		"fps_counter": true,
		"ability_bar": true
	}

func get_component_visibility(component_id: String) -> bool:
	return component_visibility.get(component_id, true)

func set_component_visibility(component_id: String, visible: bool) -> void:
	component_visibility[component_id] = visible
	emit_changed()

func clone() -> HUDConfigResource:
	var new_config := HUDConfigResource.new()
	new_config.component_visibility = component_visibility.duplicate(true)
	new_config.hud_theme_name = hud_theme_name
	new_config.max_fps_updates_per_second = max_fps_updates_per_second
	new_config.performance_monitoring_enabled = performance_monitoring_enabled
	new_config.animation_budget_ms = animation_budget_ms
	return new_config