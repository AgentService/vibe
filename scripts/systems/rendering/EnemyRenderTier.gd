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

# PHASE B: Pre-allocated arrays for light grouping to eliminate per-frame allocations
var _swarm_enemies_light: Array[EnemyEntity] = []
var _regular_enemies_light: Array[EnemyEntity] = []
var _elite_enemies_light: Array[EnemyEntity] = []
var _boss_enemies_light: Array[EnemyEntity] = []


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

## PHASE B: Light grouping API that avoids per-frame allocations
## Returns Dictionary[Tier, Array[EnemyEntity]] using preallocated arrays
func group_enemies_by_tier_light(alive_enemies: Array[EnemyEntity]) -> Dictionary:
	# Clear preallocated arrays (reuse instead of recreate)
	_swarm_enemies_light.clear()
	_regular_enemies_light.clear()
	_elite_enemies_light.clear()
	_boss_enemies_light.clear()
	
	# Get tier from enemy template via EnemyFactory (same logic as original)
	const EnemyFactoryScript := preload("res://scripts/systems/enemy_v2/EnemyFactory.gd")
	
	for enemy in alive_enemies:
		var tier: Tier = Tier.REGULAR  # Default tier
		
		# Get render tier from EnemyTemplate via the enemy's type_id
		if not enemy.type_id.is_empty():
			var template: EnemyTemplate = EnemyFactoryScript.get_template(enemy.type_id)
			if template != null:
				match template.render_tier:
					"swarm":
						tier = Tier.SWARM
					"regular":
						tier = Tier.REGULAR
					"elite":
						tier = Tier.ELITE
					"boss":
						tier = Tier.BOSS
					_:
						tier = Tier.REGULAR
		
		# Add EnemyEntity directly to preallocated arrays (no to_dictionary() call)
		match tier:
			Tier.SWARM:
				_swarm_enemies_light.append(enemy)
			Tier.REGULAR:
				_regular_enemies_light.append(enemy)
			Tier.ELITE:
				_elite_enemies_light.append(enemy)
			Tier.BOSS:
				_boss_enemies_light.append(enemy)
	
	return {
		Tier.SWARM: _swarm_enemies_light,
		Tier.REGULAR: _regular_enemies_light,
		Tier.ELITE: _elite_enemies_light,
		Tier.BOSS: _boss_enemies_light
	}

## Get all enemy instances grouped by tier (for Arena.gd)
func group_enemies_by_tier(alive_enemies: Array[EnemyEntity]) -> Dictionary:
	var swarm_enemies: Array[Dictionary] = []
	var regular_enemies: Array[Dictionary] = []
	var elite_enemies: Array[Dictionary] = []
	var boss_enemies: Array[Dictionary] = []
	
	# V2 system: get tier from enemy template via EnemyFactory
	const EnemyFactoryScript := preload("res://scripts/systems/enemy_v2/EnemyFactory.gd")
	
	for enemy in alive_enemies:
		var tier: Tier = Tier.REGULAR  # Default tier
		
		# Get render tier from EnemyTemplate via the enemy's type_id
		if not enemy.type_id.is_empty():
			var template: EnemyTemplate = EnemyFactoryScript.get_template(enemy.type_id)
			if template != null:
				match template.render_tier:
					"swarm":
						tier = Tier.SWARM
					"regular":
						tier = Tier.REGULAR
					"elite":
						tier = Tier.ELITE
					"boss":
						tier = Tier.BOSS
					_:
						tier = Tier.REGULAR
		
		var enemy_dict: Dictionary = enemy.to_dictionary()
		
		match tier:
			Tier.SWARM:
				swarm_enemies.append(enemy_dict)
			Tier.REGULAR:
				regular_enemies.append(enemy_dict)
			Tier.ELITE:
				elite_enemies.append(enemy_dict)
			Tier.BOSS:
				boss_enemies.append(enemy_dict)
	
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
	if Logger.is_level_enabled(Logger.LogLevel.DEBUG):
		Logger.debug("Tier distribution: SWARM=" + str(swarm_types.size()) + ", REGULAR=" + str(regular_types.size()) + ", ELITE=" + str(elite_types.size()) + ", BOSS=" + str(boss_types.size()) + " (total: " + str(total_types) + ")", "enemies")
	
	return {
		Tier.SWARM: swarm_types,
		Tier.REGULAR: regular_types,
		Tier.ELITE: elite_types,
		Tier.BOSS: boss_types
	}
