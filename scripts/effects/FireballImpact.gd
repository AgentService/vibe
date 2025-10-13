## FireballImpact.gd
## Self-despawning impact effect for fireball explosions.
##
## Lifecycle:
## 1. Spawned at impact position
## 2. AnimationPlayer plays expanding shockwave effect
## 3. Auto-despawns after animation completes (~0.5s)
extends Node2D

@onready var animation_player: AnimationPlayer = $AnimationPlayer

func _ready() -> void:
	# AnimationPlayer auto-plays "explode" animation

	# Auto-despawn after animation completes
	if animation_player:
		var anim_length = animation_player.get_animation("explode").length
		await get_tree().create_timer(anim_length + 0.05).timeout
	else:
		# Fallback if AnimationPlayer missing
		await get_tree().create_timer(0.5).timeout

	queue_free()
