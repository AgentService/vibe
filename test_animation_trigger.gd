extends SceneTree

func _initialize():
	print("=== Testing Animation Trigger ===")
	
	# Test EventBus signal emission
	var payload = {
		"player_pos": Vector2(0, 0),
		"target_pos": Vector2(100, 0)
	}
	
	print("Emitting EventBus.melee_attack_started signal...")
	EventBus.melee_attack_started.emit(payload)
	
	print("Test complete")
	quit()