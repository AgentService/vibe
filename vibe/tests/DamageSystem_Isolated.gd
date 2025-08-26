extends Node2D

## Isolated damage system test - passive damage monitoring.
## Shows enemies spawning, moving, and taking automatic damage over time.
## Tests damage visualization and enemy death handling.

@onready var player: CharacterBody2D = $Player
@onready var enemy_multimesh: MultiMeshInstance2D = $EnemyMultiMesh
@onready var info_label: Label = $UILayer/HUD/InfoLabel

const PLAYER_SPEED = 300.0

var damage_system: DamageSystem
var wave_director: WaveDirector
var selected_damage_type: String = "physical"
var damage_amount: float = 25.0
var auto_damage_timer: float = 0.0
var auto_damage_interval: float = 2.0  # Damage every 2 seconds
var target_nearest: bool = true  # Target nearest enemy instead of random

func _ready():
	print("=== DamageSystem_Isolated Test Started ===")
	print("Controls: WASD to move, E to spawn enemy, enemies take auto-damage over time")
	
	_setup_player()
	_setup_systems()
	_setup_enemy_multimesh()
	_spawn_test_enemies()

func _setup_player():
	var player_sprite = player.get_node("Sprite2D")
	var player_collision = player.get_node("CollisionShape2D")
	
	var texture = ImageTexture.new()
	var image = Image.create(32, 32, false, Image.FORMAT_RGB8)
	image.fill(Color.PURPLE)
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
	
	# Set up system references using the proper method
	damage_system.set_references(null, wave_director)  # AbilitySystem=null, WaveDirector=wave_director
	
	# Connect signals
	if wave_director.has_signal("enemies_updated"):
		wave_director.enemies_updated.connect(_on_enemies_updated)
	EventBus.damage_applied.connect(_on_damage_applied)
	EventBus.enemy_killed.connect(_on_enemy_killed)

func _setup_enemy_multimesh():
	var multimesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_2D
	multimesh.instance_count = 0
	
	var quad_mesh = QuadMesh.new()
	quad_mesh.size = Vector2(24, 24)
	multimesh.mesh = quad_mesh
	
	# Pink enemy texture
	var texture = ImageTexture.new()
	var image = Image.create(24, 24, false, Image.FORMAT_RGB8)
	image.fill(Color.MAGENTA)
	texture.set_image(image)
	enemy_multimesh.texture = texture
	
	enemy_multimesh.multimesh = multimesh

func _spawn_test_enemies():
	# Set initial player position away from origin
	player.position = Vector2(400, 300)
	print("Player position: ", player.position)
	
	# Spawn enemies with different health values around the player
	for i in range(5):
		var angle = (i / 5.0) * TAU
		var spawn_pos = player.position + Vector2.from_angle(angle) * 150
		_spawn_enemy_at(spawn_pos)
		print("Spawning enemy ", i+1, " at position: ", spawn_pos)
	
	# Initial visual update
	await get_tree().process_frame
	_update_enemy_visuals()

func _spawn_enemy_at(pos: Vector2, health: float = 50.0):
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
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_E:
				_spawn_enemy_near_mouse()
			KEY_1:
				selected_damage_type = "physical"
				print("Damage type: Physical")
			KEY_2:
				selected_damage_type = "fire"
				print("Damage type: Fire")
			KEY_3:
				selected_damage_type = "ice"
				print("Damage type: Ice")
			KEY_4:
				selected_damage_type = "lightning"
				print("Damage type: Lightning")
			KEY_EQUAL, KEY_PLUS:
				damage_amount = min(damage_amount + 10.0, 200.0)
				print("Damage amount: ", damage_amount)
			KEY_MINUS:
				damage_amount = max(damage_amount - 10.0, 5.0)
				print("Damage amount: ", damage_amount)

func _physics_process(delta):
	_handle_player_movement(delta)
	_update_info_display()
	_handle_auto_damage(delta)
	
	# Update player position in PlayerState for systems that depend on it
	if PlayerState:
		PlayerState.position = player.position

func _handle_auto_damage(delta):
	auto_damage_timer += delta
	if auto_damage_timer >= auto_damage_interval:
		auto_damage_timer = 0.0
		_damage_random_enemy()

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

