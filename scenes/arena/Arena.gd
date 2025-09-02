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


# ANIMATION CONFIGS
var swarm_animation_config: AnimationConfig
var regular_animation_config: AnimationConfig
var elite_animation_config: AnimationConfig
var boss_animation_config: AnimationConfig

# ANIMATION RENDERING STATE
var swarm_run_textures: Array[ImageTexture] = []
var swarm_current_frame: int = 0
var swarm_frame_timer: float = 0.0
var swarm_frame_duration: float = 0.12

var regular_run_textures: Array[ImageTexture] = []
var regular_current_frame: int = 0
var regular_frame_timer: float = 0.0
var regular_frame_duration: float = 0.1

var elite_run_textures: Array[ImageTexture] = []
var elite_current_frame: int = 0
var elite_frame_timer: float = 0.0
var elite_frame_duration: float = 0.1

var boss_run_textures: Array[ImageTexture] = []
var boss_current_frame: int = 0
var boss_frame_timer: float = 0.0
var boss_frame_duration: float = 0.1
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
	
	# Initialize GameOrchestrator systems and inject them BEFORE setting up dependent systems
	GameOrchestrator.initialize_core_loop()
	GameOrchestrator.inject_systems_to_arena(self)

	# Inject boss hit feedback system to WaveDirector for boss registration
	if GameOrchestrator.wave_director:
		GameOrchestrator.wave_director.boss_hit_feedback = boss_hit_feedback
		Logger.debug("BossHitFeedback injected to WaveDirector", "arena")
	
	_setup_card_system()
	
	
	# Set player reference in PlayerState for cached position access
	PlayerState.set_player_reference(player)
	
	# System signals connected via GameOrchestrator injection
	EventBus.level_up.connect(_on_level_up)
	
	# Setup MultiMesh instances
	_setup_projectile_multimesh()
	_load_swarm_animations()  # Load .tres animations for SWARM tier
	_load_regular_animations()  # Load .tres animations for REGULAR tier
	_load_elite_animations()    # Load .tres animations for ELITE tier
	_load_boss_animations()     # Load .tres animations for BOSS tier
	_setup_tier_multimeshes()
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
	
	# Schedule a test to check if enemies are spawning after a few seconds
	var timer = Timer.new()
	timer.wait_time = 3.0
	timer.one_shot = true
	timer.timeout.connect(_test_enemy_spawning)
	add_child(timer)
	timer.start()

func _test_enemy_spawning() -> void:
	Logger.debug("Enemy spawning test", "debug")
	if wave_director:
		var alive_enemies = wave_director.get_alive_enemies()
		if Logger.is_level_enabled(Logger.LogLevel.DEBUG):
			Logger.debug("Alive enemies: " + str(alive_enemies.size()), "debug")
		
		if alive_enemies.size() > 0:
			_update_enemy_multimesh(alive_enemies)
		else:
			Logger.debug("No enemies spawned yet", "debug")
	else:
		Logger.error("WaveDirector is null!", "ui")

func _setup_projectile_multimesh() -> void:
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_2D
	multimesh.instance_count = 0

	var quad_mesh := QuadMesh.new()
	quad_mesh.size = Vector2(8, 8)
	multimesh.mesh = quad_mesh

	# 8x8 gelber Punkt als Texture bauen
	var img := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	img.fill(Color(1.0, 1.0, 0.0, 1.0))
	var tex := ImageTexture.create_from_image(img)
	mm_projectiles.texture = tex
	mm_projectiles.z_index = 2  # Above walls

	mm_projectiles.multimesh = multimesh

# TIER-BASED ENEMY SYSTEM - optional for performance alongside sprite rendering

