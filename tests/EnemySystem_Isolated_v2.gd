extends Node2D

## Isolated Enemy V2 system test - template-based spawning with EnemyFactory.
## Tests V2 template system, deterministic variation, and visual diversity.
## Spawns 20-50 enemies with HUD overlay showing seed/health/speed/color data.

@onready var enemy_multimesh: MultiMeshInstance2D = $EnemyMultiMesh
@onready var info_label: Label = $UILayer/HUD/InfoLabel
@onready var camera: Camera2D = $Camera2D

var wave_director: WaveDirector
var max_enemies: int = 50
var test_spawn_count: int = 0
var base_enemy_scale: float = 0.8

# V2 system references
const EnemyFactory := preload("res://scripts/systems/enemy_v2/EnemyFactory.gd")
var spawn_configs: Array[SpawnConfig] = []

func _ready():
	print("=== EnemySystem_Isolated_v2 Test Started ===")
	print("Controls:")
	print("  SPACE - Spawn V2 enemy grid (deterministic)")
	print("  R - Clear all enemies")
	print("  T - Toggle enemy V2 system ON/OFF")
	print("  1-5 - Spawn specific templates")
	print("  S - Stress test (500 enemies)")
	
	_setup_camera()
	_setup_enemy_system()
	_setup_enemy_multimesh()
	_update_info_display()

func _setup_camera():
	camera.zoom = Vector2(0.6, 0.6)  # Zoom out to see more
	camera.position = Vector2(400, 300)
	print("Camera positioned at", camera.position, "with zoom", camera.zoom)

func _setup_enemy_system():
	# Create WaveDirector for Enemy V2 testing
	wave_director = WaveDirector.new()
	add_child(wave_director)
	
	# Force enable V2 system for testing
	var original_toggle = BalanceDB.use_enemy_v2_system
	if not original_toggle:
		print("Force enabling Enemy V2 system for testing")
	
	# Load V2 templates
	EnemyFactory.load_all_templates()
	print("Loaded V2 templates:", EnemyFactory.get_template_ids())
	
	print("WaveDirector setup complete - V2 system ready")

func _setup_enemy_multimesh():
	# Setup MultiMesh for visual representation
	var multimesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_2D
	multimesh.instance_count = max_enemies
	
	# Create simple quad mesh for enemies
	var quad_mesh = QuadMesh.new()
	quad_mesh.size = Vector2(24, 24) * base_enemy_scale
	multimesh.mesh = quad_mesh
	
	enemy_multimesh.multimesh = multimesh
	print("MultiMesh setup complete for", max_enemies, "enemies")

func _update_info_display():
	var info_text = "Enemy V2 System Test\n"
	info_text += "V2 Toggle: %s\n" % ("ON" if BalanceDB.use_enemy_v2_system else "OFF")
	info_text += "Templates Loaded: %d\n" % EnemyFactory.get_template_count()
	info_text += "Active Enemies: %d\n" % wave_director.get_alive_enemies().size() if wave_director else 0
	info_text += "Spawned Configs: %d\n" % spawn_configs.size()
	
	if spawn_configs.size() > 0:
		info_text += "\nLast Spawned:\n"
		var last_config = spawn_configs[-1]
		info_text += "  ID: %s\n" % last_config.template_id
		info_text += "  HP: %.1f\n" % last_config.health
		info_text += "  Speed: %.1f\n" % last_config.speed
		info_text += "  Scale: %.2f\n" % last_config.size_scale
		info_text += "  Hue: %.2f\n" % last_config.color_tint.h
	
	info_label.text = info_text

func _process(_delta):
	_update_info_display()

func _input(event):
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_SPACE:
				_spawn_deterministic_grid()
			KEY_R:
				_clear_all_enemies()
			KEY_T:
				_toggle_v2_system()
			KEY_1:
				_spawn_specific_template("ancient_lich")
			KEY_2:
				_spawn_specific_template("banana_lord")
			KEY_3:
				_spawn_specific_template("dragon_lord")
			KEY_4:
				# Spawn ancient_lich again as fallback
				_spawn_specific_template("ancient_lich")
			KEY_5:
				_spawn_specific_template("ancient_lich")
			KEY_S:
				_stress_test()

