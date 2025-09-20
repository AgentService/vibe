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

# Event-specific properties (for breach, ritual, etc.)
var context_tags: Array[String] = []
var modulate: Color = Color.WHITE


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
	context_tags = []
	modulate = Color.WHITE

## Convert to legacy EnemyType for existing systems (temporary compatibility)
func to_enemy_type() -> EnemyType:
	var enemy_type: EnemyType = EnemyType.new()
	enemy_type.id = str(template_id)
	enemy_type.health = health
	enemy_type.speed = speed
	enemy_type.speed_min = speed * 0.9  # Add some variance for legacy compatibility
	enemy_type.speed_max = speed * 1.1
	enemy_type.size = Vector2(24.0 * size_scale, 24.0 * size_scale)
	enemy_type.collision_radius = 12.0 * size_scale
	enemy_type.xp_value = 1  # Default XP value
	enemy_type.spawn_weight = 1.0
	enemy_type.render_tier = render_tier
	
	# Set visual config with color
	enemy_type.visual_config = {
		"color": {
			"r": color_tint.r,
			"g": color_tint.g, 
			"b": color_tint.b,
			"a": color_tint.a
		},
		"shape": "square"  # Default shape
	}
	
	
	return enemy_type

## Debug string representation - renamed to avoid Object.to_string() override
func debug_string() -> String:
	var tags_str = ", tags=" + str(context_tags) if context_tags.size() > 0 else ""
	return "SpawnConfig[%s]: HP=%.1f DMG=%.1f SPD=%.1f Scale=%.2f Color=%s%s" % [
		template_id, health, damage, speed, size_scale, color_tint, tags_str
	]
