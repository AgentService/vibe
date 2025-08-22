extends Node

## Enemy render tier system for organizing enemies into visual hierarchies.
## Routes enemies to appropriate MultiMesh layers based on their characteristics.

class_name EnemyRenderTier

enum Tier {
	SWARM = 0,      # 90% of enemies (small, fast) - MultiMesh
	REGULAR = 1,    # 8% of enemies (medium) - MultiMesh  
	ELITE = 2,      # 2% of enemies (large) - MultiMesh
	BOSS = 3        # <1% of enemies (animated) - Individual sprites
}

# Tier thresholds based on enemy size
const SWARM_MAX_SIZE: float = 24.0
const REGULAR_MAX_SIZE: float = 48.0
const ELITE_MAX_SIZE: float = 64.0

# Cached tier configuration
var _tier_config: Dictionary = {}

func _ready() -> void:
	Logger.info("EnemyRenderTier._ready() starting", "enemies")
	_load_tier_config()
	if BalanceDB:
		BalanceDB.balance_reloaded.connect(_on_balance_reloaded)
	Logger.info("Enemy render tier system initialized", "enemies")

func _on_balance_reloaded() -> void:
	_load_tier_config()
	Logger.info("Reloaded enemy tier configuration", "enemies")

func _load_tier_config() -> void:
	var config_path: String = "res://vibe/data/enemies/enemy_tiers.json"
	var file: FileAccess = FileAccess.open(config_path, FileAccess.READ)
	
	if file == null:
		Logger.warn("Could not load tier config: " + config_path + ", using defaults", "enemies")
		_use_default_config()
		return
	
	var json_text: String = file.get_as_text()
	file.close()
	
	var json: JSON = JSON.new()
	var parse_result: Error = json.parse(json_text)
	
	if parse_result != OK:
		Logger.warn("Failed to parse tier config JSON: " + json.get_error_message(), "enemies")
		_use_default_config()
		return
	
	_tier_config = json.data
	Logger.info("Loaded enemy tier configuration", "enemies")

func _use_default_config() -> void:
	_tier_config = {
		"tiers": {
			"swarm": {
				"name": "SWARM",
				"description": "Small, fast enemies rendered in bulk",
				"max_size": 24,
				"max_speed": 120,
				"render_method": "multimesh"
			},
			"regular": {
				"name": "REGULAR", 
				"description": "Medium enemies with basic animations",
				"max_size": 48,
				"max_speed": 80,
				"render_method": "multimesh"
			},
			"elite": {
				"name": "ELITE",
				"description": "Large enemies with special effects",
				"max_size": 64,
				"max_speed": 60,
				"render_method": "multimesh"
			},
			"boss": {
				"name": "BOSS",
				"description": "Unique enemies with individual rendering",
				"min_size": 80,
				"render_method": "individual_sprite"
			}
		}
	}

## Determine the render tier for an enemy based on its size
func get_tier_for_enemy(enemy_data: Dictionary) -> Tier:
	var enemy_size: Vector2 = enemy_data.get("size", Vector2(24, 24))
	var max_dimension: float = max(enemy_size.x, enemy_size.y)
	
	if max_dimension <= SWARM_MAX_SIZE:
		return Tier.SWARM
	elif max_dimension <= REGULAR_MAX_SIZE:
		return Tier.REGULAR
	elif max_dimension <= ELITE_MAX_SIZE:
		return Tier.ELITE
	else:
		return Tier.BOSS

## Get the string name for a tier
func get_tier_name(tier: Tier) -> String:
	match tier:
		Tier.SWARM:
			return "SWARM"
		Tier.REGULAR:
			return "REGULAR"
		Tier.ELITE:
			return "ELITE"
		Tier.BOSS:
			return "BOSS"
		_:
			return "UNKNOWN"

## Check if a tier should use MultiMesh rendering
func should_use_multimesh(tier: Tier) -> bool:
	return tier != Tier.BOSS

## Get tier configuration data
func get_tier_config(tier: Tier) -> Dictionary:
	var tier_name: String = get_tier_name(tier).to_lower()
	return _tier_config.get("tiers", {}).get(tier_name, {})

## Validate that the tier system is properly configured
func validate_configuration() -> Array[String]:
	var errors: Array[String] = []
	
	if not _tier_config.has("tiers"):
		errors.append("Missing 'tiers' section in configuration")
		return errors
	
	var tiers: Dictionary = _tier_config["tiers"]
	var required_tiers: Array[String] = ["swarm", "regular", "elite", "boss"]
	
	for tier_name in required_tiers:
		if not tiers.has(tier_name):
			errors.append("Missing tier configuration: " + tier_name)
			continue
		
		var tier_data: Dictionary = tiers[tier_name]
		if not tier_data.has("render_method"):
			errors.append("Missing render_method for tier: " + tier_name)
	
	return errors

## Get all enemies grouped by tier
func group_enemies_by_tier(enemies: Array[Dictionary]) -> Dictionary:
	var swarm_enemies: Array[Dictionary] = []
	var regular_enemies: Array[Dictionary] = []
	var elite_enemies: Array[Dictionary] = []
	var boss_enemies: Array[Dictionary] = []
	
	for enemy in enemies:
		var tier: Tier = get_tier_for_enemy(enemy)
		var enemy_size: Vector2 = enemy.get("size", Vector2(24, 24))
		var type_id: String = enemy.get("type_id", "unknown")
		
		Logger.debug("Enemy " + type_id + " (size: " + str(enemy_size) + ") assigned to " + get_tier_name(tier) + " tier", "enemies")
		
		match tier:
			Tier.SWARM:
				swarm_enemies.append(enemy)
			Tier.REGULAR:
				regular_enemies.append(enemy)
			Tier.ELITE:
				elite_enemies.append(enemy)
			Tier.BOSS:
				boss_enemies.append(enemy)
	
	var total_enemies: int = enemies.size()
	Logger.debug("Tier distribution: SWARM=" + str(swarm_enemies.size()) + ", REGULAR=" + str(regular_enemies.size()) + ", ELITE=" + str(elite_enemies.size()) + ", BOSS=" + str(boss_enemies.size()) + " (total: " + str(total_enemies) + ")", "enemies")
	
	return {
		Tier.SWARM: swarm_enemies,
		Tier.REGULAR: regular_enemies,
		Tier.ELITE: elite_enemies,
		Tier.BOSS: boss_enemies
	}
