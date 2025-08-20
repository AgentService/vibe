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

@onready var mm_projectiles: MultiMeshInstance2D = $MM_Projectiles
@onready var mm_enemies: MultiMeshInstance2D = $MM_Enemies
@onready var mm_walls: MultiMeshInstance2D = $MM_Walls
@onready var mm_terrain: MultiMeshInstance2D = $MM_Terrain
@onready var mm_obstacles: MultiMeshInstance2D = $MM_Obstacles
@onready var mm_interactables: MultiMeshInstance2D = $MM_Interactables
@onready var ability_system: AbilitySystem = AbilitySystem.new()
@onready var wave_director: WaveDirector = WaveDirector.new()
@onready var damage_system: DamageSystem = DamageSystem.new()
@onready var arena_system: ArenaSystem = ArenaSystem.new()
@onready var texture_theme_system: TextureThemeSystem = TextureThemeSystem.new()
@onready var camera_system: CameraSystem = CameraSystem.new()

var player: Player
var xp_system: XpSystem
var hud: HUD
var card_picker: CardPicker

var spawn_timer: float = 0.0
var base_spawn_interval: float = 0.25

func _ready() -> void:
	add_child(ability_system)
	add_child(wave_director)
	add_child(damage_system)
	add_child(texture_theme_system)
	add_child(arena_system)
	add_child(camera_system)
	
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
	wave_director.enemies_updated.connect(_update_enemy_multimesh)
	arena_system.arena_loaded.connect(_on_arena_loaded)
	EventBus.level_up.connect(_on_level_up)
	
	# Connect theme system
	texture_theme_system.theme_changed.connect(_on_theme_changed)
	
	# Arena subsystem signals will be connected after arena loads
	
	
	_setup_projectile_multimesh()
	_setup_enemy_multimesh()
	_setup_wall_multimesh()
	_setup_terrain_multimesh()
	_setup_obstacle_multimesh()
	_setup_interactable_multimesh()
	
	# Load the basic arena
	arena_system.load_arena("basic_arena")

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

func _setup_enemy_multimesh() -> void:
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_2D
	multimesh.instance_count = 0

	var quad_mesh := QuadMesh.new()
	quad_mesh.size = Vector2(12, 12)
	multimesh.mesh = quad_mesh

	# 12x12 roter Punkt als Texture bauen
	var img := Image.create(12, 12, false, Image.FORMAT_RGBA8)
	img.fill(Color(1.0, 0.0, 0.0, 1.0))
	var tex := ImageTexture.create_from_image(img)
	mm_enemies.texture = tex

	mm_enemies.multimesh = multimesh

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
	_handle_debug_spawning(delta)
	

func _input(event: InputEvent) -> void:
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
	RunManager.pause_game(true)
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

func _handle_debug_spawning(delta: float) -> void:
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
	var count := alive_enemies.size()
	mm_enemies.multimesh.instance_count = count

	for i in range(count):
		var enemy := alive_enemies[i]
		var transform := Transform2D()
		transform.origin = enemy["pos"]
		mm_enemies.multimesh.set_instance_transform_2d(i, transform)

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
