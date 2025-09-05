extends Control

## Debug Panel UI Controller
## Handles user interactions with the debug interface
## Communicates with DebugManager for actual debug operations

# Proper Godot UI structure - simple and clean node paths
@onready var enemy_type_dropdown: OptionButton = $PanelContainer/MarginContainer/VBoxContainer/EnemyTypeDropdown
@onready var spawn_at_cursor_btn: Button = $PanelContainer/MarginContainer/VBoxContainer/SpawnButtons/SpawnAtCursor  
@onready var spawn_at_player_btn: Button = $PanelContainer/MarginContainer/VBoxContainer/SpawnButtons/SpawnAtPlayer
@onready var count1_btn: Button = $PanelContainer/MarginContainer/VBoxContainer/CountButtons/Count1
@onready var count5_btn: Button = $PanelContainer/MarginContainer/VBoxContainer/CountButtons/Count5
@onready var count10_btn: Button = $PanelContainer/MarginContainer/VBoxContainer/CountButtons/Count10

# Entity Inspector UI elements
@onready var entity_info: RichTextLabel = $PanelContainer/MarginContainer/VBoxContainer/EntityInfo
@onready var kill_btn: Button = $PanelContainer/MarginContainer/VBoxContainer/EntityActions/KillButton
@onready var heal_btn: Button = $PanelContainer/MarginContainer/VBoxContainer/EntityActions/HealButton
@onready var damage_btn: Button = $PanelContainer/MarginContainer/VBoxContainer/EntityActions/DamageButton

# System Controls UI elements  
@onready var pause_ai_checkbox: CheckBox = $PanelContainer/MarginContainer/VBoxContainer/PauseAICheckbox
@onready var show_collision_checkbox: CheckBox = $PanelContainer/MarginContainer/VBoxContainer/ShowCollisionCheckbox
@onready var clear_all_btn: Button = $PanelContainer/MarginContainer/VBoxContainer/CountButtons/ClearAllButton
@onready var reset_session_btn: Button = $PanelContainer/MarginContainer/VBoxContainer/SystemButtons/ResetSessionButton

# Performance Stats UI elements
@onready var performance_info: RichTextLabel = $PanelContainer/MarginContainer/VBoxContainer/PerformanceInfo

var selected_count: int = 1
var available_enemy_types: Array[String] = []
var background_panel: PanelContainer

# Entity Inspector state
var inspected_entity_id: String = ""
var inspected_entity_data: Dictionary = {}

# Performance stats management
var performance_update_timer: Timer
var debug_overlay: DebugOverlay
var debug_system_controls: DebugSystemControls

# Cache to prevent memory leaks from string creation
var last_stats_text: String = ""
var stats_update_count: int = 0

func _ready() -> void:
	# Create and setup background panel
	_create_background_panel()
	
	# Setup performance stats timer EARLY (before any UI interactions)
	_setup_performance_timer()
	
	# Connect spawner button signals
	spawn_at_cursor_btn.pressed.connect(_on_spawn_at_cursor_pressed)
	spawn_at_player_btn.pressed.connect(_on_spawn_at_player_pressed)
	
	count1_btn.pressed.connect(_on_count_selected.bind(1))
	count5_btn.pressed.connect(_on_count_selected.bind(5))
	count10_btn.pressed.connect(_on_count_selected.bind(10))
	
	# Connect entity inspector button signals
	kill_btn.pressed.connect(_on_kill_pressed)
	heal_btn.pressed.connect(_on_heal_pressed)
	damage_btn.pressed.connect(_on_damage_pressed)
	
	# Connect system controls signals
	pause_ai_checkbox.toggled.connect(_on_pause_ai_toggled)
	show_collision_checkbox.toggled.connect(_on_show_collision_toggled)
	clear_all_btn.pressed.connect(_on_clear_all_pressed)
	reset_session_btn.pressed.connect(_on_reset_session_pressed)
	
	# Connect to DebugManager signals
	if DebugManager:
		DebugManager.entity_inspected.connect(_on_entity_inspected)
	
	# Load enemy types into dropdown
	_populate_enemy_dropdown()
	
	# Set initial count selection
	_on_count_selected(1)
	
	# Set initial entity inspector text
	entity_info.text = "[center][color=#FFD700]Ctrl+Click[/color] on an entity to inspect[/center]"
	_set_entity_buttons_enabled(false)
	
	# Update button text to show shortcuts
	spawn_at_cursor_btn.text = "Spawn at Cursor (V)"
	spawn_at_player_btn.text = "Spawn at Player (B)"
	
	# Auto-enable performance stats (always visible now)
	_set_performance_stats_visible(true)
	
	Logger.debug("DebugPanel initialized", "debug")

