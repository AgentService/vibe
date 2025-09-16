class_name BossSpawnManager
extends Node

# Centralizes all boss spawning logic and configuration management
# Handles both fallback and configured boss spawning with scaling

const BossSpawnConfigScript := preload("res://scripts/domain/BossSpawnConfig.gd")

# Dependencies injected from Arena
var spawn_director: SpawnDirector
var player: Node2D

func setup(spawn_dir: SpawnDirector, player_ref: Node2D) -> void:
	spawn_director = spawn_dir
	player = player_ref
	Logger.info("BossSpawnManager initialized", "boss")

# Spawns a single boss using fallback ancient_lich template
func spawn_single_boss_fallback() -> void:
	var player_pos: Vector2 = player.global_position if player else Vector2.ZERO
	var spawn_pos: Vector2 = player_pos + Vector2(150, 150)  # Legacy hardcoded position
	
	Logger.info("=== LICH SPAWN DEBUG START ===", "debug")
	Logger.info("1. V2 system enabled ✓", "debug")
	Logger.info("2. Spawn position: " + str(spawn_pos), "debug")
	
	# Direct V2 boss spawning - simplified approach
	const EnemyFactoryScript = preload("res://scripts/systems/enemy_v2/EnemyFactory.gd")
	
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
	var boss_config = EnemyFactoryScript.spawn_from_template_id("ancient_lich", spawn_context)
	if not boss_config:
		Logger.error("   ✗ Failed to generate V2 boss config", "debug")
		return
	Logger.info("   ✓ Boss config generated successfully", "debug")
	
	# Apply boss scaling (keep size_factor from enemy variation)
	Logger.info("4. Applying boss scaling...", "debug")
	var original_health = boss_config.health
	var original_damage = boss_config.damage
	boss_config.health *= 5.0  # 5x stronger
	boss_config.damage *= 2.0  # 2x damage
	# Note: size_scale now respects enemy variation size_factor
	Logger.info("   Health: " + str(original_health) + " → " + str(boss_config.health), "debug")
	Logger.info("   Damage: " + str(original_damage) + " → " + str(boss_config.damage), "debug")
	Logger.info("   Size: Using variation size_factor (%.1f)" % boss_config.size_scale, "debug")
	
	# Spawn using existing V2 system
	Logger.info("5. Checking SpawnDirector...", "debug")
	if not spawn_director:
		Logger.error("   ✗ SpawnDirector is null!", "debug")
		return
	if not spawn_director.has_method("_spawn_from_config_v2"):
		Logger.error("   ✗ SpawnDirector missing _spawn_from_config_v2 method", "debug")
		return
	Logger.info("   ✓ SpawnDirector ready", "debug")
	
	Logger.info("6. Converting to legacy enemy type...", "debug")
	var legacy_type := boss_config.to_enemy_type()
	legacy_type.is_special_boss = true
	legacy_type.display_name = "Ancient Lich Boss"
	Logger.info("   Legacy type ID: " + legacy_type.id + ", Health: " + str(legacy_type.health), "debug")
	
	Logger.info("7. Spawning via SpawnDirector...", "debug")
	Logger.info("SpawnDirector is: " + str(spawn_director), "debug")
	Logger.info("About to call _spawn_from_config_v2 with legacy_type=" + str(legacy_type.id) + ", boss_config=" + str(boss_config.template_id), "debug")
	
	if spawn_director and spawn_director.has_method("_spawn_from_config_v2"):
		Logger.info("SpawnDirector has _spawn_from_config_v2 method - calling it", "debug")
		spawn_director._spawn_from_config_v2(legacy_type, boss_config)
		Logger.info("_spawn_from_config_v2 call completed", "debug")
	else:
		Logger.warn("SpawnDirector missing or doesn't have _spawn_from_config_v2 method", "debug")
	Logger.info("=== LICH SPAWN DEBUG END - SUCCESS! ===", "debug")

# Spawns a boss using the provided configuration
func spawn_configured_boss(config: BossSpawnConfigScript, spawn_pos: Vector2) -> void:
	Logger.info("=== CONFIGURED BOSS SPAWN START ===", "debug")
	Logger.info("Boss ID: " + config.boss_id, "debug")
	Logger.info("Config: " + config.get_description(), "debug")
	Logger.info("Spawn position: " + str(spawn_pos), "debug")
	
	# Direct V2 boss spawning using configuration
	const EnemyFactoryScript = preload("res://scripts/systems/enemy_v2/EnemyFactory.gd")
	
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
	var boss_config = EnemyFactoryScript.spawn_from_template_id(config.boss_id, spawn_context)
	if not boss_config:
		Logger.error("Failed to generate boss config for: " + config.boss_id, "debug")
		return
	Logger.info("Boss config generated successfully", "debug")
	
	# Apply boss scaling (keep size_factor from enemy variation)
	var original_health = boss_config.health
	var original_damage = boss_config.damage
	boss_config.health *= 5.0  # 5x stronger
	boss_config.damage *= 2.0  # 2x damage
	# Note: size_scale now respects enemy variation size_factor
	Logger.info("Scaled - Health: " + str(original_health) + " → " + str(boss_config.health), "debug")
	Logger.info("Scaled - Damage: " + str(original_damage) + " → " + str(boss_config.damage), "debug")
	Logger.info("Scaled - Size: Using variation size_factor (%.1f)" % boss_config.size_scale, "debug")
	
	# Spawn using existing V2 system
	if not spawn_director:
		Logger.error("SpawnDirector is null!", "debug")
		return
	if not spawn_director.has_method("_spawn_from_config_v2"):
		Logger.error("SpawnDirector missing _spawn_from_config_v2 method", "debug")
		return
	
	# Convert to legacy type and spawn
	var legacy_type := boss_config.to_enemy_type()
	legacy_type.is_special_boss = true
	legacy_type.display_name = config.boss_id.capitalize() + " Boss"
	
	Logger.info("Spawning via SpawnDirector...", "debug")
	spawn_director._spawn_from_config_v2(legacy_type, boss_config)
	Logger.info("=== CONFIGURED BOSS SPAWN COMPLETE ===", "debug")
