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
	EventBus.damage_requested.connect(_on_damage_requested)
	if BalanceDB:
		BalanceDB.balance_reloaded.connect(_load_balance_values)

func _load_balance_values() -> void:
	projectile_radius = BalanceDB.get_combat_value("projectile_radius")
	enemy_radius = BalanceDB.get_combat_value("enemy_radius")
	Logger.info("Reloaded combat balance values", "combat")

func _on_combat_step(payload) -> void:
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
			var enemy_pos := enemy["pos"] as Vector2
			
			var distance := proj_pos.distance_to(enemy_pos)
			var collision_distance := projectile_radius + enemy_radius
			
			if distance <= collision_distance:
				_handle_collision(projectile, enemy, p_idx, e_idx)

func _handle_collision(projectile: Dictionary, enemy: Dictionary, proj_idx: int, enemy_idx: int) -> void:
	# Find the actual pool indices
	var actual_proj_idx := _find_projectile_pool_index(projectile)
	var actual_enemy_idx := _find_enemy_pool_index(enemy)
	
	if actual_proj_idx == -1 or actual_enemy_idx == -1:
		Logger.warn("Failed to find pool indices - proj: " + str(actual_proj_idx) + " enemy: " + str(actual_enemy_idx), "combat")
		return
	
	# Request damage calculation
	var source_id := EntityId.projectile(actual_proj_idx)
	var target_id := EntityId.enemy(actual_enemy_idx)
	var base_damage: float = BalanceDB.get_combat_value("base_damage")
	var tags := PackedStringArray(["projectile", "basic_attack"])
	
	# Kill projectile immediately
	ability_system.projectiles[actual_proj_idx]["alive"] = false
	
	# Emit damage request
	var damage_payload := EventBus.DamageRequestPayload.new(source_id, target_id, base_damage, tags)
	EventBus.damage_requested.emit(damage_payload)

func _find_projectile_pool_index(target_projectile: Dictionary) -> int:
	for i in range(ability_system.projectiles.size()):
		var projectile := ability_system.projectiles[i]
		if projectile["alive"] and projectile["pos"] == target_projectile["pos"]:
			return i
	return -1

func _find_enemy_pool_index(target_enemy: Dictionary) -> int:
	for i in range(wave_director.enemies.size()):
		var enemy := wave_director.enemies[i]
		if enemy["alive"] and enemy["pos"] == target_enemy["pos"]:
			return i
	return -1

func set_references(ability_sys: AbilitySystem, wave_dir: WaveDirector) -> void:
	ability_system = ability_sys
	wave_director = wave_dir

func _exit_tree() -> void:
	# Cleanup signal connections
	EventBus.combat_step.disconnect(_on_combat_step)
	EventBus.damage_requested.disconnect(_on_damage_requested)
	if BalanceDB:
		BalanceDB.balance_reloaded.disconnect(_load_balance_values)

func _check_enemy_player_collisions() -> void:
	var alive_enemies := wave_director.get_alive_enemies()
	var player_pos := PlayerState.position
	
	if player_pos == Vector2.ZERO:
		return  # Player position not set
	
	for enemy in alive_enemies:
		var enemy_pos := enemy["pos"] as Vector2
		var distance := player_pos.distance_to(enemy_pos)
		var collision_distance := enemy_radius + player_radius
		
		if distance <= collision_distance:
			# Enemy hits player - deal 1 damage
			EventBus.damage_taken.emit(1)
			break  # Only one damage per frame

func _on_damage_requested(payload) -> void:
	if payload.target_id.type != EntityId.Type.ENEMY:
		return
	
	# Calculate final damage (add crit, modifiers, etc. here)
	var is_crit: bool = RNG.randf("crit") < 0.1  # 10% crit chance
	var final_damage: float = payload.base_damage * (2.0 if is_crit else 1.0)
	
	
	# Apply damage to enemy
	wave_director.damage_enemy(payload.target_id.index, final_damage)
	
	# Get enemy info for detailed logging
	var enemy_info = "unknown"
	if wave_director and payload.target_id.index < wave_director.enemies.size():
		var enemy = wave_director.enemies[payload.target_id.index]
		enemy_info = "%s (hp: %.1f)" % [enemy.get("type_id", "unknown"), enemy.get("hp", 0)]
	
	# Log damage for verification
	Logger.info("DAMAGE APPLIED: Enemy[%d] %s took %.1f damage%s" % [payload.target_id.index, enemy_info, final_damage, " (CRIT!)" if is_crit else ""], "combat")
	
	# Emit damage applied signal
	var applied_payload := EventBus.DamageAppliedPayload.new(payload.target_id, final_damage, is_crit, payload.tags)
	EventBus.damage_applied.emit(applied_payload)