func _setup_tier_multimeshes() -> void:
	# Setup SWARM tier MultiMesh (small squares)
	var swarm_multimesh := MultiMesh.new()
	swarm_multimesh.transform_format = MultiMesh.TRANSFORM_2D
	swarm_multimesh.use_colors = true
	swarm_multimesh.instance_count = 0
	var swarm_mesh := QuadMesh.new()
	swarm_mesh.size = Vector2(32, 32)  # 32x32 to match knight sprite frame
	swarm_multimesh.mesh = swarm_mesh
	
	
	# Use .tres-loaded textures for SWARM tier
	if not swarm_run_textures.is_empty():
		mm_enemies_swarm.texture = swarm_run_textures[0]
		if Logger.is_level_enabled(Logger.LogLevel.DEBUG):
			Logger.debug("SWARM tier animation loaded (" + str(swarm_run_textures.size()) + " frames)", "enemies")
	else:
		Logger.error("SWARM tier .tres animation failed to load", "enemies")
	mm_enemies_swarm.multimesh = swarm_multimesh
	mm_enemies_swarm.z_index = 0  # Gameplay entities layer
	
	# Setup REGULAR tier MultiMesh (medium rectangles)
	var regular_multimesh := MultiMesh.new()
	regular_multimesh.transform_format = MultiMesh.TRANSFORM_2D
	regular_multimesh.use_colors = true
	regular_multimesh.instance_count = 0
	var regular_mesh := QuadMesh.new()
	regular_mesh.size = Vector2(32, 32)  # 32x32 to match knight sprite frame
	regular_multimesh.mesh = regular_mesh
	# Use .tres-loaded textures for REGULAR tier
	if not regular_run_textures.is_empty():
		mm_enemies_regular.texture = regular_run_textures[0]
		if Logger.is_level_enabled(Logger.LogLevel.DEBUG):
			Logger.debug("REGULAR tier animation loaded (" + str(regular_run_textures.size()) + " frames)", "enemies")
	else:
		Logger.error("REGULAR tier .tres animation failed to load", "enemies")
	mm_enemies_regular.multimesh = regular_multimesh
	mm_enemies_regular.z_index = 0  # Gameplay entities layer
	
	# Setup ELITE tier MultiMesh (large diamonds)
	var elite_multimesh := MultiMesh.new()
	elite_multimesh.transform_format = MultiMesh.TRANSFORM_2D
	elite_multimesh.use_colors = true
	elite_multimesh.instance_count = 0
	var elite_mesh := QuadMesh.new()
	elite_mesh.size = Vector2(48, 48)  # Larger elite size 
	elite_multimesh.mesh = elite_mesh
	# Use .tres-loaded textures for ELITE tier
	if not elite_run_textures.is_empty():
		mm_enemies_elite.texture = elite_run_textures[0]
		if Logger.is_level_enabled(Logger.LogLevel.DEBUG):
			Logger.debug("ELITE tier animation loaded (" + str(elite_run_textures.size()) + " frames)", "enemies")
	else:
		Logger.error("ELITE tier .tres animation failed to load", "enemies")
	mm_enemies_elite.multimesh = elite_multimesh
	mm_enemies_elite.z_index = 0  # Gameplay entities layer
	
	# Setup BOSS tier MultiMesh (large diamonds)
	var boss_multimesh := MultiMesh.new()
	boss_multimesh.transform_format = MultiMesh.TRANSFORM_2D
	boss_multimesh.use_colors = true
	boss_multimesh.instance_count = 0
	var boss_mesh := QuadMesh.new()
	boss_mesh.size = Vector2(56, 56)  # Largest size for boss distinction (SWARM:32, REGULAR:32, ELITE:48, BOSS:56)
	boss_multimesh.mesh = boss_mesh
	# Use .tres-loaded textures for BOSS tier
	if not boss_run_textures.is_empty():
		mm_enemies_boss.texture = boss_run_textures[0]
		if Logger.is_level_enabled(Logger.LogLevel.DEBUG):
			Logger.debug("BOSS tier animation loaded (" + str(boss_run_textures.size()) + " frames)", "enemies")
	else:
		Logger.error("BOSS tier .tres animation failed to load", "enemies")
	mm_enemies_boss.multimesh = boss_multimesh
	mm_enemies_boss.z_index = 0  # Gameplay entities layer
	
	Logger.debug("Tier MultiMesh instances initialized", "enemies")

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
		_animate_enemy_frames(delta)
	

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
	ability_system.projectiles_updated.connect(_update_projectile_multimesh)

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
	wave_director.enemies_updated.connect(_update_enemy_multimesh)
	
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

