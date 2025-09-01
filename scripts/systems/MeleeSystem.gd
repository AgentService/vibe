extends Node

## Melee attack system managing cone-shaped AOE attacks.
## Updates on fixed combat step (30 Hz) for deterministic behavior.

class_name MeleeSystem

var attack_cooldown: float = 0.0
var is_attacking: bool = false
var attack_duration: float = 0.2  # Visual attack duration

# Auto-attack system
var auto_attack_enabled: bool = true  # Enabled by default
var auto_attack_target: Vector2 = Vector2.ZERO

# Balance values loaded from JSON
var damage: float
var attack_range: float
var cone_angle: float  # In degrees
var attack_speed: float  # Attacks per second
var knockback_distance: float

# Attack effects tracking
var attack_effects: Array[Dictionary] = []
var max_attack_effects: int = 10

signal melee_attack_started(player_pos: Vector2, target_pos: Vector2)
signal enemies_hit(hit_enemies: Array[Dictionary])

func _ready() -> void:
	_load_balance_values()
	EventBus.combat_step.connect(_on_combat_step)
	_initialize_attack_effects_pool()
	if BalanceDB:
		BalanceDB.balance_reloaded.connect(_on_balance_reloaded)

func _load_balance_values() -> void:
	damage = BalanceDB.get_melee_value("damage")
	attack_range = BalanceDB.get_melee_value("range")
	cone_angle = BalanceDB.get_melee_value("cone_angle")
	attack_speed = BalanceDB.get_melee_value("attack_speed")
	knockback_distance = BalanceDB.get_melee_value("knockback_distance")

func _exit_tree() -> void:
	# Cleanup signal connections
	if EventBus.combat_step.is_connected(_on_combat_step):
		EventBus.combat_step.disconnect(_on_combat_step)
	if BalanceDB and BalanceDB.balance_reloaded.is_connected(_on_balance_reloaded):
		BalanceDB.balance_reloaded.disconnect(_on_balance_reloaded)
	Logger.debug("MeleeSystem: Cleaned up signal connections", "systems")

func _on_balance_reloaded() -> void:
	_load_balance_values()
	Logger.info("Reloaded melee balance values", "abilities")

func _initialize_attack_effects_pool() -> void:
	attack_effects.resize(max_attack_effects)
	for i in range(max_attack_effects):
		attack_effects[i] = {
			"pos": Vector2.ZERO,
			"target_pos": Vector2.ZERO,
			"ttl": 0.0,
			"alive": false
		}

func _on_combat_step(payload) -> void:
	_update_cooldown(payload.dt)
	_update_attack_effects(payload.dt)
	_handle_auto_attack()

func _update_cooldown(dt: float) -> void:
	if attack_cooldown > 0.0:
		attack_cooldown -= dt

func _update_attack_effects(dt: float) -> void:
	for effect in attack_effects:
		if effect["alive"]:
			effect["ttl"] -= dt
			if effect["ttl"] <= 0.0:
				effect["alive"] = false

func can_attack() -> bool:
	return attack_cooldown <= 0.0

