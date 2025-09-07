extends Node
class_name RadarSystem

## Radar system for providing enemy position data to UI components.
## Decouples enemy scanning from UI rendering by emitting data via EventBus.
## Only active in ARENA state and respects pause state.
## Updates at throttled rate (10 Hz) to reduce performance impact.

# Dependencies
var _wave_director: WaveDirector
var _enabled: bool = false

# Configuration
var _emit_hz: float = 10.0
var _throttle_accum: float = 0.0

# Data buffers (reused for performance)
var _radar_entities_buf: Array[EventBus.RadarEntity] = []
var _player_pos: Vector2 = Vector2.ZERO

# State tracking
var _current_state: StateManager.State
var _is_paused: bool = false

func _ready() -> void:
	_setup_connections()
	_load_configuration()
	_initialize_state()
	Logger.info("RadarSystem initialized", "radar")
	Logger.debug("RadarSystem: _ready complete, enabled=%s, state=%s" % [_enabled, _current_state], "radar")

func _setup_connections() -> void:
	# Connect to combat step for updates
	if EventBus:
		EventBus.combat_step.connect(_on_combat_step)
	
	# Connect to player position updates
	if PlayerState and PlayerState.player_position_changed:
		PlayerState.player_position_changed.connect(_on_player_position_changed)
	
	# Connect to state changes for ARENA-only operation
	if StateManager and StateManager.state_changed:
		StateManager.state_changed.connect(_on_state_changed)
	
	# Connect to pause state changes
	if EventBus and EventBus.game_paused_changed:
		EventBus.game_paused_changed.connect(_on_game_paused_changed)
	
	# Connect to balance reloads for configuration updates
	if BalanceDB and BalanceDB.balance_reloaded:
		BalanceDB.balance_reloaded.connect(_on_balance_reloaded)

func setup(wave_director: WaveDirector) -> void:
	_wave_director = wave_director
	_update_enabled_state()
	Logger.info("RadarSystem setup with WaveDirector dependency", "radar")

func set_enabled(enabled: bool) -> void:
	_enabled = enabled
	Logger.debug("RadarSystem enabled: %s" % enabled, "radar")

func set_emit_rate_hz(hz: float) -> void:
	_emit_hz = max(1.0, hz)  # Minimum 1 Hz
	Logger.debug("RadarSystem emit rate set to %s Hz" % _emit_hz, "radar")

func _on_combat_step(payload) -> void:
	if not _should_update():
		return
	
	# Throttle updates to configured rate
	_throttle_accum += payload.dt
	var emit_interval := 1.0 / _emit_hz
	
	if _throttle_accum >= emit_interval:
		_throttle_accum = 0.0
		_update_and_emit_radar_data()

func _should_update() -> bool:
	# Allow updates if we have any data source (WaveDirector for pooled enemies or EntityTracker for bosses)
	return _enabled and not _is_paused and (_wave_director != null or EntityTracker != null)

func _update_and_emit_radar_data() -> void:
	# Clear buffer and gather entities from available sources
	_radar_entities_buf.clear()

	var enemy_count := 0
	var boss_count := 0

	# Gather pooled enemies from WaveDirector if available
	if _wave_director:
		var alive_enemies: Array[EnemyEntity] = _wave_director.get_alive_enemies()
		for enemy in alive_enemies:
			var radar_entity = EventBus.RadarEntity.new(enemy.pos, "enemy")
			_radar_entities_buf.append(radar_entity)
		enemy_count = alive_enemies.size()
	elif EntityTracker:
		# Fallback: gather enemies from EntityTracker (robust for future decoupling)
		var enemy_ids = EntityTracker.get_entities_by_type("enemy")
		for id in enemy_ids:
			var data := EntityTracker.get_entity(id)
			if data.has("pos"):
				var radar_entity = EventBus.RadarEntity.new(data["pos"], "enemy")
				_radar_entities_buf.append(radar_entity)
		enemy_count = enemy_ids.size()

	# Always include bosses registered as scenes via EntityTracker
	if EntityTracker:
		var boss_ids = EntityTracker.get_entities_by_type("boss")
		boss_count = boss_ids.size()
		for id in boss_ids:
			var bdata := EntityTracker.get_entity(id)
			if bdata.has("pos"):
				var radar_entity = EventBus.RadarEntity.new(bdata["pos"], "boss")
				_radar_entities_buf.append(radar_entity)

	# Emit radar data via EventBus
	if EventBus:
		EventBus.radar_data_updated.emit(_radar_entities_buf, _player_pos)
		if Logger.is_level_enabled(Logger.LogLevel.DEBUG):
			Logger.debug("RadarSystem: Emitted radar data - %d enemies (+%d bosses) at player pos %s" % [enemy_count, boss_count, _player_pos], "radar")

func _on_player_position_changed(position: Vector2) -> void:
	_player_pos = position

func _on_state_changed(prev: StateManager.State, next: StateManager.State, context: Dictionary) -> void:
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

func _on_balance_reloaded() -> void:
	_load_configuration()

func _update_enabled_state() -> void:
	var should_be_enabled = (_current_state == StateManager.State.ARENA)
	Logger.debug("RadarSystem: State changed - current: %s, should_enable: %s" % [_current_state, should_be_enabled], "radar")
	set_enabled(should_be_enabled)

func _load_configuration() -> void:
	if BalanceDB:
		var config: Dictionary = BalanceDB.get_ui_value("radar")
		_emit_hz = config.get("emit_hz", 10.0)
		Logger.debug("RadarSystem configuration reloaded - emit rate: %s Hz" % _emit_hz, "radar")
	else:
		Logger.warn("RadarSystem: BalanceDB not available for configuration loading", "radar")

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
	if EventBus and EventBus.combat_step.is_connected(_on_combat_step):
		EventBus.combat_step.disconnect(_on_combat_step)
	if PlayerState and PlayerState.player_position_changed and PlayerState.player_position_changed.is_connected(_on_player_position_changed):
		PlayerState.player_position_changed.disconnect(_on_player_position_changed)
	if StateManager and StateManager.state_changed and StateManager.state_changed.is_connected(_on_state_changed):
		StateManager.state_changed.disconnect(_on_state_changed)
	if EventBus and EventBus.game_paused_changed and EventBus.game_paused_changed.is_connected(_on_game_paused_changed):
		EventBus.game_paused_changed.disconnect(_on_game_paused_changed)
	if BalanceDB and BalanceDB.balance_reloaded and BalanceDB.balance_reloaded.is_connected(_on_balance_reloaded):
		BalanceDB.balance_reloaded.disconnect(_on_balance_reloaded)
	
	Logger.debug("RadarSystem: Cleaned up signal connections", "radar")
