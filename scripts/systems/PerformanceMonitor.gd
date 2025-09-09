extends Node

## Performance Monitor - Phase 6 Arena Refactoring
## Provides debug stats and performance metrics for Arena systems
## Can be used by UI/Debug systems to display performance information

class_name PerformanceMonitor

func get_debug_stats(arena_ref: Node, wave_director: WaveDirector) -> Dictionary:
	var stats: Dictionary = {}
	
	# Enemy count from WaveDirector
	if wave_director:
		var alive_enemies: Array[EnemyEntity] = wave_director.get_alive_enemies()
		stats["enemy_count"] = alive_enemies.size()
		Logger.debug("Performance Monitor: " + str(alive_enemies.size()) + " alive enemies", "performance")
	
	# TODO: Phase 2 - Add projectile count from AbilityModule
	# if AbilityModule:
	#	var alive_projectiles = AbilityModule.get_projectile_snapshot()
	#	stats["projectile_count"] = alive_projectiles.size()
	stats["projectile_count"] = 0  # Placeholder until AbilityModule
	
	# Engine performance metrics
	stats["fps"] = Engine.get_frames_per_second()
	stats["memory_mb"] = int(OS.get_static_memory_usage() / (1024 * 1024))
	
	# Optional: Camera/visibility metrics if available through arena_ref
	if arena_ref and arena_ref.has_method("get_camera_system"):
		var camera_system = arena_ref.get_camera_system()
		if camera_system:
			stats["camera_zoom"] = camera_system.get_camera_zoom()
	
	Logger.debug("Performance Monitor: Collected " + str(stats.size()) + " performance metrics", "performance")
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
	result += "FPS: " + str(stats.get("fps", "N/A")) + " | "
	result += "Memory: " + str(stats.get("memory_mb", "N/A")) + " MB | "
	result += "Enemies: " + str(stats.get("enemy_count", "N/A")) + " | "
	result += "Projectiles: " + str(stats.get("projectile_count", "N/A"))
	return result