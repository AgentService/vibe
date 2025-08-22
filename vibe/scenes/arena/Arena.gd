extends Node2D

## Arena scene managing MultiMesh rendering and debug projectile spawning.
## Renders projectile pool via single MultiMeshInstance2D.

const PLAYER_SCENE: PackedScene = preload("res://scenes/arena/Player.tscn")
const HUD_SCENE: PackedScene = preload("res://scenes/ui/HUD.tscn")
const CARD_PICKER_SCENE: PackedScene = preload("res://scenes/ui/CardPicker.tscn")
const ArenaSystem := preload("res://scripts/systems/ArenaSystem.gd")
const TerrainSystem := preload("res://scripts/systems/TerrainSystem.gd")
const ObstacleSystem := preload("res://scripts/systems/ObstacleSystem.gd")
const InteractableSystem := preload("res://scripts/systems/InteractableSystem.gd")
const RoomLoader := preload("res://scripts/systems/RoomLoader.gd")
const TextureThemeSystem := preload("res://scripts/systems/TextureThemeSystem.gd")
const CameraSystem := preload("res://scripts/systems/CameraSystem.gd")
const EnemyRenderTier := preload("res://scripts/systems/EnemyRenderTier.gd")

@onready var mm_projectiles: MultiMeshInstance2D = $MM_Projectiles
# TIER-BASED ENEMY RENDERING SYSTEM
@onready var mm_enemies_swarm: MultiMeshInstance2D = $MM_Enemies_Swarm
@onready var mm_enemies_regular: MultiMeshInstance2D = $MM_Enemies_Regular
@onready var mm_enemies_elite: MultiMeshInstance2D = $MM_Enemies_Elite
@onready var mm_enemies_boss: MultiMeshInstance2D = $MM_Enemies_Boss
@onready var mm_walls: MultiMeshInstance2D = $MM_Walls
@onready var mm_terrain: MultiMeshInstance2D = $MM_Terrain
@onready var mm_obstacles: MultiMeshInstance2D = $MM_Obstacles
@onready var mm_interactables: MultiMeshInstance2D = $MM_Interactables
@onready var melee_effects: Node2D = $MeleeEffects
@onready var ability_system: AbilitySystem = AbilitySystem.new()
@onready var melee_system: MeleeSystem = MeleeSystem.new()
@onready var wave_director: WaveDirector = WaveDirector.new()
@onready var damage_system: DamageSystem = DamageSystem.new()
@onready var arena_system: ArenaSystem = ArenaSystem.new()
@onready var texture_theme_system: TextureThemeSystem = TextureThemeSystem.new()
@onready var camera_system: CameraSystem = CameraSystem.new()
@onready var enemy_behavior_system: EnemyBehaviorSystem = EnemyBehaviorSystem.new()
var enemy_render_tier: EnemyRenderTier

var player: Player
var xp_system: XpSystem
var hud: HUD
var card_picker: CardPicker

var spawn_timer: float = 0.0
var base_spawn_interval: float = 0.25

