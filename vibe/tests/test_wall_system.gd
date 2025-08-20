extends Node

## Simple headless test to verify wall system functionality

const WallSystem := preload("res://scripts/systems/WallSystem.gd")

func _ready() -> void:
	print("=== Wall System Test ===")
	
	var wall_system := WallSystem.new()
	print("WallSystem instance created")
	
	add_child(wall_system)
	print("WallSystem added to tree")
	
	# Check basic functionality immediately
	var bounds := wall_system.get_arena_bounds()
	print("Arena bounds: ", bounds)
	
	# The wall bodies should be created in _ready()
	await get_tree().process_frame
	
	var wall_count := wall_system.wall_bodies.size()
	var transform_count := wall_system.wall_transforms.size()
	
	print("Wall bodies: ", wall_count)
	print("Wall transforms: ", transform_count)
	
	print("✓ Wall system basic test completed")
	get_tree().quit()