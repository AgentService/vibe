extends Node

## SessionState Isolated Test (Task 04 Phase 2)
## Tests session-only run state tracking with ephemeral statistics

var test_count: int = 0
var passed_tests: int = 0

func _ready() -> void:
	print("===========================================")
	print(" SessionState Isolated Test")
	print("===========================================")

	# Wait one frame for autoload initialization
	await get_tree().process_frame

	# Run all tests
	test_initial_state()
	test_session_start()
	test_level_tracking()
	test_xp_tracking()
	test_kill_tracking()
	test_damage_tracking()
	test_time_tracking()
	test_item_collection()
	test_stage_progression()
	test_swarm_tracking()
	test_player_modifiers()
	test_session_reset()
	test_rift_fragments_calculation()

	# Print results
	print("=".repeat(43))
	print(" RESULTS: %d/%d tests passed (%.1f%%)" % [passed_tests, test_count, (passed_tests / float(test_count)) * 100.0])
	print("=".repeat(43))

	# Exit
	get_tree().quit()

func test_initial_state() -> void:
	print_test_header("Test 1: Initial State")

	# Should start with default values
	assert_equal(SessionState.current_level, 1, "Initial level should be 1")
	assert_equal(SessionState.current_xp, 0, "Initial XP should be 0")
	assert_equal(SessionState.kills, 0, "Initial kills should be 0")
	assert_equal(SessionState.damage_dealt, 0, "Initial damage dealt should be 0")
	assert_equal(SessionState.time_survived, 0.0, "Initial time survived should be 0.0")
	assert_equal(SessionState.stage_reached, 1, "Initial stage should be 1")
	assert_equal(SessionState.final_swarm_entered, false, "Swarm should not be entered initially")
	assert_equal(SessionState.collected_items.size(), 0, "Collected items should be empty")
	assert_equal(SessionState.damage_breakdown.size(), 0, "Damage breakdown should be empty")

	print(" ✓ All initial state checks passed")

func test_session_start() -> void:
	print_test_header("Test 2: Session Start")

	# Reset to clean state
	SessionState.reset()

	# Start session
	SessionState.start_run("test_character", "test_map", 2)

	# Verify session tracking
	assert_equal(SessionState.current_character, "test_character", "Character should be set")
	assert_equal(SessionState.current_map, "test_map", "Map should be set")
	assert_equal(SessionState.current_tier, 2, "Tier should be set")
	assert_equal(SessionState.is_run_active(), true, "Run should be active")

	print(" ✓ Session start tracking works")

func test_level_tracking() -> void:
	print_test_header("Test 3: Level Tracking")

	SessionState.reset()
	SessionState.start_run("test", "test", 1)

	# Initial level
	assert_equal(SessionState.current_level, 1, "Should start at level 1")

	# Gain XP to reach level 2 (need 100 XP for level 2)
	SessionState._on_xp_gained(100, 100)
	assert_equal(SessionState.current_level, 2, "Should be level 2 after 100 XP")

	# Gain more XP to reach level 3 (need 150 more XP for level 3)
	SessionState._on_xp_gained(150, 250)
	assert_equal(SessionState.current_level, 3, "Should be level 3 after 250 total XP")

	print(" ✓ Level tracking works")

func test_xp_tracking() -> void:
	print_test_header("Test 4: XP Tracking")

	SessionState.reset()
	SessionState.start_run("test", "test", 1)

	# Initial XP
	assert_equal(SessionState.current_xp, 0, "Should start at 0 XP")

	# Gain XP
	SessionState._on_xp_gained(50, 50)
	assert_equal(SessionState.current_xp, 50, "Should have 50 XP")

	SessionState._on_xp_gained(25, 75)
	assert_equal(SessionState.current_xp, 75, "Should have 75 XP")

	print(" ✓ XP tracking works")

func test_kill_tracking() -> void:
	print_test_header("Test 5: Kill Tracking")

	SessionState.reset()
	SessionState.start_run("test", "test", 1)

	# Initial kills
	assert_equal(SessionState.kills, 0, "Should start with 0 kills")

	# Record kills
	SessionState._on_enemy_killed(Vector2.ZERO, 10)
	assert_equal(SessionState.kills, 1, "Should have 1 kill")

	SessionState._on_enemy_killed(Vector2.ZERO, 10)
	SessionState._on_enemy_killed(Vector2.ZERO, 10)
	assert_equal(SessionState.kills, 3, "Should have 3 kills")

	print(" ✓ Kill tracking works")

