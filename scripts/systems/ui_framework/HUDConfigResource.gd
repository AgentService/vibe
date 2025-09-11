class_name HUDConfigResource
extends Resource

## Configuration resource for HUD component layouts and settings
## Supports player customization, preset layouts, and persistent storage

@export var layout_name: String = "default"
@export var component_positions: Dictionary = {}
@export var component_scales: Dictionary = {}
@export var component_visibility: Dictionary = {}
@export var hud_theme_name: String = "default"

# Performance settings
@export var max_fps_updates_per_second: float = 2.0
@export var performance_monitoring_enabled: bool = true
@export var animation_budget_ms: float = 2.0

# Layout presets
enum LayoutPreset {
	DEFAULT,
	MINIMAL,
	COMPETITIVE,
	CUSTOM
}

@export var current_preset: LayoutPreset = LayoutPreset.DEFAULT

func _init() -> void:
	_setup_default_positions()

func _setup_default_positions() -> void:
	# Default positions using anchor-based positioning
	component_positions = {
		"health_bar": {"anchor_preset": Control.PRESET_BOTTOM_WIDE, "offset": Vector2(0, -40)},
		"level_label": {"anchor_preset": Control.PRESET_CENTER_BOTTOM, "offset": Vector2(0, -65)},
		"xp_bar": {"anchor_preset": Control.PRESET_BOTTOM_LEFT, "offset": Vector2(10, -40)},
		"radar": {"anchor_preset": Control.PRESET_TOP_RIGHT, "offset": Vector2(-170, 20)},
		"keybindings": {"anchor_preset": Control.PRESET_TOP_RIGHT, "offset": Vector2(-170, 270)},
		"fps_counter": {"anchor_preset": Control.PRESET_BOTTOM_LEFT, "offset": Vector2(10, -80)}
	}
	
	# Default scales
	component_scales = {
		"health_bar": Vector2(1.0, 1.0),
		"level_label": Vector2(1.0, 1.0),
		"xp_bar": Vector2(1.0, 1.0),
		"radar": Vector2(1.0, 1.0),
		"keybindings": Vector2(1.0, 1.0),
		"fps_counter": Vector2(1.0, 1.0)
	}
	
	# Default visibility
	component_visibility = {
		"health_bar": true,
		"level_label": true,
		"xp_bar": true,
		"radar": true,
		"keybindings": true,
		"fps_counter": true
	}

func get_component_position(component_id: String) -> Dictionary:
	return component_positions.get(component_id, {"anchor_preset": Control.PRESET_TOP_LEFT, "offset": Vector2.ZERO})

func set_component_position(component_id: String, anchor_preset: int, offset: Vector2) -> void:
	component_positions[component_id] = {"anchor_preset": anchor_preset, "offset": offset}
	current_preset = LayoutPreset.CUSTOM
	emit_changed()

func get_component_scale(component_id: String) -> Vector2:
	return component_scales.get(component_id, Vector2.ONE)

func set_component_scale(component_id: String, scale: Vector2) -> void:
	component_scales[component_id] = scale
	current_preset = LayoutPreset.CUSTOM
	emit_changed()

func get_component_visibility(component_id: String) -> bool:
	return component_visibility.get(component_id, true)

func set_component_visibility(component_id: String, visible: bool) -> void:
	component_visibility[component_id] = visible
	emit_changed()

func apply_preset(preset: LayoutPreset) -> void:
	current_preset = preset
	match preset:
		LayoutPreset.DEFAULT:
			_setup_default_positions()
		LayoutPreset.MINIMAL:
			_setup_minimal_layout()
		LayoutPreset.COMPETITIVE:
			_setup_competitive_layout()
	emit_changed()

func _setup_minimal_layout() -> void:
	# Minimal layout - only essential elements
	component_positions = {
		"health_bar": {"anchor_preset": Control.PRESET_CENTER_BOTTOM, "offset": Vector2(0, -20)},
		"level_label": {"anchor_preset": Control.PRESET_CENTER_BOTTOM, "offset": Vector2(0, -45)},
		"xp_bar": {"anchor_preset": Control.PRESET_BOTTOM_WIDE, "offset": Vector2(0, -5)}
	}
	
	component_visibility = {
		"health_bar": true,
		"level_label": true,
		"xp_bar": true,
		"radar": false,
		"keybindings": false,
		"fps_counter": false
	}

func _setup_competitive_layout() -> void:
	# Competitive layout - optimized for gameplay focus
	component_positions = {
		"health_bar": {"anchor_preset": Control.PRESET_CENTER_BOTTOM, "offset": Vector2(0, -30)},
		"level_label": {"anchor_preset": Control.PRESET_CENTER_BOTTOM, "offset": Vector2(0, -55)},
		"xp_bar": {"anchor_preset": Control.PRESET_BOTTOM_WIDE, "offset": Vector2(0, -10)},
		"radar": {"anchor_preset": Control.PRESET_TOP_RIGHT, "offset": Vector2(-120, 10)},
		"fps_counter": {"anchor_preset": Control.PRESET_TOP_LEFT, "offset": Vector2(10, 10)}
	}
	
	# Smaller scales for competitive
	component_scales = {
		"health_bar": Vector2(0.8, 0.8),
		"radar": Vector2(0.7, 0.7),
		"fps_counter": Vector2(0.8, 0.8)
	}
	
	component_visibility = {
		"health_bar": true,
		"level_label": true,
		"xp_bar": true,
		"radar": true,
		"keybindings": false,
		"fps_counter": true
	}

func clone() -> HUDConfigResource:
	var new_config := HUDConfigResource.new()
	new_config.layout_name = layout_name
	new_config.component_positions = component_positions.duplicate(true)
	new_config.component_scales = component_scales.duplicate(true)
	new_config.component_visibility = component_visibility.duplicate(true)
	new_config.hud_theme_name = hud_theme_name
	new_config.max_fps_updates_per_second = max_fps_updates_per_second
	new_config.performance_monitoring_enabled = performance_monitoring_enabled
	new_config.animation_budget_ms = animation_budget_ms
	new_config.current_preset = current_preset
	return new_config