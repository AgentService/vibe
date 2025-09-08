extends Node

## Damage system handling projectile-enemy collision detection.
## Uses circle-circle overlap tests for performance.
## Updates on fixed combat step (30 Hz) for deterministic behavior.

class_name DamageSystem

var ability_system: AbilitySystem
var wave_director: WaveDirector

var projectile_radius: float
var enemy_radius: float
var player_radius: float = 16.0

func _ready() -> void:
	_load_balance_values()
	EventBus.combat_step.connect(_on_combat_step)
	if BalanceDB:
		BalanceDB.balance_reloaded.connect(_load_balance_values)

func _load_balance_values() -> void:
	projectile_radius = BalanceDB.get_combat_value("projectile_radius")
	enemy_radius = BalanceDB.get_combat_value("enemy_radius")
	Logger.info("Reloaded combat balance values", "combat")

func _on_combat_step(_payload) -> void:
	if not ability_system or not wave_director:
		return
	
	_check_projectile_enemy_collisions()
	_check_enemy_player_collisions()

func _check_projectile_enemy_collisions() -> void:
	var alive_projectiles := ability_system._get_alive_projectiles()
	var alive_enemies := wave_director.get_alive_enemies()
	
	for p_idx in range(alive_projectiles.size()):
		var projectile := alive_projectiles[p_idx]
		var proj_pos := projectile["pos"] as Vector2
		
		for e_idx in range(alive_enemies.size()):
			var enemy := alive_enemies[e_idx]
			# Additional safety check - skip if enemy died between getting alive list and now
			if not enemy.alive:
				continue
			var enemy_pos := enemy.pos as Vector2
			
			var distance := proj_pos.distance_to(enemy_pos)
			var collision_distance := projectile_radius + enemy_radius
			
			if distance <= collision_distance:
				_handle_collision(projectile, enemy, p_idx, e_idx)

func _handle_collision(projectile: Dictionary, enemy: EnemyEntity, _proj_idx: int, _enemy_idx: int) -> void:
	# Find the actual pool indices
	var actual_proj_idx := _find_projectile_pool_index(projectile)
	var actual_enemy_idx := _find_enemy_pool_index(enemy)
	
	if actual_proj_idx == -1 or actual_enemy_idx == -1:
		Logger.warn("Failed to find pool indices - proj: " + str(actual_proj_idx) + " enemy: " + str(actual_enemy_idx), "combat")
		return
	
	# Apply damage directly via DamageService
	var base_damage: float = BalanceDB.get_combat_value("base_damage")
	var entity_id = "enemy_" + str(actual_enemy_idx)
	
	# AUTO-REGISTER: Register enemy if not already registered
	if not DamageService.is_entity_alive(entity_id) and not DamageService.get_entity(entity_id).has("id"):
		var entity_data = {
			"id": entity_id,
			"type": "enemy",
			"hp": enemy.hp,
			"max_hp": enemy.hp,
			"alive": true,
			"pos": enemy.pos
		}
		DamageService.register_entity(entity_id, entity_data)
	
	# Kill projectile immediately
	ability_system.projectiles[actual_proj_idx]["alive"] = false
	
	# Apply damage via DamageService
	DamageService.apply_damage(entity_id, base_damage, "projectile", ["projectile", "basic_attack"])

func _find_projectile_pool_index(target_projectile: Dictionary) -> int:
	for i in range(ability_system.projectiles.size()):
		var projectile := ability_system.projectiles[i]
		if projectile["alive"] and projectile["pos"] == target_projectile["pos"]:
			return i
	return -1

func _find_enemy_pool_index(target_enemy: EnemyEntity) -> int:
	for i in range(wave_director.enemies.size()):
		var enemy := wave_director.enemies[i]
		# Use object identity instead of position comparison for reliability
		if enemy == target_enemy and enemy.alive:
			return i
	return -1

func set_references(ability_sys: AbilitySystem, wave_dir: WaveDirector) -> void:
	ability_system = ability_sys
	wave_director = wave_dir

func _exit_tree() -> void:
	# Cleanup signal connections
	EventBus.combat_step.disconnect(_on_combat_step)
	if BalanceDB:
		BalanceDB.balance_reloaded.disconnect(_load_balance_values)

func _check_enemy_player_collisions() -> void:
	var alive_enemies := wave_director.get_alive_enemies()
	var player_pos := PlayerState.position
	
	if player_pos == Vector2.ZERO:
		return  # Player position not set
	
	for enemy in alive_enemies:
		var enemy_pos := enemy.pos as Vector2
		var distance := player_pos.distance_to(enemy_pos)
		var collision_distance := enemy_radius + player_radius
		
		if distance <= collision_distance:
			# Enemy hits player - deal 1 damage
			EventBus.damage_taken.emit(1)
			break  # Only one damage per frame

# Old damage_requested handler removed - replaced by DamageService
# Projectile collision damage now handled directly via DamageService.apply_damage()
