extends Node2D

# Visual Effects POC Test Harness
# Auto-fires projectiles and AOE effects for visual testing

# Effect methods (will be created next)
const MethodA_Projectile = preload("res://tests/visual_effects/effects/MethodA_SpriteShader.tscn")
const MethodA_AOE = preload("res://tests/visual_effects/effects/MethodA_SpriteShader_AOE.tscn")
const MethodB_Projectile = preload("res://tests/visual_effects/effects/MethodB_GPUParticles.tscn")
const MethodB_AOE = preload("res://tests/visual_effects/effects/MethodB_GPUParticles_AOE.tscn")
const MethodC_AOE = preload("res://tests/visual_effects/effects/MethodC_Line2D.tscn")

@onready var player: Sprite2D = $TestPlayer

# Test parameters
var test_scale: float = 1.0
var test_aoe: float = 150.0
var test_color: Color = Color.WHITE
var active_effects: Array[Node] = []

# Auto-fire settings
var auto_fire_enabled: bool = false
var auto_fire_interval: float = 1.0
var auto_fire_timer: float = 0.0
var current_method: int = 0  # 0=A_Projectile, 1=A_AOE, 2=B_Projectile, 3=B_AOE, 4=C_AOE

func _ready() -> void:
	print("=== Visual Effects POC ===")
	print("Controls:")
	print("  1 - Method A: Sprite+Shader (Projectile)")
	print("  2 - Method A: Sprite+Shader (AOE)")
	print("  3 - Method B: GPUParticles (Projectile)")
	print("  4 - Method B: GPUParticles (AOE)")
	print("  5 - Method C: Line2D (AOE)")
	print("  SPACE - Stress test (100 random effects)")
	print("  C - Clear all effects")
	print("  A - Toggle auto-fire (fires every 1 second)")
	print("  + / - - Adjust effect scale")
	print("  [ / ] - Adjust AOE radius")
	print("")

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_1:
				_spawn_effect(MethodA_Projectile, "Sprite+Shader (Projectile)", false)
				current_method = 0
			KEY_2:
				_spawn_effect(MethodA_AOE, "Sprite+Shader (AOE)", true)
				current_method = 1
			KEY_3:
				_spawn_effect(MethodB_Projectile, "GPUParticles (Projectile)", false)
				current_method = 2
			KEY_4:
				_spawn_effect(MethodB_AOE, "GPUParticles (AOE)", true)
				current_method = 3
			KEY_5:
				_spawn_effect(MethodC_AOE, "Line2D (AOE)", true)
				current_method = 4
			KEY_SPACE:
				_stress_test()
			KEY_C:
				_clear_effects()
			KEY_A:
				auto_fire_enabled = not auto_fire_enabled
				print("Auto-fire: %s" % ("ENABLED" if auto_fire_enabled else "DISABLED"))
			KEY_EQUAL, KEY_KP_ADD:  # + key
				test_scale = clamp(test_scale + 0.1, 0.5, 3.0)
				print("Scale: %.1f" % test_scale)
			KEY_MINUS, KEY_KP_SUBTRACT:  # - key
				test_scale = clamp(test_scale - 0.1, 0.5, 3.0)
				print("Scale: %.1f" % test_scale)
			KEY_BRACKETLEFT:  # [ key
				test_aoe = clamp(test_aoe - 25.0, 50.0, 500.0)
				print("AOE Radius: %.0f" % test_aoe)
			KEY_BRACKETRIGHT:  # ] key
				test_aoe = clamp(test_aoe + 25.0, 50.0, 500.0)
				print("AOE Radius: %.0f" % test_aoe)
			KEY_R:
				test_color = Color(randf(), randf(), randf())
				print("Color: %s" % test_color)

func _process(delta: float) -> void:
	# Clean up dead effects
	active_effects = active_effects.filter(func(e): return is_instance_valid(e))

	# Auto-fire logic
	if auto_fire_enabled:
		auto_fire_timer += delta
		if auto_fire_timer >= auto_fire_interval:
			auto_fire_timer = 0.0
			_spawn_auto_fire()

	# Update debug display
	_update_debug_display()

func _spawn_auto_fire() -> void:
	# Cycle through methods for auto-fire
	var scenes = [MethodA_Projectile, MethodA_AOE, MethodB_Projectile, MethodB_AOE, MethodC_AOE]
	var names = ["Sprite+Shader (Projectile)", "Sprite+Shader (AOE)", "GPUParticles (Projectile)", "GPUParticles (AOE)", "Line2D (AOE)"]
	var is_aoe = [false, true, false, true, true]

	_spawn_effect(scenes[current_method], names[current_method], is_aoe[current_method])

func _spawn_effect(scene: PackedScene, method_name: String, is_aoe: bool) -> void:
	var effect = scene.instantiate()

	# Configure effect
	var spawn_pos = player.global_position

	# For projectiles, spawn around player in a circle
	if not is_aoe:
		var angle = randf() * TAU
		var offset = Vector2(cos(angle), sin(angle)) * 100.0
		spawn_pos += offset

	if effect.has_method("configure"):
		effect.configure({
			"position": spawn_pos,
			"scale": test_scale,
			"aoe_radius": test_aoe,
			"color": test_color,
		})
	else:
		effect.global_position = spawn_pos
		effect.scale = Vector2.ONE * test_scale
		effect.modulate = test_color

	add_child(effect)
	active_effects.append(effect)
	print("[%s] Spawned at %.0f,%.0f (scale: %.2f, AOE: %.0f, color: %s)" % [
		method_name, spawn_pos.x, spawn_pos.y, test_scale, test_aoe, test_color
	])

func _stress_test() -> void:
	print("=== STRESS TEST: 100 random effects ===")
	var scenes = [MethodA_Projectile, MethodA_AOE, MethodB_Projectile, MethodB_AOE, MethodC_AOE]
	var names = ["Sprite+Shader (P)", "Sprite+Shader (AOE)", "GPUParticles (P)", "GPUParticles (AOE)", "Line2D (AOE)"]
	var is_aoe = [false, true, false, true, true]

	for i in 100:
		var idx = randi() % scenes.size()
		_spawn_effect(scenes[idx], names[idx], is_aoe[idx])

func _clear_effects() -> void:
	print("Clearing %d effects..." % active_effects.size())
	for effect in active_effects:
		if is_instance_valid(effect):
			effect.queue_free()
	active_effects.clear()

func _update_debug_display() -> void:
	# Update window title with debug info
	var fps = Engine.get_frames_per_second()
	var title = "Effects POC | FPS: %d | Active: %d | Scale: %.1f | AOE: %.0f | Auto: %s" % [
		fps, active_effects.size(), test_scale, test_aoe,
		"ON" if auto_fire_enabled else "OFF"
	]
	DisplayServer.window_set_title(title)
