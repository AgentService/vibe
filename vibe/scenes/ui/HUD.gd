extends Control
class_name HUD

## Heads-up display showing level, XP bar, and other player stats.

@onready var level_label: Label = $VBoxContainer/LevelLabel
@onready var xp_bar: ProgressBar = $VBoxContainer/XPBar
@onready var enemy_radar: Panel = $EnemyRadar
@onready var fps_label: Label = $FPSLabel

var fps_update_timer: float = 0.0
const FPS_UPDATE_INTERVAL: float = 0.5
var debug_overlay_visible: bool = false

func _ready() -> void:
	EventBus.xp_changed.connect(_on_xp_changed)
	EventBus.level_up.connect(_on_level_up)
	
	# Initialize display
	_update_level_display(1)
	_update_xp_display(0, 30)
	_update_fps_display()

func _process(delta: float) -> void:
	fps_update_timer += delta
	if fps_update_timer >= FPS_UPDATE_INTERVAL:
		fps_update_timer = 0.0
		_update_fps_display()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_F9:
			_toggle_debug_overlay()

func _on_xp_changed(payload) -> void:
	_update_xp_display(payload.current_xp, payload.next_level_xp)

func _on_level_up(payload) -> void:
	_update_level_display(payload.new_level)

func _update_level_display(level: int) -> void:
	if level_label:
		level_label.text = "Level: " + str(level)

func _update_xp_display(current_xp: int, next_level_xp: int) -> void:
	if xp_bar:
		xp_bar.max_value = next_level_xp
		xp_bar.value = current_xp

func _update_fps_display() -> void:
	if fps_label:
		var fps: int = Engine.get_frames_per_second()
		var base_text: String = "FPS: " + str(fps)
		
		if debug_overlay_visible:
			# Add additional performance stats
			var render_info: String = _get_render_stats()
			fps_label.text = base_text + "\n" + render_info
		else:
			fps_label.text = base_text

func _toggle_debug_overlay() -> void:
	debug_overlay_visible = !debug_overlay_visible
	Logger.info("Debug overlay toggled: " + str(debug_overlay_visible), "ui")
	_update_fps_display()  # Update immediately

func _get_render_stats() -> String:
	# Get performance statistics from the rendering server
	var stats: Array[String] = []
	
	# Get draw calls from viewport
	var viewport: Viewport = get_viewport()
	if viewport:
		var draw_calls: int = RenderingServer.viewport_get_render_info(
			viewport.get_viewport_rid(), 
			RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE, 
			RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME
		)
		stats.append("Draw Calls: " + str(draw_calls))
	
	# Get memory usage
	var memory_usage: int = OS.get_static_memory_usage()
	stats.append("Memory: " + str(memory_usage / 1024 / 1024) + " MB")
	
	# Get enemy/projectile counts from Arena if available
	var arena: Node = get_tree().current_scene
	if arena and arena.has_method("get_debug_stats"):
		var debug_stats: Dictionary = arena.get_debug_stats()
		if debug_stats.has("enemy_count"):
			stats.append("Enemies: " + str(debug_stats["enemy_count"]))
		if debug_stats.has("projectile_count"):
			stats.append("Projectiles: " + str(debug_stats["projectile_count"]))
	
	return "\n".join(stats)
