extends RefCounted

## Payload for damage_dealt signal - damage events for camera shake and item procs.
## Provides compile-time type safety for visual feedback coordination and effect spawning.
##
## Position Fields (Added 2025-10-13 for Item System):
##   source_position: Where damage ORIGINATED (player position, ability spawn point)
##     - Use for: Knockback direction, damage lines, player-centric effects
##   impact_position: Where damage LANDED (enemy position at hit)
##     - Use for: Item proc spawning (lightning, explosions, poison clouds)

class_name DamageDealtPayload

var damage: float
var source: String
var target: String
var source_position: Vector2  ## Player/ability origin (for knockback, etc.)
var impact_position: Vector2  ## Enemy hit location (for item effects)

func _init(dealt_damage: float, damage_source: String, damage_target: String,
           src_pos: Vector2 = Vector2.ZERO, impact_pos: Vector2 = Vector2.ZERO) -> void:
	damage = dealt_damage
	source = damage_source
	target = damage_target
	source_position = src_pos
	impact_position = impact_pos

func _to_string() -> String:
	return "DamageDealtPayload(damage=%s, source=%s, target=%s, src_pos=%s, impact_pos=%s)" % [
		damage, source, target, source_position, impact_position
	]