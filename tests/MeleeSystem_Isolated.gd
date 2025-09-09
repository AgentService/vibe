extends Node2D

## Isolated melee system test - automatic cone melee attacks.
## Tests melee attack mechanics with cone detection and auto-attacking nearest enemies.

@onready var player: CharacterBody2D = $Player
@onready var enemy_multimesh: MultiMeshInstance2D = $EnemyMultiMesh
@onready var info_label: Label = $UILayer/HUD/InfoLabel

const PLAYER_SPEED = 300.0

var melee_system: MeleeSystem
var wave_director: WaveDirector
var damage_system: DamageSystem
var last_attack_time: float = 0.0
var attack_cooldown: float = 1.0
var auto_attack_timer: float = 0.0
var auto_attack_interval: float = 1.5  # Auto-attack every 1.5 seconds

func _ready():
	print("=== MeleeSystem_Isolated Test Started ===")
	print("Controls: WASD to move, E to spawn enemy, auto-attacks nearest enemies")
	
	_setup_player()
	_setup_systems()
	_setup_enemy_multimesh()
	_spawn_test_enemies()

func _setup_player():
	var player_sprite = player.get_node("Sprite2D")
	var player_collision = player.get_node("CollisionShape2D")
	
	var texture = ImageTexture.new()
	var image = Image.create(32, 32, false, Image.FORMAT_RGB8)
	image.fill(Color.BLUE)
	texture.set_image(image)
	player_sprite.texture = texture
	
	var shape = RectangleShape2D.new()
	shape.size = Vector2(32, 32)
	player_collision.shape = shape

func _setup_systems():
	# Create EnemyRegistry first (WaveDirector depends on it)
	var enemy_registry = EnemyRegistry.new()
	add_child(enemy_registry)
	
	# Create WaveDirector and inject EnemyRegistry
	wave_director = WaveDirector.new()
	add_child(wave_director)
	wave_director.set_enemy_registry(enemy_registry)
	
	damage_system = DamageSystem.new()
	add_child(damage_system)
	
	melee_system = MeleeSystem.new()
	add_child(melee_system)
	
	# Set up system references
	damage_system.set_references(null, wave_director)
	
	# Connect signals
	if wave_director.has_signal("enemies_updated"):
		wave_director.enemies_updated.connect(_on_enemies_updated)

func _on_enemies_updated(alive_enemies: Array):
	_update_enemy_visuals()

func _setup_enemy_multimesh():
	var multimesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_2D
	multimesh.instance_count = 0
	
	var quad_mesh = QuadMesh.new()
	quad_mesh.size = Vector2(24, 24)
	multimesh.mesh = quad_mesh
	
	# Orange enemy texture
	var texture = ImageTexture.new()
	var image = Image.create(24, 24, false, Image.FORMAT_RGB8)
	image.fill(Color.ORANGE)
	texture.set_image(image)
	enemy_multimesh.texture = texture
	
	enemy_multimesh.multimesh = multimesh

func _spawn_test_enemies():
	# Spawn a few enemies around the player
	for i in range(5):
		var angle = (i / 5.0) * TAU
		var spawn_pos = player.position + Vector2.from_angle(angle) * 100
		_spawn_enemy_at(spawn_pos)
	
	# Initial visual update
	await get_tree().process_frame
	_update_enemy_visuals()

func _spawn_enemy_at(pos: Vector2):
	if wave_director.has_method("spawn_enemy_at"):
		# Use actual enemy types that exist in .tres files
		var enemy_types = ["knight_regular", "knight_swarm", "knight_elite"]
		var random_type = enemy_types[randi() % enemy_types.size()]
		var success = wave_director.spawn_enemy_at(pos, random_type)
		if success:
			print("Enemy spawned at: ", pos, " (type: ", random_type, ")")
		else:
			print("Failed to spawn enemy at: ", pos)
	else:
		print("WaveDirector missing spawn_enemy_at method")

func _unhandled_input(event):
	if event is InputEventKey and event.pressed and event.keycode == KEY_E:
		_spawn_enemy_near_mouse()

func _physics_process(delta):
	_handle_player_movement(delta)
	_handle_auto_attack(delta)
	_update_info_display()
	
	# Update player position in PlayerState for systems that depend on it
	if PlayerState:
		PlayerState.position = player.position

func _handle_auto_attack(delta):
	auto_attack_timer += delta
	if auto_attack_timer >= auto_attack_interval:
		auto_attack_timer = 0.0
		_perform_cone_attack()

