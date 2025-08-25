extends Node2D

## Isolated damage system test - damage calculation and application.
## Tests damage types, resistance, critical hits, and enemy health management.

@onready var player: CharacterBody2D = $Player
@onready var enemy_multimesh: MultiMeshInstance2D = $EnemyMultiMesh
@onready var info_label: Label = $UILayer/HUD/InfoLabel

const PLAYER_SPEED = 300.0

var damage_system: DamageSystem
var wave_director: WaveDirector
var selected_damage_type: String = "physical"
var damage_amount: float = 25.0

func _ready():
	print("=== DamageSystem_Isolated Test Started ===")
	print("Controls: WASD to move, Click to damage, E to spawn enemy, 1-4 damage types")
	
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
	# Spawn enemies with different health values around the player
	for i in range(5):
		var angle = (i / 5.0) * TAU
		var spawn_pos = player.position + Vector2.from_angle(angle) * 120
		_spawn_enemy_at(spawn_pos)

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
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_deal_damage_to_nearest()
	elif event is InputEventKey and event.pressed:
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
	
	# Emit combat_step for DamageSystem processing
	# In real game this comes from GameOrchestrator at 30Hz
	EventBus.combat_step.emit(null)

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

func _deal_damage_to_nearest():
	if not wave_director.has_method("get_alive_enemies"):
		print("WaveDirector missing get_alive_enemies method")
		return
		
	var enemies = wave_director.get_alive_enemies()
	if enemies.is_empty():
		print("No alive enemies found")
		return
	
	# Find nearest enemy
	var nearest_enemy = null
	var nearest_distance = INF
	var player_pos = player.global_position
	
	for enemy in enemies:
		var enemy_pos = enemy.pos
		var distance = player_pos.distance_to(enemy_pos)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest_enemy = enemy
	
	if nearest_enemy and nearest_distance < 200.0:
		# Find enemy pool index
		var enemy_index = -1
		var all_enemies = wave_director.enemies
		for i in range(all_enemies.size()):
			if all_enemies[i] == nearest_enemy:
				enemy_index = i
				break
		
		if enemy_index >= 0:
			# Create proper damage request payload
			var source_id = EntityId.player()
			var target_id = EntityId.enemy(enemy_index)
			var tags = PackedStringArray([selected_damage_type, "test_damage"])
			var payload = EventBus.DamageRequestPayload_Type.new(source_id, target_id, damage_amount, tags)
			
			EventBus.damage_requested.emit(payload)
			print("Dealt ", damage_amount, " ", selected_damage_type, " damage to enemy[", enemy_index, "] ", nearest_enemy.type_id)
		else:
			print("Could not find enemy in pool")
	else:
		print("No enemies in range (max 200 units)")

func _spawn_enemy_near_mouse():
	var mouse_pos = get_global_mouse_position()
	_spawn_enemy_at(mouse_pos)
	print("Enemy spawned at mouse position")

func _on_damage_applied(payload):
	print("✓ Damage applied: ", payload.final_damage, " to ", payload.target_id, " (crit: ", payload.is_critical, ")")

func _on_enemy_killed(payload):
	print("💀 Enemy killed: ", payload.entity_id, " at ", payload.position)

func _on_enemies_updated(alive_enemies: Array):
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
		var scale = 0.5 + (health_pct * 0.5)
		transform = transform.scaled(Vector2(scale, scale))
		
		enemy_multimesh.multimesh.set_instance_transform_2d(i, transform)

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
	info_label.text += "Click: Damage nearest enemy\n"
	info_label.text += "E: Spawn enemy at mouse\n"
	info_label.text += "1-4: Damage types\n"
	info_label.text += "+/-: Damage amount\n\n"
	info_label.text += "Player: " + player_coords + "\n"
	info_label.text += "Damage: " + str(damage_amount) + " " + selected_damage_type + "\n"
	info_label.text += "Enemies alive: " + str(enemy_count) + "\n"
	info_label.text += "Nearest enemy HP: " + nearest_enemy_health
