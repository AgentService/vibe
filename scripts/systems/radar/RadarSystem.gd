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

# Old radar system variables (used when new system is disabled)
var _old_radar_timer: float = 0.0
var _old_radar_frequency: float = 30.0
var _spawn_director: SpawnDirector

func _ready() -> void:
	_setup_radar_update_manager()
	_setup_connections()
	_initialize_state()
	Logger.info("RadarSystem initialized with RadarUpdateManager integration", "radar")
	Logger.debug("RadarSystem: _ready complete, enabled=%s, state=%s" % [_enabled, _current_state], "radar")

func _setup_radar_update_manager() -> void:
	# Check configuration to determine which radar system to use
	var config: Dictionary = BalanceDB.get_ui_value("radar")
	var use_new_system: bool = config.get("use_new_radar_system", true)
	
	# DEBUG: Log the actual configuration values
	Logger.info("RadarSystem: Configuration loaded - use_new_radar_system: %s, config keys: %s" % [use_new_system, config.keys()], "radar")
	
	if use_new_system:
		# Create and setup RadarUpdateManager as child node (new system)
		_radar_update_manager = RadarUpdateManager.new()
		_radar_update_manager.name = "RadarUpdateManager"
		add_child(_radar_update_manager)
		Logger.info("RadarSystem: Using NEW radar system (RadarUpdateManager)", "radar")
	else:
		# Use old radar system - no RadarUpdateManager needed
		_radar_update_manager = null
		_old_radar_frequency = config.get("emit_hz", 30.0)
		Logger.info("RadarSystem: Using OLD radar system (legacy direct EntityTracker) at %.0f Hz" % _old_radar_frequency, "radar")

func _setup_connections() -> void:
	# Set process based on which radar system is active
	if _radar_update_manager:
		# New system: RadarUpdateManager handles timing
		set_process(false)
	else:
		# Old system: Use _process for direct EntityTracker scanning
		set_process(true)
	
	# Connect to state changes for ARENA-only operation
	if StateManager and StateManager.state_changed:
		StateManager.state_changed.connect(_on_state_changed)
	
	# Connect to pause state changes
	if EventBus and EventBus.game_paused_changed:
		EventBus.game_paused_changed.connect(_on_game_paused_changed)
	
	Logger.debug("RadarSystem: Connected to state management signals", "radar")

func setup(spawn_director: SpawnDirector = null) -> void:
	# Store SpawnDirector reference for both old and new systems
	_spawn_director = spawn_director
	
	if _radar_update_manager:
		# New system: Pass SpawnDirector to RadarUpdateManager for hybrid approach fallback
		_radar_update_manager.setup_spawn_director(spawn_director)
	
	_update_enabled_state()
	Logger.info("RadarSystem saetup completed", "radar")

func set_enabled(enabled: bool) -> void:
	_enabled = enabled
	
	if _radar_update_manager:
		# New system: Forward enabled state to RadarUpdateManager
		_radar_update_manager.set_enabled(enabled)
		Logger.debug("RadarSystem enabled: %s (forwarded to RadarUpdateManager)" % enabled, "radar")
	else:
		# Old system: Handle enabled state directly
		Logger.debug("RadarSystem enabled: %s (old system direct)" % enabled, "radar")

func _process(delta: float) -> void:
	# Old radar system: Direct EntityTracker scanning (only when new system is disabled)
	if _radar_update_manager:
		return  # New system active, skip old processing
	
	if not _enabled or not EntityTracker:
		return
	
	# Performance optimization: Skip radar processing if disabled
	if DebugManager and DebugManager.is_radar_disabled():
		return
	
	# Update at configured frequency
	_old_radar_timer += delta
	var update_interval = 1.0 / _old_radar_frequency
	
	if _old_radar_timer >= update_interval:
		_old_radar_timer = 0.0
		_process_old_radar_update()

func _process_old_radar_update() -> void:
	# Old radar system implementation: Direct SpawnDirector access (original system)
	# Performance optimization: Skip radar calculations if disabled
	if DebugManager.is_radar_disabled():
		return
	
	var radar_entities: Array[EventBus.RadarEntity] = []
	
	# Gather pooled enemies from SpawnDirector (original old system approach)
	if _spawn_director:
		var alive_enemies: Array[EnemyEntity] = _spawn_director.get_alive_enemies()
		for enemy in alive_enemies:
			var radar_entity = EventBus.RadarEntity.new(enemy.pos, "enemy")
			radar_entities.append(radar_entity)
	
	# Gather boss entities from EntityTracker (bosses were always tracked this way)
	if EntityTracker:
		var boss_ids = EntityTracker.get_entities_by_type_view("boss")
		var temp_positions: PackedVector2Array = PackedVector2Array()
		EntityTracker.get_positions_for(boss_ids, temp_positions)
		for i in range(boss_ids.size()):
			var radar_entity = EventBus.RadarEntity.new(temp_positions[i], "boss")
			radar_entities.append(radar_entity)
	
	# Get player position
	var player_position = Vector2.ZERO
	if PlayerState:
		player_position = PlayerState.position
	
	# Emit via EventBus
	if EventBus:
		EventBus.radar_data_updated.emit(radar_entities, player_position)

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
