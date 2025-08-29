extends RefCounted

## SpawnConfig holds finalized enemy spawn data produced by EnemyFactory.
## Contains deterministic stats, visuals, and metadata for pooled enemy spawning.
## This bridges the V2 template system with existing pooling/rendering.

class_name SpawnConfig

# Finalized numeric stats
var health: float
var damage: float
var speed: float

# Visual properties
var color_tint: Color
var size_scale: float

# Template metadata
var template_id: StringName
var tags: Array[StringName]
var render_tier: String

# Compatibility with existing EnemyEntity system
var position: Vector2
var velocity: Vector2

# Stable entity ID for DamageService registration (replaces get_instance_id())
var entity_id: String = ""

func _init(p_health: float = 10.0, p_damage: float = 5.0, p_speed: float = 60.0) -> void:
	health = p_health
	damage = p_damage
	speed = p_speed
	color_tint = Color.WHITE
	size_scale = 1.0
	template_id = ""
	tags = []
	render_tier = "regular"
	position = Vector2.ZERO
	velocity = Vector2.ZERO
	entity_id = ""


## Get stable entity ID for DamageService registration
func get_entity_id() -> String:
	return entity_id

## Set stable entity ID (called by spawner systems)
func set_entity_id(id: String) -> void:
	entity_id = id

## Debug string representation - renamed to avoid Object.to_string() override
func debug_string() -> String:
	return "SpawnConfig[%s|%s]: HP=%.1f DMG=%.1f SPD=%.1f Scale=%.2f Color=%s" % [
		template_id, entity_id, health, damage, speed, size_scale, color_tint
	]
