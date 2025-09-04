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
const PlayerAttackHandler := preload("res://scripts/systems/PlayerAttackHandler.gd")
const VisualEffectsManager := preload("res://scripts/systems/VisualEffectsManager.gd")
const SystemInjectionManager := preload("res://scripts/systems/SystemInjectionManager.gd")
const ArenaInputHandler := preload("res://scripts/systems/ArenaInputHandler.gd")

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
var player_attack_handler: PlayerAttackHandler


var wave_director: WaveDirector
var damage_system: DamageSystem
var arena_system: ArenaSystem
var camera_system: CameraSystem
var enemy_render_tier: EnemyRenderTier
var visual_effects_manager: VisualEffectsManager
var system_injection_manager: SystemInjectionManager
var arena_input_handler: ArenaInputHandler

@export_group("Boss Hit Feedback Settings")
@export var boss_knockback_force: float = 12.0: ## Multiplier for boss knockback force
	set(value):
		boss_knockback_force = value
		if visual_effects_manager:
			visual_effects_manager.set_boss_knockback_force(value)
@export var boss_knockback_duration: float = 2.0: ## Duration multiplier for boss knockback
	set(value):
		boss_knockback_duration = value
		if visual_effects_manager:
			visual_effects_manager.set_boss_knockback_duration(value)
@export var boss_hit_stop_duration: float = 0.15: ## Freeze time on boss hit impact
	set(value):
		boss_hit_stop_duration = value
		if visual_effects_manager:
			visual_effects_manager.set_boss_hit_stop_duration(value)
@export var boss_velocity_decay: float = 0.82: ## Boss knockback decay rate (0.7-0.95)
	set(value):
		boss_velocity_decay = value
		if visual_effects_manager:
			visual_effects_manager.set_boss_velocity_decay(value)
@export var boss_flash_duration: float = 0.2: ## Boss flash effect duration
	set(value):
		boss_flash_duration = value
		if visual_effects_manager:
			visual_effects_manager.set_boss_flash_duration(value)
@export var boss_flash_intensity: float = 5.0: ## Boss flash effect intensity
	set(value):
		boss_flash_intensity = value
		if visual_effects_manager:
			visual_effects_manager.set_boss_flash_intensity(value)

@export_group("Boss Spawn Configuration")
@export var boss_spawn_configs: Array[BossSpawnConfig] = []: ## Configurable boss spawn positions and settings
	set(value):
		boss_spawn_configs = value
		notify_property_list_changed()

@export var enable_debug_boss_spawning: bool = true: ## Enable debug boss spawning (B key)
	set(value):
		enable_debug_boss_spawning = value


