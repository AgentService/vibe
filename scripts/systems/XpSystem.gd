extends Node
class_name XpSystem

## Manages XP orb spawning and delegates progression to PlayerProgression autoload.
## XP orbs are spawned when enemies die, and collected XP is forwarded to PlayerProgression.

const XP_ORB_SCENE: PackedScene = preload("res://scenes/arena/XPOrb.tscn")

var _arena_node: Node

func _init(arena: Node) -> void:
	_arena_node = arena

func _ready() -> void:
	print("XpSystem: Initialized as XP orb spawner only (progression handled by PlayerProgression)")
	EventBus.combat_step.connect(_on_combat_step)
	EventBus.enemy_killed.connect(_on_enemy_killed)

func _exit_tree() -> void:
	# Cleanup signal connections
	if EventBus.combat_step.is_connected(_on_combat_step):
		EventBus.combat_step.disconnect(_on_combat_step)
	if EventBus.enemy_killed.is_connected(_on_enemy_killed):
		EventBus.enemy_killed.disconnect(_on_enemy_killed)
	Logger.debug("XpSystem: Cleaned up signal connections", "systems")


func _on_combat_step(_payload) -> void:
	pass

func _on_enemy_killed(payload) -> void:
	print("XpSystem: Enemy killed, spawning XP orb at %s with value %d" % [payload.pos, payload.xp_value])
	_spawn_xp_orb(payload.pos, payload.xp_value)

func _spawn_xp_orb(pos: Vector2, xp_value: int) -> void:
	print("XpSystem: Creating XP orb with value %d at position %s" % [xp_value, pos])
	var orb: XPOrb = XP_ORB_SCENE.instantiate()
	orb.global_position = pos
	orb.xp_value = xp_value
	orb.collected.connect(_on_xp_collected)
	_arena_node.add_child(orb)
	print("XpSystem: XP orb spawned and added to arena")

func _on_xp_collected(amount: int) -> void:
	print("XpSystem: XP orb collected! Amount: %d" % amount)
	# Delegate XP processing to PlayerProgression autoload
	if PlayerProgression:
		print("XpSystem: PlayerProgression found, gaining %d XP" % amount)
		PlayerProgression.gain_exp(float(amount))
		Logger.debug("XpSystem: Forwarded %d XP to PlayerProgression" % amount, "player")
		
		# Update RunManager level for card system compatibility
		RunManager.stats["level"] = PlayerProgression.level
		print("XpSystem: Updated RunManager level to %d" % PlayerProgression.level)
	else:
		print("XpSystem: ERROR - PlayerProgression not available!")
		Logger.warn("PlayerProgression not available, XP collection ignored", "player")
