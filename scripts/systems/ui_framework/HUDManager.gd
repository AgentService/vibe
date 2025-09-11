extends Node
class_name HUDManagerClass

## Centralized HUD component coordinator managing lifecycle, positioning, and state
## Integrates with EventBus for data-driven UI updates and supports player customization

var registered_components: Dictionary = {}
var hud_config: HUDConfigResource
var _hud_container: Control
var _is_hud_visible: bool = true
var _performance_monitor_timer: float = 0.0

# Configuration paths
const DEFAULT_CONFIG_PATH = "res://data/ui/hud_layouts/default_layout.tres"
const USER_CONFIG_PATH = "user://hud_layout.tres"

# Performance monitoring
const PERFORMANCE_CHECK_INTERVAL = 5.0
var _total_hud_update_time: float = 0.0
var _hud_update_count: int = 0

# Signals
signal layout_changed(new_config: HUDConfigResource)
signal component_registered(component_id: String)
signal component_unregistered(component_id: String)
signal hud_visibility_changed(visible: bool)

func _init() -> void:
	name = "HUDManager"
	# Add to autoload group for global access
	add_to_group("autoload")

func _ready() -> void:
	_setup_hud_manager()
	_load_configuration()
	_connect_signals()
	
	Logger.info("HUDManager initialized with %d components" % registered_components.size(), "ui")

func _process(delta: float) -> void:
	_performance_monitor_timer += delta
	if _performance_monitor_timer >= PERFORMANCE_CHECK_INTERVAL:
		_performance_monitor_timer = 0.0
		_check_performance_budget()

# Component lifecycle management
func register_component(component_id: String, component: Control) -> bool:
	if registered_components.has(component_id):
		Logger.warn("Component already registered: " + component_id, "ui")
		return false
	
	registered_components[component_id] = component
	
	# Apply current configuration to new component
	if hud_config and component.has_method("apply_anchor_config"):
		var position_config := hud_config.get_component_position(component_id)
		var scale_config := hud_config.get_component_scale(component_id)
		var visibility_config := hud_config.get_component_visibility(component_id)
		
		component.apply_anchor_config(position_config)
		component.set_component_scale(scale_config)
		component.set_component_visible(visibility_config)
	
	# Only reparent if component doesn't have a proper parent already
	# Components from NewHUD scene already have correct parent structure
	if _hud_container and component.get_parent() == null:
		_hud_container.add_child(component)
	elif component.get_parent() != null:
		# Component already has a parent (likely from scene), don't reparent
		Logger.debug("Component %s already has parent, skipping reparent" % component_id, "ui")
	
	component_registered.emit(component_id)
	Logger.debug("Registered HUD component: " + component_id, "ui")
	return true

func unregister_component(component_id: String) -> bool:
	if not registered_components.has(component_id):
		Logger.warn("Component not found for unregistration: " + component_id, "ui")
		return false
	
	registered_components.erase(component_id)
	component_unregistered.emit(component_id)
	Logger.debug("Unregistered HUD component: " + component_id, "ui")
	return true

func get_component(component_id: String) -> Control:
	return registered_components.get(component_id, null)

func get_all_components() -> Dictionary:
	return registered_components.duplicate()

# HUD state management
func show_hud() -> void:
	if not _is_hud_visible:
		_is_hud_visible = true
		_apply_hud_visibility()
		hud_visibility_changed.emit(true)
		Logger.info("HUD shown", "ui")

func hide_hud() -> void:
	if _is_hud_visible:
		_is_hud_visible = false
		_apply_hud_visibility()
		hud_visibility_changed.emit(false)
		Logger.info("HUD hidden", "ui")

func toggle_hud() -> void:
	if _is_hud_visible:
		hide_hud()
	else:
		show_hud()

func is_hud_visible() -> bool:
	return _is_hud_visible

# Configuration management
func load_layout_preset(preset: HUDConfigResource.LayoutPreset) -> void:
	if not hud_config:
		hud_config = HUDConfigResource.new()
	
	hud_config.apply_preset(preset)
	_apply_layout_configuration()
	Logger.info("Applied HUD layout preset: " + str(preset), "ui")

func set_component_position(component_id: String, anchor_preset: int, offset: Vector2) -> void:
	if not hud_config:
		hud_config = HUDConfigResource.new()
	
	hud_config.set_component_position(component_id, anchor_preset, offset)
	
	# Apply immediately if component exists
	var component := get_component(component_id)
	if component and component.has_method("apply_anchor_config"):
		var position_config := hud_config.get_component_position(component_id)
		component.apply_anchor_config(position_config)

