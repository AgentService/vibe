extends Node2D

## Arena scene managing MultiMesh rendering and receiving injected game systems.
## Renders projectile pool via MultiMeshInstance2D.
## Systems are initialized and managed by GameOrchestrator autoload.

const AnimationConfig_Type = preload("res://scripts/domain/AnimationConfig.gd")  # allowed: pure Resource config

# Player scene loaded dynamically to support @export hot-reload
const PauseMenu_Type = preload("res://scenes/ui/PauseMenu.gd")
const ArenaSystem := preload("res://scripts/systems/ArenaSystem.gd")
const CameraSystem := preload("res://scripts/systems/CameraSystem.gd")
const EnemyRenderTier_Type := preload("res://scripts/systems/EnemyRenderTier.gd")
const BossSpawnConfig := preload("res://scripts/domain/BossSpawnConfig.gd")
const ArenaUIManager := preload("res://scripts/systems/ArenaUIManager.gd")
const EnemyAnimationSystem := preload("res://scripts/systems/EnemyAnimationSystem.gd")
const MultiMeshManager := preload("res://scripts/systems/MultiMeshManager.gd")
const BossSpawnManager := preload("res://scripts/systems/BossSpawnManager.gd")

@onready var mm_projectiles: MultiMeshInstance2D = $MM_Projectiles
# TIER-BASED ENEMY RENDERING SYSTEM
@onready var mm_enemies_swarm: MultiMeshInstance2D = $MM_Enemies_Swarm
@onready var mm_enemies_regular: MultiMeshInstance2D = $MM_Enemies_Regular
@onready var mm_enemies_elite: MultiMeshInstance2D = $MM_Enemies_Elite
@onready var mm_enemies_boss: MultiMeshInstance2D = $MM_Enemies_Boss
@onready var melee_effects: Node2D = $MeleeEffects
var ability_system: AbilitySystem
var melee_system: MeleeSystem
var debug_controller: DebugController
var ui_manager: ArenaUIManager
var enemy_animation_system: EnemyAnimationSystem
var multimesh_manager: MultiMeshManager
var boss_spawn_manager: BossSpawnManager


var wave_director: WaveDirector
var damage_system: DamageSystem
var arena_system: ArenaSystem
var camera_system: CameraSystem
var enemy_render_tier: EnemyRenderTier
var enemy_hit_feedback: EnemyMultiMeshHitFeedback

# SYSTEM INJECTION CLEANUP - Phase 5
# Centralized system collection for cleaner injection management
var _injected: Dictionary = {}

@export_group("Boss Hit Feedback Settings")
@export var boss_knockback_force: float = 12.0: ## Multiplier for boss knockback force
	set(value):
		boss_knockback_force = value
		if boss_hit_feedback:
			boss_hit_feedback.knockback_force_multiplier = value
@export var boss_knockback_duration: float = 2.0: ## Duration multiplier for boss knockback
	set(value):
		boss_knockback_duration = value
		if boss_hit_feedback:
			boss_hit_feedback.knockback_duration_multiplier = value
@export var boss_hit_stop_duration: float = 0.15: ## Freeze time on boss hit impact
	set(value):
		boss_hit_stop_duration = value
		if boss_hit_feedback:
			boss_hit_feedback.hit_stop_duration = value
@export var boss_velocity_decay: float = 0.82: ## Boss knockback decay rate (0.7-0.95)
	set(value):
		boss_velocity_decay = value
		if boss_hit_feedback:
			boss_hit_feedback.velocity_decay_factor = value
@export var boss_flash_duration: float = 0.2: ## Boss flash effect duration
	set(value):
		boss_flash_duration = value
		if boss_hit_feedback:
			boss_hit_feedback.flash_duration_override = value
@export var boss_flash_intensity: float = 5.0: ## Boss flash effect intensity
	set(value):
		boss_flash_intensity = value
		if boss_hit_feedback:
			boss_hit_feedback.flash_intensity_override = value

@export_group("Boss Spawn Configuration")
@export var boss_spawn_configs: Array[BossSpawnConfig] = []: ## Configurable boss spawn positions and settings
	set(value):
		boss_spawn_configs = value
		notify_property_list_changed()

@export var enable_debug_boss_spawning: bool = true: ## Enable debug boss spawning (B key)
	set(value):
		enable_debug_boss_spawning = value

