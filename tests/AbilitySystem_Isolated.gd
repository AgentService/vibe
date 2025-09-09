extends Node2D

## TODO: Phase 2 - Replace with AbilityModule_Isolated test
## This file is disabled during Phase 1 removal - will be replaced with AbilityModule equivalent
## Original: Isolated ability system test - projectile spawning and management.
## Original: Tests projectile pooling, MultiMesh rendering, and lifecycle management.

@onready var player: CharacterBody2D = $Player
@onready var projectile_multimesh: MultiMeshInstance2D = $ProjectileMultiMesh
@onready var info_label: Label = $UILayer/HUD/InfoLabel

const PLAYER_SPEED = 300.0
const AbilitySystem = preload("res://scripts/systems/AbilitySystem.gd")

var ability_system: AbilitySystem
var arena_bounds: float = 600.0
var max_projectiles: int = 100
var auto_fire: bool = false
var fire_rate: float = 5.0  # projectiles per second
var fire_timer: float = 0.0

func _ready():
	print("=== AbilitySystem_Isolated Test DISABLED (Phase 1) ===")
	print("This test is temporarily disabled during AbilitySystem removal")
	print("Will be replaced with AbilityModule_Isolated in Phase 2")
	
	# Disable test functionality during Phase 1
	# _setup_player()
	# _setup_ability_system()
	# _setup_projectile_multimesh()
	
	# Show message and quit
	get_tree().create_timer(2.0).timeout.connect(func(): get_tree().quit())

func _setup_player():
	var player_sprite = player.get_node("Sprite2D")
	var player_collision = player.get_node("CollisionShape2D")
	
	# Create cyan player texture
	var texture = ImageTexture.new()
	var image = Image.create(32, 32, false, Image.FORMAT_RGB8)
	image.fill(Color.CYAN)
	texture.set_image(image)
	player_sprite.texture = texture
	
	# Set up collision shape
	var shape = RectangleShape2D.new()
	shape.size = Vector2(32, 32)
	player_collision.shape = shape

func _setup_ability_system():
	ability_system = AbilitySystem.new()
	add_child(ability_system)
	
	# Override balance values with test values
	ability_system.max_projectiles = max_projectiles
	ability_system.arena_bounds = arena_bounds
	
	# Initialize the projectile pool
	ability_system._initialize_pool()
	
	# Connect to projectile updates
	if ability_system.has_signal("projectiles_updated"):
		ability_system.projectiles_updated.connect(_on_projectiles_updated)

func _setup_projectile_multimesh():
	var multimesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_2D
	multimesh.instance_count = 0
	
	var quad_mesh = QuadMesh.new()
	quad_mesh.size = Vector2(8, 8)
	multimesh.mesh = quad_mesh
	
	# Yellow projectile texture
	var texture = ImageTexture.new()
	var image = Image.create(8, 8, false, Image.FORMAT_RGB8)
	image.fill(Color.YELLOW)
	texture.set_image(image)
	projectile_multimesh.texture = texture
	
	projectile_multimesh.multimesh = multimesh

func _unhandled_input(event):
	if event is InputEventMouseButton and event.pressed:
		print("Mouse button pressed: ", event.button_index)
		if event.button_index == MOUSE_BUTTON_LEFT:
			print("Left mouse button detected - firing projectile")
			_fire_projectile_toward_mouse()
	elif event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_SPACE:
				_toggle_auto_fire()
			KEY_C:
				_clear_all_projectiles()
			KEY_EQUAL, KEY_PLUS:
				fire_rate = min(fire_rate + 1.0, 20.0)
				print("Fire rate: ", fire_rate, " per second")
			KEY_MINUS:
				fire_rate = max(fire_rate - 1.0, 1.0)
				print("Fire rate: ", fire_rate, " per second")
			KEY_KP_ADD:  # Numpad +
				fire_rate = min(fire_rate + 1.0, 20.0)
				print("Fire rate: ", fire_rate, " per second")
			KEY_KP_SUBTRACT:  # Numpad -
				fire_rate = max(fire_rate - 1.0, 1.0)
				print("Fire rate: ", fire_rate, " per second")

