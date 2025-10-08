## ProjectileStressTest.gd
## Real-time performance test for projectile + enemy entity limits
##
## Tests scene-based projectile architecture under heavy load to validate
## theoretical 500-600 entity budget claims.
##
## Controls:
##   1-5: Spawn projectile waves (20, 50, 100, 150, 200)
##   6-9: Spawn enemy waves (100, 200, 300, 400)
##   C: Clear all entities
##   Space: Auto-spawn to target (500 total entities)
extends Node2D

# Performance monitoring
var fps_samples: Array[float] = []
var frame_times: Array[float] = []
var last_fps_update := 0.0

# Entity tracking
var active_projectiles: Array[Node2D] = []
var active_enemies: Array[Node2D] = []

# Test configuration
var projectile_scene := preload("res://scenes/abilities/projectiles/Arrow.tscn")
var target_total_entities := 500  # Target for stress test

# UI references
@onready var stats_label: Label = $CanvasLayer/StatsPanel/StatsLabel

func _ready() -> void:
	print("=== Projectile Stress Test ===")

	# Disable VSync to prevent monitor refresh sync (144 Hz), use max_fps instead
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 60

	# Verify settings applied
	print("VSync Mode: %d (0 = DISABLED)" % DisplayServer.window_get_vsync_mode())
	print("Max FPS: %d (ignoring monitor refresh rate)" % Engine.max_fps)
	print("")
	print("Controls:")
	print("  1-5: Spawn projectiles (20, 50, 100, 150, 200)")
	print("  6-9: Spawn enemies (100, 200, 300, 400)")
	print("  C: Clear all entities")
	print("  Space: Auto-spawn to %d total" % target_total_entities)
	print("")

	_update_stats_display()


func _process(delta: float) -> void:
	# Track frame timing
	var current_fps = Engine.get_frames_per_second()
	fps_samples.append(current_fps)
	frame_times.append(delta * 1000.0)  # ms

	# Keep last 60 samples (1 second at 60fps)
	if fps_samples.size() > 60:
		fps_samples.pop_front()
		frame_times.pop_front()

	# Update display every 0.5s
	last_fps_update += delta
	if last_fps_update >= 0.5:
		_update_stats_display()
		last_fps_update = 0.0

	# Clean up invalid entities
	_cleanup_invalid_entities()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_1: _spawn_projectiles(20)
			KEY_2: _spawn_projectiles(50)
			KEY_3: _spawn_projectiles(100)
			KEY_4: _spawn_projectiles(150)
			KEY_5: _spawn_projectiles(200)
			KEY_6: _spawn_test_enemies(100)
			KEY_7: _spawn_test_enemies(200)
			KEY_8: _spawn_test_enemies(300)
			KEY_9: _spawn_test_enemies(400)
			KEY_C: _clear_all_entities()
			KEY_SPACE: _auto_spawn_to_target()


## Spawns a wave of projectiles in various directions
func _spawn_projectiles(count: int) -> void:
	print("Spawning %d projectiles..." % count)

	for i in range(count):
		var projectile = projectile_scene.instantiate()

		# Random position around center
		var angle = randf() * TAU
		var distance = randf_range(100, 300)
		projectile.position = Vector2(cos(angle), sin(angle)) * distance

		# Random direction
		var dir_angle = randf() * TAU
		var direction = Vector2(cos(dir_angle), sin(dir_angle))

		# Initialize projectile (if it has initialize method)
		if projectile.has_method("initialize"):
			projectile.initialize({
				"ability_id": "stress_test",
				"source_position": projectile.position,
				"direction": direction,
				"damage": 10.0,
				"damage_type": "physical",
				"tags": ["projectile"],
				"projectile_speed": 400.0,
				"projectile_lifetime": 5.0,
				"is_homing": false,
				"pierce_count": 0,
				"knockback_distance": 0.0,
				"visual_scene_key": "arrow"
			})

		add_child(projectile)
		active_projectiles.append(projectile)

	print("✓ Spawned %d projectiles (total now: %d)" % [count, active_projectiles.size()])


## Spawns test enemies (simple Sprite2D for performance testing)
func _spawn_test_enemies(count: int) -> void:
	print("Spawning %d test enemies..." % count)

	for i in range(count):
		# Create lightweight enemy representation
		var enemy = Sprite2D.new()
		enemy.name = "TestEnemy_%d" % i

		# Create simple visual
		var texture = ImageTexture.create_from_image(
			Image.create(16, 16, false, Image.FORMAT_RGB8)
		)
		enemy.texture = texture
		enemy.modulate = Color(1.0, 0.3, 0.3)  # Red tint

		# Random position around center
		var angle = randf() * TAU
		var distance = randf_range(200, 500)
		enemy.position = Vector2(cos(angle), sin(angle)) * distance

		# Add to "enemies" group for projectile detection
		enemy.add_to_group("enemies")

		add_child(enemy)
		active_enemies.append(enemy)

	print("✓ Spawned %d enemies (total now: %d)" % [count, active_enemies.size()])