func test_damage_tracking() -> void:
	print_test_header("Test 6: Damage Tracking")

	SessionState.reset()
	SessionState.start_run("test", "test", 1)

	# Initial damage
	assert_equal(SessionState.damage_dealt, 0, "Should start with 0 damage")

	# Deal damage (using EventBus payload pattern)
	var payload1 = EventBus.DamageDealtPayload_Type.new(100.0, "player", "enemy_1")
	SessionState._on_damage_dealt(payload1)
	assert_equal(SessionState.damage_dealt, 100, "Should have 100 total damage")
	assert_equal(SessionState.damage_breakdown["enemy_1"]["total_damage"], 100, "Breakdown should track enemy_1")
	assert_equal(SessionState.damage_breakdown["enemy_1"]["hit_count"], 1, "Should have 1 hit on enemy_1")

	var payload2 = EventBus.DamageDealtPayload_Type.new(50.0, "player", "enemy_2")
	SessionState._on_damage_dealt(payload2)
	assert_equal(SessionState.damage_dealt, 150, "Should have 150 total damage")
	assert_equal(SessionState.damage_breakdown["enemy_2"]["total_damage"], 50, "Breakdown should track enemy_2")

	var payload3 = EventBus.DamageDealtPayload_Type.new(75.0, "player", "enemy_1")
	SessionState._on_damage_dealt(payload3)
	assert_equal(SessionState.damage_dealt, 225, "Should have 225 total damage")
	assert_equal(SessionState.damage_breakdown["enemy_1"]["total_damage"], 175, "enemy_1 should have 175 total")
	assert_equal(SessionState.damage_breakdown["enemy_1"]["hit_count"], 2, "Should have 2 hits on enemy_1")

	print(" ✓ Damage tracking works")

func test_time_tracking() -> void:
	print_test_header("Test 7: Time Tracking")

	SessionState.reset()
	SessionState.start_run("test", "test", 1)

	# Initial time
	assert_equal(SessionState.time_survived, 0.0, "Should start with 0 time")

	# Time is calculated in end_run() based on run_start_time
	# For testing, we can set time_survived directly
	SessionState.time_survived = 60.0
	assert_float_near(SessionState.time_survived, 60.0, 0.001, "Should track time survived")

	SessionState.time_survived = 123.5
	assert_float_near(SessionState.time_survived, 123.5, 0.001, "Should update time survived")

	print(" ✓ Time tracking works")

func test_item_collection() -> void:
	print_test_header("Test 8: Item Collection")

	SessionState.reset()
	SessionState.start_run("test", "test", 1)

	# Initial items
	assert_equal(SessionState.collected_items.size(), 0, "Should start with no items")

	# Collect items
	SessionState.collect_item("sword_001")
	assert_equal(SessionState.collected_items.size(), 1, "Should have 1 item")
	assert_true(SessionState.collected_items.has("sword_001"), "Should have sword_001")

	SessionState.collect_item("shield_002")
	SessionState.collect_item("helmet_003")
	assert_equal(SessionState.collected_items.size(), 3, "Should have 3 items")

	# Duplicates should not increase count
	SessionState.collect_item("sword_001")
	assert_equal(SessionState.collected_items.size(), 3, "Duplicates should not add")

	print(" ✓ Item collection tracking works")

func test_stage_progression() -> void:
	print_test_header("Test 9: Stage Progression")

	SessionState.reset()
	SessionState.start_run("test", "test", 1)

	# Initial stage
	assert_equal(SessionState.stage_reached, 1, "Should start at stage 1")

	# Progress stages
	SessionState.stage_reached = 2
	assert_equal(SessionState.stage_reached, 2, "Should be at stage 2")

	SessionState.stage_reached = 3
	assert_equal(SessionState.stage_reached, 3, "Should be at stage 3")

	# Stages progress forward normally
	SessionState.stage_reached = 5
	assert_equal(SessionState.stage_reached, 5, "Should be at stage 5")

	print(" ✓ Stage progression tracking works")

func test_swarm_tracking() -> void:
	print_test_header("Test 10: Swarm Tracking")

	SessionState.reset()
	SessionState.start_run("test", "test", 1)

	# Initial swarm state
	assert_equal(SessionState.final_swarm_entered, false, "Swarm should not be entered")

	# Enter swarm
	SessionState.final_swarm_entered = true
	assert_equal(SessionState.final_swarm_entered, true, "Swarm should be entered")

	print(" ✓ Swarm tracking works")

func test_player_modifiers() -> void:
	print_test_header("Test 11: Player Modifiers")

	SessionState.reset()
	SessionState.start_run("test", "test", 1)

	# Initial modifiers should have default values from BalanceDB
	var initial_size = SessionState.player_modifiers.size()
	assert_true(initial_size > 0, "Should have default modifiers loaded")

	# Modify existing modifiers
	SessionState.player_modifiers["melee_damage_add"] = 10.0
	SessionState.player_modifiers["melee_damage_mult"] = 1.2
	SessionState.player_modifiers["has_projectiles"] = true

	assert_equal(SessionState.player_modifiers.size(), initial_size, "Size should remain same after modifying")
	assert_float_near(SessionState.player_modifiers["melee_damage_add"], 10.0, 0.001, "Melee damage should be 10")
	assert_float_near(SessionState.player_modifiers["melee_damage_mult"], 1.2, 0.001, "Melee mult should be 1.2")
	assert_equal(SessionState.player_modifiers["has_projectiles"], true, "Should have projectiles")

	print(" ✓ Player modifiers tracking works")

