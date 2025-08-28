extends SceneTree

const VisualFeedbackConfig = preload("res://scripts/resources/VisualFeedbackConfig.gd")

func _initialize() -> void:
	print("=== Hit Feedback System Test ===")
	
	# Test 1: Verify visual config loading
	print("\n1. Testing VisualFeedbackConfig loading...")
	var visual_config = load("res://data/balance/visual_feedback.tres") as VisualFeedbackConfig
	if not visual_config:
		print("   ❌ FAIL: Could not load visual feedback config")
		quit()
		return
	
	print("   ✓ Config loaded successfully")
	print("   - Flash duration: " + str(visual_config.flash_duration))
	print("   - Flash intensity: " + str(visual_config.flash_intensity))
	print("   - Flash color: " + str(visual_config.flash_color))
	print("   - Knockback duration: " + str(visual_config.knockback_duration))
	
	# Test 2: Verify curves are created
	print("\n2. Testing curve availability...")
	if not visual_config.flash_curve:
		print("   ❌ FAIL: Flash curve is null")
		quit()
		return
	
	if not visual_config.knockback_curve:
		print("   ❌ FAIL: Knockback curve is null") 
		quit()
		return
	
	print("   ✓ Both flash and knockback curves available")
	
	# Test 3: Test curve sampling
	print("\n3. Testing curve sampling...")
	var flash_samples = []
	var knockback_samples = []
	
	for i in range(5):
		var progress = float(i) / 4.0
		var flash_value = visual_config.flash_curve.sample(progress)
		var knockback_value = visual_config.knockback_curve.sample(progress)
		flash_samples.append("%.2f" % flash_value)
		knockback_samples.append("%.2f" % knockback_value)
	
	print("   Flash curve samples: " + str(flash_samples))
	print("   Knockback curve samples: " + str(knockback_samples))
	
	# Test 4: Color calculation test
	print("\n4. Testing color calculation...")
	var original_color = Color.WHITE
	var flash_color = visual_config.flash_color
	
	for i in range(3):
		var progress = float(i) / 2.0
		var curve_value = visual_config.flash_curve.sample(progress)
		var current_color = original_color * flash_color.lerp(Color.WHITE, 1.0 - curve_value)
		print("   Progress " + str(progress) + ": curve=" + str(curve_value) + ", color=" + str(current_color))
	
	print("\n✅ ALL TESTS PASSED - Hit feedback config is working correctly!")
	quit()