func perform_attack(player_pos: Vector2, target_pos: Vector2, enemies: Array[EnemyEntity]) -> Array[EnemyEntity]:
	if not can_attack():
		return []
	
	# Start cooldown using effective attack speed
	var effective_speed = _get_effective_attack_speed()
	var cooldown_time = 1.0 / effective_speed
	attack_cooldown = cooldown_time
	
	# Calculate attack direction
	var attack_dir = (target_pos - player_pos).normalized()
	
	# Get effective values for this attack
	var effective_range = _get_effective_range()
	var effective_cone = _get_effective_cone_angle()
	
	# Find pooled enemies in cone
	var hit_enemies: Array[EnemyEntity] = []
	for enemy in enemies:
		if not enemy.alive:
			continue
			
		if _is_enemy_in_cone(enemy.pos, player_pos, attack_dir, effective_cone, effective_range):
			hit_enemies.append(enemy)
	
	# Use EntityTracker for efficient boss detection
	var hit_scene_bosses = _find_bosses_in_cone(player_pos, attack_dir, effective_cone, effective_range)
	
	# Create visual effect
	_spawn_attack_effect(player_pos, target_pos)
	
	# Emit signals
	melee_attack_started.emit(player_pos, target_pos)
	if hit_enemies.size() > 0 or hit_scene_bosses.size() > 0:
		enemies_hit.emit(hit_enemies)
	
	# Apply damage via DamageService to all hit entities
	var final_damage = _calculate_damage()
	var total_hit_count = 0
	
	# Apply damage to pooled enemies
	for enemy in hit_enemies:
		var enemy_pool_index = _find_enemy_pool_index(enemy)
		
		if enemy_pool_index == -1:
			Logger.warn("Failed to find enemy pool index for melee damage", "combat")
			continue
		
		var entity_id = "enemy_" + str(enemy_pool_index)
		
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
		
		var effective_knockback = _get_effective_knockback_distance()
		var killed = DamageService.apply_damage(entity_id, final_damage, "melee", ["melee"], effective_knockback, player_pos)
		if killed:
			total_hit_count += 1
		
		if Logger.is_level_enabled(Logger.LogLevel.DEBUG):
			Logger.debug("Damage applied to enemy: " + str(final_damage) + " to " + entity_id, "abilities")
	
	# Apply damage to scene-based bosses
	for boss in hit_scene_bosses:
		# Scene bosses need to be identified by their scene path or unique identifier
		var boss_id = "boss_" + str(boss.get_instance_id())
		
		# AUTO-REGISTER: Register boss if not already registered
		if not DamageService.is_entity_alive(boss_id) and not DamageService.get_entity(boss_id).has("id"):
			var entity_data = {
				"id": boss_id,
				"type": "boss",
				"hp": boss.get_current_health() if boss.has_method("get_current_health") else 200.0,
				"max_hp": boss.get_max_health() if boss.has_method("get_max_health") else 200.0,
				"alive": boss.is_alive() if boss.has_method("is_alive") else true,
				"pos": boss.global_position
			}
			DamageService.register_entity(boss_id, entity_data)
		
		var effective_knockback = _get_effective_knockback_distance()
		var killed = DamageService.apply_damage(boss_id, final_damage, "melee", ["melee"], effective_knockback, player_pos)
		if killed:
			total_hit_count += 1
		
		Logger.info("Damage applied to scene boss: " + str(final_damage) + " to " + boss_id, "combat")
	
	if Logger.is_level_enabled(Logger.LogLevel.DEBUG):
		Logger.debug("Melee attack hit " + str(hit_enemies.size()) + " pooled enemies + " + str(hit_scene_bosses.size()) + " scene bosses", "abilities")
	
	return hit_enemies

func _is_enemy_in_cone(enemy_pos: Vector2, player_pos: Vector2, attack_dir: Vector2, cone_degrees: float, range_limit: float) -> bool:
	# Check if enemy is within range
	var distance = player_pos.distance_to(enemy_pos)
	if distance > range_limit:
		return false
	
	# Check if enemy is within cone angle
	var to_enemy = (enemy_pos - player_pos).normalized()
	var dot_product = to_enemy.dot(attack_dir)
	var cone_radians = deg_to_rad(cone_degrees)
	var min_dot = cos(cone_radians / 2.0)
	
	return dot_product >= min_dot

## Find bosses using EntityTracker (no scene tree traversal)
func _find_bosses_in_cone(player_pos: Vector2, attack_dir: Vector2, cone_degrees: float, range_limit: float) -> Array[Node]:
	var hit_bosses: Array[Node] = []
	
	# Use EntityTracker for efficient boss lookup
	var boss_entity_ids = EntityTracker.get_entities_in_cone(player_pos, attack_dir, cone_degrees, range_limit, "boss")
	
	for entity_id in boss_entity_ids:
		# Get boss instance from entity_id 
		var instance_id_str = entity_id.replace("boss_", "")
		var instance_id = instance_id_str.to_int()
		
		var boss_node = instance_from_id(instance_id)
		if boss_node and is_instance_valid(boss_node):
			hit_bosses.append(boss_node)
			if Logger.is_level_enabled(Logger.LogLevel.DEBUG):
				Logger.debug("V3: Found boss in melee range via EntityTracker: " + boss_node.name, "combat")
		else:
			Logger.warn("V3: Boss node not found for entity_id: " + entity_id, "combat")
			# Clean up stale entity
			EntityTracker.unregister_entity(entity_id)
	
	return hit_bosses


