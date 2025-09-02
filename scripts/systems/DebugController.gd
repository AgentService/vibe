extends Node

## Debug Controller - Phase 3 Arena Refactoring
## Handles all debug input actions (F11, F12, B, C, T keys) and debug testing
## Can be disabled in production builds

class_name DebugController

# System references needed for debug actions
var wave_director: WaveDirector
var card_system: CardSystem
var ability_system: AbilitySystem
var arena_ref: Node  # Reference to Arena for accessing HUD, player, etc.
var camera_system: Node  # CameraSystem reference

var enabled: bool = true

func setup(arena: Node, deps: Dictionary) -> void:
	arena_ref = arena
	wave_director = deps.get("wave_director")
	card_system = deps.get("card_system") 
	ability_system = deps.get("ability_system")
	camera_system = deps.get("camera_system")

func _input(event: InputEvent) -> void:
	if not enabled or not (event is InputEventKey and event.pressed):
		return
		
	match event.keycode:
		KEY_F11:
			Logger.info("Spawning 1000 enemies for stress test", "performance")
			_spawn_stress_test_enemies()
		KEY_F12:
			Logger.info("Performance stats toggle", "performance")
			_toggle_performance_stats()
		KEY_C:
			Logger.info("Manual card selection test", "debug")
			_test_card_selection()
		KEY_B:
			Logger.info("=== B KEY PRESSED - SPAWNING V2 BOSS ===", "debug")
			_spawn_v2_boss_test()
		KEY_T:
			Logger.info("=== T KEY PRESSED - TESTING BOSS DAMAGE ===", "debug")
			_test_boss_damage()

# Debug Methods

func _spawn_stress_test_enemies() -> void:
	Logger.warn("Stress test disabled - legacy spawn method removed with V2 system migration", "performance")

func _toggle_performance_stats() -> void:
	# Force HUD debug overlay toggle
	var hud = arena_ref.hud
	if hud and hud.has_method("_toggle_debug_overlay"):
		hud._toggle_debug_overlay()
	else:
		# Print stats to console if HUD toggle not available
		_print_performance_stats()

func _test_card_selection() -> void:
	Logger.info("=== MANUAL CARD SELECTION TEST ===", "debug")
	if not card_system:
		Logger.error("Card system not available for test", "debug")
		return
	
	# Simulate level up with level 1 cards
	var test_cards: Array[CardResource] = card_system.get_card_selection(1, 3)
	Logger.info("Got " + str(test_cards.size()) + " test cards", "debug")
	
	if test_cards.is_empty():
		Logger.error("No test cards available", "debug")
		return
	
	Logger.info("Pausing game for manual test", "debug")
	PauseManager.pause_game(true)
	Logger.debug("Game pause state after PauseManager.pause_game(true): " + str(get_tree().paused), "debug")
	Logger.info("Opening card selection manually", "debug")
	
	var card_selection = arena_ref.card_selection
	if card_selection:
		card_selection.open_with_cards(test_cards)
	else:
		Logger.error("Card selection UI not available", "debug")

func _spawn_v2_boss_test() -> void:
	# Check if debug boss spawning is enabled
	var enable_debug_boss_spawning = arena_ref.enable_debug_boss_spawning
	if not enable_debug_boss_spawning:
		Logger.info("Debug boss spawning is disabled in Arena configuration", "debug")
		return
		
	# Check if V2 system is enabled
	if not BalanceDB.use_enemy_v2_system:
		Logger.warn("V2 enemy system is disabled - cannot spawn V2 boss", "debug")
		Logger.info("Enable V2 system in WavesBalance.tres to use V2 bosses", "debug")
		return
	
	# Use configured boss spawns if available, otherwise fallback to hardcoded
	var boss_spawn_configs = arena_ref.boss_spawn_configs
	if boss_spawn_configs.is_empty():
		Logger.info("No boss spawn configs found, using hardcoded fallback", "debug")
		_spawn_single_boss_fallback()
		return
	
	# Spawn all enabled boss configurations
	var player = arena_ref.player
	var player_pos: Vector2 = player.global_position if player else Vector2.ZERO
	var arena_center: Vector2 = Vector2.ZERO
	
	var spawned_count = 0
	for config in boss_spawn_configs:
		if config.enabled:
			var spawn_pos = config.calculate_spawn_position(player_pos, arena_center)
			_spawn_configured_boss(config, spawn_pos)
			spawned_count += 1
	
	Logger.info("Spawned " + str(spawned_count) + " configured bosses", "debug")