func _physics_process(delta):
	_handle_player_movement(delta)
	_handle_auto_fire(delta)
	_simulate_combat_step(delta)
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

func _handle_auto_fire(delta):
	if not auto_fire:
		return
	
	fire_timer += delta
	var fire_interval = 1.0 / fire_rate
	
	if fire_timer >= fire_interval:
		fire_timer = 0.0
		_fire_projectile_in_random_direction()

func _simulate_combat_step(delta):
	# Simulate the combat step that would normally come from EventBus
	var payload = {
		"dt": delta
	}
	if ability_system.has_method("_on_combat_step"):
		ability_system._on_combat_step(payload)
	else:
		# Manual update if method isn't available
		ability_system._update_projectiles(delta)
		var alive_projectiles = ability_system._get_alive_projectiles()
		ability_system.projectiles_updated.emit(alive_projectiles)

func _fire_projectile_toward_mouse():
	var player_pos = player.global_position
	var mouse_pos = get_global_mouse_position()
	var direction = (mouse_pos - player_pos).normalized()
	
	print("Firing projectile from ", player_pos, " toward ", mouse_pos, " direction: ", direction)
	ability_system.spawn_projectile(player_pos, direction, 400.0, 3.0)
	
	# Check projectile count after firing
	var alive_count = ability_system._get_alive_projectiles().size()
	print("Projectiles alive after firing: ", alive_count)

func _fire_projectile_in_random_direction():
	var player_pos = player.global_position
	var direction = Vector2.from_angle(randf() * TAU)
	
	ability_system.spawn_projectile(player_pos, direction, 400.0, 3.0)

func _toggle_auto_fire():
	auto_fire = not auto_fire
	print("Auto-fire: ", "ON" if auto_fire else "OFF")
	fire_timer = 0.0

func _clear_all_projectiles():
	for projectile in ability_system.projectiles:
		projectile["alive"] = false
	print("Cleared all projectiles")

func _on_projectiles_updated(alive_projectiles: Array):
	projectile_multimesh.multimesh.instance_count = alive_projectiles.size()
	
	for i in range(alive_projectiles.size()):
		var projectile = alive_projectiles[i]
		var transform = Transform2D()
		transform.origin = projectile["pos"]
		projectile_multimesh.multimesh.set_instance_transform_2d(i, transform)

func _update_info_display():
	var player_pos = player.global_position
	var alive_projectiles = ability_system._get_alive_projectiles()
	var projectile_count = alive_projectiles.size()
	var pool_usage = float(projectile_count) / float(max_projectiles) * 100.0
	
	# Count projectiles by location (near/far from player)
	var near_projectiles = 0
	var far_projectiles = 0
	for projectile in alive_projectiles:
		var distance = player_pos.distance_to(projectile["pos"])
		if distance < 200.0:
			near_projectiles += 1
		else:
			far_projectiles += 1
	
	info_label.text = "Ability System Test\n"
	info_label.text += "WASD: Move player\n"
	info_label.text += "Click: Fire toward mouse\n"
	info_label.text += "Space: Toggle auto-fire\n"
	info_label.text += "C: Clear all projectiles\n"
	info_label.text += "+/- (or numpad): Adjust fire rate\n\n"
	info_label.text += "Player pos: " + str(player_pos.round()) + "\n"
	info_label.text += "Projectiles: " + str(projectile_count) + "/" + str(max_projectiles) + "\n"
	info_label.text += "Pool usage: " + str(pool_usage) + "%\n"
	info_label.text += "Near player: " + str(near_projectiles) + "\n"
	info_label.text += "Far from player: " + str(far_projectiles) + "\n"
	info_label.text += "Auto-fire: " + ("ON" if auto_fire else "OFF") + "\n"
	info_label.text += "Fire rate: " + str(fire_rate) + "/sec\n"
	info_label.text += "Arena bounds: ±" + str(arena_bounds)