# Cached Transform2D objects for enemy MultiMesh rendering
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
	if texture_theme_system:
		texture_theme_system.process_mode = Node.PROCESS_MODE_ALWAYS
	if arena_system:
		arena_system.process_mode = Node.PROCESS_MODE_PAUSABLE
	if camera_system:
		camera_system.process_mode = Node.PROCESS_MODE_PAUSABLE
	if enemy_behavior_system:
		enemy_behavior_system.process_mode = Node.PROCESS_MODE_PAUSABLE
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
	if texture_theme_system:
		add_child(texture_theme_system)
		Logger.info("texture_theme_system added", "ui")
	if arena_system:
		add_child(arena_system)
		Logger.info("arena_system added", "ui")
	if camera_system:
		add_child(camera_system)
		Logger.info("camera_system added", "ui")
	if enemy_behavior_system:
		add_child(enemy_behavior_system)
		Logger.info("enemy_behavior_system added", "ui")
	Logger.info("All systems added as children", "ui")
	
	Logger.info("All systems added as children, continuing setup...", "enemies")
	
	# Set references for damage system (legitimate dependency injection)
	Logger.info("Setting system references...", "ui")
	if damage_system and ability_system and wave_director:
		damage_system.set_references(ability_system, wave_director)
		Logger.info("Damage system references set", "ui")
	
	# Set reference for enemy behavior system
	if enemy_behavior_system and wave_director:
		enemy_behavior_system.set_wave_director(wave_director)
		Logger.info("Enemy behavior system references set", "ui")
	
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
	Logger.info("Connected wave_director.enemies_updated signal", "ui")
	
	# Test if signal connection worked
	if wave_director.enemies_updated.is_connected(_update_enemy_multimesh):
		Logger.info("Signal connection verified", "ui")
	else:
		Logger.error("Signal connection FAILED!", "ui")
	arena_system.arena_loaded.connect(_on_arena_loaded)
	EventBus.level_up.connect(_on_level_up)
	
	# Connect melee system signals for visual effects
	melee_system.melee_attack_started.connect(_on_melee_attack_started)
	
	# Connect theme system
	texture_theme_system.theme_changed.connect(_on_theme_changed)
	Logger.info("Signals connected", "ui")
	
	# Arena subsystem signals will be connected after arena loads
	
	Logger.info("Setting up MultiMesh instances...", "ui")
	_setup_projectile_multimesh()
	Logger.info("Projectile MultiMesh setup complete", "ui")
	# OLD ENEMY SYSTEM REMOVED - Using tier-based rendering only
	_setup_tier_multimeshes()
	Logger.info("Tier MultiMesh setup complete", "ui")
	_setup_enemy_transforms()
	Logger.info("Enemy transforms setup complete", "ui")
	_setup_wall_multimesh()
	_setup_terrain_multimesh()
	_setup_obstacle_multimesh()
	_setup_interactable_multimesh()
	Logger.info("All MultiMesh setup complete", "ui")
	
	# Load the mega arena
	Logger.info("Loading mega arena...", "ui")
	arena_system.load_arena("mega_arena")
	
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

# OLD ENEMY SYSTEM COMPLETELY REMOVED - Using tier-based rendering only

func _setup_tier_multimeshes() -> void:
	# Setup SWARM tier MultiMesh (small squares)
	var swarm_multimesh := MultiMesh.new()
	swarm_multimesh.transform_format = MultiMesh.TRANSFORM_2D
	swarm_multimesh.use_colors = true
	swarm_multimesh.instance_count = 0
	var swarm_mesh := QuadMesh.new()
	swarm_mesh.size = Vector2(12, 12)  # Small squares for swarm
	swarm_multimesh.mesh = swarm_mesh
	var swarm_img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	swarm_img.fill(Color(1.0, 1.0, 1.0, 1.0))
	var swarm_tex := ImageTexture.create_from_image(swarm_img)
	mm_enemies_swarm.texture = swarm_tex
	mm_enemies_swarm.multimesh = swarm_multimesh
	
	# Setup REGULAR tier MultiMesh (medium rectangles)
	var regular_multimesh := MultiMesh.new()
	regular_multimesh.transform_format = MultiMesh.TRANSFORM_2D
	regular_multimesh.use_colors = true
	regular_multimesh.instance_count = 0
	var regular_mesh := QuadMesh.new()
	regular_mesh.size = Vector2(20, 28)  # Tall rectangles for regular
	regular_multimesh.mesh = regular_mesh
	var regular_img := Image.create(24, 24, false, Image.FORMAT_RGBA8)
	regular_img.fill(Color(1.0, 1.0, 1.0, 1.0))
	var regular_tex := ImageTexture.create_from_image(regular_img)
	mm_enemies_regular.texture = regular_tex
	mm_enemies_regular.multimesh = regular_multimesh
	
	# Setup ELITE tier MultiMesh (large diamonds)
	var elite_multimesh := MultiMesh.new()
	elite_multimesh.transform_format = MultiMesh.TRANSFORM_2D
	elite_multimesh.use_colors = true
	elite_multimesh.instance_count = 0
	var elite_mesh := QuadMesh.new()
	elite_mesh.size = Vector2(40, 40)  # Large squares for elite (will rotate to make diamond)
	elite_multimesh.mesh = elite_mesh
	var elite_img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	elite_img.fill(Color(1.0, 1.0, 1.0, 1.0))
	var elite_tex := ImageTexture.create_from_image(elite_img)
	mm_enemies_elite.texture = elite_tex
	mm_enemies_elite.multimesh = elite_multimesh
	
	# Setup BOSS tier MultiMesh (large diamonds)
	var boss_multimesh := MultiMesh.new()
	boss_multimesh.transform_format = MultiMesh.TRANSFORM_2D
	boss_multimesh.use_colors = true
	boss_multimesh.instance_count = 0
	var boss_mesh := QuadMesh.new()
	boss_mesh.size = Vector2(64, 64)  # Very large squares for bosses
	boss_multimesh.mesh = boss_mesh
	
	# Create boss texture (magenta/purple)
	var boss_img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	boss_img.fill(Color(1.0, 0.0, 1.0, 1.0))  # Magenta
	var boss_tex := ImageTexture.create_from_image(boss_img)
	mm_enemies_boss.texture = boss_tex
	mm_enemies_boss.multimesh = boss_multimesh
	
	Logger.info("Tier-specific MultiMesh instances initialized: SWARM (cyan), REGULAR (green), ELITE (blue), BOSS (magenta)", "enemies")