func set_component_scale(component_id: String, scale: Vector2) -> void:
	if not hud_config:
		hud_config = HUDConfigResource.new()
	
	hud_config.set_component_scale(component_id, scale)
	
	# Apply immediately if component exists
	var component := get_component(component_id)
	if component and component.has_method("set_component_scale"):
		component.set_component_scale(scale)

func set_component_visibility(component_id: String, visible: bool) -> void:
	if not hud_config:
		hud_config = HUDConfigResource.new()
	
	hud_config.set_component_visibility(component_id, visible)
	
	# Apply immediately if component exists
	var component := get_component(component_id)
	if component and component.has_method("set_component_visible"):
		component.set_component_visible(visible)

func save_layout() -> bool:
	if not hud_config:
		Logger.warn("No HUD configuration to save", "ui")
		return false
	
	var error := ResourceSaver.save(hud_config, USER_CONFIG_PATH)
	if error == OK:
		Logger.info("HUD layout saved to: " + USER_CONFIG_PATH, "ui")
		return true
	else:
		Logger.warn("Failed to save HUD layout: " + str(error), "ui")
		return false

func reset_to_default() -> void:
	load_layout_preset(HUDConfigResource.LayoutPreset.DEFAULT)
	Logger.info("HUD layout reset to default", "ui")

# Debug functionality
func toggle_debug_hud() -> void:
	# Toggle visibility of debug components
	for component_id in registered_components:
		if "debug" in component_id.to_lower() or "performance" in component_id.to_lower():
			var component := get_component(component_id)
			if component:
				var current_visibility := component.visible
				component.set_component_visible(not current_visibility)

func get_performance_stats() -> Dictionary:
	var stats := {
		"total_components": registered_components.size(),
		"visible_components": 0,
		"average_hud_update_time": 0.0,
		"component_stats": []
	}
	
	var total_update_time := 0.0
	var component_count := 0
	
	for component_id in registered_components:
		var component: Control = registered_components[component_id]
		if component.visible:
			stats.visible_components += 1
		
		if component.has_method("get_performance_stats"):
			var component_stats: Dictionary = component.get_performance_stats()
			stats.component_stats.append(component_stats)
			total_update_time += component_stats.get("average_update_time", 0.0)
			component_count += 1
	
	if component_count > 0:
		stats.average_hud_update_time = total_update_time / component_count
	
	return stats

# Private methods
func _setup_hud_manager() -> void:
	# Set up the HUD container
	_hud_container = Control.new()
	_hud_container.name = "HUDContainer"
	_hud_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hud_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# Add to current scene if possible
	var current_scene := get_tree().current_scene
	if current_scene:
		current_scene.add_child(_hud_container)

func _load_configuration() -> void:
	# Try to load user configuration first
	if FileAccess.file_exists(USER_CONFIG_PATH):
		hud_config = load(USER_CONFIG_PATH)
		Logger.debug("Loaded user HUD configuration", "ui")
	elif FileAccess.file_exists(DEFAULT_CONFIG_PATH):
		hud_config = load(DEFAULT_CONFIG_PATH)
		Logger.debug("Loaded default HUD configuration", "ui")
	else:
		hud_config = HUDConfigResource.new()
		Logger.debug("Created new HUD configuration", "ui")

func _connect_signals() -> void:
	# Connect to game state changes
	if EventBus:
		EventBus.game_paused_changed.connect(_on_game_paused_changed)
		EventBus.player_died.connect(_on_player_died)

func _apply_layout_configuration() -> void:
	if not hud_config:
		return
	
	for component_id in registered_components:
		var component: Control = registered_components[component_id]
		if component and component.has_method("apply_anchor_config"):
			var position_config := hud_config.get_component_position(component_id)
			var scale_config := hud_config.get_component_scale(component_id)
			var visibility_config := hud_config.get_component_visibility(component_id)
			
			component.apply_anchor_config(position_config)
			component.set_component_scale(scale_config)
			component.set_component_visible(visibility_config)
	
	layout_changed.emit(hud_config)

func _apply_hud_visibility() -> void:
	if _hud_container:
		_hud_container.visible = _is_hud_visible

func _check_performance_budget() -> void:
	var stats := get_performance_stats()
	var avg_update_time: float = stats.get("average_hud_update_time", 0.0)
	
	# Log warning if HUD updates are taking too much time (>5ms per frame)
	if avg_update_time > 5.0:
		Logger.warn("HUD performance budget exceeded: %.2f ms average" % avg_update_time, "ui")

func _on_game_paused_changed(payload) -> void:
	# HUD components process during pause, but we might want to show/hide specific elements
	pass

func _on_player_died() -> void:
	# Could dim HUD or show death overlay
	pass
