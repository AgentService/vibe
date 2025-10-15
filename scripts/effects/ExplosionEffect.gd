## ExplosionEffect.gd
## Generic self-despawning explosion effect with dynamic scaling and optional tracking.
##
## Used by: FireballImpact, VoodooDollExplosion, PoisonExplosion, and other explosion variants.
##
## Lifecycle:
## 1. Spawned at impact position
## 2. set_aoe_radius() scales effect to match gameplay AoE radius
## 3. Optional: track_enemy() enables position following (via BaseTrackedEffect)
## 4. AnimationPlayer plays impact animation
## 5. Auto-despawns after animation completes (~0.5s)
##
## Scale Calculation (Calibrated for Item Procs):
## - Base reference: 100px radius = scale 2.0 (standard item proc size)
## - Formula: scale = (radius / BASE_RADIUS) * BASE_SCALE
## - Examples: radius=50 → scale=1.0, radius=100 → scale=2.0, radius=200 → scale=4.0
##
## Usage:
##   var explosion = EXPLOSION_SCENE.instantiate()
##   arena.add_child(explosion)
##   explosion.global_position = impact_position
##   explosion.set_aoe_radius(100.0)  # Match gameplay AoE radius
##   explosion.track_enemy(enemy_id, arena)  # Optional: follow enemy
extends "res://scripts/effects/BaseTrackedEffect.gd"

@onready var animation_player: AnimationPlayer = $AnimationPlayer

## Base reference for scale calculation (calibrated for item proc explosions)
## 100px radius (typical item proc) → scale 4.0 (comfortable visual size)
## Formula: scale = (radius / BASE_RADIUS) * BASE_SCALE
## Examples:
##   - radius=50  → scale=2.0 (small explosion)
##   - radius=100 → scale=4.0 (standard item proc)
##   - radius=200 → scale=8.0 (large explosion)
const BASE_RADIUS: float = 100.0
const BASE_SCALE: float = 2.0

func _ready() -> void:
	super._ready()  # Call base class if needed

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
