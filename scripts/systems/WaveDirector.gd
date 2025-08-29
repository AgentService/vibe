extends Node

## Wave director managing pooled enemies and spawning mechanics.
## Spawns enemies from outside the arena moving toward center.
## Updates on fixed combat step (30 Hz) for deterministic behavior.
## Uses Enemy V2 system for weighted enemy spawning.

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

# Arena system for spawn configuration  
var arena_system

# Boss hit feedback system for boss registration
var boss_hit_feedback: BossHitFeedback

# Cached alive enemies list for performance
var _alive_enemies_cache: Array[EnemyEntity] = []
var _cache_dirty: bool = true
var _last_cache_frame: int = -1

# Free enemy slot tracking for faster spawning
var _last_free_index: int = 0


signal enemies_updated(alive_enemies: Array[EnemyEntity])

func _ready() -> void:
	add_to_group("wave_directors")  # For DamageRegistry sync access
	_load_balance_values()
	EventBus.combat_step.connect(_on_combat_step)

	_initialize_pool()
	if BalanceDB:
		BalanceDB.balance_reloaded.connect(_on_balance_reloaded)



func set_arena_system(injected_arena_system) -> void:
	arena_system = injected_arena_system
	Logger.info("ArenaSystem injected into WaveDirector", "waves")



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
	_spawn_enemy_v2()

# Enemy V2 spawning system
func _spawn_enemy_v2() -> void:
	# Prefer a local preload so later removal is trivial
	const EnemyFactory := preload("res://scripts/systems/enemy_v2/EnemyFactory.gd")
	
	# Use cached player position and calculate spawn position
	var target_pos: Vector2 = PlayerState.position if PlayerState.has_player_reference() else arena_center
	var angle := RNG.randf_range("waves", 0.0, TAU)
	var effective_spawn_radius: float = arena_system.get_spawn_radius() if arena_system else spawn_radius
	var spawn_pos: Vector2 = target_pos + Vector2.from_angle(angle) * effective_spawn_radius
	
	# Track spawn index for deterministic seeding
	var local_spawn_counter: int = get_alive_enemies().size()  # Simple spawn indexing
	
	# Create spawn context for EnemyFactory
	var spawn_context := {
		"run_id": RunManager.run_seed,
		"wave_index": 0,  # TODO: Add proper wave tracking
		"spawn_index": local_spawn_counter,
		"position": spawn_pos,
		"context_tags": []  # Optional context tags
	}
	
	# Generate V2 spawn configuration
	var cfg := EnemyFactory.spawn_from_weights(spawn_context)
	if not cfg:
		Logger.warn("EnemyFactory failed to generate spawn config", "waves")
		return
	
	# Convert to legacy EnemyType for existing pooling system
	var legacy_enemy_type: EnemyType = cfg.to_enemy_type()
	
	# Hand off to existing pooling/rendering system
	_spawn_from_config_v2(legacy_enemy_type, cfg)

func _spawn_from_config_v2(enemy_type: EnemyType, spawn_config: SpawnConfig) -> void:
	# Generate stable entity ID for DamageService
	var spawn_counter: int = get_alive_enemies().size()
	var entity_id: String
	
	if spawn_config.render_tier == "boss":
		entity_id = "boss:" + str(spawn_config.template_id) + ":" + str(spawn_counter)
	else:
		entity_id = "enemy:" + str(spawn_config.template_id) + ":" + str(spawn_counter)
	
	spawn_config.set_entity_id(entity_id)
	
	# Boss detection - route to scene spawning for boss-tier enemies
	if spawn_config.render_tier == "boss":
		_spawn_boss_scene(spawn_config)
		return
	
	# Use existing pooled spawn logic for regular enemies
	var free_idx := _find_free_enemy()
	if free_idx == -1:
		Logger.warn("No free enemy slots available for V2 spawn", "waves")
		return
	
	var target_pos: Vector2 = PlayerState.position if PlayerState.has_player_reference() else arena_center
	var direction: Vector2 = (target_pos - spawn_config.position).normalized()
	
	var enemy := enemies[free_idx]
	enemy.setup_with_type(enemy_type, spawn_config.position, direction * spawn_config.speed)
	_cache_dirty = true  # Mark cache as dirty when spawning
	
	Logger.debug("Spawned V2 enemy: " + str(spawn_config.template_id) + " " + spawn_config.debug_string(), "enemies")

