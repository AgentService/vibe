extends Control
class_name HUD

## Heads-up display showing level, XP bar, and other player stats.

@onready var health_bar: ProgressBar = $HealthBar
@onready var level_label: Label = $LevelLabel
@onready var xp_bar: ProgressBar = $VBoxContainer/XPBar
@onready var enemy_radar: Panel = $EnemyRadar
@onready var fps_label: Label = $FPSLabel
@onready var death_screen: Control = $DeathScreen

var fps_update_timer: float = 0.0
const FPS_UPDATE_INTERVAL: float = 0.5
var debug_overlay_visible: bool = true
var is_game_over: bool = false


func _ready() -> void:
	# HUD should always process (including FPS counter during pause)
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	# Connect to new PlayerProgression signals
	EventBus.progression_changed.connect(_on_progression_changed)
	EventBus.leveled_up.connect(_on_leveled_up)
	EventBus.damage_taken.connect(_on_player_damage_taken)
	EventBus.player_died.connect(_on_player_died)
	
	
	# Initialize display
	_initialize_progression_display()
	_update_health_display(100, 100)
	_style_health_bar()
	_style_level_label()
	_update_fps_display()
	

func _process(delta: float) -> void:
	fps_update_timer += delta
	if fps_update_timer >= FPS_UPDATE_INTERVAL:
		fps_update_timer = 0.0
		_update_fps_display()
	
	pass


func _on_progression_changed(state: Dictionary) -> void:
	var current_xp = int(state.get("exp", 0))
	var xp_to_next = int(state.get("xp_to_next", 100))
	var level = int(state.get("level", 1))
	
	# Calculate the total XP needed for the current level
	var total_xp_for_level = current_xp + xp_to_next
	
	print("HUD: Progression changed - Level: %d, XP: %d/%d" % [level, current_xp, total_xp_for_level])
	_update_xp_display(current_xp, total_xp_for_level)
	_update_level_display(level)

func _on_leveled_up(new_level: int, prev_level: int) -> void:
	print("HUD: Level up detected! %d -> %d" % [prev_level, new_level])
	_update_level_display(new_level)

func _on_player_damage_taken(_damage: int) -> void:
	# Get current player health from player node
	var player: Player = get_tree().get_first_node_in_group("player")
	if player:
		_update_health_display(player.get_health(), player.get_max_health())

func _unhandled_key_input(event: InputEvent) -> void:
	if is_game_over and event is InputEventKey and event.pressed:
		if event.physical_keycode == KEY_F5:
			_restart_game()

func _on_player_died() -> void:
	is_game_over = true
	death_screen.visible = true

	get_tree().paused = true
	Logger.info("Player died - game paused", "ui")

func _restart_game() -> void:
	is_game_over = false
	death_screen.visible = false
	get_tree().paused = false
	get_tree().reload_current_scene()
	Logger.info("Game restarted", "ui")

func _update_level_display(level: int) -> void:
	if level_label:
		level_label.text = "Level: " + str(level)

func _update_xp_display(current_xp: int, next_level_xp: int) -> void:
	if xp_bar:
		xp_bar.max_value = next_level_xp
		xp_bar.value = current_xp

func _update_health_display(current_hp: int, max_hp: int) -> void:
	if health_bar:
		health_bar.max_value = max_hp
		health_bar.value = current_hp

func _style_health_bar() -> void:
	if health_bar:
		# Create a simple theme with red fill and dark background
		var health_theme := Theme.new()
		var style_bg := StyleBoxFlat.new()
		var style_fill := StyleBoxFlat.new()
		
		# Background (empty health)
		style_bg.bg_color = Color(0.2, 0.2, 0.2, 0.8)  # Dark gray
		style_bg.border_width_left = 2
		style_bg.border_width_right = 2
		style_bg.border_width_top = 2
		style_bg.border_width_bottom = 2
		style_bg.border_color = Color(0.5, 0.5, 0.5, 1.0)  # Gray border
		
		# Fill (current health)
		style_fill.bg_color = Color(0.8, 0.2, 0.2, 1.0)  # Red
		
		health_theme.set_stylebox("background", "ProgressBar", style_bg)
		health_theme.set_stylebox("fill", "ProgressBar", style_fill)
		
		health_bar.theme = health_theme

func _style_level_label() -> void:
	if level_label:
		# Create theme for level label
		var label_theme := Theme.new()
		var style_bg := StyleBoxFlat.new()
		
		# Background
		style_bg.bg_color = Color(0.1, 0.1, 0.1, 0.9)  # Dark background
		style_bg.border_width_left = 1
		style_bg.border_width_right = 1
		style_bg.border_width_top = 1
		style_bg.border_width_bottom = 1
		style_bg.border_color = Color(0.6, 0.6, 0.6, 1.0)  # Light gray border
		style_bg.corner_radius_top_left = 3
		style_bg.corner_radius_top_right = 3
		style_bg.corner_radius_bottom_left = 3
		style_bg.corner_radius_bottom_right = 3
		style_bg.content_margin_left = 8
		style_bg.content_margin_right = 8
		style_bg.content_margin_top = 4
		style_bg.content_margin_bottom = 4
		
		label_theme.set_stylebox("normal", "Label", style_bg)
		label_theme.set_color("font_color", "Label", Color(1.0, 1.0, 1.0, 1.0))  # White text
		
		level_label.theme = label_theme

func _initialize_progression_display() -> void:
	# Get initial progression state from PlayerProgression
	if PlayerProgression:
		var state = PlayerProgression.get_progression_state()
		_on_progression_changed(state)
		print("HUD: Initialized with PlayerProgression state")
	else:
		# Fallback values
		_update_level_display(1)
		_update_xp_display(0, 100)
		print("HUD: PlayerProgression not available, using fallback values")

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
	stats.append("Memory: " + str(int(memory_usage / (1024 * 1024))) + " MB")
	
	# Get enemy/projectile counts from Arena if available
	var arena: Node = get_tree().current_scene
	if arena and arena.has_method("get_debug_stats"):
		var debug_stats: Dictionary = arena.get_debug_stats()
		if debug_stats.has("enemy_count"):
			var enemy_text: String = "Enemies: " + str(debug_stats["enemy_count"])
			if debug_stats.has("visible_enemies"):
				enemy_text += " (visible: " + str(debug_stats["visible_enemies"]) + ")"
			stats.append(enemy_text)
		if debug_stats.has("projectile_count"):
			stats.append("Projectiles: " + str(debug_stats["projectile_count"]))
	
	return "\n".join(stats)


func _toggle_debug_overlay() -> void:
	debug_overlay_visible = !debug_overlay_visible
	Logger.info("Debug overlay toggled: " + str(debug_overlay_visible), "ui")
