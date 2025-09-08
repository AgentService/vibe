extends Node

## Isolated test for CharacterManager functionality.
## Tests CRUD operations, save/load persistence, and progression synchronization.
## 
## Usage: "./Godot_v4.4.1-stable_win64_console.exe" --headless tests/CharacterManager_Isolated.tscn

var test_results: Array[Dictionary] = []

func _ready() -> void:
	print("=== CharacterManager Isolated Test ===")
	
	# Run tests immediately (autoloads should be ready)
	_run_all_tests()

func _run_all_tests() -> void:
	print("\n--- Running CharacterManager Tests ---")
	
	_test_character_creation()
	_test_character_persistence()
	_test_character_listing()
	_test_progression_sync()
	_test_character_deletion()
	
	print("--- Tests Completed ---\n")
	
	# Print results
	_print_results()
	
	# Exit
	get_tree().quit()

func _test_character_creation() -> void:
	print("Testing character creation...")
	var test_name := "test_character_creation"
	
	# Create a test character
	var profile := CharacterManager.create_character("TestKnight", StringName("Knight"))
	
	if profile == null:
		_record_failure(test_name, "Character creation returned null")
		return
	
	if profile.name != "TestKnight":
		_record_failure(test_name, "Character name mismatch: expected 'TestKnight', got '%s'" % profile.name)
		return
	
	if profile.clazz != StringName("Knight"):
		_record_failure(test_name, "Character class mismatch: expected 'Knight', got '%s'" % profile.clazz)
		return
	
	if profile.level != 1:
		_record_failure(test_name, "Character level should start at 1, got %d" % profile.level)
		return
	
	if profile.experience != 0.0:
		_record_failure(test_name, "Character exp should start at 0.0, got %.2f" % profile.experience)
		return
	
	if not profile.id or profile.id.is_empty():
		_record_failure(test_name, "Character ID should not be empty")
		return
	
	_record_success(test_name, "Character created successfully with ID: %s" % profile.id)

func _test_character_persistence() -> void:
	print("Testing character persistence...")
	var test_name := "test_character_persistence"
	
	# Create a character
	var profile := CharacterManager.create_character("PersistTest", StringName("Ranger"))
	if not profile:
		_record_failure(test_name, "Failed to create character for persistence test")
		return
	
	var original_id := profile.id
	var save_path := profile.get_save_path()
	
	# Check if save file was created
	if not FileAccess.file_exists(save_path):
		_record_failure(test_name, "Save file was not created at: %s" % save_path)
		return
	
	# Try to load the profile from disk
	var loaded_profile := load(save_path) as CharacterProfile
	if not loaded_profile:
		_record_failure(test_name, "Failed to load character profile from disk")
		return
	
	if loaded_profile.id != original_id:
		_record_failure(test_name, "Loaded profile ID mismatch")
		return
	
	if loaded_profile.name != "PersistTest":
		_record_failure(test_name, "Loaded profile name mismatch")
		return
	
	_record_success(test_name, "Character persistence working correctly")

func _test_character_listing() -> void:
	print("Testing character listing...")
	var test_name := "test_character_listing"
	
	# Get current count
	var initial_count := CharacterManager.list_characters().size()
	
	# Create two more characters
	var char1 := CharacterManager.create_character("ListTest1", StringName("Knight"))
	var char2 := CharacterManager.create_character("ListTest2", StringName("Ranger"))
	
	if not char1 or not char2:
		_record_failure(test_name, "Failed to create test characters")
		return
	
	# Check listing
	var all_characters := CharacterManager.list_characters()
	var expected_count := initial_count + 2
	
	if all_characters.size() != expected_count:
		_record_failure(test_name, "Character count mismatch: expected %d, got %d" % [expected_count, all_characters.size()])
		return
	
	# Check if our characters are in the list
	var found_char1 := false
	var found_char2 := false
	
	for character in all_characters:
		if character.id == char1.id:
			found_char1 = true
		if character.id == char2.id:
			found_char2 = true
	
	if not found_char1 or not found_char2:
		_record_failure(test_name, "Created characters not found in listing")
		return
	
	_record_success(test_name, "Character listing working correctly (%d characters total)" % all_characters.size())

func _test_progression_sync() -> void:
	print("Testing progression synchronization...")
	var test_name := "test_progression_sync"
	
	# Create a character and load it
	var profile := CharacterManager.create_character("ProgressTest", StringName("Knight"))
	if not profile:
		_record_failure(test_name, "Failed to create character for progression test")
		return
	
	CharacterManager.load_character(profile.id)
	PlayerProgression.load_from_profile(profile.progression)
	
	# Simulate gaining XP
	PlayerProgression.gain_exp(50.0)
	
	# Force immediate save (bypass debouncing for test)
	CharacterManager.save_current_immediate()
	
	# Check if current profile was updated
	var current_profile := CharacterManager.get_current()
	if not current_profile:
		_record_failure(test_name, "No current profile after loading character")
		return
	
	if current_profile.experience < 50.0:
		_record_failure(test_name, "Character profile not updated with gained XP: %.2f" % current_profile.experience)
		return
	
	_record_success(test_name, "Progression synchronization working (XP: %.2f)" % current_profile.experience)

func _test_character_deletion() -> void:
	print("Testing character deletion...")
	var test_name := "test_character_deletion"
	
	# Create a character to delete
	var profile := CharacterManager.create_character("DeleteTest", StringName("Ranger"))
	if not profile:
		_record_failure(test_name, "Failed to create character for deletion test")
		return
	
	var character_id := profile.id
	var save_path := profile.get_save_path()
	
	# Verify it exists
	if not FileAccess.file_exists(save_path):
		_record_failure(test_name, "Save file doesn't exist before deletion")
		return
	
	var initial_count := CharacterManager.list_characters().size()
	
	# Delete the character
	CharacterManager.delete_character(character_id)
	
	# Verify it was removed from list
	var final_count := CharacterManager.list_characters().size()
	if final_count != initial_count - 1:
		_record_failure(test_name, "Character count didn't decrease after deletion")
		return
	
	# Verify file was deleted
	if FileAccess.file_exists(save_path):
		_record_failure(test_name, "Save file still exists after deletion")
		return
	
	_record_success(test_name, "Character deletion working correctly")

func _record_success(test_name: String, message: String) -> void:
	test_results.append({
		"test": test_name,
		"passed": true,
		"message": message
	})
	print("✓ PASS: %s - %s" % [test_name, message])

func _record_failure(test_name: String, message: String) -> void:
	test_results.append({
		"test": test_name,
		"passed": false,
		"message": message
	})
	print("✗ FAIL: %s - %s" % [test_name, message])

func _print_results() -> void:
	var passed := 0
	var failed := 0
	
	print("\n=== Test Results ===")
	
	for result in test_results:
		if result.passed:
			passed += 1
		else:
			failed += 1
	
	print("Passed: %d" % passed)
	print("Failed: %d" % failed)
	print("Total:  %d" % test_results.size())
	
	if failed == 0:
		print("🎉 All tests passed!")
	else:
		print("❌ Some tests failed. Check output above for details.")
	
	print("===================")