# Boss scene spawning for V2 system - data-driven approach
func _spawn_boss_scene(spawn_config: SpawnConfig) -> void:
	# Get template to retrieve boss_scene_path
	var template: EnemyTemplate = EnemyFactory.get_template(spawn_config.template_id)
	if not template:
		Logger.warn("Boss template not found: " + str(spawn_config.template_id), "waves")
		return
	
	var scene_path: String = template.boss_scene_path
	if scene_path.is_empty():
		Logger.warn("Boss template missing boss_scene_path: " + str(spawn_config.template_id), "waves")
		return
	
	var boss_scene: PackedScene = load(scene_path)
	if not boss_scene:
		Logger.warn("Failed to load boss scene: " + scene_path, "waves")
		return
	
	# Instantiate boss scene
	var boss_instance = boss_scene.instantiate()
	if not boss_instance:
		Logger.warn("Failed to instantiate boss scene", "waves")
		return
	
	# Setup boss with spawn config
	if boss_instance.has_method("setup_from_spawn_config"):
		boss_instance.setup_from_spawn_config(spawn_config)
	
	# Add to scene tree
	var parent = get_parent()
	parent.add_child(boss_instance)

	# Register with boss hit feedback system
	if boss_hit_feedback:
		boss_hit_feedback.register_boss(boss_instance)
		Logger.debug("Boss registered with hit feedback system", "waves")
	else:
		Logger.warn("BossHitFeedback not available for boss registration", "waves")
	
	Logger.info("V2 Boss spawned: " + spawn_config.template_id + " [" + spawn_config.entity_id + "] (" + boss_instance.name + ") at " + str(spawn_config.position), "waves")

# HYBRID SPAWNING SYSTEM: Core routing logic
func _spawn_from_type(enemy_type: EnemyType, position: Vector2) -> void:
	if enemy_type.is_special_boss and enemy_type.boss_scene:
		_spawn_special_boss(enemy_type, position)
	else:
		_spawn_pooled_enemy(enemy_type, position)  # Current system unchanged

func _spawn_special_boss(enemy_type: EnemyType, position: Vector2) -> void:
	var boss_node = enemy_type.boss_scene.instantiate()
	get_tree().current_scene.add_child(boss_node)
	boss_node.global_position = position
	
	# Connect boss death to EventBus for XP/loot
	if boss_node.has_signal("died"):
		boss_node.died.connect(_on_special_boss_died.bind(enemy_type))
	
	# DAMAGE V2: Register boss with DamageService
	var entity_id = "boss_" + str(boss_node.get_instance_id())
	var entity_data = {
		"id": entity_id,
		"type": "boss",
		"hp": boss_node.get_max_health() if boss_node.has_method("get_max_health") else 200.0,
		"max_hp": boss_node.get_max_health() if boss_node.has_method("get_max_health") else 200.0,
		"alive": true,
		"pos": position
	}
	DamageService.register_entity(entity_id, entity_data)
	
	Logger.info("Spawned special boss: " + enemy_type.id + " at " + str(position) + " registered as " + entity_id, "waves")

func _spawn_pooled_enemy(enemy_type: EnemyType, position: Vector2) -> void:
	# Existing pooled spawn logic - UNCHANGED
	var free_idx := _find_free_enemy()
	if free_idx == -1:
		Logger.warn("No free enemy slots available", "waves")
		return
	
	var target_pos: Vector2 = PlayerState.position if PlayerState.has_player_reference() else arena_center
	var direction: Vector2 = (target_pos - position).normalized()
	
	var enemy := enemies[free_idx]
	enemy.setup_with_type(enemy_type, position, direction * enemy_type.speed)
	_cache_dirty = true  # Mark cache as dirty when spawning
	
	# DAMAGE V2: Register enemy with DamageService
	var entity_id = "enemy_" + str(free_idx)
	var entity_data = {
		"id": entity_id,
		"type": "enemy",
		"hp": enemy.hp,
		"max_hp": enemy.hp,
		"alive": true,
		"pos": position
	}
	DamageService.register_entity(entity_id, entity_data)
	
	if Logger.is_level_enabled(Logger.LogLevel.DEBUG):
		Logger.debug("Spawned pooled enemy: " + enemy_type.id + " (size: " + str(enemy_type.size) + ") registered as " + entity_id, "enemies")

func _on_special_boss_died(enemy_type: EnemyType) -> void:
	# Handle special boss death - emit via EventBus for XP/loot systems
	var payload := EventBus.EnemyKilledPayload_Type.new(Vector2.ZERO, enemy_type.xp_value)
	EventBus.enemy_killed.emit(payload)
	Logger.info("Special boss killed: " + enemy_type.id + " (XP: " + str(enemy_type.xp_value) + ")", "combat")



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

# DAMAGE V2: damage_enemy() method removed - enemies damaged via DamageService
# Enemy HP updates handled by DamageRegistry sync system (_sync_damage_to_game_entity)

func set_enemy_velocity(enemy_index: int, velocity: Vector2) -> void:
	if enemy_index < 0 or enemy_index >= max_enemies:
		return
	
	var enemy := enemies[enemy_index]
	if not enemy["alive"]:
		return
	
	enemy["vel"] = velocity





# AI methods removed - back to simple chase behavior