func _setup_enemy_transforms() -> void:
	var cache_size: int = BalanceDB.get_waves_value("enemy_transform_cache_size")
	_enemy_transforms.resize(cache_size)
	for i in range(cache_size):
		_enemy_transforms[i] = Transform2D()
	Logger.debug("Enemy transform cache initialized with " + str(cache_size) + " transforms", "performance")

func _setup_wall_multimesh() -> void:
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_2D
	multimesh.instance_count = 0

	var quad_mesh := QuadMesh.new()
	quad_mesh.size = Vector2(64, 32)
	multimesh.mesh = quad_mesh

	# Use TextureThemeSystem for wall texture
	var wall_texture := texture_theme_system.get_texture("walls")
	mm_walls.texture = wall_texture

	mm_walls.multimesh = multimesh

func _setup_terrain_multimesh() -> void:
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_2D
	multimesh.instance_count = 0

	var quad_mesh := QuadMesh.new()
	quad_mesh.size = Vector2(32, 32)
	multimesh.mesh = quad_mesh

	# Use TextureThemeSystem for terrain texture
	var terrain_texture := texture_theme_system.get_texture("terrain")
	mm_terrain.texture = terrain_texture
	mm_terrain.multimesh = multimesh

func _setup_obstacle_multimesh() -> void:
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_2D
	multimesh.instance_count = 0

	var quad_mesh := QuadMesh.new()
	quad_mesh.size = Vector2(32, 32)
	multimesh.mesh = quad_mesh

	# Use TextureThemeSystem for obstacle texture
	var obstacle_texture := texture_theme_system.get_texture("obstacles", "pillar")
	mm_obstacles.texture = obstacle_texture
	mm_obstacles.multimesh = multimesh

func _setup_interactable_multimesh() -> void:
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_2D
	multimesh.instance_count = 0

	var quad_mesh := QuadMesh.new()
	quad_mesh.size = Vector2(32, 32)
	multimesh.mesh = quad_mesh

	# Use TextureThemeSystem for interactable texture
	var interactable_texture := texture_theme_system.get_texture("interactables", "chest")
	mm_interactables.texture = interactable_texture
	mm_interactables.multimesh = multimesh

func _process(delta: float) -> void:
	# Don't handle debug spawning when game is paused
	if not get_tree().paused:
		_handle_debug_spawning(delta)
		_handle_auto_attack()
	

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
			KEY_1:
				Logger.info("Switching to basic arena", "ui")
				arena_system.load_arena("basic_arena")
			KEY_2:
				Logger.info("Switching to large arena", "ui")
				arena_system.load_arena("large_arena")
			KEY_3:
				Logger.info("Switching to mega arena", "ui")
				arena_system.load_arena("mega_arena")
			KEY_4:
				Logger.info("Switching to dungeon crawler", "ui")
				arena_system.load_arena("dungeon_crawler")
			KEY_5:
				Logger.info("Switching to hazard arena", "ui")
				arena_system.load_arena("hazard_arena")
			KEY_T:
				Logger.info("Switching theme", "ui")
				texture_theme_system.cycle_theme()
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

