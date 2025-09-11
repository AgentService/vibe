extends BaseBoss

## DragonLord special boss - example scene-based enemy
## Demonstrates hybrid spawning system with complex boss behavior
## Now inherits from BaseBoss for unified systems support

class_name DragonLord

func _ready() -> void:
	# Set DragonLord specific stats (override BaseBoss defaults)
	max_health = 300.0  # DragonLord is stronger
	current_health = 300.0
	damage = 35.0
	speed = 80.0
	attack_damage = 35.0
	attack_cooldown = 2.0
	attack_range = 90.0
	chase_range = 400.0
	
	# Call parent _ready() to handle base initialization
	super._ready()

func get_boss_name() -> String:
	return "DragonLord"

# Override parent attack with DragonLord-specific fire attack
func _perform_attack() -> void:
	Logger.debug("DragonLord breathes fire for %.1f damage!" % attack_damage, "bosses")
	
	# Apply fire damage to player via unified DamageService
	var distance_to_player: float = global_position.distance_to(target_position)
	if distance_to_player <= attack_range:
		var source_name = "boss_dragon_lord"
		var damage_tags = ["fire", "boss"]  # Fire damage type
		DamageService.apply_damage("player", attack_damage, source_name, damage_tags)
