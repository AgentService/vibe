extends Node2D

## Arena scene managing MultiMesh rendering and debug projectile spawning.
## Renders projectile pool via single MultiMeshInstance2D.

const AnimationConfig = preload("res://scripts/domain/AnimationConfig.gd")

const PLAYER_SCENE: PackedScene = preload("res://scenes/arena/Player.tscn")
const HUD_SCENE: PackedScene = preload("res://scenes/ui/HUD.tscn")
const CARD_PICKER_SCENE: PackedScene = preload("res://scenes/ui/CardPicker.tscn")
const ArenaSystem := preload("res://scripts/systems/ArenaSystem.gd")
# Removed non-existent subsystem imports - systems simplified
# TextureThemeSystem removed - no longer needed after arena simplification
const CameraSystem := preload("res://scripts/systems/CameraSystem.gd")
const EnemyRenderTier := preload("res://scripts/systems/EnemyRenderTier.gd")

@onready var mm_projectiles: MultiMeshInstance2D = $MM_Projectiles
# TIER-BASED ENEMY RENDERING SYSTEM
@onready var mm_enemies_swarm: MultiMeshInstance2D = $MM_Enemies_Swarm
@onready var mm_enemies_regular: MultiMeshInstance2D = $MM_Enemies_Regular
@onready var mm_enemies_elite: MultiMeshInstance2D = $MM_Enemies_Elite
@onready var mm_enemies_boss: MultiMeshInstance2D = $MM_Enemies_Boss
# Removed unused MultiMesh references (walls, terrain, obstacles, interactables)
@onready var melee_effects: Node2D = $MeleeEffects
@onready var ability_system: AbilitySystem = AbilitySystem.new()
@onready var melee_system: MeleeSystem = MeleeSystem.new()


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
@onready var wave_director: WaveDirector = WaveDirector.new()
@onready var damage_system: DamageSystem = DamageSystem.new()
@onready var arena_system: ArenaSystem = ArenaSystem.new()
# texture_theme_system removed - no longer needed after arena simplification
@onready var camera_system: CameraSystem = CameraSystem.new()
# enemy_behavior_system removed - AI logic moved to WaveDirector
var enemy_render_tier: EnemyRenderTier

var player: Player
var xp_system: XpSystem
var hud: HUD
var card_picker: CardPicker

var spawn_timer: float = 0.0
var base_spawn_interval: float = 0.25

var _enemy_transforms: Array[Transform2D] = []



