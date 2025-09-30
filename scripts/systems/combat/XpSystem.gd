extends Node
class_name XpSystem

## Manages XP orb spawning and delegates progression to PlayerProgression autoload.
## XP orbs are spawned when enemies die, and collected XP is forwarded to PlayerProgression.

const XP_ORB_SCENE: PackedScene = preload("res://scenes/arena/XPOrb.tscn")

var _arena_node: Node

func _init(arena: Node) -> void:
	_arena_node = arena

## Update the arena reference (used during scene transitions)
func update_arena_reference(arena: Node) -> void:
	if not arena or not is_instance_valid(arena):
		Logger.error("XpSystem: Cannot update with invalid arena reference", "progression")
		return
	
	_arena_node = arena
	Logger.info("XpSystem: Arena reference updated successfully", "progression")

func _ready() -> void:
	# Initialized as XP orb spawner only (progression handled by PlayerProgression)
	Logger.info("XpSystem: Initializing and connecting to EventBus signals", "progression")
	EventBus.combat_step.connect(_on_combat_step)
	EventBus.enemy_killed.connect(_on_enemy_killed)
	Logger.info("XpSystem: Successfully connected to enemy_killed signal", "progression")

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
	
	# Defensive checks to prevent freed instance errors
	if not _arena_node or not is_instance_valid(_arena_node):
		Logger.error("XpSystem: Arena node is invalid, cannot spawn XP orb", "progression")
		return
	
	if not XP_ORB_SCENE:
		Logger.error("XpSystem: XP_ORB_SCENE is null, cannot spawn XP orb", "progression")
		return
		
	var orb: XPOrb = XP_ORB_SCENE.instantiate()
	if not orb:
		Logger.error("XpSystem: Failed to instantiate XP orb", "progression")
		return
		
	orb.global_position = pos
	orb.xp_value = xp_value
	orb.collected.connect(_on_xp_collected)
	ClearingSemantics.add_semantic_group(orb, ClearingSemantics.CLEAR_WITH_TRANSIENTS)  # Auto-register for cleanup by EntityClearingService
	_arena_node.add_child(orb)

func _on_xp_collected(amount: int) -> void:
	# XP orb collected
	Logger.info("XpSystem: XP orb collected - %d XP" % amount, "progression")
	# Delegate XP processing to PlayerProgression autoload
	if PlayerProgression:
		PlayerProgression.gain_exp(float(amount))
		
		# Update RunManager level for card system compatibility
		RunManager.stats["level"] = PlayerProgression.level
	else:
		Logger.error("XpSystem: PlayerProgression not available, XP collection ignored!", "progression")
		pass