func _exit_tree() -> void:
	# Cleanup signal connections to prevent memory leaks
	if DebugManager and DebugManager.entity_inspected.is_connected(_on_entity_inspected):
		DebugManager.entity_inspected.disconnect(_on_entity_inspected)
	
	# Clean up performance timer
	if performance_update_timer:
		performance_update_timer.stop()
		if performance_update_timer.timeout.is_connected(_update_performance_stats):
			performance_update_timer.timeout.disconnect(_update_performance_stats)
	
	Logger.debug("DebugPanel: Cleaned up signal connections", "debug")

func _input(event: InputEvent) -> void:
	# Block game attacks when mouse is over debug panel, but allow UI interactions
	if event is InputEventMouseButton and event.pressed and _is_mouse_over_debug_panel():
		# Block left click attacks specifically - but let UI handle the click first
		if event.button_index == MOUSE_BUTTON_LEFT:
			# Mark this event as handled for game systems (prevents attacks)
			# But don't consume it here - let UI buttons process it first
			call_deferred("_block_game_input")
		return
		
	# Handle debug panel keyboard shortcuts
	if not visible or not DebugManager or not DebugManager.is_debug_mode_active():
		return
		
	if event is InputEventKey and event.pressed:
		var key_event := event as InputEventKey
		
		# V key: Spawn at cursor (same as clicking "Spawn at Cursor" button)
		if key_event.keycode == KEY_V:
			_on_spawn_at_cursor_pressed()
			get_viewport().set_input_as_handled()
		
		# B key: Spawn at player (same as clicking "Spawn at Player" button)
		if key_event.keycode == KEY_B:
			_on_spawn_at_player_pressed()
			get_viewport().set_input_as_handled()

func _block_game_input() -> void:
	# Delayed blocking to ensure UI gets the click first
	get_viewport().set_input_as_handled()

func _is_mouse_over_debug_panel() -> bool:
	# Check if mouse position is within the debug panel bounds
	var mouse_pos := get_global_mouse_position()
	var panel_rect := get_global_rect()
	return visible and panel_rect.has_point(mouse_pos)


func _populate_enemy_dropdown() -> void:
	# Clear existing items
	enemy_type_dropdown.clear()
	available_enemy_types.clear()
	
	# Only include implemented/tested enemy types for now
	var implemented_enemies: Array[String] = [
		"ancient_lich",    # Boss type
		"dragon_lord",     # Boss type  
		"goblin"           # Swarm type
	]
	
	# Load available enemy types from EnemyFactory
	const EnemyFactory = preload("res://scripts/systems/enemy_v2/EnemyFactory.gd")
	
	# Ensure templates are loaded
	if not EnemyFactory._templates_loaded:
		EnemyFactory.load_all_templates()
	
	# Add only implemented enemy types
	for template_id in implemented_enemies:
		if EnemyFactory._templates.has(template_id):
			var template = EnemyFactory._templates[template_id]
			# Verify template has positive weight
			if template.weight > 0.0:
				available_enemy_types.append(template_id)
				var display_name = template_id.replace("_", " ").capitalize()
				enemy_type_dropdown.add_item(display_name)
		else:
			Logger.warn("Implemented enemy type not found in templates: " + template_id, "debug")
	
	Logger.debug("Loaded %d implemented enemy types into dropdown" % available_enemy_types.size(), "debug")

func _on_spawn_at_cursor_pressed() -> void:
	var selected_enemy_type := _get_selected_enemy_type()
	if selected_enemy_type.is_empty():
		Logger.warn("No enemy type selected for cursor spawn", "debug")
		return
	
	if DebugManager:
		DebugManager.spawn_enemy_at_cursor(selected_enemy_type, selected_count)

func _on_spawn_at_player_pressed() -> void:
	var selected_enemy_type := _get_selected_enemy_type()
	if selected_enemy_type.is_empty():
		Logger.warn("No enemy type selected for player spawn", "debug")
		return
	
	if DebugManager:
		DebugManager.spawn_enemy_at_player(selected_enemy_type, selected_count)

