extends SceneTree

func _initialize() -> void:
	print("=== Testing Hit Feedback System Integration ===")
	
	# Load and instantiate the Arena scene
	var arena_scene = load("res://vibe/scenes/arena/Arena.tscn") as PackedScene
	if not arena_scene:
		print("❌ FAIL: Could not load Arena scene")
		quit()
		return
	
	var arena = arena_scene.instantiate()
	root.add_child(arena)
	
	print("✓ Arena scene loaded")
	
	# Systems should initialize immediately in _ready()
	
	# Try to find the hit feedback system
	var hit_feedback = null
	for child in arena.get_children():
		if child.get_script() and child.get_script().resource_path.ends_with("EnemyMultiMeshHitFeedback.gd"):
			hit_feedback = child
			break
	
	if not hit_feedback:
		print("❌ FAIL: Could not find EnemyMultiMeshHitFeedback system")
		quit()
		return
	
	print("✓ Hit feedback system found")
	
	# Check if visual config is loaded
	if not hit_feedback.visual_config:
		print("❌ FAIL: Visual config not loaded")
		quit()
		return
	
	print("✓ Visual config loaded:")
	print("  - Flash duration: " + str(hit_feedback.visual_config.flash_duration))
	print("  - Flash color: " + str(hit_feedback.visual_config.flash_color))
	print("  - Flash curve available: " + str(hit_feedback.visual_config.flash_curve != null))
	print("  - Knockback curve available: " + str(hit_feedback.visual_config.knockback_curve != null))
	
	# Check if dependencies are injected
	if not hit_feedback.enemy_render_tier:
		print("❌ FAIL: EnemyRenderTier not injected")
		quit()
		return
	
	print("✓ EnemyRenderTier injected")
	
	if not hit_feedback.wave_director:
		print("❌ FAIL: WaveDirector not injected")
		quit()
		return
	
	print("✓ WaveDirector injected")
	
	# Check MultiMesh references
	var mm_count = 0
	if hit_feedback.mm_enemies_swarm: mm_count += 1
	if hit_feedback.mm_enemies_regular: mm_count += 1
	if hit_feedback.mm_enemies_elite: mm_count += 1
	if hit_feedback.mm_enemies_boss: mm_count += 1
	
	if mm_count != 4:
		print("❌ FAIL: MultiMesh references not properly set (" + str(mm_count) + "/4)")
		quit()
		return
	
	print("✓ All MultiMesh references set (" + str(mm_count) + "/4)")
	
	print("\n🎉 SUCCESS: Hit feedback system is properly configured and ready!")
	print("   - All dependencies injected")
	print("   - Visual config loaded with enhanced values")
	print("   - MultiMesh references set")
	print("   - System should now respond to damage_applied signals")
	
	quit()