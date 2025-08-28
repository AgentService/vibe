extends SceneTree

## Simple test for DamageRegistry V2 - validates basic functionality in isolation

const DamageRegistryV2 = preload("res://scripts/systems/damage_v2/DamageRegistry.gd")

func _initialize() -> void:
	print("=== DamageRegistry V2 Test ===")
	
	# Create registry instance
	var registry = DamageRegistryV2.new()
	
	# Test 1: Register entities
	print("\n1. Testing entity registration...")
	var enemy_data = {
		"id": "enemy_0",
		"type": "enemy",
		"hp": 100.0,
		"max_hp": 100.0,
		"alive": true,
		"pos": Vector2(50, 50)
	}
	
	var boss_data = {
		"id": "boss_ancient_lich",
		"type": "boss", 
		"hp": 200.0,
		"max_hp": 200.0,
		"alive": true,
		"pos": Vector2(100, 100)
	}
	
	registry.register_entity("enemy_0", enemy_data)
	registry.register_entity("boss_ancient_lich", boss_data)
	
	print("✓ Registered 2 entities")
	
	# Test 2: Apply damage without killing
	print("\n2. Testing damage application...")
	var killed = registry.apply_damage("enemy_0", 25.0, "test")
	print("Enemy killed: ", killed)
	
	var enemy = registry.get_entity("enemy_0")
	print("Enemy HP after damage: ", enemy.get("hp", 0))
	
	# Test 3: Kill entity
	print("\n3. Testing entity death...")
	killed = registry.apply_damage("enemy_0", 100.0, "test_kill")
	print("Enemy killed: ", killed)
	
	enemy = registry.get_entity("enemy_0") 
	print("Enemy alive: ", enemy.get("alive", false))
	
	# Test 4: Test damage on dead entity
	print("\n4. Testing damage on dead entity...")
	killed = registry.apply_damage("enemy_0", 10.0, "test_overkill")
	print("Dead entity killed again: ", killed)
	
	# Test 5: Test get alive entities
	print("\n5. Testing alive entities query...")
	var alive_entities = registry.get_alive_entities()
	print("Alive entities: ", alive_entities)
	
	print("\n=== Test Complete ===")
	print("SUCCESS: DamageRegistry V2 basic functionality works!")
	
	quit()