func _ready() -> void:
	Logger.info("ARENA READY FUNCTION STARTING", "ui")
	
	# Arena input should work during pause for debug controls
	process_mode = Node.PROCESS_MODE_ALWAYS
	Logger.info("Arena process mode set to ALWAYS", "ui")
	
	# Set proper process modes for systems (with null checks)
	Logger.info("Setting system process modes...", "ui")
	if ability_system:
		ability_system.process_mode = Node.PROCESS_MODE_PAUSABLE
	if melee_system:
		melee_system.process_mode = Node.PROCESS_MODE_PAUSABLE
	if wave_director:
		wave_director.process_mode = Node.PROCESS_MODE_PAUSABLE
	if damage_system:
		damage_system.process_mode = Node.PROCESS_MODE_PAUSABLE
	# texture_theme_system removed
	if arena_system:
		arena_system.process_mode = Node.PROCESS_MODE_PAUSABLE
	if camera_system:
		camera_system.process_mode = Node.PROCESS_MODE_PAUSABLE
	# enemy_behavior_system removed
	Logger.info("System process modes set", "ui")
	
	Logger.info("Adding systems as children...", "ui")
	if ability_system:
		add_child(ability_system)
		Logger.info("ability_system added", "ui")
	if melee_system:
		add_child(melee_system)
		Logger.info("melee_system added", "ui")
	if wave_director:
		add_child(wave_director)
		Logger.info("wave_director added", "ui")
	if damage_system:
		add_child(damage_system)
		Logger.info("damage_system added", "ui")
	# texture_theme_system removed
	if arena_system:
		add_child(arena_system)
		Logger.info("arena_system added", "ui")
	if camera_system:
		add_child(camera_system)
		Logger.info("camera_system added", "ui")
	# enemy_behavior_system removed
	Logger.info("All systems added as children", "ui")
	
	Logger.info("All systems added as children, continuing setup...", "enemies")
	
	# Set references for damage system (legitimate dependency injection)
	Logger.info("Setting system references...", "ui")
	if damage_system and ability_system and wave_director:
		damage_system.set_references(ability_system, wave_director)
		Logger.info("Damage system references set", "ui")
	
	# Enemy behavior system removed - AI logic moved to WaveDirector
	
	Logger.info("About to create enemy render tier...", "ui")
	
	# Test if EnemyRenderTier class exists
	if EnemyRenderTier == null:
		Logger.error("EnemyRenderTier class is null!", "ui")
		return
	
	# Create enemy render tier system manually
	enemy_render_tier = EnemyRenderTier.new()
	Logger.info("Enemy render tier created", "ui")
	
	# Test if the instance was created
	if enemy_render_tier == null:
		Logger.error("EnemyRenderTier instance creation failed!", "ui")
		return
	
	Logger.info("EnemyRenderTier instance verified", "ui")
	
	Logger.info("Adding EnemyRenderTier as child...", "ui")
	add_child(enemy_render_tier)
	Logger.info("Enemy render tier system added to Arena", "ui")
	
	# Force call ready if needed
	if not enemy_render_tier.is_node_ready():
		Logger.info("Manually calling enemy_render_tier._ready()", "ui")
		enemy_render_tier._ready()
	else:
		Logger.info("EnemyRenderTier is already ready", "ui")
	
	# Test tier system functionality
	var test_enemy = {"size": Vector2(20, 20), "type_id": "test"}
	var test_tier = enemy_render_tier.get_tier_for_enemy(test_enemy)
	Logger.info("Test enemy tier: " + enemy_render_tier.get_tier_name(test_tier), "ui")
	
	# Create and add new systems
	Logger.info("Starting player setup...", "ui")
	_setup_player()
	Logger.info("Starting XP system setup...", "ui")
	_setup_xp_system()
	Logger.info("Starting UI setup...", "ui")
	_setup_ui()
	Logger.info("Setup functions completed", "ui")
	
	# Set player reference in PlayerState for cached position access
	Logger.info("Setting player reference...", "ui")
	PlayerState.set_player_reference(player)
	
	# Connect signals AFTER systems are added and ready
	Logger.info("Connecting signals...", "ui")
	ability_system.projectiles_updated.connect(_update_projectile_multimesh)
	wave_director.enemies_updated.connect(_update_enemy_multimesh)
	Logger.info("Connected enemy MultiMesh rendering", "ui")
	
	arena_system.arena_loaded.connect(_on_arena_loaded)
	EventBus.level_up.connect(_on_level_up)
	
	# Connect melee system signals for visual effects
	melee_system.melee_attack_started.connect(_on_melee_attack_started)
	
	# Theme system removed - no longer needed after arena simplification
	Logger.info("Signals connected", "ui")
	
	# Arena subsystem signals will be connected after arena loads
	
	Logger.info("Setting up MultiMesh instances...", "ui")
	_setup_projectile_multimesh()
	Logger.info("Projectile MultiMesh setup complete", "ui")
	# TIER-BASED ENEMY SYSTEM - optional for performance
	_load_swarm_animations()  # Load .tres animations for SWARM tier
	_load_regular_animations()  # Load .tres animations for REGULAR tier
	_load_elite_animations()    # Load .tres animations for ELITE tier
	_load_boss_animations()     # Load .tres animations for BOSS tier
	_setup_tier_multimeshes()
	Logger.info("Tier MultiMesh setup complete", "ui")
	_setup_enemy_transforms()
	Logger.info("Enemy transforms setup complete", "ui")
	Logger.info("All MultiMesh setup complete", "ui")
	
	# Arena system now loads default arena automatically
	Logger.info("Using default arena...", "ui")
	
	# Print debug help
	_print_debug_help()
	Logger.info("ARENA READY FUNCTION COMPLETED", "ui")
	
	# Schedule a test to check if enemies are spawning after a few seconds
	var timer = Timer.new()
	timer.wait_time = 3.0
	timer.one_shot = true
	timer.timeout.connect(_test_enemy_spawning)
	add_child(timer)
	timer.start()
	Logger.info("Scheduled enemy spawning test in 3 seconds", "ui")