func _update_projectile_multimesh(alive_projectiles: Array[Dictionary]) -> void:
	var count := alive_projectiles.size()
	mm_projectiles.multimesh.instance_count = count

	for i in range(count):
		var projectile := alive_projectiles[i]
		var proj_transform := Transform2D()
		proj_transform.origin = projectile["pos"]
		mm_projectiles.multimesh.set_instance_transform_2d(i, proj_transform)

func _update_enemy_multimesh(alive_enemies: Array[EnemyEntity]) -> void:
	if enemy_render_tier == null:
		Logger.warn("EnemyRenderTier is null, skipping tier-based rendering", "enemies")
		return
	
	# Group enemies by tier
	var tier_groups := enemy_render_tier.group_enemies_by_tier(alive_enemies)
	
	# Update each tier's MultiMesh
	_update_tier_multimesh(tier_groups[EnemyRenderTier_Type.Tier.SWARM], mm_enemies_swarm, Vector2(24, 24), EnemyRenderTier_Type.Tier.SWARM)
	_update_tier_multimesh(tier_groups[EnemyRenderTier_Type.Tier.REGULAR], mm_enemies_regular, Vector2(32, 32), EnemyRenderTier_Type.Tier.REGULAR) 
	_update_tier_multimesh(tier_groups[EnemyRenderTier_Type.Tier.ELITE], mm_enemies_elite, Vector2(48, 48), EnemyRenderTier_Type.Tier.ELITE)
	_update_tier_multimesh(tier_groups[EnemyRenderTier_Type.Tier.BOSS], mm_enemies_boss, Vector2(64, 64), EnemyRenderTier_Type.Tier.BOSS)
	
	# Removed excessive tier rendering debug logs

func _update_tier_multimesh(tier_enemies: Array[Dictionary], mm_instance: MultiMeshInstance2D, _base_size: Vector2, tier: EnemyRenderTier_Type.Tier) -> void:
	var count := tier_enemies.size()
	if mm_instance and mm_instance.multimesh:
		mm_instance.multimesh.instance_count = count
		# Removed per-tier update debug log
		
		for i in range(count):
			var enemy := tier_enemies[i]
			
			# Basic transform with position only
			var instance_transform := Transform2D()
			instance_transform.origin = enemy["pos"]
			
			mm_instance.multimesh.set_instance_transform_2d(i, instance_transform)
			
			# Set color based on tier for visual debugging
			var tier_color := _get_tier_debug_color(tier)
			mm_instance.multimesh.set_instance_color(i, tier_color)


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

func _get_enemy_color_for_type(type_id: String) -> Color:
	# Fallback colors based on type_id
	match type_id:
		"knight_swarm":
			return Color(1.0, 0.0, 0.0, 1.0)  # Red
		"knight_regular":
			return Color(0.0, 1.0, 0.0, 1.0)  # Green
		"knight_elite":
			return Color(0.0, 0.0, 1.0, 1.0)  # Blue
		"knight_boss":
			return Color(1.0, 0.0, 1.0, 1.0)  # Magenta
		_:
			return Color(1.0, 0.0, 0.0, 1.0)  # Default red

func _get_tier_debug_color(tier: EnemyRenderTier_Type.Tier) -> Color:
	# Distinct colors for each tier for visual debugging - more saturated for better visibility
	match tier:
		EnemyRenderTier_Type.Tier.SWARM:
			return Color(1.5, 0.3, 0.3, 1.0)  # Bright Red
		EnemyRenderTier_Type.Tier.REGULAR:
			return Color(0.3, 1.5, 1.5, 1.0)  # Bright Cyan
		EnemyRenderTier_Type.Tier.ELITE:
			return Color(1.5, 0.3, 1.5, 1.0)  # Bright Magenta
		EnemyRenderTier_Type.Tier.BOSS:
			return Color(1.8, 0.9, 0.2, 1.0)  # Very Bright Orange
		_:
			return Color(1.0, 1.0, 1.0, 1.0)  # White fallback