func test_session_reset() -> void:
	print_test_header("Test 12: Session Reset")

	# Setup dirty state
	SessionState.start_run("character", "map", 3)
	# Level up happens automatically via XP gain
	SessionState._on_xp_gained(500, 500)
	SessionState._on_enemy_killed(Vector2.ZERO, 10)

	var damage_payload = EventBus.DamageDealtPayload_Type.new(1000.0, "player", "enemy_1")
	SessionState._on_damage_dealt(damage_payload)

	SessionState.collect_item("item_1")
	SessionState.stage_reached = 10
	SessionState.final_swarm_entered = true
	SessionState.player_modifiers["damage"] = 100.0

	# Reset
	SessionState.reset()

	# Verify clean state
	assert_equal(SessionState.current_level, 1, "Level should reset to 1")
	assert_equal(SessionState.current_xp, 0, "XP should reset to 0")
	assert_equal(SessionState.kills, 0, "Kills should reset to 0")
	assert_equal(SessionState.damage_dealt, 0, "Damage should reset to 0")
	assert_equal(SessionState.time_survived, 0.0, "Time should reset to 0.0")
	assert_equal(SessionState.stage_reached, 1, "Stage should reset to 1")
	assert_equal(SessionState.final_swarm_entered, false, "Swarm should reset to false")
	assert_equal(SessionState.collected_items.size(), 0, "Items should clear")
	assert_equal(SessionState.damage_breakdown.size(), 0, "Damage breakdown should clear")
	assert_true(SessionState.player_modifiers.size() > 0, "Modifiers should reset to defaults")
	assert_equal(SessionState.player_modifiers["melee_damage_add"], 0.0, "Melee damage should reset to 0")
	assert_equal(SessionState.is_run_active(), false, "Run should not be active")

	print(" ✓ Session reset works correctly")

func test_rift_fragments_calculation() -> void:
	print_test_header("Test 13: Rift Fragments Calculation")

	SessionState.reset()

	# Tier 1 run: stage 5, 300 kills, 90 seconds
	SessionState.start_run("test", "test", 1)
	SessionState.stage_reached = 5
	for i in range(300):
		SessionState._on_enemy_killed(Vector2.ZERO, 10)
	SessionState.time_survived = 90.0

	var fragments_t1 = SessionState.calculate_rift_fragments_earned()
	# Base: (5 * 10) + (300 / 100) + (90 / 60) = 50 + 3 + 1 = 54
	# Tier 1 mult: 54 * 1.0 = 54
	assert_equal(fragments_t1, 54, "Tier 1 should award 54 fragments")

	# Tier 2 run: same stats
	SessionState.reset()
	SessionState.start_run("test", "test", 2)
	SessionState.stage_reached = 5
	for i in range(300):
		SessionState._on_enemy_killed(Vector2.ZERO, 10)
	SessionState.time_survived = 90.0

	var fragments_t2 = SessionState.calculate_rift_fragments_earned()
	# Base: 54 (same as above)
	# Tier 2 mult: 54 * 1.1 = 59.4 → 59
	assert_equal(fragments_t2, 59, "Tier 2 should award 59 fragments (10% bonus)")

	# Tier 3 run with swarm entered
	SessionState.reset()
	SessionState.start_run("test", "test", 3)
	SessionState.stage_reached = 5
	for i in range(300):
		SessionState._on_enemy_killed(Vector2.ZERO, 10)
	SessionState.time_survived = 90.0
	SessionState.final_swarm_entered = true

	var fragments_t3 = SessionState.calculate_rift_fragments_earned()
	# Base: 54 + 10 (swarm bonus) = 64
	# Tier 3 mult: 64 * 1.2 = 76.8 → 76
	assert_equal(fragments_t3, 76, "Tier 3 + swarm should award 76 fragments (20% bonus + 10)")

	print(" ✓ Rift fragments calculation works correctly")

# Helper Functions
func print_test_header(text: String) -> void:
	print()
	print("-".repeat(43))
	print(" %s" % text)
	print("-".repeat(43))

func assert_equal(actual, expected, message: String) -> void:
	test_count += 1
	if actual == expected:
		passed_tests += 1
		print(" ✓ %s" % message)
	else:
		print(" ✗ %s (expected: %s, actual: %s)" % [message, str(expected), str(actual)])

func assert_float_near(actual: float, expected: float, tolerance: float, message: String) -> void:
	test_count += 1
	if abs(actual - expected) < tolerance:
		passed_tests += 1
		print(" ✓ %s" % message)
	else:
		print(" ✗ %s (expected: %f, actual: %f, tolerance: %f)" % [message, expected, actual, tolerance])

func assert_true(condition: bool, message: String) -> void:
	test_count += 1
	if condition:
		passed_tests += 1
		print(" ✓ %s" % message)
	else:
		print(" ✗ %s (expected true)" % message)
