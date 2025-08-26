extends Node

## Wave director managing pooled enemies and spawning mechanics.
## Spawns enemies from outside the arena moving toward center.
## Updates on fixed combat step (30 Hz) for deterministic behavior.
## Supports typed enemy spawning via EnemyRegistry.

class_name WaveDirector

# Import ArenaSystem for dependency injection
const ArenaSystem = preload("res://scripts/systems/ArenaSystem.gd")

var enemies: Array[EnemyEntity] = []
var max_enemies: int
var spawn_timer: float = 0.0
var spawn_interval: float
var arena_center: Vector2
var spawn_radius: float
var enemy_speed_min: float
var enemy_speed_max: float
var spawn_count_min: int
var spawn_count_max: int
var arena_bounds: float
var target_distance: float

# Enemy typing system
var enemy_registry: EnemyRegistry
# Arena system for spawn configuration  
var arena_system

# Cached alive enemies list for performance
var _alive_enemies_cache: Array[EnemyEntity] = []
var _cache_dirty: bool = true
var _last_cache_frame: int = -1

# Free enemy slot tracking for faster spawning
var _last_free_index: int = 0


signal enemies_updated(alive_enemies: Array[EnemyEntity])

func _ready() -> void:
	_load_balance_values()
	EventBus.combat_step.connect(_on_combat_step)
	# Only setup enemy registry if not already injected
	if not enemy_registry:
		_setup_enemy_registry()
	_initialize_pool()
	if BalanceDB:
		BalanceDB.balance_reloaded.connect(_on_balance_reloaded)

# Dependency injection methods - called by GameOrchestrator
func set_enemy_registry(injected_registry: EnemyRegistry) -> void:
	enemy_registry = injected_registry
	Logger.info("EnemyRegistry injected into WaveDirector", "waves")

func set_arena_system(injected_arena_system) -> void:
	arena_system = injected_arena_system
	Logger.info("ArenaSystem injected into WaveDirector", "waves")

func _setup_enemy_registry() -> void:
	# Fallback - create own registry if none was injected (for backwards compatibility)
	enemy_registry = EnemyRegistry.new()
	add_child(enemy_registry)
	Logger.info("Enemy registry initialized (fallback)", "waves")

func _load_balance_values() -> void:
	max_enemies = BalanceDB.get_waves_value("max_enemies")
	spawn_interval = BalanceDB.get_waves_value("spawn_interval")
	arena_center = BalanceDB.get_waves_value("arena_center")
	# spawn_radius now comes from ArenaSystem, set via dependency injection
	enemy_speed_min = BalanceDB.get_waves_value("enemy_speed_min")
	enemy_speed_max = BalanceDB.get_waves_value("enemy_speed_max")
	spawn_count_min = BalanceDB.get_waves_value("spawn_count_min")
	spawn_count_max = BalanceDB.get_waves_value("spawn_count_max")
	arena_bounds = BalanceDB.get_waves_value("arena_bounds")
	target_distance = BalanceDB.get_waves_value("target_distance")


func _exit_tree() -> void:
	# Cleanup signal connections
	if EventBus.combat_step.is_connected(_on_combat_step):
		EventBus.combat_step.disconnect(_on_combat_step)
	if BalanceDB and BalanceDB.balance_reloaded.is_connected(_on_balance_reloaded):
		BalanceDB.balance_reloaded.disconnect(_on_balance_reloaded)
	Logger.debug("WaveDirector: Cleaned up signal connections", "systems")

func _on_balance_reloaded() -> void:
	_load_balance_values()
	_initialize_pool()
	Logger.info("Reloaded wave balance values", "waves")

func _choose_enemy_type() -> String:
	# Use EnemyRegistry for weighted selection
	if not enemy_registry:
		Logger.warn("EnemyRegistry not available, using fallback", "waves")
		return "knight_regular"
	
	var enemy_type: EnemyType = enemy_registry.get_random_enemy_type("waves")
	if not enemy_type:
		Logger.warn("No enemy types available from registry, using fallback", "waves")
		return "knight_regular"
	
	return enemy_type.id

