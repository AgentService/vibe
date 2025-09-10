extends Node
class_name XpSystem

## Manages XP orb spawning and delegates progression to PlayerProgression autoload.
## XP orbs are spawned when enemies die, and collected XP is forwarded to PlayerProgression.

const XP_ORB_SCENE: PackedScene = preload("res://scenes/arena/XPOrb.tscn")

var _arena_node: Node

func _init(arena: Node) -> void:
	_arena_node = arena

func _ready() -> void:
	# Initialized as XP orb spawner only (progression handled by PlayerProgression)
	EventBus.combat_step.connect(_on_combat_step)
	EventBus.enemy_killed.connect(_on_enemy_killed)

func _exit_tree() -> void:
	# Cleanup signal connections
	if EventBus.combat_step.is_connected(_on_combat_step):
		EventBus.combat_step.disconnect(_on_combat_step)
	if EventBus.enemy_killed.is_connected(_on_enemy_killed):
		EventBus.enemy_killed.disconnect(_on_enemy_killed)
	# Cleaned up signal connections


func _on_combat_step(_payload) -> void:
	pass

func _on_enemy_killed(pos: Vector2, xp_value: int) -> void:
	# Enemy killed, spawning XP orb
	_spawn_xp_orb(pos, xp_value)

func _spawn_xp_orb(pos: Vector2, xp_value: int) -> void:
	# Creating XP orb
	var orb: XPOrb = XP_ORB_SCENE.instantiate()
	orb.global_position = pos
	orb.xp_value = xp_value
	orb.collected.connect(_on_xp_collected)
	_arena_node.add_child(orb)
	# XP orb spawned and added to arena

func _on_xp_collected(amount: int) -> void:
	# XP orb collected
	# Delegate XP processing to PlayerProgression autoload
	if PlayerProgression:
		# PlayerProgression found, gaining XP
		PlayerProgression.gain_exp(float(amount))
		# Forwarded XP to PlayerProgression
		
		# Update RunManager level for card system compatibility
		RunManager.stats["level"] = PlayerProgression.level
		# Updated RunManager level
	else:
		# ERROR - PlayerProgression not available!
		# PlayerProgression not available, XP collection ignored
		pass