func _on_count_selected(count: int) -> void:
	selected_count = count
	
	# Update button states to show selection
	count1_btn.button_pressed = (count == 1)
	count5_btn.button_pressed = (count == 5)
	count10_btn.button_pressed = (count == 10)
	
	Logger.debug("Selected spawn count: %d" % count, "debug")

func _get_selected_enemy_type() -> String:
	var selected_index := enemy_type_dropdown.selected
	if selected_index < 0 or selected_index >= available_enemy_types.size():
		return ""
	return available_enemy_types[selected_index]

func _on_entity_inspected(entity_data: Dictionary) -> void:
	inspected_entity_data = entity_data
	inspected_entity_id = entity_data.get("id", "")
	
	# Update entity info display - improved data extraction
	var entity_type = entity_data.get("type", "Unknown")
	var current_hp = entity_data.get("current_hp", entity_data.get("hp", 0))
	var max_hp = entity_data.get("max_hp", entity_data.get("max_health", entity_data.get("health", 1)))
	var pos = entity_data.get("position", entity_data.get("global_position", Vector2.ZERO))
	
	# Handle different position formats
	var position_vec: Vector2
	if pos is Vector2:
		position_vec = pos as Vector2
	else:
		position_vec = Vector2.ZERO
		
	# Fallback for boss data structure
	if current_hp == 0 and max_hp <= 1:
		current_hp = entity_data.get("health", entity_data.get("life", 0))
		max_hp = entity_data.get("max_health", entity_data.get("max_life", current_hp))
	
	# Use table format with left alignment - better readability
	var info_text := "[table=2]"
	info_text += "[cell][color=yellow]Type:[/color][/cell][cell]%s[/cell]" % entity_type
	info_text += "[cell][color=yellow]ID:[/color][/cell][cell]%s[/cell]" % inspected_entity_id  
	info_text += "[cell][color=yellow]Health:[/color][/cell][cell]%d/%d[/cell]" % [current_hp, max_hp]
	info_text += "[cell][color=yellow]Position:[/color][/cell][cell](%.1f, %.1f)[/cell]" % [position_vec.x, position_vec.y]
	info_text += "[/table]"
	
	entity_info.text = info_text
	_set_entity_buttons_enabled(true)
	
	Logger.debug("Entity inspected: %s" % entity_data, "debug")

func _set_entity_buttons_enabled(enabled: bool) -> void:
	kill_btn.disabled = not enabled
	heal_btn.disabled = not enabled
	damage_btn.disabled = not enabled
	Logger.debug("Entity buttons enabled: %s" % enabled, "debug")

# Entity Inspector Action Handlers
func _on_kill_pressed() -> void:
	if inspected_entity_id.is_empty():
		Logger.warn("No entity selected for kill action", "debug")
		return
	
	Logger.info("Kill action triggered for entity: %s" % inspected_entity_id, "debug")
	if DebugManager:
		DebugManager.kill_entity(inspected_entity_id)
	else:
		Logger.warn("DebugManager not available for kill action", "debug")
	
func _on_heal_pressed() -> void:
	if inspected_entity_id.is_empty():
		Logger.warn("No entity selected for heal action", "debug")
		return
	
	Logger.info("Heal action triggered for entity: %s" % inspected_entity_id, "debug")
	if DebugManager:
		DebugManager.heal_entity(inspected_entity_id, 50)  # Heal for 50 HP (int)
	else:
		Logger.warn("DebugManager not available for heal action", "debug")

func _on_damage_pressed() -> void:
	if inspected_entity_id.is_empty():
		Logger.warn("No entity selected for damage action", "debug")
		return
	
	Logger.info("Damage action triggered for entity: %s" % inspected_entity_id, "debug")
	if DebugManager:
		DebugManager.damage_entity(inspected_entity_id, 25)  # Apply 25 damage (int)
	else:
		Logger.warn("DebugManager not available for damage action", "debug")

# Legacy scene tree manipulation methods removed - now using DebugManager pipeline