# Debug methods moved to DebugController system - Phase 3 Arena Refactoring


func _spawn_single_boss_fallback() -> void:
	var player_pos: Vector2 = player.global_position if player else Vector2.ZERO
	var spawn_pos: Vector2 = player_pos + Vector2(150, 150)  # Legacy hardcoded position
	
	Logger.info("=== LICH SPAWN DEBUG START ===", "debug")
	Logger.info("1. V2 system enabled ✓", "debug")
	Logger.info("2. Spawn position: " + str(spawn_pos), "debug")
	
	# Direct V2 boss spawning - simplified approach
	const EnemyFactory = preload("res://scripts/systems/enemy_v2/EnemyFactory.gd")
	
	# Create boss spawn context
	var spawn_context := {
		"run_id": RunManager.run_seed,
		"wave_index": 999,
		"spawn_index": 0,
		"position": spawn_pos,
		"context_tags": ["boss", "manual_spawn"]
	}
	
	# Generate boss config
	Logger.info("3. Generating boss config from ancient_lich template...", "debug")
	var boss_config = EnemyFactory.spawn_from_template_id("ancient_lich", spawn_context)
	if not boss_config:
		Logger.error("   ✗ Failed to generate V2 boss config", "debug")
		return
	Logger.info("   ✓ Boss config generated successfully", "debug")
	
	# Apply boss scaling
	Logger.info("4. Applying boss scaling...", "debug")
	var original_health = boss_config.health
	var original_damage = boss_config.damage
	boss_config.health *= 5.0  # 5x stronger
	boss_config.damage *= 2.0  # 2x damage
	boss_config.size_scale *= 1.5  # Larger
	Logger.info("   Health: " + str(original_health) + " → " + str(boss_config.health), "debug")
	Logger.info("   Damage: " + str(original_damage) + " → " + str(boss_config.damage), "debug")
	
	# Spawn using existing V2 system
	Logger.info("5. Checking WaveDirector...", "debug")
	if not wave_director:
		Logger.error("   ✗ WaveDirector is null!", "debug")
		return
	if not wave_director.has_method("_spawn_from_config_v2"):
		Logger.error("   ✗ WaveDirector missing _spawn_from_config_v2 method", "debug")
		return
	Logger.info("   ✓ WaveDirector ready", "debug")
	
	Logger.info("6. Converting to legacy enemy type...", "debug")
	var legacy_type := boss_config.to_enemy_type()
	legacy_type.is_special_boss = true
	legacy_type.display_name = "Ancient Lich Boss"
	Logger.info("   Legacy type ID: " + legacy_type.id + ", Health: " + str(legacy_type.health), "debug")
	
	Logger.info("7. Spawning via WaveDirector...", "debug")
	Logger.info("WaveDirector is: " + str(wave_director), "debug")
	Logger.info("About to call _spawn_from_config_v2 with legacy_type=" + str(legacy_type.id) + ", boss_config=" + str(boss_config.template_id), "debug")
	
	if wave_director and wave_director.has_method("_spawn_from_config_v2"):
		Logger.info("WaveDirector has _spawn_from_config_v2 method - calling it", "debug")
		wave_director._spawn_from_config_v2(legacy_type, boss_config)
		Logger.info("_spawn_from_config_v2 call completed", "debug")
	else:
		Logger.warn("WaveDirector missing or doesn't have _spawn_from_config_v2 method", "debug")
	Logger.info("=== LICH SPAWN DEBUG END - SUCCESS! ===", "debug")

