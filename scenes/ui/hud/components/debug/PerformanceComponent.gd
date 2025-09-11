class_name PerformanceComponent
extends BaseHUDComponent

## Performance monitoring component displaying FPS, memory usage, and system statistics
## Optimized for minimal performance impact with configurable update rates

@export var show_fps: bool = true
@export var show_memory: bool = true
@export var show_draw_calls: bool = true
@export var show_entity_counts: bool = true
@export var compact_display: bool = false

# UI Components
var _performance_label: Label
var _background_panel: Panel

# Performance tracking
var _fps_history: Array[int] = []
var _memory_history: Array[float] = []
const HISTORY_SIZE: int = 10

# Update control
var _performance_update_timer: float = 0.0
const PERFORMANCE_UPDATE_INTERVAL: float = 0.5

func _init() -> void:
	super._init()
	component_id = "performance"
	update_frequency = 2.0  # 2 FPS for performance stats
	enable_performance_monitoring = true

func _setup_component() -> void:
	_create_performance_ui()
	_style_performance_display()
	_connect_performance_signals()

func _update_component(delta: float) -> void:
	_performance_update_timer += delta
	if _performance_update_timer >= PERFORMANCE_UPDATE_INTERVAL:
		_performance_update_timer = 0.0
		_update_performance_display()

func _create_performance_ui() -> void:
	# Create background panel
	_background_panel = Panel.new()
	_background_panel.name = "PerformanceBackground"
	add_child(_background_panel)
	
	# Create performance label
	_performance_label = Label.new()
	_performance_label.name = "PerformanceLabel"
	_performance_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_performance_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_performance_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_performance_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_performance_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_background_panel.add_child(_performance_label)
	
	# Set initial size
	custom_minimum_size = Vector2(150, 60) if compact_display else Vector2(200, 100)

func _style_performance_display() -> void:
	# Style background panel
	var style_box := StyleBoxFlat.new()
	style_box.bg_color = Color(0.0, 0.0, 0.0, 0.8)  # Semi-transparent black
	style_box.border_width_left = 1
	style_box.border_width_right = 1
	style_box.border_width_top = 1
	style_box.border_width_bottom = 1
	style_box.border_color = Color(0.4, 0.4, 0.4, 0.9)  # Gray border
	style_box.corner_radius_top_left = 3
	style_box.corner_radius_top_right = 3
	style_box.corner_radius_bottom_left = 3
	style_box.corner_radius_bottom_right = 3
	style_box.content_margin_left = 5
	style_box.content_margin_right = 5
	style_box.content_margin_top = 3
	style_box.content_margin_bottom = 3
	
	_background_panel.add_theme_stylebox_override("panel", style_box)
	_background_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	# Style label
	_performance_label.add_theme_color_override("font_color", Color.WHITE)
	_performance_label.add_theme_font_size_override("font_size", 10 if compact_display else 11)
	_performance_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func _connect_performance_signals() -> void:
	# Connect to debug settings changes
	if DebugManager:
		# DebugManager might have performance settings changes
		pass

func _update_performance_display() -> void:
	var stats: Array[String] = []
	
	# FPS with history
	if show_fps:
		var current_fps: int = int(Engine.get_frames_per_second())
		_fps_history.append(current_fps)
		if _fps_history.size() > HISTORY_SIZE:
			_fps_history.pop_front()
		
		var avg_fps := _calculate_average_fps()
		if compact_display:
			stats.append("FPS: %d" % current_fps)
		else:
			stats.append("FPS: %d (avg: %d)" % [current_fps, avg_fps])
	
	# Memory usage
	if show_memory:
		var memory_usage: int = OS.get_static_memory_usage()
		var memory_mb: float = memory_usage / (1024.0 * 1024.0)
		_memory_history.append(memory_mb)
		if _memory_history.size() > HISTORY_SIZE:
			_memory_history.pop_front()
		
		if compact_display:
			stats.append("Mem: %dMB" % int(memory_mb))
		else:
			var avg_memory := _calculate_average_memory()
			stats.append("Memory: %dMB (avg: %dMB)" % [int(memory_mb), int(avg_memory)])
	
	# Draw calls (skip in headless mode to prevent resource leaks)
	if show_draw_calls and DisplayServer.get_name() != "headless":
		var draw_calls: int = _get_draw_calls()
		stats.append("Draw Calls: %d" % draw_calls)
	
	# Entity counts from arena/game systems
	if show_entity_counts:
		var entity_stats := _get_entity_statistics()
		for stat in entity_stats:
			stats.append(stat)
	
	# HUD performance stats (if enabled)
	if enable_performance_monitoring and HUDManager:
		var hud_stats := HUDManager.get_performance_stats()
		if not compact_display and hud_stats.has("average_hud_update_time"):
			var hud_time: float = hud_stats.get("average_hud_update_time", 0.0)
			if hud_time > 0.1:  # Only show if significant
				stats.append("HUD: %.1fms" % hud_time)
	
	# Update display
	var display_text := "\n".join(stats)
	if display_text != _performance_label.text:
		_performance_label.text = display_text
		_auto_resize_to_content()