func _calculate_damage() -> float:
	var base_damage = damage
	var bonus_damage = RunManager.stats.get("melee_damage_add", 0.0)
	var damage_mult = RunManager.stats.get("melee_damage_mult", 1.0)
	return (base_damage + bonus_damage) * damage_mult

func _get_effective_attack_speed() -> float:
	var base_speed = attack_speed
	var bonus_speed = RunManager.stats.get("melee_attack_speed_add", 0.0)
	return base_speed + bonus_speed

func _get_effective_range() -> float:
	var base_range = attack_range
	var bonus_range = RunManager.stats.get("melee_range_add", 0.0)
	return base_range + bonus_range

func _get_effective_cone_angle() -> float:
	var base_angle = cone_angle
	var bonus_angle = RunManager.stats.get("melee_cone_angle_add", 0.0)
	return base_angle + bonus_angle

func _get_effective_knockback_distance() -> float:
	var base_knockback = knockback_distance
	var bonus_knockback = RunManager.stats.get("melee_knockback_add", 0.0)
	var knockback_mult = RunManager.stats.get("melee_knockback_mult", 1.0)
	return (base_knockback + bonus_knockback) * knockback_mult


func _spawn_attack_effect(player_pos: Vector2, target_pos: Vector2) -> void:
	var free_idx = _find_free_attack_effect()
	if free_idx == -1:
		return  # No free slots
	
	var effect = attack_effects[free_idx]
	effect["pos"] = player_pos
	effect["target_pos"] = target_pos
	effect["ttl"] = attack_duration
	effect["alive"] = true

func _find_free_attack_effect() -> int:
	for i in range(attack_effects.size()):
		if not attack_effects[i]["alive"]:
			return i
	return -1

func get_active_attack_effects() -> Array[Dictionary]:
	var active_effects: Array[Dictionary] = []
	for effect in attack_effects:
		if effect["alive"]:
			active_effects.append(effect)
	return active_effects

func get_attack_stats() -> Dictionary:
	return {
		"damage": damage,
		"range": attack_range,
		"cone_angle": cone_angle,
		"attack_speed": attack_speed,
		"cooldown_remaining": attack_cooldown,
		"auto_attack_enabled": auto_attack_enabled
	}

func _handle_auto_attack() -> void:
	if not auto_attack_enabled or not can_attack():
		return
	
	# Auto-attack will be triggered from Arena with proper enemy data
	# This method is called from combat step but Arena manages the actual attack calls

func set_auto_attack_enabled(enabled: bool) -> void:
	auto_attack_enabled = enabled
	Logger.info("Auto-attack " + ("enabled" if enabled else "disabled"), "abilities")

func set_auto_attack_target(target_pos: Vector2) -> void:
	auto_attack_target = target_pos

## Find enemy pool index using EntityTracker (no WaveDirector dependency)
func _find_enemy_pool_index(target_enemy: EnemyEntity) -> int:
	# Use EntityTracker to find enemies near the target position
	var nearby_entity_ids = EntityTracker.get_entities_in_radius(target_enemy.pos, 1.0, "enemy")
	
	for entity_id in nearby_entity_ids:
		var entity_data = EntityTracker.get_entity(entity_id)
		if entity_data.has("pos"):
			var entity_pos: Vector2 = entity_data["pos"]
			# Use exact position match to identify the specific enemy
			if entity_pos.distance_to(target_enemy.pos) < 0.1:  # Very close match
				var enemy_index_str = entity_id.replace("enemy_", "")
				return enemy_index_str.to_int()
	
	Logger.warn("V3: Could not find entity_id for enemy at position " + str(target_enemy.pos), "combat")
	return -1

