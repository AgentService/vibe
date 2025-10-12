extends Node

## Enemy Animation System - Archived
## MultiMesh animation system no longer needed - scene-based enemies handle their own animations

class_name EnemyAnimationSystem

# DEPRECATED: This system is no longer used
# Scene-based enemies handle their own animations through AnimationPlayer nodes

func setup(_unused_refs: Dictionary = {}) -> void:
	Logger.info("EnemyAnimationSystem: Scene-based enemies handle their own animations", "animations")

func animate_frames(_delta: float) -> void:
	# No longer needed - scene-based enemies self-animate
	pass
