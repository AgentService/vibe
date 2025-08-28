extends Node

## Isolated test for EnemyHitFeedback system
## Tests flash and knockback effects with deterministic damage events

class_name EnemyHitFeedbackTest

var test_enemy_sprite: Sprite2D
var test_enemy_body: CharacterBody2D
var hit_feedback: EnemyHitFeedback
var test_results: Array[String] = []
var test_frame_count: int = 0
const MAX_TEST_FRAMES: int = 180  # 6 seconds at 30 FPS

func _ready() -> void:
	Logger.info("Starting EnemyHitFeedback isolated test", "test")
	
	# Seed RNG for deterministic tests
	RNG.seed_all(12345)
	
	# Setup test scene
	_setup_test_scene()
	
	# Run tests
	await _run_flash_test()
	await _run_knockback_test()
	await _run_combined_test()
	
	# Report results
	_report_results()

func _setup_test_scene() -> void:
	"""Setup a minimal test scene with enemy sprite and hit feedback"""
	
	# Create test enemy body
	test_enemy_body = CharacterBody2D.new()
	test_enemy_body.name = "TestEnemy"
	test_enemy_body.position = Vector2(400, 300)
	add_child(test_enemy_body)
	
	# Create test enemy sprite
	test_enemy_sprite = Sprite2D.new()
	test_enemy_sprite.name = "EnemySprite"
	
	# Create a simple colored texture for testing
	var image = Image.create(32, 32, false, Image.FORMAT_RGB8)
	image.fill(Color.RED)
	var texture = ImageTexture.new()
	texture.set_image(image)
	test_enemy_sprite.texture = texture
	
	test_enemy_body.add_child(test_enemy_sprite)
	
	# Create hit feedback component
	hit_feedback = EnemyHitFeedback.new()
	hit_feedback.name = "HitFeedback"
	test_enemy_body.add_child(hit_feedback)
	
	# Setup hit feedback - use the same format that EntityId.enemy(999) will produce
	hit_feedback.setup("ENEMY:999", test_enemy_sprite, test_enemy_body, false)
	
	Logger.info("Test scene setup complete", "test")

func _run_flash_test() -> void:
	"""Test flash effect functionality"""
	Logger.info("Running flash effect test", "test")
	
	var original_color = test_enemy_sprite.modulate
	
	# Create damage payload with no knockback
	var test_entity_id = EntityId.enemy(999)  # Use a test enemy ID
	var damage_payload = EventBus.DamageAppliedPayload_Type.new(
		test_entity_id,
		50.0,
		false,  # Not a crit
		PackedStringArray(["melee"]),
		0.0,  # No knockback
		Vector2(300, 300)  # Source position
	)
	
	# Trigger damage event
	EventBus.damage_applied.emit(damage_payload)
	
	# Wait a frame for the effect to start
	await get_tree().process_frame
	
	# Check if sprite color changed (flash started)
	if test_enemy_sprite.modulate != original_color:
		test_results.append("✓ Flash effect started correctly")
	else:
		test_results.append("✗ Flash effect failed to start")
	
	# Wait for flash to complete
	await get_tree().create_timer(0.3).timeout
	
	# Check if sprite returned to original color
	if test_enemy_sprite.modulate == original_color:
		test_results.append("✓ Flash effect completed correctly")
	else:
		test_results.append("✗ Flash effect failed to reset color")

func _run_knockback_test() -> void:
	"""Test knockback effect functionality"""
	Logger.info("Running knockback effect test", "test")
	
	var original_position = test_enemy_body.position
	
	# Create damage payload with knockback
	var test_entity_id = EntityId.enemy(999)  # Use same test enemy ID
	var damage_payload = EventBus.DamageAppliedPayload_Type.new(
		test_entity_id,
		30.0,
		false,
		PackedStringArray(["melee"]),
		50.0,  # 50 pixel knockback
		Vector2(300, 300)  # Source position (left of enemy)
	)
	
	# Trigger damage event
	EventBus.damage_applied.emit(damage_payload)
	
	# Wait a frame for the effect to start
	await get_tree().process_frame
	
	# Check if knockback velocity is set
	if hit_feedback.get_knockback_velocity().length() > 0:
		test_results.append("✓ Knockback effect started correctly")
	else:
		test_results.append("✗ Knockback effect failed to start")
	
	# Wait for knockback to complete
	await get_tree().create_timer(0.2).timeout
	
	# Check if knockback finished
	if not hit_feedback.is_being_knocked_back():
		test_results.append("✓ Knockback effect completed correctly")
	else:
		test_results.append("✗ Knockback effect failed to complete")

