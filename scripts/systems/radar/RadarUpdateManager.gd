@tool
extends Node
class_name RadarUpdateManager

## RADAR PERFORMANCE V3: Batched radar updates with ring buffer optimization
## Replaces individual EntityTracker scans with type-indexed views and batched processing
## Configurable update frequency (default 60Hz) for smooth radar updates
## Uses latest-only ring buffer semantics for radar data (transient, drop-old behavior)

const RingBuffer = preload("res://scripts/utils/RingBuffer.gd")
const ObjectPool = preload("res://scripts/utils/ObjectPool.gd")
const PayloadReset = preload("res://scripts/utils/PayloadReset.gd")

# Reusable batched payload buffers (cleared each step, not reallocated)
var _ids_buf: PackedStringArray = PackedStringArray()
var _pos_buf: PackedVector2Array = PackedVector2Array()
var _type_buf: PackedByteArray = PackedByteArray() # 0 = enemy, 1 = boss

# Temp buffers to fetch positions per type without allocation
var _enemy_pos_tmp: PackedVector2Array = PackedVector2Array()
var _boss_pos_tmp: PackedVector2Array = PackedVector2Array()

var _player_position: Vector2 = Vector2.ZERO

# Dependencies
var _spawn_director: SpawnDirector = null

# Queue + pool with latest-only semantics
var _radar_update_queue: RingBuffer
var _radar_payload_pool: ObjectPool

# State control
var _enabled: bool = false
var _update_frequency: float = 60.0  # Default 60 Hz for smooth updates
var _update_timer: float = 0.0

# Adaptive frequency for burst spawning scenarios
var _base_frequency: float = 60.0
var _last_entity_count: int = 0
var _entity_count_spike_threshold: int = 50  # Temporarily slow down if 50+ entities spawn

func _ready() -> void:
	_setup_infrastructure()
	_connect_signals()
	_load_configuration()
	set_process(true)  # Use _process for configurable frequency
	Logger.info("RadarUpdateManager initialized with %.0f Hz update frequency" % _update_frequency, "radar")

func _setup_infrastructure() -> void:
	# Ring buffer sized for burst spawning scenarios
	_radar_update_queue = RingBuffer.new()
	_radar_update_queue.setup(16) # Larger buffer to handle enemy spawn bursts
	
	# Object pool for radar batch payloads
	_radar_payload_pool = ObjectPool.new()
	_radar_payload_pool.setup(4, 
		PayloadReset.create_radar_batch_payload,
		PayloadReset.clear_radar_batch_payload
	)

func _connect_signals() -> void:
	# Track player position for radar center
	if EventBus and EventBus.player_position_changed:
		EventBus.player_position_changed.connect(Callable(self, "_on_player_position_changed"))
	
	# Listen for state changes to enable/disable radar processing
	if StateManager:
		StateManager.state_changed.connect(Callable(self, "_on_state_changed"))
	
	# Listen for balance reloads to update frequency
	if BalanceDB:
		BalanceDB.balance_reloaded.connect(Callable(self, "_on_balance_reloaded"))

func set_enabled(enabled: bool) -> void:
	_enabled = enabled
	Logger.info("RadarUpdateManager enabled: %s" % enabled, "radar")

func set_update_frequency(hz: float) -> void:
	_update_frequency = max(1.0, hz)  # Minimum 1 Hz
	Logger.debug("RadarUpdateManager frequency set to %.0f Hz" % _update_frequency, "radar")

func setup_spawn_director(spawn_director: SpawnDirector) -> void:
	_spawn_director = spawn_director
	Logger.debug("RadarUpdateManager: SpawnDirector dependency setup for hybrid fallback", "radar")

func _process(delta: float) -> void:
	if not _enabled or not EntityTracker:
		return
	
	# Performance optimization: Skip radar processing if disabled
	if DebugManager and DebugManager.is_radar_disabled():
		return
	
	# Update at configured frequency
	_update_timer += delta
	var update_interval = 1.0 / _update_frequency
	
	if _update_timer >= update_interval:
		_update_timer = 0.0
		_process_radar_update()

