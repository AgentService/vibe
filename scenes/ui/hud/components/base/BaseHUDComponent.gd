class_name BaseHUDComponent
extends Control

## Base class for all HUD components providing lifecycle management, 
## EventBus integration, and performance monitoring

@export var component_id: String = ""
@export var update_frequency: float = 60.0  # Max updates per second
@export var enable_performance_monitoring: bool = false

# Internal state
var _last_update_time: float = 0.0
var _update_count: int = 0
var _frame_time_accumulator: float = 0.0
var _is_registered: bool = false
var _signal_connections: Array[Dictionary] = []

# Performance metrics
var average_update_time: float = 0.0
var peak_update_time: float = 0.0

signal component_ready(component_id: String)
signal component_destroyed(component_id: String)

func _init() -> void:
	# Ensure all HUD components process during pause
	process_mode = Node.PROCESS_MODE_ALWAYS

func _ready() -> void:
	if component_id.is_empty():
		component_id = _generate_component_id()
	
	_setup_component()
	_connect_base_signals()
	
	# Defer registration to avoid node tree busy state
	call_deferred("_register_with_hud_manager")
	
	component_ready.emit(component_id)
	Logger.debug("HUD component initialized: " + component_id, "ui")

func _exit_tree() -> void:
	_cleanup_signal_connections()
	_unregister_from_hud_manager()
	component_destroyed.emit(component_id)
	Logger.debug("HUD component destroyed: " + component_id, "ui")

func _process(delta: float) -> void:
	if not _should_update():
		return
	
	var start_time := Time.get_ticks_msec()
	
	_update_component(delta)
	
	if enable_performance_monitoring:
		_track_performance(start_time)

# Virtual methods for subclasses to override
func _setup_component() -> void:
	# Override in subclasses for initialization
	pass

func _update_component(delta: float) -> void:
	# Override in subclasses for per-frame updates
	pass

func _cleanup_component() -> void:
	# Override in subclasses for cleanup
	pass

# Signal connection helpers
func connect_to_signal(signal_obj: Signal, callback: Callable, flags: int = 0) -> void:
	if not signal_obj.is_connected(callback):
		signal_obj.connect(callback, flags)
		_signal_connections.append({
			"signal": signal_obj,
			"callback": callback
		})

func disconnect_from_signal(signal_obj: Signal, callback: Callable) -> void:
	if signal_obj.is_connected(callback):
		signal_obj.disconnect(callback)
		_signal_connections = _signal_connections.filter(
			func(conn): return conn.signal != signal_obj or conn.callback != callback
		)

# Component state management
func set_component_visible(visible: bool) -> void:
	self.visible = visible
	if visible:
		Logger.debug("Component shown: " + component_id, "ui")
	else:
		Logger.debug("Component hidden: " + component_id, "ui")

func set_component_scale(new_scale: Vector2) -> void:
	scale = new_scale
	Logger.debug("Component scaled: %s to %s" % [component_id, new_scale], "ui")

func set_update_frequency(frequency: float) -> void:
	update_frequency = max(1.0, frequency)

# Performance monitoring
func get_performance_stats() -> Dictionary:
	return {
		"component_id": component_id,
		"update_count": _update_count,
		"average_update_time": average_update_time,
		"peak_update_time": peak_update_time,
		"last_update_time": _last_update_time
	}

func reset_performance_stats() -> void:
	_update_count = 0
	_frame_time_accumulator = 0.0
	average_update_time = 0.0
	peak_update_time = 0.0

# Position and layout helpers
func apply_anchor_config(config: Dictionary) -> void:
	# No programmatic positioning - respect editor settings for all components
	pass

func get_anchor_config() -> Dictionary:
	# Calculate the most appropriate preset for current anchors
	var preset := _determine_anchor_preset()
	return {
		"anchor_preset": preset,
		"offset": position
	}

# Private methods
func _should_update() -> bool:
	var current_time: float = Time.get_ticks_msec() / 1000.0
	var time_since_last_update: float = current_time - _last_update_time
	var min_interval: float = 1.0 / update_frequency
	
	if time_since_last_update >= min_interval:
		_last_update_time = current_time
		return true
	
	return false

func _track_performance(start_time: int) -> void:
	var end_time := Time.get_ticks_msec()
	var frame_time := float(end_time - start_time)
	
	_update_count += 1
	_frame_time_accumulator += frame_time
	
	average_update_time = _frame_time_accumulator / _update_count
	peak_update_time = max(peak_update_time, frame_time)

func _generate_component_id() -> String:
	return get_script().get_path().get_file().get_basename() + "_" + str(get_instance_id())

# Base setup method removed - duplicate method

func _connect_base_signals() -> void:
	# Connect to HUD manager signals if available
	# Note: HUDManager is a singleton, layout_changed signal will be available once connected
	pass

func _register_with_hud_manager() -> void:
	if HUDManager and not _is_registered:
		HUDManager.register_component(component_id, self)
		_is_registered = true

func _unregister_from_hud_manager() -> void:
	if HUDManager and _is_registered:
		HUDManager.unregister_component(component_id)
		_is_registered = false

func _cleanup_signal_connections() -> void:
	for connection in _signal_connections:
		var signal_obj: Signal = connection.signal
		var callback: Callable = connection.callback
		if signal_obj.is_connected(callback):
			signal_obj.disconnect(callback)
	_signal_connections.clear()
	
	_cleanup_component()

func _on_layout_changed(new_config: HUDConfigResource) -> void:
	# Apply new configuration from layout change
	var position_config := new_config.get_component_position(component_id)
	var scale_config := new_config.get_component_scale(component_id)
	var visibility_config := new_config.get_component_visibility(component_id)
	
	apply_anchor_config(position_config)
	set_component_scale(scale_config)
	set_component_visible(visibility_config)

func _determine_anchor_preset() -> int:
	# Determine the closest anchor preset based on current anchor values
	var left := anchor_left
	var right := anchor_right
	var top := anchor_top
	var bottom := anchor_bottom
	
	# Check for common presets
	if left == 0.0 and right == 1.0 and top == 1.0 and bottom == 1.0:
		return Control.PRESET_BOTTOM_WIDE
	elif left == 0.5 and right == 0.5 and top == 1.0 and bottom == 1.0:
		return Control.PRESET_CENTER_BOTTOM
	elif left == 1.0 and right == 1.0 and top == 0.0 and bottom == 0.0:
		return Control.PRESET_TOP_RIGHT
	elif left == 0.0 and right == 0.0 and top == 1.0 and bottom == 1.0:
		return Control.PRESET_BOTTOM_LEFT
	
	return Control.PRESET_TOP_LEFT
