extends Node
class_name RadarSystem

## Radar system coordination layer for RadarUpdateManager integration.
## RADAR PERFORMANCE V3: Simplified to coordinate RadarUpdateManager instead of direct EntityTracker scans
## Eliminates 60 Hz O(N) entity scanning bottleneck in favor of 30 Hz batched processing
## RadarUpdateManager handles all zero-allocation batched processing; this provides setup/coordination

# Dependencies  
var _radar_update_manager: RadarUpdateManager
var _enabled: bool = false

# State tracking
var _current_state: StateManager.State
var _is_paused: bool = false

func _ready() -> void:
	_setup_radar_update_manager()
	_setup_connections()
	_initialize_state()
	Logger.info("RadarSystem initialized with RadarUpdateManager integration", "radar")
	Logger.debug("RadarSystem: _ready complete, enabled=%s, state=%s" % [_enabled, _current_state], "radar")

func _setup_radar_update_manager() -> void:
	# Create and setup RadarUpdateManager as child node
	_radar_update_manager = RadarUpdateManager.new()
	_radar_update_manager.name = "RadarUpdateManager"
	add_child(_radar_update_manager)
	
	Logger.debug("RadarSystem: RadarUpdateManager created and attached", "radar")

func _setup_connections() -> void:
	# No longer need _process - RadarUpdateManager handles 30Hz combat step timing
	set_process(false)
	
	# Connect to state changes for ARENA-only operation
	if StateManager and StateManager.state_changed:
		StateManager.state_changed.connect(_on_state_changed)
	
	# Connect to pause state changes
	if EventBus and EventBus.game_paused_changed:
		EventBus.game_paused_changed.connect(_on_game_paused_changed)
	
	Logger.debug("RadarSystem: Connected to state management signals", "radar")

func setup(wave_director: WaveDirector = null) -> void:
	# Pass WaveDirector to RadarUpdateManager for hybrid approach fallback
	if _radar_update_manager and wave_director:
		_radar_update_manager.setup_wave_director(wave_director)
	_update_enabled_state()
	Logger.info("RadarSystem setup completed (RadarUpdateManager handles data sourcing)", "radar")

func set_enabled(enabled: bool) -> void:
	_enabled = enabled
	
	# Forward enabled state to RadarUpdateManager
	if _radar_update_manager:
		_radar_update_manager.set_enabled(enabled)
	
	Logger.debug("RadarSystem enabled: %s (forwarded to RadarUpdateManager)" % enabled, "radar")

func _on_state_changed(_prev: StateManager.State, next: StateManager.State, _context: Dictionary) -> void:
	_current_state = next
	_update_enabled_state()

func _on_game_paused_changed(payload) -> void:
	# Handle both typed payload (EventBus.GamePausedChangedPayload) and Dictionary
	if payload:
		if typeof(payload) == TYPE_DICTIONARY:
			_is_paused = payload.get("is_paused", false)
		else:
			# Assume typed payload with is_paused property
			_is_paused = payload.is_paused if "is_paused" in payload else false
		Logger.debug("RadarSystem pause state: %s" % _is_paused, "radar")

func _update_enabled_state() -> void:
	var should_be_enabled = (_current_state == StateManager.State.ARENA)
	Logger.debug("RadarSystem: State changed - current: %s, should_enable: %s" % [_current_state, should_be_enabled], "radar")
	set_enabled(should_be_enabled)

func _initialize_state() -> void:
	# Initialize current state from StateManager to handle startup scenarios
	if StateManager:
		_current_state = StateManager.get_current_state()
		_update_enabled_state()
		Logger.debug("RadarSystem: Initialized state from StateManager: %s" % _current_state, "radar")
	else:
		Logger.warn("RadarSystem: StateManager not available for state initialization", "radar")

func _exit_tree() -> void:
	# Cleanup signal connections
	if StateManager and StateManager.state_changed and StateManager.state_changed.is_connected(_on_state_changed):
		StateManager.state_changed.disconnect(_on_state_changed)
	if EventBus and EventBus.game_paused_changed and EventBus.game_paused_changed.is_connected(_on_game_paused_changed):
		EventBus.game_paused_changed.disconnect(_on_game_paused_changed)
	
	Logger.debug("RadarSystem: Cleaned up signal connections", "radar")

## DEBUG: Get performance statistics from RadarUpdateManager
func get_debug_info() -> Dictionary:
	var base_info = {
		"enabled": _enabled,
		"current_state": _current_state,
		"is_paused": _is_paused,
		"radar_update_manager_attached": _radar_update_manager != null
	}
	
	if _radar_update_manager:
		var manager_info = _radar_update_manager.get_debug_info()
		base_info["radar_update_manager"] = manager_info
	
	return base_info

## DEPRECATED METHODS (kept for compatibility, but no longer used)
func set_emit_rate_hz(hz: float) -> void:
	# RadarUpdateManager uses 30Hz combat step alignment - emit rate no longer configurable
	Logger.debug("RadarSystem: set_emit_rate_hz() deprecated - RadarUpdateManager uses 30Hz combat step", "radar")

func _load_configuration() -> void:
	# Configuration loading no longer needed - RadarUpdateManager handles its own setup
	Logger.debug("RadarSystem: _load_configuration() deprecated - RadarUpdateManager handles configuration", "radar")