func _load_configuration() -> void:
	if BalanceDB:
		var config: Dictionary = BalanceDB.get_ui_value("radar")
		_base_frequency = config.get("emit_hz", 60.0)  # Default 60 Hz
		_update_frequency = _base_frequency
		Logger.debug("RadarUpdateManager: Loaded base frequency %.0f Hz from balance data" % _base_frequency, "radar")
	else:
		_base_frequency = 60.0
		_update_frequency = _base_frequency
		Logger.warn("RadarUpdateManager: BalanceDB not available, using default 60 Hz", "radar")

func _on_balance_reloaded() -> void:
	_load_configuration()

func _on_state_changed(_prev: StateManager.State, next: StateManager.State, _context: Dictionary) -> void:
	# Only process radar in ARENA state
	var should_enable = (next == StateManager.State.ARENA)
	set_enabled(should_enable)

func _on_player_position_changed(payload) -> void:
	# Handle both typed payload and direct Vector2
	if typeof(payload) == TYPE_VECTOR2:
		_player_position = payload
	elif payload and "position" in payload:
		_player_position = payload.position
	elif payload and "pos" in payload:
		_player_position = payload.pos
	else:
		Logger.warn("RadarUpdateManager: Invalid player position payload format", "radar")

# Removed: _on_combat_step - now using _process with configurable frequency

func _process_radar_update() -> void:
	# Clear reusable buffers without reallocations
	_ids_buf.resize(0)
	_pos_buf.resize(0)
	_type_buf.resize(0)
	_enemy_pos_tmp.resize(0)
	_boss_pos_tmp.resize(0)

	# HYBRID APPROACH: Get enemies from both EntityTracker and SpawnDirector for reliability  
	# This fixes radar freeze issues with mesh enemies while maintaining boss performance
	var enemy_ids: PackedStringArray
	var boss_ids: PackedStringArray
	
	# Reduced logging - only focus on key issues
	enemy_ids = EntityTracker.get_entities_by_type_view("enemy")
	boss_ids = EntityTracker.get_entities_by_type_view("boss")
	
	# Fallback for mesh enemies: Use SpawnDirector.get_alive_enemies() if EntityTracker seems problematic
	var use_spawndirector_fallback = false
	if enemy_ids.size() == 0 and _spawn_director:
		# Check if SpawnDirector has alive enemies that EntityTracker missed
		var alive_enemies = _spawn_director.get_alive_enemies()
		if alive_enemies.size() > 0:
			use_spawndirector_fallback = true
	
	
	# Adaptive frequency: Temporarily reduce update rate during entity count spikes
	var current_entity_count = enemy_ids.size() + boss_ids.size()
	var entity_count_delta = abs(current_entity_count - _last_entity_count)
	
	if entity_count_delta > _entity_count_spike_threshold:
		# Temporarily reduce frequency during burst spawning
		_update_frequency = _base_frequency * 0.5  # Half frequency during spikes
	else:
		# Restore normal frequency
		_update_frequency = _base_frequency
	
	_last_entity_count = current_entity_count
	
	# Minimal logging for key issues only

	# Handle enemy data based on source (EntityTracker vs SpawnDirector fallback)
	if use_spawndirector_fallback:
		# Use SpawnDirector as source for mesh enemies (old radar system approach)
		var alive_enemies = _spawn_director.get_alive_enemies()
		for enemy in alive_enemies:
			_ids_buf.append("enemy_fallback_" + str(_ids_buf.size()))  # Generate consistent ID
			_pos_buf.append(enemy.pos)
			_type_buf.push_back(0) # 0 = enemy
	else:
		# Use EntityTracker for mesh enemies (new optimized approach)
		EntityTracker.get_positions_for(enemy_ids, _enemy_pos_tmp)
		_ids_buf.append_array(enemy_ids)
		_pos_buf.append_array(_enemy_pos_tmp)
		# Push type values for each enemy (remove the resize call that was causing double entries)
		for i in enemy_ids.size():
			_type_buf.push_back(0) # 0 = enemy
	
	# Always use EntityTracker for bosses (works reliably)
	EntityTracker.get_positions_for(boss_ids, _boss_pos_tmp)
	_ids_buf.append_array(boss_ids)
	_pos_buf.append_array(_boss_pos_tmp)
	for i in boss_ids.size():
		_type_buf.push_back(1) # 1 = boss

	# Single batched payload per step
	var payload = _radar_payload_pool.acquire()
	payload["ids"] = _ids_buf.duplicate() # Duplicate to avoid buffer reuse conflicts
	payload["positions"] = _pos_buf.duplicate()
	payload["types"] = _type_buf.duplicate()
	payload["player_pos"] = _player_position

	# Latest-only queueing: if full, drop oldest
	if not _radar_update_queue.try_push(payload):
		# Buffer full - drop oldest by popping then pushing new
		var old_payload = _radar_update_queue.try_pop()
		if old_payload:
			_radar_payload_pool.release(old_payload)
		_radar_update_queue.try_push(payload)

	_emit_latest_radar_data()

