extends Node

## Test to verify melee attacks properly damage and kill enemies
## Run with: ../Godot_v4.4.1-stable_win64_console.exe --headless tests/test_melee_damage_flow.tscn

var test_timer: Timer

func _ready() -> void:
	print("=== Testing Melee Damage Flow ===")
	
	# Set up timer to run test after autoloads are ready
	test_timer = Timer.new()
	test_timer.wait_time = 0.5
	test_timer.one_shot = true
	test_timer.timeout.connect(_run_test)
	add_child(test_timer)
	test_timer.start()

func _run_test() -> void:
	# Create minimal systems
	var melee_system = MeleeSystem.new()
	var wave_director = WaveDirector.new() 
	var damage_system = DamageSystem.new()
	var ability_system = AbilitySystem.new()
	
	# Add systems as children so their _ready() gets called
	add_child(ability_system)
	add_child(wave_director)
	add_child(melee_system)
	add_child(damage_system)
	
	# Set up references
	damage_system.set_references(ability_system, wave_director)
	
	# Wait a frame for systems to initialize
	await get_tree().process_frame
	
	# Set up player position for PlayerState
	PlayerState.position = Vector2(50, 100)
	
	# Manually spawn an enemy at known position
	var enemy_pos = Vector2(100, 100)
	var spawned = wave_director.spawn_enemy_at(enemy_pos, "grunt_basic")
	
	if not spawned:
		print("ERROR: Failed to spawn enemy!")
		get_tree().quit()
		return
	
	# Wait a frame for spawn to complete
	await get_tree().process_frame
		
	# Get the spawned enemy
	var enemies = wave_director.get_alive_enemies()
	if enemies.size() == 0:
		print("ERROR: No enemy spawned!")
		get_tree().quit()
		return
		
	var enemy = enemies[0]
	print("Enemy spawned: type=%s, hp=%s, pos=%s" % [enemy.get("type_id"), enemy.get("hp"), enemy.get("pos")])
	
	# Test 1: Verify melee attack detects enemy in cone
	var player_pos = Vector2(50, 100)  # Close to enemy
	var target_pos = enemy_pos  # Target the enemy
	
	var hit_enemies = melee_system.perform_attack(player_pos, target_pos, enemies)
	print("Melee attack hit %d enemies" % hit_enemies.size())
	
	if hit_enemies.size() == 0:
		print("ERROR: Melee attack did not hit enemy in range!")
		print("  Player pos: %s" % player_pos)
		print("  Target pos: %s" % target_pos) 
		print("  Enemy pos: %s" % enemy.get("pos"))
		print("  Distance: %s" % player_pos.distance_to(enemy.get("pos")))
		print("  Melee range: %s" % melee_system.range)
	
	# Wait for signals to process
	await get_tree().process_frame
	await get_tree().process_frame
	
	# Check if enemy took damage
	var updated_enemies = wave_director.get_alive_enemies()
	if updated_enemies.size() > 0:
		var updated_enemy = updated_enemies[0]
		print("Enemy after attack: hp=%s (was %s)" % [updated_enemy.get("hp"), enemy.get("hp")])
		
		if updated_enemy.get("hp") == enemy.get("hp"):
			print("WARNING: Enemy HP unchanged - damage may not be applying!")
			print("  Expected damage: %s" % melee_system.damage)
	else:
		print("Enemy killed successfully!")
	
	# Test 2: Attack multiple times to ensure enemy dies
	print("\nTesting multiple attacks to kill enemy...")
	for i in range(5):
		var current_enemies = wave_director.get_alive_enemies()
		if current_enemies.size() == 0:
			print("Enemy already killed!")
			break
			
		hit_enemies = melee_system.perform_attack(player_pos, target_pos, current_enemies)
		await get_tree().process_frame
		await get_tree().process_frame
		
		var alive = wave_director.get_alive_enemies()
		if alive.size() == 0:
			print("Enemy killed after %d total attacks!" % (i + 2))
			break
		else:
			print("Attack %d: Enemy still alive with hp=%s" % [i + 2, alive[0].get("hp")])
	
	print("\n=== Test Complete ===")
	get_tree().quit()