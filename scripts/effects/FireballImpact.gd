## FireballImpact.gd
## Self-despawning impact effect for fireball explosions.
##
## Lifecycle:
## 1. Spawned at impact position
## 2. set_aoe_radius() scales effect to match AoE size
## 3. AnimationPlayer plays impact animation
## 4. Auto-despawns after animation completes (~0.5s)
##
## Scale Calculation:
## - Base reference: 350px radius = scale 10.0
## - Formula: scale = (radius / BASE_RADIUS) * BASE_SCALE
## - Example: 500px radius = (500 / 350) * 10 = 14.29 scale
extends Node2D

@onready var animation_player: AnimationPlayer = $AnimationPlayer

## Base reference for scale calculation
## 350px AoE radius = 700px diameter. 32px sprite needs 21.875 scale to match diameter.
## Formula: (radius × 2) / sprite_size = (350 × 2) / 32 = 21.875
const BASE_RADIUS: float = 350.0
const BASE_SCALE: float = 21.875

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

## Sets the visual scale based on AoE radius
## Call this immediately after instantiation to match impact size to gameplay AoE
func set_aoe_radius(radius: float) -> void:
	if radius <= 0.0:
		return

	# Calculate proportional scale based on radius
	var target_scale = (radius / BASE_RADIUS) * BASE_SCALE
	scale = Vector2(target_scale, target_scale)