func _emit_latest_radar_data() -> void:
	var latest_payload = _radar_update_queue.pop_latest_or_null()
	if latest_payload == null:
		return

	# Convert batched arrays back to EventBus.RadarEntity format for UI compatibility
	var radar_entities: Array[EventBus.RadarEntity] = []
	var ids: PackedStringArray = latest_payload["ids"]
	var positions: PackedVector2Array = latest_payload["positions"]
	var types: PackedByteArray = latest_payload["types"]
	
	var entity_count = ids.size()
	if entity_count != positions.size() or entity_count != types.size():
		Logger.warn("RadarUpdateManager: Payload array size mismatch - ids:%d pos:%d types:%d" % [ids.size(), positions.size(), types.size()], "radar")
		_radar_payload_pool.release(latest_payload)
		return
	
	# Convert back to RadarEntity objects at the UI boundary
	for i in range(entity_count):
		var entity_type: String = "enemy" if types[i] == 0 else "boss"
		var radar_entity = EventBus.RadarEntity.new(positions[i], entity_type)
		radar_entities.append(radar_entity)
	
	var player_pos: Vector2 = latest_payload["player_pos"]
	
	# Emit via existing EventBus interface for UI compatibility
	if EventBus:
		EventBus.radar_data_updated.emit(radar_entities, player_pos)
	
	# Return payload to pool
	_radar_payload_pool.release(latest_payload)

func _exit_tree() -> void:
	# Cleanup signal connections
	if EventBus and EventBus.player_position_changed and EventBus.player_position_changed.is_connected(Callable(self, "_on_player_position_changed")):
		EventBus.player_position_changed.disconnect(Callable(self, "_on_player_position_changed"))
	
	if StateManager and StateManager.state_changed.is_connected(Callable(self, "_on_state_changed")):
		StateManager.state_changed.disconnect(Callable(self, "_on_state_changed"))
	
	if BalanceDB and BalanceDB.balance_reloaded.is_connected(Callable(self, "_on_balance_reloaded")):
		BalanceDB.balance_reloaded.disconnect(Callable(self, "_on_balance_reloaded"))
	
	Logger.debug("RadarUpdateManager: Cleaned up signal connections", "radar")

## DEBUG: Get performance statistics
func get_debug_info() -> Dictionary:
	return {
		"enabled": _enabled,
		"update_frequency": _update_frequency,
		"update_timer": _update_timer,
		"queue_count": _radar_update_queue.count() if _radar_update_queue else 0,
		"queue_capacity": _radar_update_queue.capacity() if _radar_update_queue else 0,
		"pool_available": _radar_payload_pool.available_count() if _radar_payload_pool else 0,
		"buffer_sizes": {
			"ids": _ids_buf.size(),
			"positions": _pos_buf.size(), 
			"types": _type_buf.size()
		}
	}