func _spawn_configured_boss(config: BossSpawnConfig, spawn_pos: Vector2) -> void:
	Logger.info("=== CONFIGURED BOSS SPAWN START ===", "debug")
	Logger.info("Boss ID: " + config.boss_id, "debug")
	Logger.info("Config: " + config.get_description(), "debug")
	Logger.info("Spawn position: " + str(spawn_pos), "debug")
	
	# Direct V2 boss spawning using configuration
	const EnemyFactory = preload("res://scripts/systems/enemy_v2/EnemyFactory.gd")
	
	# Create boss spawn context
	var spawn_context := {
		"run_id": RunManager.run_seed,
		"wave_index": 999,
		"spawn_index": 0,
		"position": spawn_pos,
		"context_tags": ["boss", "configured_spawn"]
	}
	
	# Generate boss config from template
	Logger.info("Generating boss config from template: " + config.boss_id, "debug")
	var boss_config = EnemyFactory.spawn_from_template_id(config.boss_id, spawn_context)
	if not boss_config:
		Logger.error("Failed to generate boss config for: " + config.boss_id, "debug")
		return
	Logger.info("Boss config generated successfully", "debug")
	
	# Apply boss scaling
	var original_health = boss_config.health
	var original_damage = boss_config.damage
	boss_config.health *= 5.0  # 5x stronger
	boss_config.damage *= 2.0  # 2x damage
	boss_config.size_scale *= 1.5  # Larger
	Logger.info("Scaled - Health: " + str(original_health) + " → " + str(boss_config.health), "debug")
	Logger.info("Scaled - Damage: " + str(original_damage) + " → " + str(boss_config.damage), "debug")
	
	# Spawn using existing V2 system
	if not wave_director:
		Logger.error("WaveDirector is null!", "debug")
		return
	if not wave_director.has_method("_spawn_from_config_v2"):
		Logger.error("WaveDirector missing _spawn_from_config_v2 method", "debug")
		return
	
	# Convert to legacy type and spawn
	var legacy_type := boss_config.to_enemy_type()
	legacy_type.is_special_boss = true
	legacy_type.display_name = config.boss_id.capitalize() + " Boss"
	
	Logger.info("Spawning via WaveDirector...", "debug")
	wave_director._spawn_from_config_v2(legacy_type, boss_config)
	Logger.info("=== CONFIGURED BOSS SPAWN COMPLETE ===", "debug")

# _test_boss_damage moved to DebugController


# All debug methods moved to DebugController - Phase 3 cleanup



# Debug helper methods moved to DebugController - Phase 3 cleanup


func _exit_tree() -> void:
	# Cleanup signal connections
	if ability_system:
		ability_system.projectiles_updated.disconnect(_update_projectile_multimesh)
	if wave_director:
		wave_director.enemies_updated.disconnect(_update_enemy_multimesh)
	if arena_system:
		arena_system.arena_loaded.disconnect(_on_arena_loaded)
	EventBus.level_up.disconnect(_on_level_up)

func _animate_enemy_frames(delta: float) -> void:
	# Animate each tier with .tres-based animation
	_animate_swarm_tier(delta)
	_animate_regular_tier(delta)
	_animate_elite_tier(delta)
	_animate_boss_tier(delta)

func _animate_swarm_tier(delta: float) -> void:
	# Only animate if we have .tres-loaded swarm textures
	if swarm_run_textures.is_empty():
		return
	
	swarm_frame_timer += delta
	if swarm_frame_timer >= swarm_frame_duration:
		swarm_frame_timer = 0.0
		swarm_current_frame = (swarm_current_frame + 1) % swarm_run_textures.size()
		
		# Update SWARM tier texture
		if mm_enemies_swarm and mm_enemies_swarm.multimesh and mm_enemies_swarm.multimesh.instance_count > 0:
			mm_enemies_swarm.texture = swarm_run_textures[swarm_current_frame]

func _animate_regular_tier(delta: float) -> void:
	if regular_run_textures.is_empty():
		return
	
	regular_frame_timer += delta
	if regular_frame_timer >= regular_frame_duration:
		regular_frame_timer = 0.0
		regular_current_frame = (regular_current_frame + 1) % regular_run_textures.size()
		
		# Update REGULAR tier texture
		if mm_enemies_regular and mm_enemies_regular.multimesh and mm_enemies_regular.multimesh.instance_count > 0:
			mm_enemies_regular.texture = regular_run_textures[regular_current_frame]