func _handle_player_movement(delta):
	var input_vector = Vector2.ZERO
	
	if Input.is_action_pressed("move_left"):
		input_vector.x -= 1
	if Input.is_action_pressed("move_right"):
		input_vector.x += 1
	if Input.is_action_pressed("move_up"):
		input_vector.y -= 1
	if Input.is_action_pressed("move_down"):
		input_vector.y += 1
	
	if input_vector != Vector2.ZERO:
		input_vector = input_vector.normalized()
		player.velocity = input_vector * PLAYER_SPEED
	else:
		player.velocity = Vector2.ZERO
	
	player.move_and_slide()

func _perform_cone_attack():
	if not wave_director.has_method("get_alive_enemies"):
		return
		
	var enemies = wave_director.get_alive_enemies()
	if enemies.is_empty():
		return
	
	var player_pos = player.global_position
	var attack_range = 80.0
	var cone_angle = 60.0  # degrees
	
	# Find nearest enemy to determine attack direction
	var nearest_enemy = null
	var nearest_distance = INF
	
	for enemy in enemies:
		var distance = player_pos.distance_to(enemy.pos)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest_enemy = enemy
	
	if not nearest_enemy or nearest_distance > attack_range:
		return
	
	# Attack direction toward nearest enemy
	var attack_direction = (nearest_enemy.pos - player_pos).normalized()
	var enemies_hit = 0
	
	print("Cone attack! Direction: ", attack_direction)
	
	# Find all enemies in cone
	for enemy in enemies:
		var to_enemy = enemy.pos - player_pos
		var distance = to_enemy.length()
		
		if distance <= attack_range:
			var enemy_direction = to_enemy.normalized()
			var angle_diff = rad_to_deg(attack_direction.angle_to(enemy_direction))
			
			if abs(angle_diff) <= cone_angle / 2.0:
				# Enemy is in cone - apply damage via unified system
				var old_hp = enemy.hp
				var enemy_id = "enemy_" + str(enemy_idx)
				var damage_amount = 30.0
				
				# Use unified damage system
				DamageService.apply_damage(enemy_id, damage_amount)
				enemies_hit += 1
				
				print("  Hit enemy: ", enemy.type_id, " HP: ", old_hp, " -> ", enemy.hp)
				
				if enemy.hp <= 0:
					enemy.alive = false
					print("  Enemy killed!")
	
	if enemies_hit > 0:
		print("Cone attack hit ", enemies_hit, " enemies")
		_update_enemy_visuals()
	else:
		print("Cone attack missed")

func _spawn_enemy_near_mouse():
	var mouse_pos = get_global_mouse_position()
	_spawn_enemy_at(mouse_pos)
	print("Enemy spawned at mouse position")

func _on_melee_attack(attack_data: Dictionary):
	print("Melee attack hit: ", attack_data)

func _update_enemy_visuals():
	var alive_enemies = wave_director.get_alive_enemies()
	enemy_multimesh.multimesh.instance_count = alive_enemies.size()
	
	for i in range(alive_enemies.size()):
		var enemy = alive_enemies[i]
		var transform = Transform2D()
		transform.origin = enemy.pos
		
		# Color-code by health percentage
		var health_pct = 1.0
		if enemy.hp > 0 and enemy.max_hp > 0:
			health_pct = enemy.hp / enemy.max_hp
		
		# Vary the size based on health (wounded enemies appear smaller)
		var enemy_scale = 0.5 + (health_pct * 0.5)
		transform = transform.scaled(Vector2(enemy_scale, enemy_scale))
		
		enemy_multimesh.multimesh.set_instance_transform_2d(i, transform)

func _update_info_display():
	var enemy_count = 0
	var player_coords = "(" + str(int(player.position.x)) + ", " + str(int(player.position.y)) + ")"
	var next_attack_in = auto_attack_interval - auto_attack_timer
	
	if wave_director and wave_director.has_method("get_alive_enemies"):
		enemy_count = wave_director.get_alive_enemies().size()
	
	info_label.text = "Melee System Test\n"
	info_label.text += "WASD: Move\n"
	info_label.text += "E: Spawn enemy at mouse\n"
	info_label.text += "Auto cone attacks every 1.5s\n\n"
	info_label.text += "Player: " + player_coords + "\n"
	info_label.text += "Next attack in: " + str(next_attack_in).pad_decimals(1) + "s\n"
	info_label.text += "Enemies alive: " + str(enemy_count)