func _test_enemy_spawning() -> void:
	Logger.info("=== ENEMY SPAWNING TEST ===", "ui")
	if wave_director:
		var alive_enemies = wave_director.get_alive_enemies()
		Logger.info("Total alive enemies: " + str(alive_enemies.size()), "ui")
		
		if alive_enemies.size() > 0:
			var first_enemy = alive_enemies[0]
			Logger.info("First enemy type: " + str(first_enemy.get("type_id", "unknown")), "ui")
			Logger.info("First enemy size: " + str(first_enemy.get("size", Vector2.ZERO)), "ui")
			
			# Test calling _update_enemy_multimesh directly
			Logger.info("Testing direct call to _update_enemy_multimesh...", "ui")
			_update_enemy_multimesh(alive_enemies)
		else:
			Logger.warn("No enemies are alive!", "ui")
	else:
		Logger.error("WaveDirector is null!", "ui")
	Logger.info("=== END TEST ===", "ui")

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
		Logger.info("SWARM tier using .tres-based animation (" + str(swarm_run_textures.size()) + " frames)", "enemies")
	else:
		Logger.error("SWARM tier .tres animation failed to load", "enemies")
	mm_enemies_swarm.multimesh = swarm_multimesh
	mm_enemies_swarm.z_index = -1  # Render behind sprites
	
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
		Logger.info("REGULAR tier using .tres-based animation (" + str(regular_run_textures.size()) + " frames)", "enemies")
	else:
		Logger.error("REGULAR tier .tres animation failed to load", "enemies")
	mm_enemies_regular.multimesh = regular_multimesh
	mm_enemies_regular.z_index = -1  # Render behind sprites
	
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
		Logger.info("ELITE tier using .tres-based animation (" + str(elite_run_textures.size()) + " frames)", "enemies")
	else:
		Logger.error("ELITE tier .tres animation failed to load", "enemies")
	mm_enemies_elite.multimesh = elite_multimesh
	mm_enemies_elite.z_index = -1  # Render behind sprites
	
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
		Logger.info("BOSS tier using .tres-based animation (" + str(boss_run_textures.size()) + " frames)", "enemies")
	else:
		Logger.error("BOSS tier .tres animation failed to load", "enemies")
	mm_enemies_boss.multimesh = boss_multimesh
	mm_enemies_boss.z_index = -1  # Render behind sprites
	
	Logger.info("Tier-specific MultiMesh instances initialized with 16-frame knight running animation", "enemies")

func _setup_enemy_transforms() -> void:
	var cache_size: int = BalanceDB.get_waves_value("enemy_transform_cache_size")
	_enemy_transforms.resize(cache_size)
	for i in range(cache_size):
		_enemy_transforms[i] = Transform2D()
	Logger.debug("Enemy transform cache initialized with " + str(cache_size) + " transforms", "performance")

# Removed unused MultiMesh setup functions (walls, terrain, obstacles, interactables)

func _process(delta: float) -> void:
	# Don't handle debug spawning when game is paused
	if not get_tree().paused:
		_handle_debug_spawning(delta)
		_handle_auto_attack()
		_animate_enemy_frames(delta)
	

func _input(event: InputEvent) -> void:
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
	
	if event is InputEventKey and event.pressed:
		match event.keycode:
			# Arena switching removed - now using single default arena
			KEY_T:
				Logger.info("Theme switching disabled - no longer needed after arena simplification", "ui")
			KEY_F10:
				Logger.info("Manual pause toggle", "ui")
				PauseManager.toggle_pause()
			KEY_F11:
				Logger.info("Spawning 1000 enemies for stress test", "performance")
				_spawn_stress_test_enemies()
			KEY_F12:
				Logger.info("Performance stats toggle", "performance")
				_toggle_performance_stats()

func _setup_player() -> void:
	player = PLAYER_SCENE.instantiate()
	player.global_position = Vector2(0, 0)  # Center of arena
	add_child(player)
	
	# Setup camera to follow player
	camera_system.setup_camera(player)
	Logger.debug("Player positioned at arena center: " + str(player.global_position), "player")

func _setup_xp_system() -> void:
	xp_system = XpSystem.new(self)
	add_child(xp_system)

func _setup_ui() -> void:
	# Create CanvasLayer for UI
	var ui_layer: CanvasLayer = CanvasLayer.new()
	ui_layer.name = "UILayer"
	add_child(ui_layer)
	
	hud = HUD_SCENE.instantiate()
	ui_layer.add_child(hud)
	
	
	card_picker = CARD_PICKER_SCENE.instantiate()
	ui_layer.add_child(card_picker)


func _on_level_up(payload) -> void:
	PauseManager.pause_game(true)
	card_picker.open()

# Theme functions removed - no longer needed after arena simplification