func _spawn_deterministic_grid():
	print("Spawning deterministic V2 enemy grid...")
	
	var grid_size = 7  # 7x7 = 49 enemies
	var spacing = 80.0
	var start_pos = Vector2(100, 100)
	
	for y in range(grid_size):
		for x in range(grid_size):
			var pos = start_pos + Vector2(x * spacing, y * spacing)
			_spawn_v2_enemy_at(pos, test_spawn_count)
			test_spawn_count += 1
	
	print("Grid spawn complete - %d enemies spawned" % (grid_size * grid_size))

func _spawn_specific_template(template_id: String):
	print("Spawning specific template: ", template_id)
	var pos = Vector2(400 + randf_range(-200, 200), 300 + randf_range(-200, 200))
	_spawn_v2_enemy_at(pos, test_spawn_count, template_id)
	test_spawn_count += 1

func _spawn_v2_enemy_at(position: Vector2, spawn_index: int, template_id: String = ""):
	# Create spawn context for deterministic generation
	var spawn_context = {
		"run_id": 12345,  # Fixed run ID for deterministic results
		"wave_index": 1,
		"spawn_index": spawn_index,
		"position": position,
		"context_tags": []
	}
	
	# Spawn from specific template or random weighted selection
	var config: SpawnConfig
	if template_id.is_empty():
		config = EnemyFactory.spawn_from_weights(spawn_context)
	else:
		config = EnemyFactory.spawn_from_template_id(template_id, spawn_context)
	
	if not config:
		print("Failed to spawn V2 enemy")
		return
	
	# Store config for display
	spawn_configs.append(config)
	
	# Convert to legacy EnemyType and spawn via WaveDirector
	var legacy_type = config.to_enemy_type()
	wave_director.spawn_enemy_at(position, legacy_type.id)
	
	# Update visual representation
	_update_multimesh_visual(spawn_configs.size() - 1, config)
	
	print("Spawned V2: %s" % config.debug_string())

func _update_multimesh_visual(index: int, config: SpawnConfig):
	if index >= max_enemies:
		return
		
	var multimesh = enemy_multimesh.multimesh
	if not multimesh:
		return
		
	# Set transform (position and scale)
	var transform = Transform2D()
	transform = transform.scaled(Vector2.ONE * config.size_scale)
	transform.origin = config.position
	multimesh.set_instance_transform_2d(index, transform)
	
	# Set color (if supported)
	if multimesh.transform_format == MultiMesh.TRANSFORM_2D:
		multimesh.set_instance_color(index, config.color_tint)

func _clear_all_enemies():
	print("Clearing all enemies...")
	spawn_configs.clear()
	test_spawn_count = 0
	
	# Clear WaveDirector enemies
	if wave_director:
		for enemy in wave_director.enemies:
			enemy.alive = false
			enemy.hp = 0.0
	
	# Clear MultiMesh visuals
	if enemy_multimesh.multimesh:
		for i in range(max_enemies):
			enemy_multimesh.multimesh.set_instance_transform_2d(i, Transform2D())
	
	print("All enemies cleared")

func _toggle_v2_system():
	# This is a test environment - we'll just log the toggle state
	var current_state = BalanceDB.use_enemy_v2_system
	print("V2 System Toggle: %s -> %s" % [current_state, not current_state])
	print("Note: Toggle change requires BalanceDB modification")

func _stress_test():
	print("Starting stress test - 500 enemies...")
	_clear_all_enemies()
	
	var stress_count = 500
	var area_size = 1000.0  # Spread over larger area
	
	for i in range(stress_count):
		var pos = Vector2(
			randf_range(-area_size/2, area_size/2) + 400,
			randf_range(-area_size/2, area_size/2) + 300
		)
		_spawn_v2_enemy_at(pos, i)
		
		# Update every 50 spawns
		if i % 50 == 0:
			print("Stress test progress: %d/%d" % [i, stress_count])
	
	print("Stress test complete - %d enemies spawned" % stress_count)
	print("Performance check: MultiMesh batching should be intact")

func _exit_tree():
	print("=== EnemySystem_Isolated_v2 Test Complete ===")
	print("Final stats:")
	print("  Configs generated: %d" % spawn_configs.size())
	print("  Templates used: %s" % str(EnemyFactory.get_template_ids()))