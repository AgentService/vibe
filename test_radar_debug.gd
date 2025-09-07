extends Node

## Quick test to verify RadarSystem works with actual enemies
## This will simulate an arena with enemies to test radar functionality

func _ready() -> void:
	print("=== Radar Debug Test ===")
	
	# Wait a few frames for systems to initialize
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	
	# Check if RadarSystem exists
	var radar_system = GameOrchestrator.get_radar_system()
	if radar_system:
		print("✓ RadarSystem found in GameOrchestrator")
		
		# Check if WaveDirector exists
		var wave_director = GameOrchestrator.get_wave_director()
		if wave_director:
			print("✓ WaveDirector found")
			
			# Get alive enemies count
			var enemies = wave_director.get_alive_enemies()
			print("Current alive enemies: %d" % enemies.size())
			
			# Check if RadarSystem is enabled
			print("RadarSystem enabled: %s" % radar_system._enabled)
			print("Current state: %s" % StateManager.current_state)
			
			# Check player position
			print("Player position: %s" % radar_system._player_pos)
		else:
			print("✗ WaveDirector not found")
	else:
		print("✗ RadarSystem not found")
	
	# Check EventBus signal connections
	if EventBus.radar_data_updated:
		var connections = EventBus.radar_data_updated.get_connections()
		print("Radar data signal connections: %d" % connections.size())
		for connection in connections:
			print("  - Connected to: %s" % connection.callable.get_object())
	
	print("=== Test Complete ===")
	get_tree().quit()