func _on_enemies_updated(alive_enemies: Array[Dictionary]) -> void:
	pass

func _handle_melee_attack(target_pos: Vector2) -> void:
	if not player or not melee_system:
		return
	
	var player_pos = player.global_position
	var alive_enemies = wave_director.get_alive_enemies()
	melee_system.perform_attack(player_pos, target_pos, alive_enemies)

func _handle_projectile_attack(target_pos: Vector2) -> void:
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

func _update_enemy_multimesh(alive_enemies: Array[Dictionary]) -> void:
	if enemy_render_tier == null:
		Logger.warn("EnemyRenderTier is null, skipping tier-based rendering", "enemies")
		return
	
	# Group enemies by tier
	var tier_groups := enemy_render_tier.group_enemies_by_tier(alive_enemies)
	
	# Update each tier's MultiMesh
	_update_tier_multimesh(tier_groups[EnemyRenderTier.Tier.SWARM], mm_enemies_swarm, Vector2(24, 24), EnemyRenderTier.Tier.SWARM)
	_update_tier_multimesh(tier_groups[EnemyRenderTier.Tier.REGULAR], mm_enemies_regular, Vector2(32, 32), EnemyRenderTier.Tier.REGULAR) 
	_update_tier_multimesh(tier_groups[EnemyRenderTier.Tier.ELITE], mm_enemies_elite, Vector2(48, 48), EnemyRenderTier.Tier.ELITE)
	_update_tier_multimesh(tier_groups[EnemyRenderTier.Tier.BOSS], mm_enemies_boss, Vector2(64, 64), EnemyRenderTier.Tier.BOSS)
	
	Logger.debug("Updated tier rendering - SWARM: " + str(tier_groups[EnemyRenderTier.Tier.SWARM].size()) + 
				", REGULAR: " + str(tier_groups[EnemyRenderTier.Tier.REGULAR].size()) + 
				", ELITE: " + str(tier_groups[EnemyRenderTier.Tier.ELITE].size()) + 
				", BOSS: " + str(tier_groups[EnemyRenderTier.Tier.BOSS].size()), "enemies")

func _update_tier_multimesh(tier_enemies: Array[Dictionary], mm_instance: MultiMeshInstance2D, base_size: Vector2, tier: EnemyRenderTier.Tier) -> void:
	var count := tier_enemies.size()
	if mm_instance and mm_instance.multimesh:
		mm_instance.multimesh.instance_count = count
		Logger.debug("Updated MultiMesh for tier with " + str(count) + " enemies (base_size: " + str(base_size) + ")", "enemies")
		
		for i in range(count):
			var enemy := tier_enemies[i]
			
			# Basic transform with position only
			var transform := Transform2D()
			transform.origin = enemy["pos"]
			
			mm_instance.multimesh.set_instance_transform_2d(i, transform)
			
			# Set color based on tier for visual debugging
			var tier_color := _get_tier_debug_color(tier)
			mm_instance.multimesh.set_instance_color(i, tier_color)

# Removed unused MultiMesh update functions (walls, terrain, obstacles, interactables)

func _on_arena_loaded(arena_bounds: Rect2) -> void:
	Logger.info("Arena loaded with bounds: " + str(arena_bounds), "ui")
	
	# Set camera bounds for the new arena
	camera_system.set_arena_bounds(arena_bounds)
	var payload := EventBus.ArenaBoundsChangedPayload.new(arena_bounds)
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

func _get_tier_debug_color(tier: EnemyRenderTier.Tier) -> Color:
	# Distinct colors for each tier for visual debugging - more saturated for better visibility
	match tier:
		EnemyRenderTier.Tier.SWARM:
			return Color(1.5, 0.3, 0.3, 1.0)  # Bright Red
		EnemyRenderTier.Tier.REGULAR:
			return Color(0.3, 1.5, 1.5, 1.0)  # Bright Cyan
		EnemyRenderTier.Tier.ELITE:
			return Color(1.5, 0.3, 1.5, 1.0)  # Bright Magenta
		EnemyRenderTier.Tier.BOSS:
			return Color(1.8, 0.9, 0.2, 1.0)  # Very Bright Orange
		_:
			return Color(1.0, 1.0, 1.0, 1.0)  # White fallback

