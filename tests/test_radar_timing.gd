extends Node

## Quick test to debug radar timing issues
## Check if enemies appear immediately on radar when spawned

func _ready() -> void:
	print("=== RADAR TIMING DEBUG TEST ===")
	await get_tree().process_frame
	
	if not EntityTracker:
		print("ERROR: EntityTracker not available")
		get_tree().quit(1)
		return
	
	# Spawn a test enemy
	print("Spawning test enemy...")
	EntityTracker.register_entity("test_enemy", {
		"type": "enemy",
		"pos": Vector2(100, 100),
		"alive": true
	})
	
	# Check if it appears immediately in radar view
	var enemy_view = EntityTracker.get_entities_by_type_view("enemy")
	print("Enemy view size: %d" % enemy_view.size())
	
	if enemy_view.size() > 0:
		print("✅ Enemy appears immediately in radar view")
		print("Enemy ID: %s" % enemy_view[0])
	else:
		print("❌ Enemy NOT appearing in radar view")
	
	# Clean up
	EntityTracker.unregister_entity("test_enemy")
	print("Test complete")
	get_tree().quit(0)