func _animate_elite_tier(delta: float) -> void:
	if elite_run_textures.is_empty():
		return
	
	elite_frame_timer += delta
	if elite_frame_timer >= elite_frame_duration:
		elite_frame_timer = 0.0
		elite_current_frame = (elite_current_frame + 1) % elite_run_textures.size()
		
		# Update ELITE tier texture
		if mm_enemies_elite and mm_enemies_elite.multimesh and mm_enemies_elite.multimesh.instance_count > 0:
			mm_enemies_elite.texture = elite_run_textures[elite_current_frame]

func _animate_boss_tier(delta: float) -> void:
	if boss_run_textures.is_empty():
		return
	
	boss_frame_timer += delta
	if boss_frame_timer >= boss_frame_duration:
		boss_frame_timer = 0.0
		boss_current_frame = (boss_current_frame + 1) % boss_run_textures.size()
		
		# Update BOSS tier texture
		if mm_enemies_boss and mm_enemies_boss.multimesh and mm_enemies_boss.multimesh.instance_count > 0:
			mm_enemies_boss.texture = boss_run_textures[boss_current_frame]

func _load_swarm_animations() -> void:
	var resource_path := "res://data/animations/swarm_enemy_animations.tres"
	swarm_animation_config = load(resource_path) as AnimationConfig
	if swarm_animation_config == null:
		Logger.warn("Failed to load swarm animation config from: " + resource_path, "enemies")
		return
	
	Logger.debug("Loaded swarm animation config", "enemies")
	_create_swarm_textures()

func _create_swarm_textures() -> void:
	if swarm_animation_config == null:
		Logger.warn("No swarm animation config available", "enemies")
		return
	
	var knight_full := swarm_animation_config.sprite_sheet
	if knight_full == null:
		Logger.warn("Failed to load swarm sprite sheet", "enemies")
		return
	
	var knight_image := knight_full.get_image()
	var frame_width: int = swarm_animation_config.frame_size.x
	var frame_height: int = swarm_animation_config.frame_size.y
	var columns: int = swarm_animation_config.grid_columns
	
	# Load run animation frames from .tres
	var run_anim: Dictionary = swarm_animation_config.animations.run
	swarm_frame_duration = run_anim.duration
	
	swarm_run_textures.clear()
	for frame_idx in run_anim.frames:
		var col: int = int(frame_idx) % columns
		var row: int = int(frame_idx) / columns
		
		var frame_image := Image.create(frame_width, frame_height, false, Image.FORMAT_RGBA8)
		frame_image.blit_rect(knight_image, Rect2i(col * frame_width, row * frame_height, frame_width, frame_height), Vector2i(0, 0))
		var frame_texture := ImageTexture.create_from_image(frame_image)
		swarm_run_textures.append(frame_texture)
	
	if Logger.is_level_enabled(Logger.LogLevel.DEBUG):
		Logger.debug("Created " + str(swarm_run_textures.size()) + " swarm textures", "enemies")

func _load_regular_animations() -> void:
	var resource_path := "res://data/animations/regular_enemy_animations.tres"
	regular_animation_config = load(resource_path) as AnimationConfig
	if regular_animation_config == null:
		Logger.warn("Failed to load regular animation config from: " + resource_path, "enemies")
		return
	
	Logger.debug("Loaded regular animation config", "enemies")
	_create_regular_textures()

func _create_regular_textures() -> void:
	if regular_animation_config == null:
		Logger.warn("No regular animation config available", "enemies")
		return
	
	var knight_full := regular_animation_config.sprite_sheet
	if knight_full == null:
		Logger.warn("Failed to load regular sprite sheet", "enemies")
		return
	
	var knight_image := knight_full.get_image()
	var frame_width: int = regular_animation_config.frame_size.x
	var frame_height: int = regular_animation_config.frame_size.y
	var columns: int = regular_animation_config.grid_columns
	
	var run_anim: Dictionary = regular_animation_config.animations.run
	regular_frame_duration = run_anim.duration
	
	regular_run_textures.clear()
	for frame_idx in run_anim.frames:
		var col: int = int(frame_idx) % columns
		var row: int = int(frame_idx) / columns
		
		var frame_image := Image.create(frame_width, frame_height, false, Image.FORMAT_RGBA8)
		frame_image.blit_rect(knight_image, Rect2i(col * frame_width, row * frame_height, frame_width, frame_height), Vector2i(0, 0))
		var frame_texture := ImageTexture.create_from_image(frame_image)
		regular_run_textures.append(frame_texture)
	
	if Logger.is_level_enabled(Logger.LogLevel.DEBUG):
		Logger.debug("Created " + str(regular_run_textures.size()) + " regular textures", "enemies")

