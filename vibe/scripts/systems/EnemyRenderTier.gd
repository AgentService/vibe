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


func _ready() -> void:
	Logger.info("Enemy render tier system initialized", "enemies")

## Determine the render tier for an enemy based on its EnemyType resource
func get_tier_for_enemy(enemy_type: EnemyType) -> Tier:
	if not enemy_type:
		Logger.error("get_tier_for_enemy called with null enemy_type", "enemies")
		return Tier.REGULAR
	
	# Use the render_tier property from the EnemyType resource
	match enemy_type.render_tier:
		"swarm":
			return Tier.SWARM
		"regular":
			return Tier.REGULAR
		"elite":
			return Tier.ELITE
		"boss":
			return Tier.BOSS
		_:
			Logger.warn("Unknown render_tier '" + enemy_type.render_tier + "' for enemy " + enemy_type.id + ", defaulting to REGULAR", "enemies")
			return Tier.REGULAR

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


## Get all enemy instances grouped by tier (for Arena.gd)
func group_enemies_by_tier(alive_enemies: Array[Dictionary], enemy_registry: EnemyRegistry) -> Dictionary:
	var swarm_enemies: Array[Dictionary] = []
	var regular_enemies: Array[Dictionary] = []
	var elite_enemies: Array[Dictionary] = []
	var boss_enemies: Array[Dictionary] = []
	
	if not enemy_registry:
		Logger.warn("EnemyRegistry not provided, cannot determine tiers", "enemies")
		return {
			Tier.SWARM: swarm_enemies,
			Tier.REGULAR: regular_enemies,
			Tier.ELITE: elite_enemies,
			Tier.BOSS: boss_enemies
		}
	
	for enemy in alive_enemies:
		var type_id: String = enemy.get("type_id", "")
		if type_id.is_empty():
			Logger.warn("Enemy instance missing type_id, defaulting to REGULAR tier", "enemies")
			regular_enemies.append(enemy)
			continue
		
		var enemy_type: EnemyType = enemy_registry.get_enemy_type(type_id)
		if not enemy_type:
			Logger.warn("Enemy type not found for ID: " + type_id + ", defaulting to REGULAR tier", "enemies")
			regular_enemies.append(enemy)
			continue
		
		var tier: Tier = get_tier_for_enemy(enemy_type)
		
		match tier:
			Tier.SWARM:
				swarm_enemies.append(enemy)
			Tier.REGULAR:
				regular_enemies.append(enemy)
			Tier.ELITE:
				elite_enemies.append(enemy)
			Tier.BOSS:
				boss_enemies.append(enemy)
	
	return {
		Tier.SWARM: swarm_enemies,
		Tier.REGULAR: regular_enemies,
		Tier.ELITE: elite_enemies,
		Tier.BOSS: boss_enemies
	}

## Get all enemy types grouped by tier (for EnemyRegistry)
func group_enemy_types_by_tier(enemy_types: Array[EnemyType]) -> Dictionary:
	var swarm_types: Array[EnemyType] = []
	var regular_types: Array[EnemyType] = []
	var elite_types: Array[EnemyType] = []
	var boss_types: Array[EnemyType] = []
	
	for enemy_type in enemy_types:
		var tier: Tier = get_tier_for_enemy(enemy_type)
		
		Logger.info("Enemy " + enemy_type.id + " assigned to " + get_tier_name(tier) + " tier", "enemies")
		
		match tier:
			Tier.SWARM:
				swarm_types.append(enemy_type)
			Tier.REGULAR:
				regular_types.append(enemy_type)
			Tier.ELITE:
				elite_types.append(enemy_type)
			Tier.BOSS:
				boss_types.append(enemy_type)
	
	var total_types: int = enemy_types.size()
	Logger.debug("Tier distribution: SWARM=" + str(swarm_types.size()) + ", REGULAR=" + str(regular_types.size()) + ", ELITE=" + str(elite_types.size()) + ", BOSS=" + str(boss_types.size()) + " (total: " + str(total_types) + ")", "enemies")
	
	return {
		Tier.SWARM: swarm_types,
		Tier.REGULAR: regular_types,
		Tier.ELITE: elite_types,
		Tier.BOSS: boss_types
	}