## Automatically spawns entities to reach target total
func _auto_spawn_to_target() -> void:
	var current_total = active_projectiles.size() + active_enemies.size()
	var needed = target_total_entities - current_total

	if needed <= 0:
		print("Already at or above target (%d total)" % current_total)
		return

	# Split 60/40 between projectiles and enemies
	var projectiles_to_spawn = int(needed * 0.6)
	var enemies_to_spawn = needed - projectiles_to_spawn

	print("Auto-spawning to target %d total entities..." % target_total_entities)
	print("  Projectiles: +%d" % projectiles_to_spawn)
	print("  Enemies: +%d" % enemies_to_spawn)

	_spawn_projectiles(projectiles_to_spawn)
	_spawn_test_enemies(enemies_to_spawn)


## Clears all test entities
func _clear_all_entities() -> void:
	print("Clearing all entities...")

	# Clear projectiles
	for projectile in active_projectiles:
		if is_instance_valid(projectile):
			projectile.queue_free()
	active_projectiles.clear()

	# Clear enemies
	for enemy in active_enemies:
		if is_instance_valid(enemy):
			enemy.queue_free()
	active_enemies.clear()

	print("✓ All entities cleared")


## Removes invalid entities from tracking arrays
func _cleanup_invalid_entities() -> void:
	active_projectiles = active_projectiles.filter(func(p): return is_instance_valid(p))
	active_enemies = active_enemies.filter(func(e): return is_instance_valid(e))


## Updates the stats display with current metrics
func _update_stats_display() -> void:
	if not stats_label:
		return

	# Calculate stats
	var current_fps = Engine.get_frames_per_second()
	var avg_fps = _calculate_average(fps_samples)
	var min_fps = _calculate_min(fps_samples)
	var avg_frame_time = _calculate_average(frame_times)

	var total_entities = active_projectiles.size() + active_enemies.size()

	# FPS color coding
	var fps_color := Color.GREEN
	if avg_fps < 55:
		fps_color = Color.YELLOW
	if avg_fps < 45:
		fps_color = Color.RED

	# Build stats text
	var stats_text := ""
	stats_text += "=== PERFORMANCE METRICS ===\n"
	stats_text += "FPS: [color=%s]%.1f[/color] (avg: %.1f, min: %.1f)\n" % [
		fps_color.to_html(false), current_fps, avg_fps, min_fps
	]
	stats_text += "Frame Time: %.2f ms\n" % avg_frame_time
	stats_text += "\n"
	stats_text += "=== ENTITY COUNTS ===\n"
	stats_text += "Projectiles: %d\n" % active_projectiles.size()
	stats_text += "Enemies: %d\n" % active_enemies.size()
	stats_text += "TOTAL: [color=%s]%d[/color]\n" % [
		_get_entity_count_color(total_entities).to_html(false),
		total_entities
	]
	stats_text += "\n"
	stats_text += "=== BUDGET ANALYSIS ===\n"
	stats_text += _get_performance_assessment(avg_fps, total_entities)

	stats_label.text = stats_text


## Returns color based on entity count (green < 300, yellow < 600, red >= 600)
func _get_entity_count_color(count: int) -> Color:
	if count < 300:
		return Color.GREEN
	elif count < 600:
		return Color.YELLOW
	else:
		return Color.RED


## Returns performance assessment text
func _get_performance_assessment(avg_fps: float, total_entities: int) -> String:
	var assessment := ""

	if avg_fps >= 58 and total_entities < 300:
		assessment = "✅ Excellent - Plenty of headroom"
	elif avg_fps >= 55 and total_entities < 500:
		assessment = "✅ Good - Scene-based comfortable range"
	elif avg_fps >= 50 and total_entities < 700:
		assessment = "⚠️  Acceptable - Approaching limits"
	elif avg_fps >= 45:
		assessment = "⚠️  Degraded - Consider optimization"
	else:
		assessment = "❌ Poor - MultiMesh needed"

	# Add entity budget recommendation
	var projectile_budget = 600 - active_enemies.size()
	if projectile_budget > 0:
		assessment += "\n\nProjectile budget: ~%d max\n(with %d enemies)" % [
			projectile_budget, active_enemies.size()
		]

	return assessment


## Helper: Calculate average of float array
func _calculate_average(values: Array[float]) -> float:
	if values.is_empty():
		return 0.0
	var sum := 0.0
	for v in values:
		sum += v
	return sum / values.size()


## Helper: Calculate minimum of float array
func _calculate_min(values: Array[float]) -> float:
	if values.is_empty():
		return 0.0
	var min_val := INF
	for v in values:
		if v < min_val:
			min_val = v
	return min_val