func _run_combined_test() -> void:
	"""Test flash and knockback together (critical hit)"""
	Logger.info("Running combined effect test", "test")
	
	var original_color = test_enemy_sprite.modulate
	
	# Create critical damage payload with knockback
	var test_entity_id = EntityId.enemy(999)  # Use same test enemy ID
	var damage_payload = EventBus.DamageAppliedPayload_Type.new(
		test_entity_id,
		100.0,
		true,  # Critical hit
		PackedStringArray(["melee"]),
		75.0,  # Larger knockback
		Vector2(350, 250)  # Different source position
	)
	
	# Trigger damage event
	EventBus.damage_applied.emit(damage_payload)
	
	# Wait a frame for effects to start
	await get_tree().process_frame
	
	# Check if both effects started
	var flash_started = test_enemy_sprite.modulate != original_color
	var knockback_started = hit_feedback.get_knockback_velocity().length() > 0
	
	if flash_started and knockback_started:
		test_results.append("✓ Combined effects started correctly")
	else:
		test_results.append("✗ Combined effects failed to start (flash: %s, knockback: %s)" % [flash_started, knockback_started])
	
	# Wait for effects to complete
	await get_tree().create_timer(0.4).timeout
	
	# Check if both effects completed
	var flash_completed = test_enemy_sprite.modulate == original_color
	var knockback_completed = not hit_feedback.is_being_knocked_back()
	
	if flash_completed and knockback_completed:
		test_results.append("✓ Combined effects completed correctly")
	else:
		test_results.append("✗ Combined effects failed to complete (flash: %s, knockback: %s)" % [flash_completed, knockback_completed])

func _run_wrong_entity_test() -> void:
	"""Test that feedback ignores damage for other entities"""
	Logger.info("Running wrong entity test", "test")
	
	var original_color = test_enemy_sprite.modulate
	
	# Create damage payload for different entity
	var other_entity_id = EntityId.enemy(888)  # Different entity ID
	var damage_payload = EventBus.DamageAppliedPayload_Type.new(
		other_entity_id,
		50.0,
		false,
		PackedStringArray(["melee"]),
		25.0,
		Vector2(300, 300)
	)
	
	# Trigger damage event
	EventBus.damage_applied.emit(damage_payload)
	
	# Wait a frame
	await get_tree().process_frame
	
	# Check that no effects were triggered
	var no_flash = test_enemy_sprite.modulate == original_color
	var no_knockback = hit_feedback.get_knockback_velocity().length() == 0
	
	if no_flash and no_knockback:
		test_results.append("✓ Correctly ignored damage for other entity")
	else:
		test_results.append("✗ Incorrectly responded to damage for other entity")

func _report_results() -> void:
	"""Report test results"""
	Logger.info("=== EnemyHitFeedback Test Results ===", "test")
	
	var passed = 0
	var total = test_results.size()
	
	for result in test_results:
		Logger.info(result, "test")
		if result.begins_with("✓"):
			passed += 1
	
	var success_rate = (float(passed) / float(total)) * 100.0
	Logger.info("Tests passed: %d/%d (%.1f%%)" % [passed, total, success_rate], "test")
	
	if passed == total:
		Logger.info("✓ All EnemyHitFeedback tests PASSED", "test")
	else:
		Logger.warn("✗ Some EnemyHitFeedback tests FAILED", "test")
	
	# Cleanup
	queue_free()

func _process(_delta: float) -> void:
	test_frame_count += 1
	if test_frame_count > MAX_TEST_FRAMES:
		Logger.warn("EnemyHitFeedback test exceeded max frames, terminating", "test")
		_report_results()
