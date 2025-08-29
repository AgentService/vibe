extends Node

## Isolated Boss System Test
## Tests BaseBoss functionality, health signals, DamageService integration

var test_boss: BaseBoss
var test_spawn_config: SpawnConfig
var health_signals_received: int = 0
var died_signal_received: bool = false

func _ready() -> void:
	print("=== BOSS SYSTEM ISOLATED TEST START ===")
	
	# Connect test timer
	var timer = $TestTimer
	timer.timeout.connect(_finish_test)
	
	# Run tests in sequence
	await get_tree().process_frame  # Wait one frame for autoloads
	_test_boss_creation()
	
	timer.start()

func _test_boss_creation() -> void:
	print("\n[TEST] Creating test boss...")
	
	# Create spawn config with stable entity ID
	test_spawn_config = SpawnConfig.new(150.0, 30.0, 70.0)
	test_spawn_config.template_id = "test_boss"
	test_spawn_config.render_tier = "boss"
	test_spawn_config.position = Vector2(100, 100)
	test_spawn_config.set_entity_id("test_boss:isolated_test:1")
	
	# Load and instantiate boss template
	var boss_scene = load("res://scenes/bosses/BossTemplate.tscn")
	if not boss_scene:
		print("[ERROR] Failed to load BossTemplate.tscn")
		get_tree().quit(1)
		return
	
	test_boss = boss_scene.instantiate() as BaseBoss
	if not test_boss:
		print("[ERROR] Failed to instantiate BaseBoss from template")
		get_tree().quit(1)
		return
	
	# Connect to signals
	test_boss.health_changed.connect(_on_boss_health_changed)
	test_boss.died.connect(_on_boss_died)
	
	# Add to scene and setup
	add_child(test_boss)
	test_boss.setup_from_spawn_config(test_spawn_config)
	
	print("[PASS] Boss created successfully")
	print("  Entity ID: " + test_boss.entity_id)
	print("  Health: %.1f/%.1f" % [test_boss.get_current_health(), test_boss.get_max_health()])
	
	await get_tree().process_frame
	_test_damage_integration()

func _test_damage_integration() -> void:
	print("\n[TEST] Testing damage integration...")
	
	var initial_health = test_boss.get_current_health()
	
	# Test DamageService damage application
	var damage_applied = DamageService.apply_damage(test_boss.entity_id, 25.0, "test", ["test"])
	
	await get_tree().process_frame
	
	var new_health = test_boss.get_current_health()
	
	if new_health < initial_health:
		print("[PASS] Damage integration working")
		print("  Health: %.1f → %.1f (took %.1f damage)" % [initial_health, new_health, initial_health - new_health])
	else:
		print("[FAIL] Damage not applied correctly")
		print("  Expected health < %.1f, got %.1f" % [initial_health, new_health])
	
	await get_tree().process_frame
	_test_death_sequence()

func _test_death_sequence() -> void:
	print("\n[TEST] Testing death sequence...")
	
	# Deal lethal damage
	var current_health = test_boss.get_current_health()
	var damage_applied = DamageService.apply_damage(test_boss.entity_id, current_health + 10.0, "test", ["lethal"])
	
	# Wait for signal processing
	await get_tree().process_frame
	await get_tree().process_frame
	
	if died_signal_received:
		print("[PASS] Death sequence triggered correctly")
	else:
		print("[FAIL] Death signal not received")

func _on_boss_health_changed(current: float, max_health: float) -> void:
	health_signals_received += 1
	print("[SIGNAL] health_changed: %.1f/%.1f (signal #%d)" % [current, max_health, health_signals_received])

func _on_boss_died(entity_id: String) -> void:
	died_signal_received = true
	print("[SIGNAL] died: " + entity_id)

func _finish_test() -> void:
	print("\n=== BOSS SYSTEM TEST RESULTS ===")
	print("Health signals received: %d" % health_signals_received)
	print("Death signal received: %s" % str(died_signal_received))
	
	var passed_tests = 0
	var total_tests = 3
	
	if test_boss and test_boss.entity_id == "test_boss:isolated_test:1":
		passed_tests += 1
		print("✓ Boss creation and setup")
	else:
		print("✗ Boss creation and setup")
	
	if health_signals_received >= 1:
		passed_tests += 1
		print("✓ Health signal propagation")
	else:
		print("✗ Health signal propagation")
	
	if died_signal_received:
		passed_tests += 1
		print("✓ Death sequence")
	else:
		print("✗ Death sequence")
	
	print("\nPassed: %d/%d tests" % [passed_tests, total_tests])
	
	if passed_tests == total_tests:
		print("=== ALL TESTS PASSED ===")
		get_tree().quit(0)
	else:
		print("=== SOME TESTS FAILED ===")
		get_tree().quit(1)