var boss_hit_feedback: BossHitFeedback

var player: Player
var xp_system: XpSystem
var card_system: CardSystem
# UI elements now managed by ArenaUIManager

var spawn_timer: float = 0.0
var base_spawn_interval: float = 0.25

var _enemy_transforms: Array[Transform2D] = []



func _ready() -> void:
	Logger.info("Arena initializing", "ui")
	
	# Arena input should work during pause for debug controls
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	
	# Create enemy render tier system
	if EnemyRenderTier == null:
		Logger.error("EnemyRenderTier class is null!", "ui")
		return
	
	enemy_render_tier = EnemyRenderTier_Type.new()
	if enemy_render_tier == null:
		Logger.error("EnemyRenderTier instance creation failed!", "ui")
		return
	
	add_child(enemy_render_tier)
	
	# Force call ready if needed
	if not enemy_render_tier.is_node_ready():
		enemy_render_tier._ready()
	
	# Create enemy hit feedback system
	enemy_hit_feedback = EnemyMultiMeshHitFeedback.new()
	add_child(enemy_hit_feedback)
	
	# Create boss hit feedback system
	boss_hit_feedback = BossHitFeedback.new()
	# Apply Arena's exported settings to the boss hit feedback system
	boss_hit_feedback.knockback_force_multiplier = boss_knockback_force
	boss_hit_feedback.knockback_duration_multiplier = boss_knockback_duration
	boss_hit_feedback.hit_stop_duration = boss_hit_stop_duration
	boss_hit_feedback.velocity_decay_factor = boss_velocity_decay
	boss_hit_feedback.flash_duration_override = boss_flash_duration
	boss_hit_feedback.flash_intensity_override = boss_flash_intensity
	add_child(boss_hit_feedback)
	
	# Create and add new systems
	_setup_player()
	_setup_xp_system()
	_setup_ui()
	
	# Setup MultiMesh Manager BEFORE system injection
	multimesh_manager = MultiMeshManager.new()
	add_child(multimesh_manager)
	multimesh_manager.setup(mm_projectiles, mm_enemies_swarm, mm_enemies_regular, mm_enemies_elite, mm_enemies_boss, enemy_render_tier)
	
	# Setup Boss Spawn Manager
	boss_spawn_manager = BossSpawnManager.new()
	add_child(boss_spawn_manager)
	
	# Initialize GameOrchestrator systems and inject them AFTER MultiMesh Manager is ready
	GameOrchestrator.initialize_core_loop()
	GameOrchestrator.inject_systems_to_arena(self)

	# Inject boss hit feedback system to WaveDirector for boss registration
	if GameOrchestrator.wave_director:
		GameOrchestrator.wave_director.boss_hit_feedback = boss_hit_feedback
		Logger.debug("BossHitFeedback injected to WaveDirector", "arena")
	
	_setup_card_system()
	
	
	# Set player reference in PlayerState for cached position access
	PlayerState.set_player_reference(player)
	
	# Setup Boss Spawn Manager with dependencies
	boss_spawn_manager.setup(wave_director, player)
	
	# System signals connected via GameOrchestrator injection
	EventBus.level_up.connect(_on_level_up)
	_setup_enemy_animation_system()
	_setup_enemy_transforms()
	
	# Setup hit feedback system with MultiMesh references
	if enemy_hit_feedback:
		enemy_hit_feedback.setup_multimesh_references(mm_enemies_swarm, mm_enemies_regular, mm_enemies_elite, mm_enemies_boss)
		# Inject EnemyRenderTier reference
		if enemy_render_tier:
			enemy_hit_feedback.set_enemy_render_tier(enemy_render_tier)
		# Inject WaveDirector reference if available
		if wave_director:
			enemy_hit_feedback.set_wave_director(wave_director)
	
	# Debug help now provided by DebugController
	Logger.info("Arena ready", "ui")


func _setup_enemy_animation_system() -> void:
	enemy_animation_system = EnemyAnimationSystem.new()
	add_child(enemy_animation_system)
	
	var multimesh_refs = {
		"swarm": mm_enemies_swarm,
		"regular": mm_enemies_regular,
		"elite": mm_enemies_elite,
		"boss": mm_enemies_boss
	}
	
	enemy_animation_system.setup(multimesh_refs)
	Logger.info("EnemyAnimationSystem initialized", "animations")