func _test_boss_damage() -> void:
	Logger.info("=== BOSS DAMAGE TEST START ===", "debug")
	
	# Register existing entities first
	DamageService.debug_register_all_existing_entities()
	
	# Use DamageService to find registered bosses (no scene tree traversal)
	var boss_entity_ids = DamageService.get_entities_by_type("boss")
	
	Logger.info("Found " + str(boss_entity_ids.size()) + " registered bosses", "debug")
	
	if boss_entity_ids.is_empty():
		Logger.warn("No registered bosses found to test damage on", "debug")
		return
	
	var entity_id = boss_entity_ids[0]
	var boss_data = DamageService.get_entity(entity_id)
	Logger.info("Testing boss: " + entity_id + " at position " + str(boss_data.get("pos", Vector2.ZERO)), "debug")
	Logger.info("Boss health before: " + str(boss_data.get("hp", 0)) + "/" + str(boss_data.get("max_hp", 0)), "debug")
	
	# Apply damage via DamageService
	var damage_applied = DamageService.apply_damage(entity_id, 50.0, "test_damage", ["test"])
	Logger.info("Damage applied: " + str(damage_applied), "debug")
	
	# Check health after damage
	boss_data = DamageService.get_entity(entity_id)
	Logger.info("Boss health after: " + str(boss_data.get("hp", 0)) + "/" + str(boss_data.get("max_hp", 0)), "debug")
	
	Logger.info("=== BOSS DAMAGE TEST END ===", "debug")

# Performance/Debug Stats

func _print_performance_stats() -> void:
	var stats: Dictionary = get_debug_stats()
	var fps: int = Engine.get_frames_per_second()
	var memory: int = int(OS.get_static_memory_usage() / (1024 * 1024))
	
	Logger.info("=== Performance Stats ===", "performance")
	Logger.info("FPS: " + str(fps), "performance")
	Logger.info("Memory: " + str(memory) + " MB", "performance")
	Logger.info("Total enemies: " + str(stats.get("enemy_count", 0)), "performance")
	Logger.info("Visible enemies: " + str(stats.get("visible_enemies", 0)), "performance")
	Logger.info("Projectiles: " + str(stats.get("projectile_count", 0)), "performance")
	Logger.info("Active sprites: " + str(stats.get("active_sprites", 0)), "performance")

func get_debug_stats() -> Dictionary:
	var stats: Dictionary = {}
	
	if wave_director:
		var alive_enemies: Array[EnemyEntity] = wave_director.get_alive_enemies()
		stats["enemy_count"] = alive_enemies.size()
		
		# Add culling stats
		var visible_rect: Rect2 = _get_visible_world_rect()
		var visible_count: int = 0
		for enemy in alive_enemies:
			if _is_enemy_visible(enemy.pos, visible_rect):
				visible_count += 1
		stats["visible_enemies"] = visible_count
	
	if ability_system:
		var alive_projectiles: Array[Dictionary] = ability_system._get_alive_projectiles()
		stats["projectile_count"] = alive_projectiles.size()
	
	return stats

# Helper methods for debug stats

func _get_visible_world_rect() -> Rect2:
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var zoom: float = camera_system.get_camera_zoom()
	var camera_pos: Vector2 = camera_system.get_camera_position()
	var margin: float = BalanceDB.get_waves_value("enemy_viewport_cull_margin")
	
	var half_size: Vector2 = (viewport_size / zoom) * 0.5 + Vector2(margin, margin)
	return Rect2(camera_pos - half_size, half_size * 2)

func _is_enemy_visible(enemy_pos: Vector2, visible_rect: Rect2) -> bool:
	return visible_rect.has_point(enemy_pos)

# Boss Spawning Debug Methods