func _spawn_stress_test_enemies() -> void:
	if not wave_director:
		Logger.warn("WaveDirector not available for stress test", "performance")
		return
	
	var target_pos: Vector2 = player.global_position if player else Vector2.ZERO
	var spawn_count: int = 1000
	var spawned: int = 0
	
	for i in range(spawn_count):
		# Spawn enemies in a circle around player
		var angle: float = (i / float(spawn_count)) * TAU
		var distance: float = 300.0 + (i % 10) * 100.0  # Vary distances
		var spawn_pos: Vector2 = target_pos + Vector2.from_angle(angle) * distance
		
		if wave_director.spawn_enemy_at(spawn_pos, "grunt"):
			spawned += 1
		else:
			break  # Pool exhausted
	
	Logger.info("Stress test: spawned " + str(spawned) + " enemies", "performance")

func _toggle_performance_stats() -> void:
	# Force HUD debug overlay toggle
	if hud and hud.has_method("_toggle_debug_overlay"):
		hud._toggle_debug_overlay()
	else:
		# Print stats to console if HUD toggle not available
		_print_performance_stats()



func _print_debug_help() -> void:
	Logger.info("=== Debug Controls ===", "ui")
	Logger.info("F10: Pause/resume toggle", "ui")
	Logger.info("F12: Performance stats toggle", "ui")
	Logger.info("WASD: Move player", "ui")
	Logger.info("FPS overlay: Always visible", "ui")
	Logger.info("", "ui")

func _print_performance_stats() -> void:
	var stats: Dictionary = get_debug_stats()
	var fps: int = Engine.get_frames_per_second()
	var memory: int = OS.get_static_memory_usage() / 1024 / 1024
	
	Logger.info("=== Performance Stats ===", "performance")
	Logger.info("FPS: " + str(fps), "performance")
	Logger.info("Memory: " + str(memory) + " MB", "performance")
	Logger.info("Total enemies: " + str(stats.get("enemy_count", 0)), "performance")
	Logger.info("Visible enemies: " + str(stats.get("visible_enemies", 0)), "performance")
	Logger.info("Projectiles: " + str(stats.get("projectile_count", 0)), "performance")
	Logger.info("Active sprites: " + str(stats.get("active_sprites", 0)), "performance")

func get_debug_stats() -> Dictionary:
	var stats: Dictionary = {}
	
	if wave_director:
		var alive_enemies: Array[Dictionary] = wave_director.get_alive_enemies()
		stats["enemy_count"] = alive_enemies.size()
		
		# Add culling stats
		var visible_rect: Rect2 = _get_visible_world_rect()
		var visible_count: int = 0
		for enemy in alive_enemies:
			if _is_enemy_visible(enemy["pos"], visible_rect):
				visible_count += 1
		stats["visible_enemies"] = visible_count
	
	if ability_system:
		var alive_projectiles: Array[Dictionary] = ability_system.get_alive_projectiles()
		stats["projectile_count"] = alive_projectiles.size()
	
	
	return stats


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
	
	Logger.info("Loaded swarm animation config from .tres", "enemies")
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
	
	Logger.info("Created " + str(swarm_run_textures.size()) + " swarm animation textures", "enemies")

func _load_regular_animations() -> void:
	var resource_path := "res://data/animations/regular_enemy_animations.tres"
	regular_animation_config = load(resource_path) as AnimationConfig
	if regular_animation_config == null:
		Logger.warn("Failed to load regular animation config from: " + resource_path, "enemies")
		return
	
	Logger.info("Loaded regular animation config from .tres", "enemies")
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
	
	Logger.info("Created " + str(regular_run_textures.size()) + " regular animation textures", "enemies")

func _load_elite_animations() -> void:
	var resource_path := "res://data/animations/elite_enemy_animations.tres"
	elite_animation_config = load(resource_path) as AnimationConfig
	if elite_animation_config == null:
		Logger.warn("Failed to load elite animation config from: " + resource_path, "enemies")
		return
	
	Logger.info("Loaded elite animation config from .tres", "enemies")
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
	
	Logger.info("Created " + str(elite_run_textures.size()) + " elite animation textures", "enemies")

func _load_boss_animations() -> void:
	var resource_path := "res://data/animations/boss_enemy_animations.tres"
	boss_animation_config = load(resource_path) as AnimationConfig
	if boss_animation_config == null:
		Logger.warn("Failed to load boss animation config from: " + resource_path, "enemies")
		return
	
	Logger.info("Loaded boss animation config from .tres", "enemies")
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
	
	Logger.info("Created " + str(boss_run_textures.size()) + " boss animation textures", "enemies")
