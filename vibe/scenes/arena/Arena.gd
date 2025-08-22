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
const EnemyRenderer := preload("res://scripts/systems/EnemyRenderer.gd")

@onready var mm_projectiles: MultiMeshInstance2D = $MM_Projectiles
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
@onready var enemy_renderer: EnemyRenderer = EnemyRenderer.new()

var player: Player
var xp_system: XpSystem
var hud: HUD
var card_picker: CardPicker

var spawn_timer: float = 0.0
var base_spawn_interval: float = 0.25


func _ready() -> void:
	# Arena input should work during pause for debug controls
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	# Set proper process modes for systems
	ability_system.process_mode = Node.PROCESS_MODE_PAUSABLE
	melee_system.process_mode = Node.PROCESS_MODE_PAUSABLE
	wave_director.process_mode = Node.PROCESS_MODE_PAUSABLE
	damage_system.process_mode = Node.PROCESS_MODE_PAUSABLE
	texture_theme_system.process_mode = Node.PROCESS_MODE_ALWAYS
	arena_system.process_mode = Node.PROCESS_MODE_PAUSABLE
	camera_system.process_mode = Node.PROCESS_MODE_PAUSABLE
	enemy_renderer.process_mode = Node.PROCESS_MODE_PAUSABLE
	
	add_child(ability_system)
	add_child(melee_system)
	add_child(wave_director)
	add_child(damage_system)
	add_child(texture_theme_system)
	add_child(arena_system)
	add_child(camera_system)
	add_child(enemy_renderer)
	
	# Set references for damage system (legitimate dependency injection)
	damage_system.set_references(ability_system, wave_director)
	
	# Create and add new systems
	_setup_player()
	_setup_xp_system()
	_setup_ui()
	
	# Set player reference in PlayerState for cached position access
	PlayerState.set_player_reference(player)
	
	# Connect signals AFTER systems are added and ready
	ability_system.projectiles_updated.connect(_update_projectile_multimesh)
	wave_director.enemies_updated.connect(_on_enemies_updated)
	arena_system.arena_loaded.connect(_on_arena_loaded)
	EventBus.level_up.connect(_on_level_up)
	
	# Connect melee system signals for visual effects
	melee_system.melee_attack_started.connect(_on_melee_attack_started)
	
	# Connect theme system
	texture_theme_system.theme_changed.connect(_on_theme_changed)
	
	# Arena subsystem signals will be connected after arena loads
	
	
	_setup_projectile_multimesh()
	_setup_wall_multimesh()
	_setup_terrain_multimesh()
	_setup_obstacle_multimesh()
	_setup_interactable_multimesh()
	
	# Load the mega arena
	arena_system.load_arena("mega_arena")
	
	# Print debug help
	_print_debug_help()

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

func _on_enemies_updated(alive_enemies: Array[Dictionary]) -> void:
	if enemy_renderer:
		enemy_renderer.update_enemies(alive_enemies)

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
	
	if enemy_renderer:
		stats["active_sprites"] = enemy_renderer.get_active_sprite_count()
	
	return stats

func _exit_tree() -> void:
	# Cleanup signal connections
	ability_system.projectiles_updated.disconnect(_update_projectile_multimesh)
	wave_director.enemies_updated.disconnect(_on_enemies_updated)
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
