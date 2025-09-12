extends BaseBoss

## Test Boss - Demonstrates shadow system integration with BaseBoss
## Simple boss for testing shadow functionality

class_name TestShadowBoss

func _ready() -> void:
	# Set custom boss stats (override BaseBoss defaults)
	max_health = 150.0
	current_health = 150.0
	damage = 20.0
	speed = 40.0
	attack_damage = 20.0
	attack_cooldown = 2.5
	attack_range = 70.0
	chase_range = 250.0
	
	# Shadow configured directly in scene tree - see BossShadow node in Inspector
	
	# Call parent _ready() to handle all base initialization
	super._ready()

func get_boss_name() -> String:
	return "TestShadowBoss"

# Required: Implement boss's attack behavior
func _perform_attack() -> void:
	Logger.debug("TestShadowBoss attacks for %.1f damage!" % attack_damage, "bosses")
	
	# Apply damage to player via unified DamageService
	var distance_to_player: float = global_position.distance_to(target_position)
	if distance_to_player <= attack_range:
		var source_name = "boss_test_shadow"
		var damage_tags = ["physical", "boss", "test"]
		DamageService.apply_damage("player", attack_damage, source_name, damage_tags)
