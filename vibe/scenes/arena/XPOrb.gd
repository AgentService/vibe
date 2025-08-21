extends Node2D
class_name XPOrb

## XP orb that moves toward player and can be collected.

signal collected(xp_value: int)

@export var xp_value: int = 1
@export var magnet_radius: float = 120.0
@export var move_speed: float = 180.0
@export var pickup_radius: float = 12.0

var _player: Node2D
var _moving_to_player: bool = false

func _ready() -> void:
	# XP orbs should pause with the game
	process_mode = Node.PROCESS_MODE_PAUSABLE
	_player = get_tree().get_first_node_in_group("player")

func _process(delta: float) -> void:
	if not _player:
		return
		
	var distance_to_player: float = global_position.distance_to(_player.global_position)
	
	if distance_to_player <= pickup_radius:
		collected.emit(xp_value)
		queue_free()
		return
	
	if distance_to_player <= magnet_radius:
		_moving_to_player = true
	
	if _moving_to_player:
		var direction: Vector2 = (_player.global_position - global_position).normalized()
		global_position += direction * move_speed * delta
