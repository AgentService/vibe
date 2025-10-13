## LightningImpact.gd
## Self-despawning impact effect for lightning strikes.
##
## Lifecycle:
## 1. Spawned at strike position (enemy location)
## 2. AnimationPlayer plays lightning strike animation
## 3. Auto-despawns after animation completes (~0.4s)
##
## Usage:
##   var lightning = LightningImpact_SCENE.instantiate()
##   arena.add_child(lightning)
##   lightning.global_position = enemy_position
##   lightning.scale = Vector2(0.3, 0.3)  # Smaller for item procs
extends Node2D

@onready var animation_player: AnimationPlayer = $AnimationPlayer

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
