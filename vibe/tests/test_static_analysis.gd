extends SceneTree

# Test the static analysis tool headlessly
# This mimics what would happen when run from Godot Editor

func _initialize() -> void:
	print("🔧 Testing Static Analysis Tool...")
	
	# Load and run the analysis tool
	var checker_script = load("res://tools/check_boundaries.gd")
	var checker = checker_script.new()
	
	# Run the analysis
	checker._run()
	
	print("\n✅ Static analysis test completed!")
	quit(0)