func _damage_random_enemy():
	if not wave_director.has_method("get_alive_enemies"):
		return
		
	var enemies = wave_director.get_alive_enemies()
	if enemies.is_empty():
		return
	
	var target_enemy = null
	var target_idx = -1
	
	if target_nearest and player:
		# Find nearest enemy to player
		var nearest_dist = INF
		for i in range(enemies.size()):
			var enemy = enemies[i]
			var dist = player.position.distance_to(enemy.pos)
			if dist < nearest_dist:
				nearest_dist = dist
				target_enemy = enemy
				target_idx = i
		print("Targeting nearest enemy #", target_idx, " at distance ", nearest_dist)
	else:
		# Pick a random alive enemy
		target_idx = randi() % enemies.size()
		target_enemy = enemies[target_idx]
		print("Picked random enemy #", target_idx, " from alive list")
	
	# Find enemy pool index
	var enemy_index = -1
	var all_enemies = wave_director.enemies
	for i in range(all_enemies.size()):
		if all_enemies[i] == target_enemy:
			enemy_index = i
			print("  Found enemy at pool index: ", i)
			break
	
	if enemy_index == -1:
		print("  ERROR: Could not find enemy in pool!")
	
	if enemy_index >= 0:
		var old_hp = target_enemy.hp
		print("Auto-damage: ", damage_amount, " ", selected_damage_type, " to enemy[", enemy_index, "] ", target_enemy.type_id)
		print("  Enemy position: ", target_enemy.pos)
		print("  Enemy HP before damage: ", old_hp)
		print("  Total enemies in pool: ", all_enemies.size())
		print("  Alive enemies before damage: ", enemies.size())
		
		# Use WaveDirector's damage_enemy method which handles death properly
		wave_director.damage_enemy(enemy_index, damage_amount)
		
		# Check if enemy actually died
		print("  Enemy HP after damage: ", target_enemy.hp)
		print("  Enemy alive status: ", target_enemy.alive)
		
		# Get updated enemy list
		var updated_enemies = wave_director.get_alive_enemies()
		print("  Alive enemies after damage: ", updated_enemies.size())
		
		# Manually trigger enemies_updated signal to ensure visual update
		if wave_director.has_signal("enemies_updated"):
			wave_director.enemies_updated.emit(updated_enemies)
		
		# Force multimesh update
		_update_enemy_visuals()

func _spawn_enemy_near_mouse():
	var mouse_pos = get_global_mouse_position()
	_spawn_enemy_at(mouse_pos)
	print("Enemy spawned at mouse position")

func _on_damage_applied(payload):
	print("✓ Damage applied: ", payload.final_damage, " to ", payload.target_id, " (crit: ", payload.is_critical, ")")

func _on_enemy_killed(payload):
	print("💀 Enemy killed at ", payload.pos, " (XP: ", payload.xp_value, ")")

func _update_enemy_visuals():
	var alive_enemies = wave_director.get_alive_enemies()
	print("  === Visual update ===")
	print("    Alive enemies: ", alive_enemies.size())
	print("    Previous instance count: ", enemy_multimesh.multimesh.instance_count)
	enemy_multimesh.multimesh.instance_count = alive_enemies.size()
	print("    New instance count: ", enemy_multimesh.multimesh.instance_count)
	
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
		
		# Log first few enemy positions for debugging
		if i < 3:
			print("    Enemy ", i, " at ", enemy.pos, " (HP: ", enemy.hp, "/", enemy.max_hp, ")")

func _on_enemies_updated(alive_enemies: Array):
	_update_enemy_visuals()

func _update_info_display():
	var enemy_count = 0
	var nearest_enemy_health = "N/A"
	var player_coords = "(" + str(int(player.position.x)) + ", " + str(int(player.position.y)) + ")"
	
	if wave_director and wave_director.has_method("get_alive_enemies"):
		var enemies = wave_director.get_alive_enemies()
		enemy_count = enemies.size()
		
		# Find nearest enemy health
		var nearest_distance = INF
		var player_pos = player.global_position
		
		for enemy in enemies:
			var enemy_pos = enemy.pos
			var distance = player_pos.distance_to(enemy_pos)
			if distance < nearest_distance and distance < 200.0:
				nearest_distance = distance
				nearest_enemy_health = str(int(enemy.hp)) + "/" + str(int(enemy.max_hp))
	
	info_label.text = "Damage System Test\n"
	info_label.text += "WASD: Move\n"
	info_label.text += "E: Spawn enemy at mouse\n"
	info_label.text += "1-4: Damage types\n"
	info_label.text += "+/-: Damage amount\n"
	info_label.text += "Auto-damage every 2sec\n\n"
	info_label.text += "Player: " + player_coords + "\n"
	info_label.text += "Damage: " + str(damage_amount) + " " + selected_damage_type + "\n"
	info_label.text += "Enemies alive: " + str(enemy_count) + "\n"
	info_label.text += "Nearest enemy HP: " + nearest_enemy_health