func _on_theme_changed(theme_name: String) -> void:
	Logger.info("Theme changed to: " + theme_name, "ui")
	# Update all MultiMesh textures with new theme
	_update_multimesh_textures()

func _update_multimesh_textures() -> void:
	# Update wall textures
	var wall_texture := texture_theme_system.get_texture("walls")
	mm_walls.texture = wall_texture
	
	# Update terrain textures
	var terrain_texture := texture_theme_system.get_texture("terrain")
	mm_terrain.texture = terrain_texture
	
	# Update obstacle textures
	var obstacle_texture := texture_theme_system.get_texture("obstacles", "pillar")
	mm_obstacles.texture = obstacle_texture
	
	# Update interactable textures
	var interactable_texture := texture_theme_system.get_texture("interactables", "chest")
	mm_interactables.texture = interactable_texture
	
	Logger.debug("MultiMesh textures updated for theme", "ui")

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
	if not melee_effects:
		return
	
	# Get effective melee stats for visual effect (including card modifiers)
	var effective_cone_angle = melee_system._get_effective_cone_angle()
	var effective_range = melee_system._get_effective_range()
	
	# Create cone visual effect
	var cone_polygon = Polygon2D.new()
	cone_polygon.color = Color(1.0, 0.8, 0.2, 0.3)  # Semi-transparent yellow
	
	# Calculate cone points - cone tip at player, opening towards target
	var attack_dir = (target_pos - player_pos).normalized()
	var cone_points: PackedVector2Array = []
	
	# Start at player position (cone tip)
	cone_points.append(Vector2.ZERO)
	
	# Calculate cone edges  
	var half_angle = deg_to_rad(effective_cone_angle / 2.0)
	var left_dir = attack_dir.rotated(-half_angle)
	var right_dir = attack_dir.rotated(half_angle)
	
	# Add cone edge points (spread from tip towards target direction)
	cone_points.append(left_dir * effective_range)
	cone_points.append(right_dir * effective_range)
	
	cone_polygon.polygon = cone_points
	cone_polygon.position = player_pos
	
	# Add to scene
	melee_effects.add_child(cone_polygon)
	
	# Remove after short duration
	var tween = create_tween()
	tween.tween_property(cone_polygon, "modulate:a", 0.0, 0.2)
	tween.tween_callback(cone_polygon.queue_free)

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
			var enemy_size: Vector2 = enemy.get("size", base_size)
			var scale_factor := enemy_size / base_size
			
			var transform := Transform2D()
			transform.origin = enemy["pos"]
			transform = transform.scaled(scale_factor)
			
			# Add rotation for elite enemies to make diamond shapes
			if tier == EnemyRenderTier.Tier.ELITE:
				transform = transform.rotated(PI / 4.0)  # 45 degree rotation for diamond
			
			mm_instance.multimesh.set_instance_transform_2d(i, transform)
			
			# Set color based on tier for visual debugging
			var tier_color := _get_tier_debug_color(tier)
			mm_instance.multimesh.set_instance_color(i, tier_color)

func _update_wall_multimesh(wall_transforms: Array[Transform2D]) -> void:
	var count := wall_transforms.size()
	
	if mm_walls and mm_walls.multimesh:
		mm_walls.multimesh.instance_count = count

		for i in range(count):
			var transform := wall_transforms[i]
			mm_walls.multimesh.set_instance_transform_2d(i, transform)

func _update_terrain_multimesh(terrain_transforms: Array[Transform2D]) -> void:
	var count := terrain_transforms.size()
	mm_terrain.multimesh.instance_count = count

	for i in range(count):
		var transform := terrain_transforms[i]
		mm_terrain.multimesh.set_instance_transform_2d(i, transform)

func _update_obstacle_multimesh(obstacle_transforms: Array[Transform2D]) -> void:
	var count := obstacle_transforms.size()
	mm_obstacles.multimesh.instance_count = count

	for i in range(count):
		var transform := obstacle_transforms[i]
		mm_obstacles.multimesh.set_instance_transform_2d(i, transform)

