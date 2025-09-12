extends Node
class_name HUDManagerClass

## Simplified HUD component coordinator managing lifecycle and performance
## Components use editor-based positioning, no programmatic layout management

var registered_components: Dictionary = {}
var _is_hud_visible: bool = true
var _performance_monitor_timer: float = 0.0

# Performance monitoring
const PERFORMANCE_CHECK_INTERVAL = 5.0

# Signals
signal component_registered(component_id: String)
signal component_unregistered(component_id: String)
signal hud_visibility_changed(visible: bool)

func _init() -> void:
	name = "HUDManager"
	# Add to autoload group for global access
	add_to_group("autoload")

func _ready() -> void:
	_connect_signals()
	Logger.info("HUDManager initialized (simplified version)", "ui")

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
		hud_visibility_changed.emit(true)
		Logger.info("HUD shown", "ui")

func hide_hud() -> void:
	if _is_hud_visible:
		_is_hud_visible = false
		hud_visibility_changed.emit(false)
		Logger.info("HUD hidden", "ui")

func toggle_hud() -> void:
	if _is_hud_visible:
		hide_hud()
	else:
		show_hud()

func is_hud_visible() -> bool:
	return _is_hud_visible

# Component visibility management (simplified)
func set_component_visibility(component_id: String, visible: bool) -> void:
	var component := get_component(component_id)
	if component and component.has_method("set_component_visible"):
		component.set_component_visible(visible)

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

func _connect_signals() -> void:
	# Connect to game state changes
	if EventBus:
		EventBus.game_paused_changed.connect(_on_game_paused_changed)
		EventBus.player_died.connect(_on_player_died)

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