# System Control Handlers
func _on_pause_ai_toggled(pressed: bool) -> void:
	Logger.info("AI pause toggled: %s" % pressed, "debug")
	if debug_system_controls:
		debug_system_controls.set_ai_paused(pressed)
	else:
		Logger.warn("DebugSystemControls not available", "debug")

func _on_show_collision_toggled(pressed: bool) -> void:
	Logger.info("Collision shapes visibility toggled: %s" % pressed, "debug")
	if debug_system_controls:
		debug_system_controls.set_collision_shapes_visible(pressed)
	else:
		Logger.warn("DebugSystemControls not available", "debug")

# Performance stats are now always visible, no toggle needed

func _on_clear_all_pressed() -> void:
	Logger.info("Clear all enemies triggered", "debug")
	if debug_system_controls:
		debug_system_controls.clear_all_entities()
	else:
		Logger.warn("DebugSystemControls not available", "debug")

func _on_reset_session_pressed() -> void:
	Logger.info("Reset session triggered", "debug")
	if debug_system_controls:
		debug_system_controls.reset_session()
	else:
		Logger.warn("DebugSystemControls not available", "debug")


func _create_background_panel() -> void:
	# Apply proper Godot theme-based styling
	call_deferred("_apply_proper_styling")

func _apply_proper_styling() -> void:
	# Apply styling to PanelContainer (visual container)
	var panel_container = get_node("PanelContainer")
	if panel_container:
		var panel_style := StyleBoxFlat.new()
		panel_style.bg_color = Color(0, 0, 0, 1.0)  # Solid black background
		panel_style.border_width_left = 2
		panel_style.border_width_top = 2
		panel_style.border_width_right = 2
		panel_style.border_width_bottom = 2
		panel_style.border_color = Color(0.3, 0.3, 0.3, 1.0)  # Dark gray border
		panel_style.corner_radius_top_left = 8
		panel_style.corner_radius_top_right = 8
		panel_style.corner_radius_bottom_left = 8
		panel_style.corner_radius_bottom_right = 8
		
		panel_container.add_theme_stylebox_override("panel", panel_style)
		
	# Apply margin to MarginContainer (proper padding)
	var margin_container = get_node("PanelContainer/MarginContainer")
	if margin_container:
		margin_container.add_theme_constant_override("margin_left", 8)
		margin_container.add_theme_constant_override("margin_right", 8)
		margin_container.add_theme_constant_override("margin_top", 8)
		margin_container.add_theme_constant_override("margin_bottom", 8)
		
	# Apply separation to VBoxContainer (spacing between elements)
	var vbox_container = get_node("PanelContainer/MarginContainer/VBoxContainer")
	if vbox_container:
		vbox_container.add_theme_constant_override("separation", 4)
		
	Logger.debug("Applied proper Godot theme-based styling", "debug")


func _setup_performance_timer() -> void:
	# Create performance update timer - update every second for responsive FPS display
	performance_update_timer = Timer.new()
	performance_update_timer.wait_time = 1.0  # 1 second updates for good responsiveness
	performance_update_timer.timeout.connect(_update_performance_stats)
	add_child(performance_update_timer)
	
	# Try to get reference to DebugOverlay via DebugManager
	if DebugManager and DebugManager.has_method("get_debug_overlay"):
		debug_overlay = DebugManager.get_debug_overlay()
	else:
		# Fallback: search scene tree
		var scene_tree := get_tree()
		if scene_tree and scene_tree.current_scene:
			debug_overlay = _find_debug_overlay(scene_tree.current_scene)
	
	# Try to get reference to DebugSystemControls via DebugManager
	if DebugManager and DebugManager.has_method("get_debug_system_controls"):
		debug_system_controls = DebugManager.get_debug_system_controls()
	else:
		# Fallback: search scene tree
		var scene_tree := get_tree()
		if scene_tree and scene_tree.current_scene:
			debug_system_controls = _find_debug_system_controls(scene_tree.current_scene)
	
	Logger.debug("Performance stats timer setup complete", "debug")

func _find_debug_overlay(node: Node) -> DebugOverlay:
	# Check if this node is the debug overlay
	if node is DebugOverlay:
		return node as DebugOverlay
	
	# Check by name as well
	if node.name == "DebugOverlay" and node.has_method("get_performance_stats"):
		return node as DebugOverlay
	
	# Search children recursively
	for child in node.get_children():
		var result = _find_debug_overlay(child)
		if result:
			return result
	
	return null