func _setup_enemy_transforms() -> void:
	var cache_size: int = BalanceDB.get_waves_value("enemy_transform_cache_size")
	_enemy_transforms.resize(cache_size)
	for i in range(cache_size):
		_enemy_transforms[i] = Transform2D()
	if Logger.is_level_enabled(Logger.LogLevel.DEBUG):
		Logger.debug("Enemy transform cache initialized with " + str(cache_size) + " transforms", "performance")


func _process(delta: float) -> void:
	# Don't handle debug spawning when game is paused
	if not get_tree().paused:
		_handle_debug_spawning(delta)
		_handle_auto_attack()
		# Animation handled by dedicated system
		if enemy_animation_system:
			enemy_animation_system.animate_frames(delta)
	

func _input(event: InputEvent) -> void:
	# Handle Escape key for pause menu (priority handling)
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		# Check if card selection is currently visible - if so, let it handle the input
		if ui_manager and ui_manager.get_card_selection() and ui_manager.get_card_selection().visible:
			return  # Let card selection handle the escape key
		
		# Toggle pause menu through UI manager
		if ui_manager:
			ui_manager.toggle_pause()
		return
	
	# Handle mouse position updates for auto-attack
	if event is InputEventMouseMotion:
		var world_pos = get_global_mouse_position()
		melee_system.set_auto_attack_target(world_pos)
	
	# Handle mouse clicks for attacks
	if event is InputEventMouseButton and event.pressed:
		# Convert screen coordinates to world coordinates
		var world_pos = get_global_mouse_position()
		if event.button_index == MOUSE_BUTTON_LEFT:
			_handle_melee_attack(world_pos)
		elif event.button_index == MOUSE_BUTTON_RIGHT and RunManager.stats.get("has_projectiles", false):
			_handle_projectile_attack(world_pos)
		return
	
	# All debug keys now handled by DebugController system

func _setup_player() -> void:
	# Load player scene dynamically to support @export hot-reload
	var player_scene = load("res://scenes/arena/Player.tscn") as PackedScene
	player = player_scene.instantiate()
	player.global_position = Vector2(0, 0)  # Center of arena
	add_child(player)
	
	# Camera setup now handled in injection method

func _setup_xp_system() -> void:
	xp_system = XpSystem.new(self)
	_injected["XpSystem"] = xp_system
	add_child(xp_system)

func _setup_ui() -> void:
	# Create and configure ArenaUIManager
	ui_manager = ArenaUIManager.new()
	add_child(ui_manager)
	ui_manager.setup()
	
	# Connect UI manager events
	ui_manager.card_selected.connect(_on_card_selected)

func _setup_card_system() -> void:
	# CardSystem is now injected by GameOrchestrator - just verify it's ready
	if card_system:
		Logger.debug("Card system setup completed with injected system", "cards")
	else:
		Logger.warn("Card system not yet injected during setup", "cards")

# ============================================================================
# DEPENDENCY INJECTION METHODS
# Called by GameOrchestrator to inject initialized systems with proper 
# process modes and signal connections
# ============================================================================

# Phase 5: Centralized system injection collector
# Provides dictionary-based injection while maintaining backward compatibility
func inject_systems(systems: Dictionary) -> void:
	_injected = systems.duplicate()
	Logger.info("Arena: Centralized system injection completed with " + str(_injected.size()) + " systems", "systems")
	
	# Optional: connect signals here centrally if needed in future
	# For now, individual set_* methods handle their own connections

func set_card_system(injected_card_system: CardSystem) -> void:
	card_system = injected_card_system
	_injected["CardSystem"] = injected_card_system
	Logger.info("CardSystem injected into Arena", "cards")
	
	# Complete the card system setup through UI manager
	if ui_manager:
		ui_manager.setup_card_system(card_system)
		Logger.debug("Card system connected to ArenaUIManager", "cards")

func set_ability_system(injected_ability_system: AbilitySystem) -> void:
	ability_system = injected_ability_system
	_injected["AbilitySystem"] = injected_ability_system
	Logger.info("AbilitySystem injected into Arena", "systems")
	
	ability_system.process_mode = Node.PROCESS_MODE_PAUSABLE
	ability_system.projectiles_updated.connect(multimesh_manager.update_projectiles)