func _calculate_average_fps() -> int:
	if _fps_history.is_empty():
		return 0
	
	var total: int = 0
	for fps in _fps_history:
		total += fps
	return total / _fps_history.size()

func _calculate_average_memory() -> float:
	if _memory_history.is_empty():
		return 0.0
	
	var total: float = 0.0
	for mem in _memory_history:
		total += mem
	return total / _memory_history.size()

func _get_draw_calls() -> int:
	# Get draw calls from viewport (with error handling)
	var viewport: Viewport = get_viewport()
	if not viewport:
		return 0
	
	var draw_calls: int = RenderingServer.viewport_get_render_info(
		viewport.get_viewport_rid(),
		RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE,
		RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME
	)
	return draw_calls

func _get_entity_statistics() -> Array[String]:
	var stats: Array[String] = []
	
	# Get stats from current scene (usually Arena)
	var current_scene: Node = get_tree().current_scene
	if current_scene and current_scene.has_method("get_debug_stats"):
		var debug_stats: Dictionary = current_scene.get_debug_stats()
		
		if debug_stats.has("enemy_count"):
			var enemy_text: String = "Enemies: %d" % debug_stats["enemy_count"]
			if debug_stats.has("visible_enemies") and not compact_display:
				enemy_text += " (vis: %d)" % debug_stats["visible_enemies"]
			stats.append(enemy_text)
		
		if debug_stats.has("projectile_count"):
			stats.append("Projectiles: %d" % debug_stats["projectile_count"])
		
		if debug_stats.has("boss_count") and debug_stats["boss_count"] > 0:
			stats.append("Bosses: %d" % debug_stats["boss_count"])
	
	# Get stats from EntityTracker if available
	if EntityTracker:
		var alive_entities: Array[String] = EntityTracker.get_alive_entities()
		if alive_entities.size() > 0:
			stats.append("Total Entities: %d" % alive_entities.size())
	
	return stats

func _auto_resize_to_content() -> void:
	# Auto-resize the component to fit content
	await get_tree().process_frame
	
	if not _performance_label:
		return
	
	# Get text dimensions
	var content_size := _performance_label.get_theme_font("font").get_multiline_string_size(
		_performance_label.text,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		_performance_label.get_theme_font_size("font_size")
	)
	
	# Add padding from panel style
	var padding := Vector2(10, 6)  # Margin from style box
	var required_size := content_size + padding
	
	# Clamp to reasonable bounds
	required_size.x = max(required_size.x, 100)
	required_size.x = min(required_size.x, 300)
	required_size.y = max(required_size.y, 30)
	required_size.y = min(required_size.y, 150)
	
	# Update size
	custom_minimum_size = required_size
	size = required_size

# Public API
func set_display_mode(fps: bool, memory: bool, draw_calls: bool, entities: bool) -> void:
	"""Configure which performance metrics to display"""
	show_fps = fps
	show_memory = memory
	show_draw_calls = draw_calls
	show_entity_counts = entities
	_update_performance_display()

func set_compact_mode(compact: bool) -> void:
	"""Toggle between compact and detailed display"""
	compact_display = compact
	_style_performance_display()
	_update_performance_display()

func reset_performance_history() -> void:
	"""Clear performance history for fresh metrics"""
	_fps_history.clear()
	_memory_history.clear()

func get_current_performance_stats() -> Dictionary:
	"""Get current performance statistics"""
	return {
		"current_fps": int(Engine.get_frames_per_second()) if not _fps_history.is_empty() else 0,
		"average_fps": _calculate_average_fps(),
		"current_memory_mb": OS.get_static_memory_usage() / (1024.0 * 1024.0),
		"average_memory_mb": _calculate_average_memory(),
		"draw_calls": _get_draw_calls() if DisplayServer.get_name() != "headless" else 0
	}

func toggle_visibility() -> void:
	"""Toggle performance component visibility"""
	visible = not visible
	Logger.debug("Performance component visibility: " + str(visible), "ui")
