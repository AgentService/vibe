extends Control
class_name DebugOverlay

## Debug Overlay System
## Provides visual debugging information and performance stats overlay

@onready var performance_label: Label = Label.new()

var update_timer: Timer
var last_fps: int = 0
var last_enemy_count: int = 0

func _ready() -> void:
	# Setup overlay as a top-level UI element
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE  # Don't block input
	
	# Create performance label
	performance_label.position = Vector2(10, 10)
	performance_label.add_theme_color_override("font_color", Color.WHITE)
	performance_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	performance_label.add_theme_constant_override("shadow_offset_x", 1)
	performance_label.add_theme_constant_override("shadow_offset_y", 1)
	add_child(performance_label)
	
	# Setup update timer
	update_timer = Timer.new()
	update_timer.wait_time = 0.5  # Update twice per second
	update_timer.timeout.connect(_update_performance_stats)
	add_child(update_timer)
	update_timer.start()
	
	Logger.debug("DebugOverlay initialized", "debug")

func _exit_tree() -> void:
	if update_timer and update_timer.timeout.is_connected(_update_performance_stats):
		update_timer.timeout.disconnect(_update_performance_stats)
	Logger.debug("DebugOverlay: Cleaned up", "debug")

func get_performance_stats() -> Dictionary:
	"""Get current performance statistics"""
	return {
		"fps": Engine.get_frames_per_second(),
		"memory_mb": Performance.get_monitor(Performance.MEMORY_STATIC) / 1024.0 / 1024.0,
		"enemy_count": _count_enemies(),
		"boss_count": _count_bosses()
	}

func _update_performance_stats() -> void:
	var stats = get_performance_stats()
	
	var text = "FPS: %d\n" % stats.fps
	text += "Enemies: %d\n" % stats.enemy_count
	text += "Bosses: %d\n" % stats.boss_count
	text += "Memory: %.1f MB" % stats.memory_mb
	
	performance_label.text = text

func _count_enemies() -> int:
	# Count enemies from various sources
	var count = 0
	
	# Check WaveDirector if available
	var wave_director = get_node_or_null("/root/WaveDirector")
	if wave_director and wave_director.has_method("get_alive_enemies"):
		var alive_enemies = wave_director.get_alive_enemies()
		count += alive_enemies.size()
	
	return count

func _count_bosses() -> int:
	# Count boss nodes in scene tree
	var scene_tree = get_tree()
	if not scene_tree or not scene_tree.current_scene:
		return 0
	
	return _count_bosses_recursive(scene_tree.current_scene)

func _count_bosses_recursive(node: Node) -> int:
	var count = 0
	
	# Check if node is a boss
	if node.name.contains("Boss") or node.name.contains("Lich") or node.name.contains("Dragon"):
		if "alive" in node and node.alive:
			count += 1
		elif not ("alive" in node):  # If no alive property, assume it exists
			count += 1
	elif node.is_in_group("bosses"):
		count += 1
	
	# Search children
	for child in node.get_children():
		count += _count_bosses_recursive(child)
	
	return count