func _find_debug_system_controls(node: Node) -> DebugSystemControls:
	# Check if this node is the debug system controls
	if node is DebugSystemControls:
		return node as DebugSystemControls
	
	# Check by name as well
	if node.name == "DebugSystemControls" and node.has_method("set_ai_paused"):
		return node as DebugSystemControls
	
	# Search children recursively
	for child in node.get_children():
		var result = _find_debug_system_controls(child)
		if result:
			return result
	
	return null

func _set_performance_stats_visible(visible: bool) -> void:
	# Performance stats are now always visible, so force visible to true
	if performance_info:
		performance_info.visible = true  # Always keep visible
	
	# Start/stop the update timer (check if timer exists first)
	if performance_update_timer:
		if visible:
			performance_update_timer.start()
			# Performance stats will update immediately and every second thereafter
			_update_performance_stats()  # Update immediately
		else:
			performance_update_timer.stop()
	else:
		Logger.warn("Performance update timer not initialized", "debug")
	
	Logger.debug("Performance stats setup: timer_exists=%s, performance_info_exists=%s" % [performance_update_timer != null, performance_info != null], "debug")

func _update_performance_stats() -> void:
	if not performance_info:
		return
	
	# Update every second for responsive FPS display
	# No cycle limiting - timer is already at 1 second intervals
		
	# Get current values with caching to prevent string creation
	var fps = Engine.get_frames_per_second()
	@warning_ignore("static_called_on_instance")
	var memory_mb = Performance.get_monitor(Performance.MEMORY_STATIC) / 1024.0 / 1024.0
	
	# Get enemy count from multiple sources (mesh enemies + bosses) - cached approach
	var enemy_count = 0
	var boss_count = 0
	
	# Only count enemies if they might have changed (check every 10 cycles)
	if stats_update_count % 20 == 0:  # Even less frequent enemy counting
		# Count from WaveDirector (mesh enemies)
		if debug_system_controls and debug_system_controls.wave_director:
			var alive_enemies = debug_system_controls.wave_director.get_alive_enemies()
			enemy_count = alive_enemies.size()
		
		# Count bosses separately from scene tree
		boss_count = _count_bosses_in_scene()
	else:
		# Use cached values from last stats text
		if last_stats_text.contains("Enemies: "):
			var parts = last_stats_text.split("Enemies: ")[1].split(" (")
			if parts.size() > 0:
				var total_str = parts[0]
				if total_str.is_valid_int():
					enemy_count = 0  # Will be calculated from total below
	
	var total_enemies = enemy_count + boss_count
	
	# Build new stats string using cached values and minimal string operations
	var new_stats_text = str("FPS: ", fps, "\nEnemies: ", total_enemies, " (Mesh: ", enemy_count, ", Bosses: ", boss_count, ")\nProjectiles: 0\nMemory: ", "%.1f" % memory_mb, " MB")
	
	# Only update text if values actually changed to prevent memory leaks
	if new_stats_text != last_stats_text:
		# Use minimal string operations for BBCode
		performance_info.text = str("[color=white]", new_stats_text, "[/color]")
		last_stats_text = new_stats_text

func _count_bosses_in_scene() -> int:
	var scene_tree := get_tree()
	if not scene_tree or not scene_tree.current_scene:
		return 0
	
	return _count_bosses_recursive(scene_tree.current_scene)

func _count_bosses_recursive(node: Node) -> int:
	var count = 0
	
	# Look for boss nodes
	if node.name.contains("Boss") or node.name.contains("Lich") or node.name.contains("Dragon"):
		# Check if it's actually alive/active
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

func _count_enemies_in_scene() -> int:
	var scene_tree := get_tree()
	if not scene_tree or not scene_tree.current_scene:
		return 0
	
	return _count_enemies_recursive(scene_tree.current_scene)

func _count_enemies_recursive(node: Node) -> int:
	var count = 0
	
	# Check if this node is an enemy (look for common enemy indicators)
	if node.name.contains("Enemy") or node.name.contains("Lich") or node.name.contains("Dragon") or node.name.contains("Goblin"):
		count += 1
	elif node.is_in_group("enemies"):
		count += 1
	
	# Recursively count children
	for child in node.get_children():
		count += _count_enemies_recursive(child)
	
	return count
