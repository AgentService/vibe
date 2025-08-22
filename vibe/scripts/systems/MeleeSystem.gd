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
var range: float
var cone_angle: float  # In degrees
var attack_speed: float  # Attacks per second

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
	range = BalanceDB.get_melee_value("range")
	cone_angle = BalanceDB.get_melee_value("cone_angle")
	attack_speed = BalanceDB.get_melee_value("attack_speed")

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

func perform_attack(player_pos: Vector2, target_pos: Vector2, enemies: Array[Dictionary]) -> Array[Dictionary]:
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
	
	# Find enemies in cone
	var hit_enemies: Array[Dictionary] = []
	for e_idx in range(enemies.size()):
		var enemy = enemies[e_idx]
		if not enemy.get("alive", false):
			continue
			
		var enemy_pos = enemy.get("pos", Vector2.ZERO)
		if _is_enemy_in_cone(enemy_pos, player_pos, attack_dir, effective_cone, effective_range):
			# Store both enemy data and index for EntityId creation
			var hit_enemy = enemy.duplicate()
			hit_enemy["_array_index"] = e_idx  # Store index for EntityId
			hit_enemies.append(hit_enemy)
	
	# Create visual effect
	_spawn_attack_effect(player_pos, target_pos)
	
	# Emit signals
	melee_attack_started.emit(player_pos, target_pos)
	if hit_enemies.size() > 0:
		enemies_hit.emit(hit_enemies)
	
	# Apply damage to hit enemies
	for enemy in hit_enemies:
		var final_damage = _calculate_damage()
		var source_id = EntityId.player()
		var target_id = EntityId.enemy(enemy["_array_index"])
		var damage_tags = PackedStringArray(["melee"])
		var damage_payload = EventBus.DamageRequestPayload.new(source_id, target_id, final_damage, damage_tags)
		EventBus.damage_requested.emit(damage_payload)
		Logger.debug("Damage request: " + str(final_damage) + " to enemy " + enemy.get("type_id", "unknown") + " (hp: " + str(enemy.get("hp", 0)) + ")", "abilities")
	
	
	Logger.debug("Melee attack hit " + str(hit_enemies.size()) + " enemies", "abilities")
	return hit_enemies

func _is_enemy_in_cone(enemy_pos: Vector2, player_pos: Vector2, attack_dir: Vector2, cone_degrees: float, attack_range: float) -> bool:
	# Check if enemy is within range
	var distance = player_pos.distance_to(enemy_pos)
	if distance > attack_range:
		return false
	
	# Check if enemy is within cone angle
	var to_enemy = (enemy_pos - player_pos).normalized()
	var dot_product = to_enemy.dot(attack_dir)
	var cone_radians = deg_to_rad(cone_degrees)
	var min_dot = cos(cone_radians / 2.0)
	
	return dot_product >= min_dot

func _calculate_damage() -> float:
	return damage

func _get_effective_attack_speed() -> float:
	return attack_speed

func _get_effective_range() -> float:
	return range

func _get_effective_cone_angle() -> float:
	return cone_angle


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
		"range": range,
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
