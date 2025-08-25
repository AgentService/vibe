extends Node2D

## Isolated melee system test - player melee attacks and enemy interactions.
## Tests melee attack mechanics, collision detection, and enemy damage.

@onready var player: CharacterBody2D = $Player
@onready var enemy_multimesh: MultiMeshInstance2D = $EnemyMultiMesh
@onready var info_label: Label = $UILayer/HUD/InfoLabel

const PLAYER_SPEED = 300.0

var melee_system: MeleeSystem
var enemy_registry: EnemyRegistry
var damage_system: DamageSystem
var last_attack_time: float = 0.0
var attack_cooldown: float = 1.0

func _ready():
	print("=== MeleeSystem_Isolated Test Started ===")
	print("Controls: WASD to move, Click to melee attack, E to spawn enemy")
	
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
	enemy_registry = EnemyRegistry.new()
	add_child(enemy_registry)
	
	damage_system = DamageSystem.new()
	add_child(damage_system)
	
	melee_system = MeleeSystem.new()
	add_child(melee_system)
	
	# Set up system references
	if damage_system.has_method("set_references"):
		damage_system.set_references(null, enemy_registry)
	if melee_system.has_method("set_wave_director_reference"):
		melee_system.set_wave_director_reference(enemy_registry)
	
	# Connect signals
	enemy_registry.enemies_updated.connect(_on_enemies_updated)
	if melee_system.has_signal("melee_attack_performed"):
		melee_system.melee_attack_performed.connect(_on_melee_attack)

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
		var spawn_pos = Vector2.from_angle(angle) * 100
		_spawn_enemy_at(spawn_pos)

func _spawn_enemy_at(pos: Vector2):
	if enemy_registry.has_method("spawn_enemy"):
		enemy_registry.spawn_enemy("basic", pos)
	else:
		# Fallback manual enemy creation
		var enemy_data = {
			"id": "enemy_" + str(Time.get_unix_time_from_system()),
			"type": "basic",
			"pos": pos,
			"health": 50.0,
			"max_health": 50.0
		}
		if enemy_registry.has_method("add_enemy"):
			enemy_registry.add_enemy(enemy_data)

func _unhandled_input(event):
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_perform_melee_attack()
	elif event is InputEventKey and event.pressed and event.keycode == KEY_E:
		_spawn_enemy_near_mouse()

func _physics_process(delta):
	_handle_player_movement(delta)
	_update_info_display()

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

func _perform_melee_attack():
	var current_time = Time.get_time_dict_from_system()
	var time_float = current_time.hour * 3600 + current_time.minute * 60 + current_time.second
	
	if time_float - last_attack_time < attack_cooldown:
		return
	
	last_attack_time = time_float
	
	var attack_pos = player.global_position
	var mouse_pos = get_global_mouse_position()
	var attack_direction = (mouse_pos - attack_pos).normalized()
	
	if melee_system.has_method("perform_melee_attack"):
		melee_system.perform_melee_attack(attack_pos, attack_direction, 25.0, 50.0)
	print("Melee attack performed toward mouse position")

func _spawn_enemy_near_mouse():
	var mouse_pos = get_global_mouse_position()
	_spawn_enemy_at(mouse_pos)
	print("Enemy spawned at mouse position")

func _on_melee_attack(attack_data: Dictionary):
	print("Melee attack hit: ", attack_data)

func _on_enemies_updated(alive_enemies: Array):
	enemy_multimesh.multimesh.instance_count = alive_enemies.size()
	
	for i in range(alive_enemies.size()):
		var enemy = alive_enemies[i]
		var transform = Transform2D()
		if enemy.has("pos"):
			transform.origin = enemy["pos"]
		elif enemy.has("position"):
			transform.origin = enemy["position"]
		enemy_multimesh.multimesh.set_instance_transform_2d(i, transform)

func _update_info_display():
	var enemy_count = 0
	var can_attack = Time.get_time_dict_from_system().hour * 3600 + Time.get_time_dict_from_system().minute * 60 + Time.get_time_dict_from_system().second - last_attack_time >= attack_cooldown
	
	if enemy_registry and enemy_registry.has_method("get_alive_enemies"):
		enemy_count = enemy_registry.get_alive_enemies().size()
	
	info_label.text = "Melee System Test\n"
	info_label.text += "WASD: Move\n"
	info_label.text += "Click: Melee attack\n"
	info_label.text += "E: Spawn enemy at mouse\n\n"
	info_label.text += "Player pos: " + str(player.global_position.round()) + "\n"
	info_label.text += "Attack ready: " + ("Yes" if can_attack else "No") + "\n"
	info_label.text += "Enemies alive: " + str(enemy_count)