func set_arena_system(injected_arena_system: ArenaSystem) -> void:
	arena_system = injected_arena_system
	_injected["ArenaSystem"] = injected_arena_system
	Logger.info("ArenaSystem injected into Arena", "systems")
	
	arena_system.process_mode = Node.PROCESS_MODE_PAUSABLE
	arena_system.arena_loaded.connect(_on_arena_loaded)

func set_camera_system(injected_camera_system: CameraSystem) -> void:
	camera_system = injected_camera_system
	_injected["CameraSystem"] = injected_camera_system
	Logger.info("CameraSystem injected into Arena", "systems")
	
	camera_system.process_mode = Node.PROCESS_MODE_PAUSABLE
	if player:
		camera_system.setup_camera(player)

func set_wave_director(injected_wave_director: WaveDirector) -> void:
	wave_director = injected_wave_director
	_injected["WaveDirector"] = injected_wave_director
	Logger.info("WaveDirector injected into Arena", "systems")
	
	wave_director.process_mode = Node.PROCESS_MODE_PAUSABLE
	wave_director.enemies_updated.connect(multimesh_manager.update_enemies)
	
	# Inject WaveDirector into hit feedback system if it exists
	if enemy_hit_feedback:
		enemy_hit_feedback.set_wave_director(wave_director)

func set_melee_system(injected_melee_system: MeleeSystem) -> void:
	melee_system = injected_melee_system
	_injected["MeleeSystem"] = injected_melee_system
	Logger.info("MeleeSystem injected into Arena", "systems")
	
	melee_system.process_mode = Node.PROCESS_MODE_PAUSABLE
	melee_system.melee_attack_started.connect(_on_melee_attack_started)

func set_damage_system(injected_damage_system: DamageSystem) -> void:
	damage_system = injected_damage_system
	_injected["DamageSystem"] = injected_damage_system
	Logger.info("DamageSystem injected into Arena", "systems")
	
	damage_system.process_mode = Node.PROCESS_MODE_PAUSABLE

func setup_debug_controller() -> void:
	# Create and configure DebugController with system dependencies
	debug_controller = DebugController.new()
	add_child(debug_controller)
	
	# Use centralized _injected dictionary for cleaner dependency management
	debug_controller.setup(self, _injected)
	Logger.info("DebugController setup complete with " + str(_injected.size()) + " injected systems", "systems")

func _on_level_up(payload) -> void:
	Logger.info("Player leveled up to level " + str(payload.new_level), "player")
	
	if not card_system:
		Logger.error("Card system not initialized", "cards")
		return
	
	# Get card selection for current level
	var cards: Array[CardResource] = card_system.get_card_selection(payload.new_level, 3)
	
	if cards.is_empty():
		Logger.warn("No cards available for level " + str(payload.new_level), "cards")
		return
	
	# Pause game and show card selection through UI manager
	Logger.debug("About to pause game for card selection", "cards")
	PauseManager.pause_game(true)
	Logger.debug("Game paused, opening card selection", "cards")
	if ui_manager:
		ui_manager.open_card_selection(cards)

func _on_card_selected(card: CardResource) -> void:
	if not card:
		Logger.error("Null card selected", "cards")
		return
	
	Logger.info("Player selected card: " + card.name, "cards")
	card_system.apply_card(card)


func _on_enemies_updated(_alive_enemies: Array[EnemyEntity]) -> void:
	pass

func _handle_melee_attack(target_pos: Vector2) -> void:
	if not player or not melee_system:
		return
	
	var player_pos = player.global_position
	var alive_enemies = wave_director.get_alive_enemies()
	melee_system.perform_attack(player_pos, target_pos, alive_enemies)

func _handle_projectile_attack(_target_pos: Vector2) -> void:
	if not player or not ability_system:
		return
	
	_spawn_debug_projectile()

func _handle_auto_attack() -> void:
	if not melee_system.auto_attack_enabled or not player:
		return
	
	var player_pos = player.global_position
	var alive_enemies = wave_director.get_alive_enemies()
	
	# Only attack if there are enemies nearby
	if alive_enemies.size() > 0:
		melee_system.perform_attack(player_pos, melee_system.auto_attack_target, alive_enemies)

func _on_melee_attack_started(player_pos: Vector2, target_pos: Vector2) -> void:
	_show_melee_cone_effect(player_pos, target_pos)

