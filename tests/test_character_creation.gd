extends SceneTree

## Test character creation with data-driven CharacterType resources
## Validates that CharacterSelect can load and use character types from configuration files

func _initialize() -> void:
	print("=== Testing Character Creation Data-Driven Migration ===")
	
	var success_count := 0
	var test_count := 0
	
	# Test 1: CharacterType resource class functionality
	test_count += 1
	print("\nTest 1: CharacterType resource class")
	var knight_type := CharacterType.new()
	knight_type.id = "knight"
	knight_type.display_name = "Knight"
	knight_type.description = "Sturdy melee fighter"
	knight_type.base_hp = 100.0
	knight_type.base_damage = 25.0
	knight_type.base_speed = 1.0
	
	var knight_stats := knight_type.get_stats()
	if knight_stats["hp"] == 100.0 and knight_stats["damage"] == 25.0 and knight_stats["speed"] == 1.0:
		print("✅ CharacterType.get_stats() works correctly")
		success_count += 1
	else:
		print("❌ CharacterType.get_stats() failed")
		print("Expected: {hp: 100.0, damage: 25.0, speed: 1.0}")
		print("Got: ", knight_stats)
	
	# Test 2: Character data format compatibility
	test_count += 1
	print("\nTest 2: Character data format compatibility")
	var char_data := knight_type.get_character_data()
	var expected_format := {
		"name": "Knight",
		"description": "Sturdy melee fighter",
		"stats": {"hp": 100.0, "damage": 25.0, "speed": 1.0}
	}
	
	if char_data.has_all(["name", "description", "stats"]) and char_data["name"] == "Knight":
		print("✅ Character data format compatible with existing UI")
		success_count += 1
	else:
		print("❌ Character data format incompatible")
		print("Expected format with name, description, stats")
		print("Got: ", char_data)
	
	# Test 3: Resource file loading
	test_count += 1
	print("\nTest 3: Character types resource loading")
	var resource_path := "res://data/core/character-types.tres"
	
	if ResourceLoader.exists(resource_path):
		var loaded_resource = ResourceLoader.load(resource_path) as CharacterTypeDict
		if loaded_resource and loaded_resource.character_types:
			var loaded_types: Dictionary = loaded_resource.character_types
			if loaded_types.has("knight") and loaded_types.has("ranger"):
				var knight_resource := loaded_types["knight"] as CharacterType
				if knight_resource and knight_resource.display_name == "Knight":
					print("✅ Character types resource loads successfully")
					success_count += 1
				else:
					print("❌ Character types resource invalid format")
			else:
				print("❌ Character types resource missing required types")
		else:
			print("❌ Character types resource invalid or empty")
	else:
		print("❌ Character types resource file not found at: " + resource_path)
	
	# Test 4: Migration validation - ensure no hardcoded values remain
	test_count += 1
	print("\nTest 4: Migration validation")
	var char_select_path := "res://scenes/ui/CharacterSelect.gd"
	if FileAccess.file_exists(char_select_path):
		var file := FileAccess.open(char_select_path, FileAccess.READ)
		var content := file.get_as_text()
		file.close()
		
		# Check that old hardcoded data structure is gone
		if not content.contains('\"knight\": {') and not content.contains('\"stats\": {\"hp\": 100'):
			print("✅ Hardcoded character data removed from CharacterSelect")
			success_count += 1
		else:
			print("❌ Hardcoded character data still present in CharacterSelect")
	else:
		print("❌ CharacterSelect.gd not found")
	
	# Summary
	print("\n=== Character Creation Test Results ===")
	print("Passed: %d/%d tests" % [success_count, test_count])
	
	if success_count == test_count:
		print("✅ All character creation migration tests PASSED")
	else:
		print("❌ Some character creation migration tests FAILED")
	
	# Always quit after testing
	quit(0 if success_count == test_count else 1)