func _get_enemy_speed(enemy_type_id: String) -> float:
	if not enemy_registry:
		return RNG.randf_range("waves", enemy_speed_min, enemy_speed_max)
	
	var enemy_type: EnemyType = enemy_registry.get_enemy_type(enemy_type_id)
	if not enemy_type:
		Logger.warn("No enemy type found for ID: " + enemy_type_id + ", using default speed", "waves")
		return RNG.randf_range("waves", enemy_speed_min, enemy_speed_max)
	
	return RNG.randf_range("waves", enemy_type.speed_min, enemy_type.speed_max)


func _initialize_pool() -> void:
	enemies.resize(max_enemies)
	for i in range(max_enemies):
		var entity = EnemyEntity.new()
		entity.pos = Vector2.ZERO
		entity.vel = Vector2.ZERO
		entity.hp = 0.0
		entity.max_hp = 0.0
		entity.alive = false
		entity.type_id = ""
		entity.speed = 60.0
		entity.size = Vector2(24, 24)
		enemies[i] = entity

func _on_combat_step(payload) -> void:
	_handle_spawning(payload.dt)
	_update_enemies(payload.dt)
	var alive_enemies := get_alive_enemies()
	#Logger.debug("WaveDirector emitting enemies_updated with " + str(alive_enemies.size()) + " enemies", "waves")
	enemies_updated.emit(alive_enemies)

func _handle_spawning(dt: float) -> void:
	# Check for spawn disabled cheat
	if CheatSystem and CheatSystem.is_spawn_disabled():
		return
	
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
	
	# Try registry first, fallback to legacy system
	var enemy_type_obj = null
	var enemy_type_str: String = "grunt"
	if enemy_registry:
		enemy_type_obj = enemy_registry.get_random_enemy_type("waves")
	if enemy_type_obj == null:
		# Fallback to legacy enemy type selection
		enemy_type_str = _choose_enemy_type()
		Logger.debug("Using legacy enemy type: " + enemy_type_str, "waves")
	else:
		enemy_type_str = enemy_type_obj.id
		Logger.debug("Using registry enemy type: " + enemy_type_str, "waves")
	
	# Use cached player position from PlayerState autoload
	var target_pos: Vector2 = PlayerState.position if PlayerState.has_player_reference() else arena_center
	
	var angle := RNG.randf_range("waves", 0.0, TAU)
	var effective_spawn_radius: float = arena_system.get_spawn_radius() if arena_system else spawn_radius
	Logger.info("WaveDirector using spawn_radius: " + str(effective_spawn_radius) + " (arena_system exists: " + str(arena_system != null) + ")", "waves")
	var spawn_pos: Vector2 = target_pos + Vector2.from_angle(angle) * effective_spawn_radius
	var direction: Vector2 = (target_pos - spawn_pos).normalized()
	
	var enemy := enemies[free_idx]
	
	# Setup enemy using available method
	if enemy_type_obj:
		# Use entity setup if enemy type is available
		enemy.setup_with_type(enemy_type_obj, spawn_pos, direction * enemy_type_obj.speed)
	else:
		# Fallback to manual setup (should not happen with .tres system)
		Logger.warn("Using fallback manual enemy setup for: " + enemy_type_str, "waves")
		var speed := _get_enemy_speed(enemy_type_str)
		enemy.pos = spawn_pos
		enemy.vel = direction * speed
		enemy.hp = 3.0  # Fallback default HP
		enemy.max_hp = 3.0
		enemy.alive = true
		enemy.type_id = enemy_type_str
	_cache_dirty = true  # Mark cache as dirty when spawning
	
	if enemy_type_obj:
		Logger.debug("Spawned enemy: " + enemy_type_obj.id + " (size: " + str(enemy_type_obj.size) + ")", "enemies")
	else:
		Logger.debug("Spawned enemy: " + enemy_type_str, "enemies")