var player: Player
var xp_system: XpSystem
var card_system: CardSystem
# UI elements now managed by ArenaUIManager

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
	
	# Create visual effects manager and setup hit feedback systems
	visual_effects_manager = VisualEffectsManager.new()
	visual_effects_manager.boss_knockback_force = boss_knockback_force
	visual_effects_manager.boss_knockback_duration = boss_knockback_duration
	visual_effects_manager.boss_hit_stop_duration = boss_hit_stop_duration
	visual_effects_manager.boss_velocity_decay = boss_velocity_decay
	visual_effects_manager.boss_flash_duration = boss_flash_duration
	visual_effects_manager.boss_flash_intensity = boss_flash_intensity
	add_child(visual_effects_manager)
	visual_effects_manager.setup_hit_feedback_systems()
	
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
	
	# Setup Player Attack Handler
	player_attack_handler = PlayerAttackHandler.new()
	add_child(player_attack_handler)
	
	# Setup System Injection Manager
	system_injection_manager = SystemInjectionManager.new()
	add_child(system_injection_manager)
	system_injection_manager.setup(self)
	
	# Initialize GameOrchestrator systems and inject them AFTER MultiMesh Manager is ready
	GameOrchestrator.initialize_core_loop()
	GameOrchestrator.inject_systems_to_arena(self)

	# Inject boss hit feedback system to WaveDirector for boss registration
	if GameOrchestrator.wave_director:
		GameOrchestrator.wave_director.boss_hit_feedback = visual_effects_manager.get_boss_hit_feedback()
		Logger.debug("BossHitFeedback injected to WaveDirector", "arena")
	
	_setup_card_system()
	
	
	# Set player reference in PlayerState for cached position access
	PlayerState.set_player_reference(player)
	
	# Setup Boss Spawn Manager with dependencies
	boss_spawn_manager.setup(wave_director, player)
	
	# Setup Player Attack Handler with dependencies
	player_attack_handler.setup(player, melee_system, ability_system, wave_director, melee_effects, get_viewport())
	
	# Setup Arena Input Handler
	arena_input_handler = ArenaInputHandler.new()
	add_child(arena_input_handler)
	arena_input_handler.setup(ui_manager, melee_system, player_attack_handler, self)
	
	# System signals connected via GameOrchestrator injection
	EventBus.level_up.connect(_on_level_up)
	_setup_enemy_animation_system()
	_setup_enemy_transforms()
	
	# Setup visual effects manager with MultiMesh references and dependencies
	if visual_effects_manager:
		visual_effects_manager.setup_enemy_feedback_references(mm_enemies_swarm, mm_enemies_regular, mm_enemies_elite, mm_enemies_boss)
		# Configure dependencies if available
		if enemy_render_tier or wave_director:
			visual_effects_manager.configure_enemy_feedback_dependencies(enemy_render_tier, wave_director)
	
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
		player_attack_handler.handle_debug_spawning(delta)
		player_attack_handler.handle_auto_attack()
		# Animation handled by dedicated system
		if enemy_animation_system:
			enemy_animation_system.animate_frames(delta)
	

# PHASE 14: Input handling now managed by ArenaInputHandler

func _setup_player() -> void:
	# Load player scene dynamically to support @export hot-reload
	var player_scene = load("res://scenes/arena/Player.tscn") as PackedScene
	player = player_scene.instantiate()
	player.global_position = Vector2(0, 0)  # Center of arena
	add_child(player)
	
	# Camera setup now handled in injection method

func _setup_xp_system() -> void:
	xp_system = XpSystem.new(self)
	add_child(xp_system)
	# XP system is created locally, not injected by GameOrchestrator

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

# PHASE 13: System injection now handled by SystemInjectionManager
# All injection methods delegated to centralized manager

func inject_systems(systems: Dictionary) -> void:
	if system_injection_manager:
		system_injection_manager.inject_systems(systems)

func set_card_system(injected_card_system: CardSystem) -> void:
	if system_injection_manager:
		system_injection_manager.set_card_system(injected_card_system)

func set_ability_system(injected_ability_system: AbilitySystem) -> void:
	if system_injection_manager:
		system_injection_manager.set_ability_system(injected_ability_system)

func set_arena_system(injected_arena_system: ArenaSystem) -> void:
	if system_injection_manager:
		system_injection_manager.set_arena_system(injected_arena_system)

func set_camera_system(injected_camera_system: CameraSystem) -> void:
	if system_injection_manager:
		system_injection_manager.set_camera_system(injected_camera_system)

func set_wave_director(injected_wave_director: WaveDirector) -> void:
	if system_injection_manager:
		system_injection_manager.set_wave_director(injected_wave_director)

func set_melee_system(injected_melee_system: MeleeSystem) -> void:
	if system_injection_manager:
		system_injection_manager.set_melee_system(injected_melee_system)

func set_damage_system(injected_damage_system: DamageSystem) -> void:
	if system_injection_manager:
		system_injection_manager.set_damage_system(injected_damage_system)

func setup_debug_controller() -> void:
	# Create and configure DebugController with system dependencies
	debug_controller = DebugController.new()
	add_child(debug_controller)
	
	# Use SystemInjectionManager for DebugController setup
	if system_injection_manager:
		system_injection_manager.setup_debug_controller()
	else:
		Logger.error("SystemInjectionManager not available for DebugController setup", "systems")

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
