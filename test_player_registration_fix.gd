extends Node

## Simple test node to validate player registration fix
## Add this to a scene to test the fix

func _ready() -> void:
	print("=== Player Registration Fix Test ===")
	
	# Wait a bit for game to initialize
	await get_tree().create_timer(2.0).timeout
	
	# Test the player registration multiple times
	test_player_registration()

func test_player_registration() -> void:
	print("Testing player registration...")
	
	# Check if player exists
	if not PlayerState.has_player_reference():
		print("ERROR: No player reference available")
		return
	
	var player = PlayerState._player_ref
	if not player:
		print("ERROR: Player reference is null")
		return
	
	# Check registration status
	if player.has_method("is_registered_with_damage_system"):
		var is_registered = player.is_registered_with_damage_system()
		print("Player registration status: %s" % is_registered)
		
		if not is_registered:
			print("Player not registered - attempting registration...")
			if player.has_method("ensure_damage_registration"):
				var success = player.ensure_damage_registration()
				print("Registration attempt result: %s" % success)
			else:
				print("Player missing ensure_damage_registration method")
	else:
		print("Player missing is_registered_with_damage_system method")
	
	# Test damage application
	print("Testing damage application to player...")
	var damage_result = DamageService.apply_damage("player", 10, "test_script", ["test"])
	print("Damage application result: %s" % damage_result)
	
	print("=== Test Complete ===")