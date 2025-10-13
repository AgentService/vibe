## LightningImpact.gd
## Self-despawning impact effect for lightning strikes with enemy tracking.
##
## Lifecycle:
## 1. Spawned at exact impact_position (where damage landed)
## 2. Tracks enemy node each frame to follow fast-moving targets
## 3. AnimationPlayer plays lightning strike animation
## 4. Auto-despawns after animation completes (~0.4s)
##
## Usage:
##   var lightning = LightningImpact_SCENE.instantiate()
##   arena.add_child(lightning)
##   lightning.global_position = impact_position
##   lightning.track_enemy(enemy_id, arena)  # Enable tracking
##   lightning.scale = Vector2(3.0, 3.0)
extends Node2D

@onready var animation_player: AnimationPlayer = $AnimationPlayer

## Enemy tracking state
var _tracking_enemy_id: String = ""
var _arena: Node2D = null
var _enemy_node: Node = null

func _ready() -> void:
	# AnimationPlayer auto-plays "strike" animation

	# Auto-despawn after animation completes
	if animation_player:
		var anim_length = animation_player.get_animation("strike").length
		await get_tree().create_timer(anim_length + 0.05).timeout
	else:
		# Fallback if AnimationPlayer missing
		await get_tree().create_timer(0.4).timeout

	queue_free()


## Enables frame-accurate enemy tracking during animation.
## Call this after adding to scene tree and setting initial position.
##
## Parameters:
##   enemy_id: Entity ID of enemy to track
##   arena: Arena reference for finding enemy nodes
func track_enemy(enemy_id: String, arena: Node2D) -> void:
	_tracking_enemy_id = enemy_id
	_arena = arena

	# Find enemy node for tracking
	_enemy_node = _find_enemy_node(enemy_id)

	if not _enemy_node:
		Logger.debug("LightningImpact: Cannot track enemy, node not found: %s" % enemy_id, "effects")


## Updates position each frame to follow tracked enemy
func _process(_delta: float) -> void:
	if not _enemy_node or not is_instance_valid(_enemy_node):
		return

	# Follow enemy's global position frame by frame
	global_position = _enemy_node.global_position


## Finds enemy node in scene tree by entity_id
func _find_enemy_node(entity_id: String) -> Node:
	if not _arena:
		return null

	# Search for enemy in "enemies" group
	var enemies := _arena.get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if "entity_id" in enemy and enemy.entity_id == entity_id:
			return enemy

	return null
