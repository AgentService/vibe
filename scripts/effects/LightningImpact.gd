## LightningImpact.gd
## Self-despawning impact effect for lightning strikes with enemy tracking.
##
## Lifecycle:
## 1. Spawned at exact impact_position (where damage landed)
## 2. Tracks enemy node each frame to follow fast-moving targets (via BaseTrackedEffect)
## 3. AnimationPlayer plays lightning strike animation
## 4. Auto-despawns after animation completes (~0.4s)
##
## Usage:
##   var lightning = LightningImpact_SCENE.instantiate()
##   arena.add_child(lightning)
##   lightning.global_position = impact_position
##   lightning.track_enemy(enemy_id, arena)  # Enable tracking (inherited from BaseTrackedEffect)
##   lightning.scale = Vector2(3.0, 3.0)
extends "res://scripts/effects/BaseTrackedEffect.gd"

@onready var animation_player: AnimationPlayer = $AnimationPlayer

func _ready() -> void:
	super._ready()  # Call base class if needed

	# AnimationPlayer auto-plays "strike" animation

	# Auto-despawn after animation completes
	if animation_player:
		var anim_length = animation_player.get_animation("strike").length
		await get_tree().create_timer(anim_length + 0.05).timeout
	else:
		# Fallback if AnimationPlayer missing
		await get_tree().create_timer(0.4).timeout

	queue_free()