## Public method for manual enemy spawning (debug/testing)
func spawn_enemy_at(position: Vector2, enemy_type_str: String = "green_slime") -> bool:
	var free_idx := _find_free_enemy()
	if free_idx == -1:
		return false
	
	# Try registry first, fallback to legacy
	var enemy_type_obj = null
	if enemy_registry:
		enemy_type_obj = enemy_registry.get_enemy_type(enemy_type_str)
	
	var target_pos: Vector2 = PlayerState.position if PlayerState.has_player_reference() else arena_center
	var direction := (target_pos - position).normalized()
	
	var enemy := enemies[free_idx]
	
	# Setup enemy using available method
	if enemy_type_obj:
		# Use entity setup if enemy type is available
		enemy.setup_with_type(enemy_type_obj, position, direction * enemy_type_obj.speed)
	else:
		# Fallback to manual setup (should not happen with .tres system)
		Logger.warn("Using fallback manual spawn_enemy_at for: " + enemy_type_str, "waves")
		var speed := _get_enemy_speed(enemy_type_str)
		enemy.pos = position
		enemy.vel = direction * speed
		enemy.hp = 3.0  # Fallback default HP
		enemy.max_hp = 3.0
		enemy.alive = true
		enemy.type_id = enemy_type_str
	_cache_dirty = true  # Mark cache as dirty when spawning
	return true

func _find_free_enemy() -> int:
	# Start search from last known free index for better performance
	for i in range(_last_free_index, max_enemies):
		if not enemies[i].alive:
			_last_free_index = i
			return i
	
	# If not found, search from beginning to last free index
	for i in range(0, _last_free_index):
		if not enemies[i].alive:
			_last_free_index = i
			return i
	
	return -1

func _update_enemies(dt: float) -> void:
	# Use cached player position from PlayerState autoload  
	var target_pos: Vector2 = PlayerState.position if PlayerState.has_player_reference() else arena_center
	var update_distance: float = BalanceDB.get_waves_value("enemy_update_distance")
	
	# Only update alive enemies to improve performance
	var alive_enemies = get_alive_enemies()
	for enemy in alive_enemies:
		var dist_to_target: float = enemy.pos.distance_to(target_pos)
		
		# Only update enemies within update distance for performance
		if dist_to_target <= update_distance:
			# Simple chase behavior - move toward player
			var direction: Vector2 = (target_pos - enemy.pos).normalized()
			enemy.vel = direction * enemy.speed
			
			# Update enemy position based on current velocity
			enemy.pos += enemy.vel * dt
		
		# Kill enemy if it reaches target or goes out of bounds - DISABLED
		# if dist_to_target < target_distance or _is_out_of_bounds(enemy["pos"]):
		#	enemy["alive"] = false
		#	_cache_dirty = true  # Mark cache as dirty when enemy dies

func _is_out_of_bounds(pos: Vector2) -> bool:
	return abs(pos.x) > arena_bounds or abs(pos.y) > arena_bounds

func get_alive_enemies() -> Array[EnemyEntity]:
	var current_frame = Engine.get_process_frames()
	
	# Use cached list if available and not dirty, or if already rebuilt this frame
	if (not _cache_dirty and not _alive_enemies_cache.is_empty()) or _last_cache_frame == current_frame:
		return _alive_enemies_cache
	
	# Rebuild cache - only once per frame maximum
	_alive_enemies_cache.clear()
	for i in range(enemies.size()):
		var enemy = enemies[i]
		if enemy.alive:
			_alive_enemies_cache.append(enemy)
	
	_cache_dirty = false
	_last_cache_frame = current_frame
	return _alive_enemies_cache

# Player reference no longer needed - using PlayerState autoload for position

func damage_enemy(enemy_index: int, damage: float) -> void:
	if enemy_index < 0 or enemy_index >= max_enemies:
		return
	
	var enemy := enemies[enemy_index]
	if not enemy.alive:
		return
	
	var old_hp = enemy.hp
	enemy.hp -= damage
	Logger.info("Enemy[%d] %s: %.1f → %.1f HP (took %.1f damage)" % [enemy_index, enemy.type_id, old_hp, enemy.hp, damage], "combat")
	
	if enemy.hp <= 0.0:
		var death_pos: Vector2 = enemy.pos
		enemy.alive = false
		_cache_dirty = true  # Mark cache as dirty when enemy dies from damage
		Logger.info("Enemy[%d] %s KILLED at position %s" % [enemy_index, enemy.type_id, death_pos], "combat")
		var payload := EventBus.EnemyKilledPayload_Type.new(death_pos, 1)
		EventBus.enemy_killed.emit(payload)

func set_enemy_velocity(enemy_index: int, velocity: Vector2) -> void:
	if enemy_index < 0 or enemy_index >= max_enemies:
		return
	
	var enemy := enemies[enemy_index]
	if not enemy["alive"]:
		return
	
	enemy["vel"] = velocity

# AI methods removed - back to simple chase behavior
