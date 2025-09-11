extends Control
class_name NewHUD

## New component-based HUD system using HUDManager for coordination
## Designed to coexist with and eventually replace the old HUD system

@onready var level_label: Label = $LevelLabel
@onready var xp_bar: ProgressBar = $XPBar
@onready var player_health: HealthBarComponent = $PlayerHealthBar
@onready var enemy_radar: RadarComponent = $EnemyRadar  
@onready var performance_display: PerformanceComponent = $PerformanceDisplay

# State tracking
var _is_initialized: bool = false

func _ready() -> void:
	# HUD should always process (including during pause)
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	# Wait for HUDManager to be ready
	if HUDManager:
		_initialize_new_hud()
	else:
		# Retry initialization on next frame if HUDManager not ready
		call_deferred("_initialize_new_hud")

func _initialize_new_hud() -> void:
	if _is_initialized:
		return
	
	Logger.info("Initializing new component-based HUD system", "ui")
	
	# Apply default HUD layout configuration
	if HUDManager.hud_config:
		_apply_hud_layout()
	else:
		# Load default layout
		HUDManager.load_layout_preset(HUDConfigResource.LayoutPreset.DEFAULT)
	
	# Connect to new progression signals
	_connect_new_hud_signals()
	
	# Style the remaining non-component elements
	_style_legacy_elements()
	
	# Initialize component states
	_initialize_component_states()
	
	_is_initialized = true
	Logger.info("New HUD system initialization complete", "ui")

func _connect_new_hud_signals() -> void:
	# Connect to EventBus signals
	if EventBus:
		EventBus.health_changed.connect(_on_health_changed)
		EventBus.progression_changed.connect(_on_progression_changed)
		EventBus.leveled_up.connect(_on_leveled_up)
	
	# Connect to HUDManager signals
	if HUDManager:
		HUDManager.layout_changed.connect(_on_layout_changed)

func _style_legacy_elements() -> void:
	# Style level label (similar to old HUD)
	if level_label:
		var label_theme := Theme.new()
		var style_bg := StyleBoxFlat.new()
		
		style_bg.bg_color = Color(0.1, 0.1, 0.1, 0.9)
		style_bg.border_width_left = 1
		style_bg.border_width_right = 1
		style_bg.border_width_top = 1
		style_bg.border_width_bottom = 1
		style_bg.border_color = Color(0.6, 0.6, 0.6, 1.0)
		style_bg.corner_radius_top_left = 3
		style_bg.corner_radius_top_right = 3
		style_bg.corner_radius_bottom_left = 3
		style_bg.corner_radius_bottom_right = 3
		style_bg.content_margin_left = 8
		style_bg.content_margin_right = 8
		style_bg.content_margin_top = 4
		style_bg.content_margin_bottom = 4
		
		label_theme.set_stylebox("normal", "Label", style_bg)
		label_theme.set_color("font_color", "Label", Color.WHITE)
		level_label.theme = label_theme
	
	# Style XP bar
	if xp_bar:
		var xp_theme := Theme.new()
		var style_bg := StyleBoxFlat.new()
		var style_fill := StyleBoxFlat.new()
		
		style_bg.bg_color = Color(0.2, 0.2, 0.4, 0.8)
		style_fill.bg_color = Color(0.4, 0.6, 1.0, 1.0)
		
		xp_theme.set_stylebox("background", "ProgressBar", style_bg)
		xp_theme.set_stylebox("fill", "ProgressBar", style_fill)
		xp_bar.theme = xp_theme

func _initialize_component_states() -> void:
	# Initialize health bar with current player state
	if player_health and PlayerProgression:
		var initial_health := 100.0
		player_health.update_health(initial_health, initial_health)
	
	# Initialize progression display with current state
	if PlayerProgression:
		var state = PlayerProgression.get_progression_state()
		_on_progression_changed(state)

func _apply_hud_layout() -> void:
	# Apply layout configuration to non-component elements
	# Components will be handled automatically by HUDManager
	
	if not HUDManager.hud_config:
		return
	
	# Apply level label positioning
	if level_label:
		var config = HUDManager.hud_config.get_component_position("level_label")
		var anchor_preset = config.get("anchor_preset", Control.PRESET_CENTER_BOTTOM)
		var offset = config.get("offset", Vector2(0, -65))
		
		level_label.set_anchors_and_offsets_preset(anchor_preset)
		level_label.position += offset
	
	# Apply XP bar positioning
	if xp_bar:
		var config = HUDManager.hud_config.get_component_position("xp_bar")
		var anchor_preset = config.get("anchor_preset", Control.PRESET_BOTTOM_LEFT)
		var offset = config.get("offset", Vector2(10, -40))
		
		xp_bar.set_anchors_and_offsets_preset(anchor_preset)
		xp_bar.position += offset

# Signal handlers
func _on_health_changed(current_health: float, max_health: float) -> void:
	if player_health:
		player_health.update_health(current_health, max_health)

func _on_progression_changed(state: Dictionary) -> void:
	var current_xp = int(state.get("exp", 0))
	var xp_to_next = int(state.get("xp_to_next", 100))
	var level = int(state.get("level", 1))
	
	Logger.debug("New HUD: Progression changed - Level: %d, XP: %d/%d" % [level, current_xp, xp_to_next], "ui")
	
	# Update level display
	if level_label:
		level_label.text = "Level: " + str(level)
	
	# Update XP bar
	if xp_bar:
		xp_bar.max_value = xp_to_next
		xp_bar.value = current_xp

func _on_leveled_up(new_level: int, prev_level: int) -> void:
	Logger.debug("New HUD: Level up detected! %d -> %d" % [prev_level, new_level], "ui")
	if level_label:
		level_label.text = "Level: " + str(new_level)

func _on_layout_changed(new_config: HUDConfigResource) -> void:
	Logger.debug("New HUD: Layout configuration changed", "ui")
	_apply_hud_layout()

# Public API for switching between HUD systems
func set_hud_visible(visible: bool) -> void:
	self.visible = visible
	if visible:
		Logger.info("New HUD system shown", "ui")
	else:
		Logger.info("New HUD system hidden", "ui")

func get_hud_performance_stats() -> Dictionary:
	var stats = {
		"system": "new_hud",
		"initialized": _is_initialized,
		"components": {}
	}
	
	# Gather stats from all components
	if player_health and player_health.has_method("get_health_stats"):
		stats.components["health"] = player_health.get_health_stats()
	
	if enemy_radar and enemy_radar.has_method("get_radar_stats"):
		stats.components["radar"] = enemy_radar.get_radar_stats()
	
	if performance_display and performance_display.has_method("get_current_performance_stats"):
		stats.components["performance"] = performance_display.get_current_performance_stats()
	
	return stats