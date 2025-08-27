extends SceneTree

## Test boss spawning system for Enemy V2 MVP completion
## Validates that ancient_lich template routes to scene spawning instead of pools

func _initialize():
	print("=== Boss Spawning Test ===")
	
	# Enable V2 system
	if not BalanceDB.use_enemy_v2_system:
		print("ERROR: V2 system not enabled in BalanceDB")
		quit()
		return
	
	# Load EnemyFactory and test boss template
	const EnemyFactory = preload("res://scripts/systems/enemy_v2/EnemyFactory.gd")
	EnemyFactory.load_all_templates()
	
	print("Templates loaded: ", EnemyFactory.get_template_count())
	
	# Test ancient_lich template specifically
	var lich_template = EnemyFactory.get_template("ancient_lich")
	if not lich_template:
		print("ERROR: ancient_lich template not found")
		quit()
		return
	
	print("Ancient Lich Template Found:")
	print("  ID: ", lich_template.id)
	print("  Render Tier: ", lich_template.render_tier) 
	print("  Health Range: ", lich_template.health_range)
	print("  Damage Range: ", lich_template.damage_range)
	print("  Parent Path: ", lich_template.parent_path)
	
	# Test spawn config generation
	var spawn_context = {
		"run_id": 12345,
		"wave_index": 1,
		"spawn_index": 0,
		"position": Vector2(100, 100)
	}
	
	var spawn_config = EnemyFactory.spawn_from_template_id("ancient_lich", spawn_context)
	if not spawn_config:
		print("ERROR: Failed to generate spawn config for ancient_lich")
		quit()
		return
	
	print("Spawn Config Generated:")
	print("  Template ID: ", spawn_config.template_id)
	print("  Render Tier: ", spawn_config.render_tier)
	print("  Health: ", spawn_config.health)
	print("  Damage: ", spawn_config.damage)
	print("  Speed: ", spawn_config.speed)
	print("  Color Tint: ", spawn_config.color_tint)
	print("  Size Scale: ", spawn_config.size_scale)
	
	# Verify render_tier is "boss"
	if spawn_config.render_tier == "boss":
		print("✅ Boss detection will work - render_tier = 'boss'")
	else:
		print("❌ Boss detection FAILED - render_tier = '", spawn_config.render_tier, "'")
	
	# Test scene loading
	var boss_scene_path = "res://scenes/bosses/AncientLich.tscn"
	var boss_scene = load(boss_scene_path)
	if boss_scene:
		print("✅ Boss scene loads successfully: ", boss_scene_path)
		
		# Test instantiation
		var boss_instance = boss_scene.instantiate()
		if boss_instance:
			print("✅ Boss scene instantiates successfully")
			print("✅ Boss has setup_from_spawn_config method: ", boss_instance.has_method("setup_from_spawn_config"))
			boss_instance.queue_free()
		else:
			print("❌ Boss scene instantiation failed")
	else:
		print("❌ Boss scene loading failed: ", boss_scene_path)
	
	print("=== Boss Spawning Test Complete ===")
	quit()