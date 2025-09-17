extends Node

## Performance Monitor - Phase 6 Arena Refactoring
## Provides debug stats and performance metrics for Arena systems
## Can be used by UI/Debug systems to display performance information

class_name PerformanceMonitor

func get_debug_stats(arena_ref: Node, spawn_director: SpawnDirector) -> Dictionary:
	var stats: Dictionary = {}
	
	# Enemy count from SpawnDirector
	if spawn_director:
		var alive_enemies: Array[EnemyEntity] = spawn_director.get_alive_enemies()
		stats["enemy_count"] = alive_enemies.size()
		if Logger.is_debug():
			Logger.debug("Performance Monitor: %d alive enemies" % alive_enemies.size(), "performance")
	
	# TODO: Phase 2 - Add projectile count from AbilityModule
	# if AbilityModule:
	#	var alive_projectiles = AbilityModule.get_projectile_snapshot()
	#	stats["projectile_count"] = alive_projectiles.size()
	stats["projectile_count"] = 0  # Placeholder until AbilityModule
	
	# Engine performance metrics
	stats["fps"] = Engine.get_frames_per_second()
	stats["memory_mb"] = int(OS.get_static_memory_usage() / (1024 * 1024))
	
	# Optional: Camera/visibility metrics from player's camera
	if arena_ref and arena_ref.has_method("get_player"):
		var player = arena_ref.get_player()
		if player:
			var player_camera = player.get_node_or_null("PlayerCamera")
			if player_camera and player_camera is Camera2D:
				stats["camera_zoom"] = player_camera.zoom.x
			else:
				stats["camera_zoom"] = 1.0
	
	if Logger.is_debug():
		Logger.debug("Performance Monitor: Collected %d performance metrics" % stats.size(), "performance")
	return stats

func print_stats(stats: Dictionary) -> void:
	Logger.info("=== Performance Stats ===", "performance")
	
	# Order stats for readable output
	var ordered_keys = ["fps", "memory_mb", "enemy_count", "projectile_count", "camera_zoom"]
	
	for key in ordered_keys:
		if stats.has(key):
			Logger.info("%s: %s" % [key, str(stats[key])], "performance")
	
	# Print any additional stats not in ordered list
	for key in stats.keys():
		if key not in ordered_keys:
			Logger.info("%s: %s" % [key, str(stats[key])], "performance")
	
	Logger.info("=== End Performance Stats ===", "performance")

func get_formatted_stats_string(stats: Dictionary) -> String:
	var result: String = ""
	result += "FPS: %s | " % stats.get("fps", "N/A")
	result += "Memory: %s MB | " % stats.get("memory_mb", "N/A")
	result += "Enemies: %s | " % stats.get("enemy_count", "N/A")
	result += "Projectiles: %s" % stats.get("projectile_count", "N/A")
	return result