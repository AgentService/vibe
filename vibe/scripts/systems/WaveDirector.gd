extends Node

## Wave director managing pooled enemies and spawning mechanics.
## Spawns enemies from outside the arena moving toward center.
## Updates on fixed combat step (30 Hz) for deterministic behavior.

class_name WaveDirector

var enemies: Array[Dictionary] = []
var max_enemies: int
var spawn_timer: float = 0.0
var spawn_interval: float
var arena_center: Vector2
var spawn_radius: float
var enemy_hp: float
var enemy_speed_min: float
var enemy_speed_max: float
var spawn_count_min: int
var spawn_count_max: int
var arena_bounds: float
var target_distance: float

# Cached alive enemies list for performance
var _alive_enemies_cache: Array[Dictionary] = []
var _cache_dirty: bool = true

signal enemies_updated(alive_enemies: Array[Dictionary])

func _ready() -> void:
	_load_balance_values()
	EventBus.combat_step.connect(_on_combat_step)
	_initialize_pool()
	if BalanceDB:
		BalanceDB.balance_reloaded.connect(_on_balance_reloaded)

func _load_balance_values() -> void:
	max_enemies = BalanceDB.get_waves_value("max_enemies")
	spawn_interval = BalanceDB.get_waves_value("spawn_interval")
	var center_data: Dictionary = BalanceDB.get_waves_value("arena_center")
	arena_center = Vector2(center_data.get("x", 400.0), center_data.get("y", 300.0))
	spawn_radius = BalanceDB.get_waves_value("spawn_radius")
	enemy_hp = BalanceDB.get_waves_value("enemy_hp")
	enemy_speed_min = BalanceDB.get_waves_value("enemy_speed_min")
	enemy_speed_max = BalanceDB.get_waves_value("enemy_speed_max")
	spawn_count_min = BalanceDB.get_waves_value("spawn_count_min")
	spawn_count_max = BalanceDB.get_waves_value("spawn_count_max")
	arena_bounds = BalanceDB.get_waves_value("arena_bounds")
	target_distance = BalanceDB.get_waves_value("target_distance")

func _on_balance_reloaded() -> void:
	_load_balance_values()
	_initialize_pool()
	Logger.info("Reloaded wave balance values", "waves")

func _initialize_pool() -> void:
	enemies.resize(max_enemies)
	for i in range(max_enemies):
		enemies[i] = {
			"pos": Vector2.ZERO,
			"vel": Vector2.ZERO,
			"hp": enemy_hp,
			"alive": false
		}

func _on_combat_step(payload) -> void:
	_handle_spawning(payload.dt)
	_update_enemies(payload.dt)
	var alive_enemies := get_alive_enemies()
	enemies_updated.emit(alive_enemies)

func _handle_spawning(dt: float) -> void:
	spawn_timer += dt
	if spawn_timer >= spawn_interval:
		spawn_timer = 0.0
		var spawn_count := RNG.randi_range("waves", spawn_count_min, spawn_count_max)
		for i in spawn_count:
			_spawn_enemy()

func _spawn_enemy() -> void:
	var free_idx := _find_free_enemy()
	if free_idx == -1:
		Logger.warn("No free enemy slots available", "waves")
		return
	
	# Use cached player position from PlayerState autoload
	var target_pos: Vector2 = PlayerState.position if PlayerState.position != Vector2.ZERO else arena_center
	
	var angle := RNG.randf_range("waves", 0.0, TAU)
	var spawn_pos := target_pos + Vector2.from_angle(angle) * spawn_radius
	var direction := (target_pos - spawn_pos).normalized()
	var speed := RNG.randf_range("waves", enemy_speed_min, enemy_speed_max)
	
	var enemy := enemies[free_idx]
	enemy["pos"] = spawn_pos
	enemy["vel"] = direction * speed
	enemy["hp"] = enemy_hp
	enemy["alive"] = true
	_cache_dirty = true  # Mark cache as dirty when spawning

## Public method for manual enemy spawning (debug/testing)
func spawn_enemy_at(position: Vector2, enemy_type: String = "grunt") -> bool:
	var free_idx := _find_free_enemy()
	if free_idx == -1:
		return false
	
	var target_pos: Vector2 = PlayerState.position if PlayerState.position != Vector2.ZERO else arena_center
	var direction := (target_pos - position).normalized()
	var speed := RNG.randf_range("waves", enemy_speed_min, enemy_speed_max)
	
	var enemy := enemies[free_idx]
	enemy["pos"] = position
	enemy["vel"] = direction * speed
	enemy["hp"] = enemy_hp
	enemy["alive"] = true
	_cache_dirty = true  # Mark cache as dirty when spawning
	return true

func _find_free_enemy() -> int:
	for i in range(max_enemies):
		if not enemies[i]["alive"]:
			return i
	return -1

func _update_enemies(dt: float) -> void:
	# Use cached player position from PlayerState autoload
	var target_pos: Vector2 = PlayerState.position if PlayerState.position != Vector2.ZERO else arena_center
	var update_distance: float = BalanceDB.get_waves_value("enemy_update_distance")
	
	for enemy in enemies:
		if not enemy["alive"]:
			continue
		
		var dist_to_target: float = enemy["pos"].distance_to(target_pos)
		
		# Only update enemies within update distance for performance
		if dist_to_target <= update_distance:
			# Update enemy direction to always move toward player/center
			var direction: Vector2 = (target_pos - enemy["pos"]).normalized()
			var speed: float = enemy["vel"].length()
			enemy["vel"] = direction * speed
			enemy["pos"] += enemy["vel"] * dt
		
		# Kill enemy if it reaches target or goes out of bounds
		if dist_to_target < target_distance or _is_out_of_bounds(enemy["pos"]):
			enemy["alive"] = false
			_cache_dirty = true  # Mark cache as dirty when enemy dies

func _is_out_of_bounds(pos: Vector2) -> bool:
	return abs(pos.x) > arena_bounds or abs(pos.y) > arena_bounds

func get_alive_enemies() -> Array[Dictionary]:
	# Use cached list if available and not dirty
	if not _cache_dirty and _alive_enemies_cache.size() > 0:
		return _alive_enemies_cache
	
	# Rebuild cache
	_alive_enemies_cache.clear()
	for enemy in enemies:
		if enemy["alive"]:
			_alive_enemies_cache.append(enemy)
	
	_cache_dirty = false
	return _alive_enemies_cache

# Player reference no longer needed - using PlayerState autoload for position

func damage_enemy(enemy_index: int, damage: float) -> void:
	if enemy_index < 0 or enemy_index >= max_enemies:
		return
	
	var enemy := enemies[enemy_index]
	if not enemy["alive"]:
		return
	
	enemy["hp"] -= damage
	if enemy["hp"] <= 0.0:
		var death_pos: Vector2 = enemy["pos"]
		enemy["alive"] = false
		_cache_dirty = true  # Mark cache as dirty when enemy dies from damage
		var payload := EventBus.EnemyKilledPayload.new(death_pos, 1)
		EventBus.enemy_killed.emit(payload)
