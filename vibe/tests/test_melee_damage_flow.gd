extends SceneTree

## Test to verify melee attacks properly damage and kill enemies
## Run with: ../Godot_v4.4.1-stable_win64_console.exe --headless --script tests/test_melee_damage_flow.gd

func _initialize() -> void:
	print("=== Testing Melee Damage Flow ===")
	
	# Create minimal systems
	var melee_system = load("res://vibe/scripts/systems/MeleeSystem.gd").new()
	var wave_director = load("res://vibe/scripts/systems/WaveDirector.gd").new() 
	var damage_system = load("res://vibe/scripts/systems/DamageSystem.gd").new()
	var ability_system = load("res://vibe/scripts/systems/AbilitySystem.gd").new()
	
	# Initialize systems
	melee_system._ready()
	wave_director._ready()
	ability_system._ready()
	damage_system._ready()
	damage_system.set_references(ability_system, wave_director)
	
	# Manually spawn an enemy at known position
	var enemy_pos = Vector2(100, 100)
	wave_director.spawn_enemy_at(enemy_pos, "grunt_basic")
	
	# Get the spawned enemy
	var enemies = wave_director.get_alive_enemies()
	if enemies.size() == 0:
		print("ERROR: No enemy spawned!")
		quit()
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
	
	# Process the damage system to handle the damage_requested signal
	await create_timer(0.1).timeout
	
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
		hit_enemies = melee_system.perform_attack(player_pos, target_pos, wave_director.get_alive_enemies())
		await create_timer(0.1).timeout
		
		var alive = wave_director.get_alive_enemies()
		if alive.size() == 0:
			print("Enemy killed after %d attacks!" % (i + 1))
			break
		else:
			print("Attack %d: Enemy still alive with hp=%s" % [i + 1, alive[0].get("hp")])
	
	print("\n=== Test Complete ===")
	quit()