func _show_melee_cone_effect(player_pos: Vector2, target_pos: Vector2) -> void:
	# Use manually created polygon from the scene
	var cone_polygon = $MeleeEffects/MeleeCone
	if not cone_polygon:
		return
	
	# Get effective melee stats to match the actual damage area
	var effective_range = melee_system._get_effective_range()
	var range_scale = effective_range / 100.0  # Assuming your cone is ~100 units long
	
	# Position and scale the cone at player position
	cone_polygon.global_position = player_pos
	cone_polygon.scale = Vector2(range_scale, range_scale)  # Scale to match damage range
	
	# Point the cone toward mouse/target position (where damage occurs)
	var attack_dir = (target_pos - player_pos).normalized()
	cone_polygon.rotation = attack_dir.angle() - PI/2  # Fix 90° offset (cone was 1/4 ahead)
	
	# Show the cone with transparency
	cone_polygon.visible = true
	cone_polygon.modulate.a = 0.3
	
	# Hide after short duration
	var tween = create_tween()
	tween.tween_property(cone_polygon, "modulate:a", 0.0, 0.2)
	tween.tween_callback(func(): cone_polygon.visible = false)

func _handle_debug_spawning(delta: float) -> void:
	# Only auto-shoot projectiles if player has projectile abilities
	if not RunManager.stats.get("has_projectiles", false):
		return
		
	spawn_timer += delta
	var current_interval: float = base_spawn_interval / RunManager.stats.fire_rate_mult
	
	if spawn_timer >= current_interval:
		spawn_timer = 0.0
		_spawn_debug_projectile()

func _spawn_debug_projectile() -> void:
	if not player:
		return
	
	var spawn_pos: Vector2 = player.global_position
	var mouse_pos := get_global_mouse_position()
	var direction := (mouse_pos - spawn_pos).normalized()

	var projectile_count: int = 1 + RunManager.stats.projectile_count_add
	var base_speed: float = 480.0 * RunManager.stats.projectile_speed_mult
	
	for i in range(projectile_count):
		var spread: float = 0.0
		if projectile_count > 1:
			var spread_range: float = 0.4
			spread = RNG.randf_range("waves", -spread_range, spread_range) * (i - projectile_count / 2.0)
		
		var final_direction: Vector2 = direction.rotated(spread)
		ability_system.spawn_projectile(spawn_pos, final_direction, base_speed, 2.0)



func _on_arena_loaded(arena_bounds: Rect2) -> void:
	Logger.info("Arena loaded with bounds: " + str(arena_bounds), "ui")
	
	# Set camera bounds for the new arena
	camera_system.set_arena_bounds(arena_bounds)
	var payload := EventBus.ArenaBoundsChangedPayload_Type.new(arena_bounds)
	EventBus.arena_bounds_changed.emit(payload)

func _get_visible_world_rect() -> Rect2:
	var viewport_size := get_viewport().get_visible_rect().size
	var zoom := camera_system.get_camera_zoom()
	var camera_pos := camera_system.get_camera_position()
	var margin: float = BalanceDB.get_waves_value("enemy_viewport_cull_margin")
	
	var half_size := (viewport_size / zoom) * 0.5 + Vector2(margin, margin)
	return Rect2(camera_pos - half_size, half_size * 2)

func _is_enemy_visible(enemy_pos: Vector2, visible_rect: Rect2) -> bool:
	return visible_rect.has_point(enemy_pos)

# Boss spawning delegate methods - forward calls to BossSpawnManager
func spawn_single_boss_fallback() -> void:
	if boss_spawn_manager:
		boss_spawn_manager.spawn_single_boss_fallback()
	else:
		Logger.error("BossSpawnManager not initialized", "boss")

func spawn_configured_boss(config: BossSpawnConfig, spawn_pos: Vector2) -> void:
	if boss_spawn_manager:
		boss_spawn_manager.spawn_configured_boss(config, spawn_pos)
	else:
		Logger.error("BossSpawnManager not initialized", "boss")



func _exit_tree() -> void:
	# Cleanup signal connections
	if ability_system and multimesh_manager:
		ability_system.projectiles_updated.disconnect(multimesh_manager.update_projectiles)
	if wave_director and multimesh_manager:
		wave_director.enemies_updated.disconnect(multimesh_manager.update_enemies)
	if arena_system:
		arena_system.arena_loaded.disconnect(_on_arena_loaded)
	EventBus.level_up.disconnect(_on_level_up)