func _update_interactable_multimesh(interactable_transforms: Array[Transform2D]) -> void:
	var count := interactable_transforms.size()
	mm_interactables.multimesh.instance_count = count

	for i in range(count):
		var transform := interactable_transforms[i]
		mm_interactables.multimesh.set_instance_transform_2d(i, transform)

func _on_arena_loaded(arena_data: Dictionary) -> void:
	Logger.info("Arena loaded: " + str(arena_data.get("name", "Unknown Arena")), "ui")
	
	# Set camera bounds for the new arena
	var arena_bounds: Rect2 = arena_system.get_arena_bounds()
	camera_system.set_arena_bounds(arena_bounds)
	var payload := EventBus.ArenaBoundsChangedPayload.new(arena_bounds)
	EventBus.arena_bounds_changed.emit(payload)
	
	# Connect subsystem signals after arena is loaded
	if arena_system and arena_system.terrain_system:
		arena_system.terrain_system.terrain_updated.connect(_update_terrain_multimesh)
	
	if arena_system and arena_system.obstacle_system:
		arena_system.obstacle_system.obstacles_updated.connect(_update_obstacle_multimesh)
	
	if arena_system and arena_system.interactable_system:
		arena_system.interactable_system.interactables_updated.connect(_update_interactable_multimesh)
	
	if arena_system and arena_system.wall_system:
		arena_system.wall_system.walls_updated.connect(_update_wall_multimesh)
		
		# Manually trigger initial wall update
		if arena_system.wall_system.wall_transforms.size() > 0:
			_update_wall_multimesh(arena_system.wall_system.wall_transforms)

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
		"grunt_basic":
			return Color(1.0, 0.0, 0.0, 1.0)  # Red
		"slime_green":
			return Color(0.2, 0.8, 0.2, 1.0)  # Green
		"archer_skeleton":
			return Color(0.8, 0.8, 0.9, 1.0)  # Light Gray
		_:
			return Color(1.0, 0.0, 0.0, 1.0)  # Default red

func _get_tier_debug_color(tier: EnemyRenderTier.Tier) -> Color:
	# Distinct colors for each tier for visual debugging
	match tier:
		EnemyRenderTier.Tier.SWARM:
			return Color(1.0, 1.0, 0.0, 1.0)  # Bright Yellow
		EnemyRenderTier.Tier.REGULAR:
			return Color(0.0, 1.0, 1.0, 1.0)  # Bright Cyan
		EnemyRenderTier.Tier.ELITE:
			return Color(1.0, 0.0, 1.0, 1.0)  # Bright Magenta
		EnemyRenderTier.Tier.BOSS:
			return Color(1.0, 0.5, 0.0, 1.0)  # Bright Orange
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
	Logger.info("Cache size: " + str(_enemy_transforms.size()), "performance")

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
	ability_system.projectiles_updated.disconnect(_update_projectile_multimesh)
	wave_director.enemies_updated.disconnect(_update_enemy_multimesh)
	arena_system.arena_loaded.disconnect(_on_arena_loaded)
	EventBus.level_up.disconnect(_on_level_up)
	
	# Cleanup arena subsystem signals
	if arena_system.terrain_system and arena_system.terrain_system.terrain_updated.is_connected(_update_terrain_multimesh):
		arena_system.terrain_system.terrain_updated.disconnect(_update_terrain_multimesh)
	if arena_system.obstacle_system and arena_system.obstacle_system.obstacles_updated.is_connected(_update_obstacle_multimesh):
		arena_system.obstacle_system.obstacles_updated.disconnect(_update_obstacle_multimesh)
	if arena_system.interactable_system and arena_system.interactable_system.interactables_updated.is_connected(_update_interactable_multimesh):
		arena_system.interactable_system.interactables_updated.disconnect(_update_interactable_multimesh)
	if arena_system.wall_system and arena_system.wall_system.walls_updated.is_connected(_update_wall_multimesh):
		arena_system.wall_system.walls_updated.disconnect(_update_wall_multimesh)