func _spawn_single_boss_fallback() -> void:
	var player = arena_ref.player
	var player_pos: Vector2 = player.global_position if player else Vector2.ZERO
	var spawn_pos: Vector2 = player_pos + Vector2(150, 150)  # Legacy hardcoded position
	
	Logger.info("=== LICH SPAWN DEBUG START ===", "debug")
	Logger.info("1. V2 system enabled ✓", "debug")
	Logger.info("2. Spawn position: " + str(spawn_pos), "debug")
	
	# Direct V2 boss spawning - simplified approach
	const EnemyFactory = preload("res://scripts/systems/enemy_v2/EnemyFactory.gd")
	
	# Create boss spawn context
	var spawn_context := {
		"run_id": RunManager.run_seed,
		"wave_index": 999,
		"spawn_index": 0,
		"position": spawn_pos,
		"context_tags": ["boss", "manual_spawn"]
	}
	
	# Generate boss config
	Logger.info("3. Generating boss config from ancient_lich template...", "debug")
	var boss_config = EnemyFactory.spawn_from_template_id("ancient_lich", spawn_context)
	if not boss_config:
		Logger.error("   ✗ Failed to generate V2 boss config", "debug")
		return
	Logger.info("   ✓ Boss config generated successfully", "debug")
	
	# Apply boss scaling
	Logger.info("4. Applying boss scaling...", "debug")
	var original_health = boss_config.health
	var original_damage = boss_config.damage
	boss_config.health *= 5.0  # 5x stronger
	boss_config.damage *= 2.0  # 2x damage
	boss_config.size_scale *= 1.5  # Larger
	Logger.info("   Health: " + str(original_health) + " → " + str(boss_config.health), "debug")
	Logger.info("   Damage: " + str(original_damage) + " → " + str(boss_config.damage), "debug")
	
	# Spawn using existing V2 system
	Logger.info("5. Checking WaveDirector...", "debug")
	if not wave_director:
		Logger.error("   ✗ WaveDirector is null!", "debug")
		return
	if not wave_director.has_method("_spawn_from_config_v2"):
		Logger.error("   ✗ WaveDirector missing _spawn_from_config_v2 method", "debug")
		return
	Logger.info("   ✓ WaveDirector ready", "debug")
	
	Logger.info("6. Converting to legacy enemy type...", "debug")
	var legacy_type := boss_config.to_enemy_type()
	legacy_type.is_special_boss = true
	legacy_type.display_name = "Ancient Lich Boss"
	Logger.info("   Legacy type ID: " + legacy_type.id + ", Health: " + str(legacy_type.health), "debug")
	
	Logger.info("7. Spawning via WaveDirector...", "debug")
	Logger.info("WaveDirector is: " + str(wave_director), "debug")
	Logger.info("About to call _spawn_from_config_v2 with legacy_type=" + str(legacy_type.id) + ", boss_config=" + str(boss_config.template_id), "debug")
	
	if wave_director and wave_director.has_method("_spawn_from_config_v2"):
		Logger.info("WaveDirector has _spawn_from_config_v2 method - calling it", "debug")
		wave_director._spawn_from_config_v2(legacy_type, boss_config)
		Logger.info("_spawn_from_config_v2 call completed", "debug")
	else:
		Logger.warn("WaveDirector missing or doesn't have _spawn_from_config_v2 method", "debug")
	Logger.info("=== LICH SPAWN DEBUG END - SUCCESS! ===", "debug")

func _spawn_configured_boss(config: BossSpawnConfig, spawn_pos: Vector2) -> void:
	Logger.info("=== CONFIGURED BOSS SPAWN START ===", "debug")
	Logger.info("Boss ID: " + config.boss_id, "debug")
	Logger.info("Config: " + config.get_description(), "debug")
	Logger.info("Spawn position: " + str(spawn_pos), "debug")
	
	# Direct V2 boss spawning using configuration
	const EnemyFactory = preload("res://scripts/systems/enemy_v2/EnemyFactory.gd")
	
	# Create boss spawn context
	var spawn_context := {
		"run_id": RunManager.run_seed,
		"wave_index": 999,
		"spawn_index": 0,
		"position": spawn_pos,
		"context_tags": ["boss", "configured_spawn"]
	}
	
	# Generate boss config from template
	Logger.info("Generating boss config from template: " + config.boss_id, "debug")
	var boss_config = EnemyFactory.spawn_from_template_id(config.boss_id, spawn_context)
	if not boss_config:
		Logger.error("Failed to generate boss config for: " + config.boss_id, "debug")
		return
	Logger.info("Boss config generated successfully", "debug")
	
	# Apply boss scaling
	var original_health = boss_config.health
	var original_damage = boss_config.damage
	boss_config.health *= 5.0  # 5x stronger
	boss_config.damage *= 2.0  # 2x damage
	boss_config.size_scale *= 1.5  # Larger
	Logger.info("Scaled - Health: " + str(original_health) + " → " + str(boss_config.health), "debug")
	Logger.info("Scaled - Damage: " + str(original_damage) + " → " + str(boss_config.damage), "debug")
	
	# Spawn using existing V2 system
	if not wave_director:
		Logger.error("WaveDirector is null!", "debug")
		return
	if not wave_director.has_method("_spawn_from_config_v2"):
		Logger.error("WaveDirector missing _spawn_from_config_v2 method", "debug")
		return
	
	# Convert to legacy type and spawn
	var legacy_type := boss_config.to_enemy_type()
	legacy_type.is_special_boss = true
	legacy_type.display_name = config.boss_id.capitalize() + " Boss"
	
	Logger.info("Spawning via WaveDirector...", "debug")
	wave_director._spawn_from_config_v2(legacy_type, boss_config)
	Logger.info("=== CONFIGURED BOSS SPAWN COMPLETE ===", "debug")

func print_debug_help() -> void:
	Logger.info("=== Debug Controls ===", "ui")
	Logger.info("B: Spawn Dragon Lord boss (hybrid spawning test)", "ui")
	Logger.info("C: Test card selection", "ui")
	Logger.info("Escape: Pause/resume toggle", "ui")
	Logger.info("F11: Spawn 1000 enemies (stress test)", "ui")
	Logger.info("F12: Performance stats toggle", "ui")
	Logger.info("WASD: Move player", "ui")
	Logger.info("FPS overlay: Always visible", "ui")
	Logger.info("", "ui")