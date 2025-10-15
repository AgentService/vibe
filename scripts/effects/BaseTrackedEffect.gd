## BaseTrackedEffect.gd
## Base class for visual effects that can track enemy positions.
##
## Provides optional enemy tracking functionality for effects that need to follow
## moving targets during their animation (lightning strikes, beam effects, etc.).
##
## Usage:
##   extends BaseTrackedEffect
##
##   func _ready() -> void:
##       super._ready()  # Call base class _ready if overridden
##       # Your effect setup here
##
##   # After spawning and positioning:
##   effect.track_enemy(enemy_id, arena)  # Enable tracking
##
## Features:
##   - Frame-accurate position updates (60 FPS visual tracking)
##   - Graceful handling of enemy death (stops tracking, doesn't crash)
##   - Zero overhead when tracking not enabled
##   - Works with any effect that extends this class
extends Node2D

## Enemy tracking state
var _tracking_enemy_id: String = ""
var _arena: Node2D = null
var _enemy_node: Node = null


## Base _ready for child classes to override
func _ready() -> void:
	pass  # Override in child classes if needed


## Enables frame-accurate enemy tracking during effect animation.
## Call this after adding to scene tree and setting initial position.
##
## Parameters:
##   enemy_id: Entity ID of enemy to track
##   arena: Arena reference for finding enemy nodes
##
## Example:
##   var effect = EFFECT_SCENE.instantiate()
##   arena.add_child(effect)
##   effect.global_position = impact_position
##   effect.track_enemy(enemy_id, arena)  # Enable tracking
func track_enemy(enemy_id: String, arena: Node2D) -> void:
	_tracking_enemy_id = enemy_id
	_arena = arena

	# Find enemy node using EffectSpawner helper
	_enemy_node = EffectSpawner.find_enemy_node(enemy_id, arena)

	if not _enemy_node:
		Logger.debug("%s: Cannot track enemy, node not found: %s" % [name, enemy_id], "effects")


## Updates position each frame to follow tracked enemy.
## Override this if you need custom tracking behavior (e.g., offset, interpolation).
func _process(_delta: float) -> void:
	if not _enemy_node or not is_instance_valid(_enemy_node):
		return

	# Follow enemy's global position frame by frame
	global_position = _enemy_node.global_position