func _load_elite_animations() -> void:
	var resource_path := "res://data/animations/elite_enemy_animations.tres"
	elite_animation_config = load(resource_path) as AnimationConfig
	if elite_animation_config == null:
		Logger.warn("Failed to load elite animation config from: " + resource_path, "enemies")
		return
	
	Logger.debug("Loaded elite animation config", "enemies")
	_create_elite_textures()

func _create_elite_textures() -> void:
	if elite_animation_config == null:
		Logger.warn("No elite animation config available", "enemies")
		return
	
	var knight_full := elite_animation_config.sprite_sheet
	if knight_full == null:
		Logger.warn("Failed to load elite sprite sheet", "enemies")
		return
	
	var knight_image := knight_full.get_image()
	var frame_width: int = elite_animation_config.frame_size.x
	var frame_height: int = elite_animation_config.frame_size.y
	var columns: int = elite_animation_config.grid_columns
	
	var run_anim: Dictionary = elite_animation_config.animations.run
	elite_frame_duration = run_anim.duration
	
	elite_run_textures.clear()
	for frame_idx in run_anim.frames:
		var col: int = int(frame_idx) % columns
		var row: int = int(frame_idx) / columns
		
		var frame_image := Image.create(frame_width, frame_height, false, Image.FORMAT_RGBA8)
		frame_image.blit_rect(knight_image, Rect2i(col * frame_width, row * frame_height, frame_width, frame_height), Vector2i(0, 0))
		var frame_texture := ImageTexture.create_from_image(frame_image)
		elite_run_textures.append(frame_texture)
	
	if Logger.is_level_enabled(Logger.LogLevel.DEBUG):
		Logger.debug("Created " + str(elite_run_textures.size()) + " elite textures", "enemies")

func _load_boss_animations() -> void:
	var resource_path := "res://data/animations/boss_enemy_animations.tres"
	boss_animation_config = load(resource_path) as AnimationConfig
	if boss_animation_config == null:
		Logger.warn("Failed to load boss animation config from: " + resource_path, "enemies")
		return
	
	Logger.debug("Loaded boss animation config", "enemies")
	_create_boss_textures()

func _create_boss_textures() -> void:
	if boss_animation_config == null:
		Logger.warn("No boss animation config available", "enemies")
		return
	
	var knight_full := boss_animation_config.sprite_sheet
	if knight_full == null:
		Logger.warn("Failed to load boss sprite sheet", "enemies")
		return
	
	var knight_image := knight_full.get_image()
	var frame_width: int = boss_animation_config.frame_size.x
	var frame_height: int = boss_animation_config.frame_size.y
	var columns: int = boss_animation_config.grid_columns
	
	var run_anim: Dictionary = boss_animation_config.animations.run
	boss_frame_duration = run_anim.duration
	
	boss_run_textures.clear()
	for frame_idx in run_anim.frames:
		var col: int = int(frame_idx) % columns
		var row: int = int(frame_idx) / columns
		
		var frame_image := Image.create(frame_width, frame_height, false, Image.FORMAT_RGBA8)
		frame_image.blit_rect(knight_image, Rect2i(col * frame_width, row * frame_height, frame_width, frame_height), Vector2i(0, 0))
		var frame_texture := ImageTexture.create_from_image(frame_image)
		boss_run_textures.append(frame_texture)
	
	if Logger.is_level_enabled(Logger.LogLevel.DEBUG):
		Logger.debug("Created " + str(boss_run_textures.size()) + " boss textures", "enemies")
