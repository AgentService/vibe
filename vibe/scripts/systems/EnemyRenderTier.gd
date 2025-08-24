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

func _ready() -> void:
	Logger.info("Enemy render tier system initialized", "enemies")

## Determine the render tier for an enemy based on its type
func get_tier_for_enemy(enemy_data: Dictionary) -> Tier:
	var type_id: String = enemy_data.get("type_id", "unknown")
	
	# Assign tier based on enemy type for proper visual distinction
	match type_id:
		"knight_swarm":
			return Tier.SWARM
		"knight_regular":
			return Tier.REGULAR
		"knight_elite":
			return Tier.ELITE
		"knight_boss":
			return Tier.BOSS
		_:
			# Fallback to size-based assignment
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
		
		Logger.info("Enemy " + type_id + " (size: " + str(enemy_size) + ") assigned to " + get_tier_name(tier) + " tier", "enemies")
		
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
