extends Node

## Visual debugging script to analyze hit feedback issues
## Tests color visibility, timing, and MultiMesh rendering

class_name VisualFeedbackDebug

var test_multimesh: MultiMeshInstance2D
var visual_config: VisualFeedbackConfig
var test_results: Array[String] = []

func _ready() -> void:
	print("=== Visual Feedback Debug Analysis ===")
	
	# Load visual config
	visual_config = load("res://data/balance/visual-feedback.tres") as VisualFeedbackConfig
	if not visual_config:
		print("ERROR: Failed to load visual feedback config")
		return
	
	_analyze_config_values()
	_test_color_visibility()
	_test_multimesh_setup()
	_report_findings()

func _analyze_config_values() -> void:
	print("\n--- Configuration Analysis ---")
	print("Flash duration: %s seconds" % visual_config.flash_duration)
	print("Flash intensity: %s" % visual_config.flash_intensity)
	print("Flash color: %s" % visual_config.flash_color)
	
	# Check if flash color is actually WHITE
	if visual_config.flash_color == Color.WHITE:
		test_results.append("ISSUE: Flash color is WHITE, same as original MultiMesh color - no visible change!")
	
	# Check flash curve exists
	if not visual_config.flash_curve:
		test_results.append("ISSUE: Flash curve is null - will cause errors in color calculation")
	else:
		print("Flash curve points: %d" % visual_config.flash_curve.point_count)
		for i in range(visual_config.flash_curve.point_count):
			var point = visual_config.flash_curve.get_point_position(i)
			print("  Point %d: %s" % [i, point])

func _test_color_visibility() -> void:
	print("\n--- Color Visibility Analysis ---")
	
	var original_color = Color.WHITE
	var flash_color = visual_config.flash_color
	
	print("Original MultiMesh color: %s" % original_color)
	print("Flash color: %s" % flash_color)
	
	# Test different lerp values to see visibility
	for intensity in [0.2, 0.5, 0.8, 1.0]:
		var result_color = original_color.lerp(flash_color, intensity)
		print("Lerp intensity %s: %s" % [intensity, result_color])
		
		if result_color.is_equal_approx(original_color):
			test_results.append("CRITICAL: Lerp intensity %s results in identical color!" % intensity)

func _test_multimesh_setup() -> void:
	print("\n--- MultiMesh Rendering Analysis ---")
	
	# Create test MultiMesh to verify behavior
	test_multimesh = MultiMeshInstance2D.new()
	add_child(test_multimesh)
	
	var multimesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_2D
	multimesh.use_colors = true
	multimesh.instance_count = 1
	
	var mesh = QuadMesh.new()
	mesh.size = Vector2(32, 32)
	multimesh.mesh = mesh
	
	test_multimesh.multimesh = multimesh
	
	# Test color changes
	var original_color = Color.WHITE
	var test_colors = [
		Color.RED,      # Highly visible
		Color.YELLOW,   # Medium visibility  
		Color(1.5, 1.5, 1.5, 1.0),  # Brighter white
		Color(2.0, 2.0, 2.0, 1.0),  # Much brighter
	]
	
	print("Testing color visibility on MultiMesh...")
	for i in range(test_colors.size()):
		var color = test_colors[i]
		multimesh.set_instance_color(0, color)
		print("Test color %d: %s (Values > 1.0: %s)" % [i, color, color.r > 1.0 or color.g > 1.0 or color.b > 1.0])

func _report_findings() -> void:
	print("\n=== FINDINGS ===")
	
	if test_results.is_empty():
		print("✓ No major issues found")
	else:
		for issue in test_results:
			print("⚠ %s" % issue)
	
	print("\n=== RECOMMENDATIONS ===")
	print("1. Change flash_color from WHITE to a more visible color (RED, YELLOW, or CYAN)")
	print("2. Use additive color values (r,g,b > 1.0) for white flash to make it brighter")
	print("3. Consider using modulate instead of set_instance_color for more dramatic effects")
	print("4. Add visual debugging logs to track color applications in real-time")
	print("5. Test flash timing - 0.12s may be too fast to see")
	
	queue_free()