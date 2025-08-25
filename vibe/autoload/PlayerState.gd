extends Node

## Cached player state for performance-optimized cross-system access.
## Emits position updates at 10-15Hz or when position delta > 12px.

signal player_position_changed(position: Vector2)

var position: Vector2 = Vector2.ZERO
var _last_emitted_position: Vector2 = Vector2.ZERO
var _update_timer: float = 0.0
var _player_ref: Node2D

const UPDATE_INTERVAL: float = 1.0 / 12.0  # 12Hz
const MIN_DELTA_THRESHOLD: float = 12.0  # pixels

func _ready() -> void:
	# Connect to combat step for regular updates
	EventBus.combat_step.connect(_on_combat_step)

func _exit_tree() -> void:
	# Cleanup signal connections
	if EventBus.combat_step.is_connected(_on_combat_step):
		EventBus.combat_step.disconnect(_on_combat_step)

func set_player_reference(player: Node2D) -> void:
	_player_ref = player
	if _player_ref:
		position = _player_ref.global_position
		_last_emitted_position = position
		player_position_changed.emit(position)

func _on_combat_step(payload: EventBus.CombatStepPayload_Type) -> void:
	if not _player_ref:
		return
	
	_update_timer += payload.dt
	var current_pos: Vector2 = _player_ref.global_position
	position = current_pos
	
	var delta_distance: float = position.distance_to(_last_emitted_position)
	var should_emit: bool = false
	
	# Emit if enough time has passed (rate limiting)
	if _update_timer >= UPDATE_INTERVAL:
		should_emit = true
		_update_timer = 0.0
	# Or if position changed significantly (responsiveness)
	elif delta_distance >= MIN_DELTA_THRESHOLD:
		should_emit = true
		_update_timer = 0.0  # Reset timer to avoid double-emits
	
	if should_emit:
		_last_emitted_position = position
		var pos_payload := EventBus.PlayerPositionChangedPayload_Type.new(position)
		EventBus.player_position_changed.emit(pos_payload)
		player_position_changed.emit(position)

func has_player_reference() -> bool:
	return _player_ref != null
