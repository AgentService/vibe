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
@onready var pause_ai_button: Button = $PanelContainer/MarginContainer/VBoxContainer/PauseAIButton
@onready var clear_all_btn: Button = $PanelContainer/MarginContainer/VBoxContainer/SystemButtons/ClearAllButton
@onready var reset_session_btn: Button = $PanelContainer/MarginContainer/VBoxContainer/SystemButtons/ResetSessionButton

# Performance Stats UI elements
@onready var performance_info: RichTextLabel = $PanelContainer/MarginContainer/VBoxContainer/PerformanceInfo

var selected_count: int = 1
var selected_spawn_method: String = "cursor"  # "cursor" or "player"
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
var cached_enemy_count: int = 0
var cached_boss_count: int = 0

func _ready() -> void:
	# Check debug configuration to see if panels should be disabled
	var config_path: String = "res://config/debug.tres"
	if ResourceLoader.exists(config_path):
		var debug_config: DebugConfig = load(config_path) as DebugConfig
		if debug_config and not debug_config.debug_panels_enabled:
			Logger.info("DebugPanel disabled via debug.tres configuration", "debug")
			queue_free()  # Remove the entire node
			return
	
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
	pause_ai_button.toggled.connect(_on_pause_ai_toggled)
	clear_all_btn.pressed.connect(_on_clear_all_pressed)
	reset_session_btn.pressed.connect(_on_reset_session_pressed)
	
	# Connect to DebugManager signals
	if DebugManager:
		DebugManager.entity_inspected.connect(_on_entity_inspected)
	
	# Subscribe to damage sync for real-time HP updates
	EventBus.damage_entity_sync.connect(_on_entity_damage_sync)
	
	# Load enemy types into dropdown
	_populate_enemy_dropdown()
	
	# Set initial count selection
	_on_count_selected(1)
	
	# Set initial spawn method selection
	_update_spawn_method_buttons()
	
	# Set initial entity inspector text
	entity_info.text = "[center][color=#FFD700]Ctrl+Click[/color] on an entity to inspect[/center]"
	_set_entity_buttons_enabled(false)
	
	# Update button text to show shortcuts (shortened for better layout)
	spawn_at_cursor_btn.text = "At Cursor (V)"
	spawn_at_player_btn.text = "At Player (B)"
	
	# Auto-enable performance stats (always visible now)
	_set_performance_stats_visible(true)
	
	Logger.debug("DebugPanel initialized", "debug")

func _exit_tree() -> void:
	# Cleanup signal connections to prevent memory leaks
	if DebugManager and DebugManager.entity_inspected.is_connected(_on_entity_inspected):
		DebugManager.entity_inspected.disconnect(_on_entity_inspected)
	
	# Cleanup damage sync connection
	if EventBus.damage_entity_sync.is_connected(_on_entity_damage_sync):
		EventBus.damage_entity_sync.disconnect(_on_entity_damage_sync)
	
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
	
	# Block spacebar/ui_accept from activating UI elements - preserve for player roll only
	if event is InputEventKey and event.pressed:
		var key_event := event as InputEventKey
		if key_event.keycode == KEY_SPACE or event.is_action_pressed("ui_accept"):
			# Don't consume the input - let it pass through to player for roll
			# But make sure no UI element is focused to prevent activation
			if get_viewport().gui_get_focus_owner():
				get_viewport().gui_get_focus_owner().release_focus()
			# Don't mark as handled - let player receive the input
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
	
	# Add "Spawn All" option first
	available_enemy_types.append("__SPAWN_ALL__")
	enemy_type_dropdown.add_item("🌟 Spawn All")
	
	# Load available enemy types from EnemyFactory - all data-driven types
	const EnemyFactoryScript = preload("res://scripts/systems/enemy_v2/EnemyFactory.gd")
	
	# Ensure templates are loaded
	if not EnemyFactoryScript._templates_loaded:
		EnemyFactoryScript.load_all_templates()
	
	# Add only enemy variations (not base templates) with positive weight
	for template_id in EnemyFactoryScript._templates:
		var template = EnemyFactoryScript._templates[template_id]
		# Only include enemy variations (those with parent_path) or specific standalone enemies
		# Base templates (boss_base, melee_base, etc.) should not appear in debug dropdown
		var is_variation = not template.parent_path.is_empty()
		var is_standalone_enemy = template.parent_path.is_empty() and not template_id.ends_with("_base")
		
		if template.weight > 0.0 and (is_variation or is_standalone_enemy):
			available_enemy_types.append(template_id)
			var display_name = template_id.replace("_", " ").capitalize()
			enemy_type_dropdown.add_item(display_name)
	
	# Auto-select "Spawn All" (first item)
	enemy_type_dropdown.selected = 0
	
	Logger.debug("Loaded %d data-driven enemy types into dropdown (Spawn All auto-selected)" % available_enemy_types.size(), "debug")

func _on_spawn_at_cursor_pressed() -> void:
	var selected_enemy_type := _get_selected_enemy_type()
	if selected_enemy_type.is_empty():
		Logger.warn("No enemy type selected for cursor spawn", "debug")
		return
	
	# Update selected spawn method and button states
	selected_spawn_method = "cursor"
	_update_spawn_method_buttons()
	
	if DebugManager:
		if selected_enemy_type == "__SPAWN_ALL__":
			_spawn_all_enemies_at_cursor()
		else:
			DebugManager.spawn_enemy_at_cursor(selected_enemy_type, selected_count)

func _on_spawn_at_player_pressed() -> void:
	var selected_enemy_type := _get_selected_enemy_type()
	if selected_enemy_type.is_empty():
		Logger.warn("No enemy type selected for player spawn", "debug")
		return
	
	# Update selected spawn method and button states
	selected_spawn_method = "player"
	_update_spawn_method_buttons()
	
	if DebugManager:
		if selected_enemy_type == "__SPAWN_ALL__":
			_spawn_all_enemies_at_player()
		else:
			DebugManager.spawn_enemy_at_player(selected_enemy_type, selected_count)

func _on_count_selected(count: int) -> void:
	selected_count = count
	
	# Update button states to show selection
	count1_btn.button_pressed = (count == 1)
	count5_btn.button_pressed = (count == 5)
	count10_btn.button_pressed = (count == 10)
	
	# Remove focus from all count buttons after selection
	count1_btn.release_focus()
	count5_btn.release_focus()
	count10_btn.release_focus()
	
	Logger.debug("Selected spawn count: %d" % count, "debug")

func _update_spawn_method_buttons() -> void:
	"""Update spawn method button states to show which is currently selected"""
	spawn_at_cursor_btn.button_pressed = (selected_spawn_method == "cursor")
	spawn_at_player_btn.button_pressed = (selected_spawn_method == "player")

func _get_selected_enemy_type() -> String:
	var selected_index := enemy_type_dropdown.selected
	if selected_index < 0 or selected_index >= available_enemy_types.size():
		return ""
	return available_enemy_types[selected_index]

func _spawn_all_enemies_at_cursor() -> void:
	Logger.info("Spawning all enemy types at cursor (count: %d)" % selected_count, "debug")
	for enemy_type in available_enemy_types:
		if enemy_type != "__SPAWN_ALL__":
			DebugManager.spawn_enemy_at_cursor(enemy_type, selected_count)

func _spawn_all_enemies_at_player() -> void:
	Logger.info("Spawning all enemy types at player (count: %d)" % selected_count, "debug") 
	for enemy_type in available_enemy_types:
		if enemy_type != "__SPAWN_ALL__":
			DebugManager.spawn_enemy_at_player(enemy_type, selected_count)

func _on_entity_inspected(entity_data: Dictionary) -> void:
	inspected_entity_data = entity_data
	inspected_entity_id = entity_data.get("id", "")
	
	# Update entity info display - improved data extraction
	var entity_type = entity_data.get("type", "Unknown")
	var current_hp = entity_data.get("current_hp", entity_data.get("hp", 0))
	var max_hp = entity_data.get("max_hp", entity_data.get("max_health", entity_data.get("health", 1)))
		
	# Fallback for boss data structure
	if current_hp == 0 and max_hp <= 1:
		current_hp = entity_data.get("health", entity_data.get("life", 0))
		max_hp = entity_data.get("max_health", entity_data.get("max_life", current_hp))
	
	# Use table format with left alignment - better readability
	var info_text := "[table=2]"
	info_text += "[cell][color=yellow]Type:[/color][/cell][cell]%s[/cell]" % entity_type
	info_text += "[cell][color=yellow]ID:[/color][/cell][cell]%s[/cell]" % inspected_entity_id  
	info_text += "[cell][color=yellow]Health:[/color][/cell][cell]%d/%d[/cell]" % [current_hp, max_hp]
	info_text += "[/table]"
	
	entity_info.text = info_text
	_set_entity_buttons_enabled(true)
	
	Logger.debug("Entity inspected: %s" % entity_data, "debug")

func _on_entity_damage_sync(payload: Dictionary) -> void:
	# Check if this damage sync is for our inspected entity
	var entity_id = payload.get("entity_id", "")
	if entity_id != inspected_entity_id or inspected_entity_id.is_empty():
		return
	
	var is_death = payload.get("is_death", false)
	
	if is_death:
		# Entity died - clear selection immediately
		entity_info.text = "[center][color=red]Entity has been killed[/color][/center]"
		_set_entity_buttons_enabled(false)
		inspected_entity_id = ""
		inspected_entity_data.clear()
		Logger.debug("Cleared inspector - entity %s was killed" % entity_id, "debug")
	else:
		# Entity took damage - refresh inspector with fresh data from EntityTracker
		var fresh_entity_data = EntityTracker.get_entity(entity_id)
		if fresh_entity_data.has("id"):
			_on_entity_inspected(fresh_entity_data)
			Logger.debug("Refreshed inspector for %s after damage sync" % entity_id, "debug")
		else:
			# Entity no longer tracked - clear selection
			entity_info.text = "[center][color=red]Entity no longer tracked[/color][/center]"
			_set_entity_buttons_enabled(false)
			inspected_entity_id = ""
			inspected_entity_data.clear()

func _reacquire_debug_system_controls() -> void:
	# Always get fresh reference from DebugManager to ensure connection
	if DebugManager and DebugManager.has_method("get_debug_system_controls"):
		debug_system_controls = DebugManager.get_debug_system_controls()
		if debug_system_controls:
			Logger.debug("DebugPanel: Successfully reacquired DebugSystemControls from DebugManager", "debug")
		else:
			Logger.warn("DebugPanel: DebugManager returned null DebugSystemControls", "debug")
	else:
		# Fallback: search scene tree
		var scene_tree := get_tree()
		if scene_tree and scene_tree.current_scene:
			debug_system_controls = _find_debug_system_controls(scene_tree.current_scene)
			if debug_system_controls:
				Logger.debug("DebugPanel: Found DebugSystemControls via scene tree fallback", "debug")

func _update_inspector_hp_display(new_hp: float, is_death: bool = false) -> void:
	if inspected_entity_data.is_empty():
		return
	
	# Update cached entity data
	inspected_entity_data["hp"] = new_hp
	inspected_entity_data["current_hp"] = new_hp
	
	if is_death:
		inspected_entity_data["alive"] = false
		entity_info.text = "[center][color=red]Entity has been killed[/color][/center]"
		_set_entity_buttons_enabled(false)
		inspected_entity_id = ""  # Clear selection
		return
	
	# Rebuild the entity info display with updated HP
	var entity_type = inspected_entity_data.get("type", "Unknown")
	var max_hp = inspected_entity_data.get("max_hp", inspected_entity_data.get("max_health", 100))
	
	# Use table format with left alignment - same as entity inspection
	var info_text := "[table=2]"
	info_text += "[cell][color=yellow]Type:[/color][/cell][cell]%s[/cell]" % entity_type
	info_text += "[cell][color=yellow]ID:[/color][/cell][cell]%s[/cell]" % inspected_entity_id  
	info_text += "[cell][color=yellow]Health:[/color][/cell][cell][color=lime]%.0f[/color]/%.0f[/cell]" % [new_hp, max_hp]
	info_text += "[/table]"
	
	entity_info.text = info_text

func _set_entity_buttons_enabled(enabled: bool) -> void:
	kill_btn.disabled = not enabled
	heal_btn.disabled = not enabled
	damage_btn.disabled = not enabled
	Logger.debug("Entity buttons enabled: %s" % enabled, "debug")

# Entity Inspector Action Handlers
func _on_kill_pressed() -> void:
	if not _validate_entity_for_damage_action():
		return
	
	Logger.info("Kill action triggered for entity: %s" % inspected_entity_id, "debug")
	if DebugManager:
		DebugManager.kill_entity(inspected_entity_id)
	else:
		Logger.warn("DebugManager not available for kill action", "debug")
	
func _on_heal_pressed() -> void:
	if not _validate_entity_for_damage_action():
		return
	
	Logger.info("Heal action triggered for entity: %s" % inspected_entity_id, "debug")
	if DebugManager:
		DebugManager.heal_entity(inspected_entity_id, 50)  # Heal for 50 HP (int)
	else:
		Logger.warn("DebugManager not available for heal action", "debug")

func _on_damage_pressed() -> void:
	if not _validate_entity_for_damage_action():
		return
	
	Logger.info("Damage action triggered for entity: %s" % inspected_entity_id, "debug")
	if DebugManager:
		DebugManager.damage_entity(inspected_entity_id, 25)  # Apply 25 damage (int)
	else:
		Logger.warn("DebugManager not available for damage action", "debug")

# Entity validation for damage actions
func _validate_entity_for_damage_action() -> bool:
	if inspected_entity_id.is_empty():
		Logger.warn("No entity selected for damage action", "debug")
		return false
	
	# Check if entity exists in EntityTracker
	var in_tracker := EntityTracker.is_entity_alive(inspected_entity_id)
	if not in_tracker:
		Logger.warn("Entity not found in EntityTracker: " + inspected_entity_id, "debug")
		entity_info.text = "[center][color=red]Entity no longer exists in tracker[/color][/center]"
		_set_entity_buttons_enabled(false)
		return false
	
	# Check if entity exists in DamageService
	var damage_service_entity := DamageService.get_entity(inspected_entity_id)
	var in_damage_service := damage_service_entity.has("id")
	if not in_damage_service:
		Logger.warn("Entity not registered in DamageService: " + inspected_entity_id, "debug")
		entity_info.text = "[center][color=orange]Entity not registered for damage operations[/color]\nTry re-selecting the entity[/center]"
		
		# Try to auto-register the entity from EntityTracker data
		var tracker_data := EntityTracker.get_entity(inspected_entity_id)
		if tracker_data.has("id"):
			Logger.info("Auto-registering entity with DamageService: " + inspected_entity_id, "debug")
			DamageService.register_entity(inspected_entity_id, tracker_data)
			entity_info.text = "[center][color=green]Entity auto-registered successfully[/color]\nDamage actions should now work[/center]"
			return true
		else:
			return false
	
	return true

# Legacy scene tree manipulation methods removed - now using DebugManager pipeline

# System Control Handlers
func _on_pause_ai_toggled(pressed: bool) -> void:
	Logger.info("AI pause toggled: %s" % pressed, "debug")
	
	# Update button text to reflect state
	_update_pause_ai_button_text()
	
	# Lazy-fetch DebugSystemControls if not available
	if not debug_system_controls:
		_reacquire_debug_system_controls()
	
	if debug_system_controls:
		debug_system_controls.set_ai_paused(pressed)
	else:
		Logger.warn("DebugSystemControls not available for AI pause", "debug")

func _update_pause_ai_button_text() -> void:
	if pause_ai_button:
		if pause_ai_button.button_pressed:
			pause_ai_button.text = "AI Paused"
		else:
			pause_ai_button.text = "Pause AI"


# Performance stats are now always visible, no toggle needed

func _on_clear_all_pressed() -> void:
	Logger.info("Clear all enemies triggered", "debug")
	
	# Remove focus from button for better UX
	clear_all_btn.release_focus()
	
	# Prefer DebugManager central clear (works even without DebugSystemControls)
	if DebugManager and DebugManager.has_method("clear_all_entities"):
		DebugManager.clear_all_entities()
		return
	# Fallback to DebugSystemControls if present
	if debug_system_controls:
		debug_system_controls.clear_all_entities()
	else:
		Logger.warn("DebugSystemControls not available for clear all", "debug")

func _on_reset_session_pressed() -> void:
	Logger.info("Reset session triggered", "debug")
	
	# Remove focus from button for better UX
	reset_session_btn.release_focus()
	
	# Lazy-fetch DebugSystemControls if not available
	if not debug_system_controls:
		_reacquire_debug_system_controls()
	
	if debug_system_controls:
		debug_system_controls.reset_session()
	else:
		Logger.warn("DebugSystemControls not available for reset session", "debug")


func _create_background_panel() -> void:
	# Apply proper Godot theme-based styling
	call_deferred("_apply_proper_styling")

func _apply_proper_styling() -> void:
	# Apply styling to PanelContainer (visual container)
	var panel_container = get_node("PanelContainer")
	if panel_container:
		var panel_style := StyleBoxFlat.new()
		panel_style.bg_color = Color(0.1, 0.1, 0.1, 0.92)  # Modern dark background with transparency
		panel_style.border_width_left = 1
		panel_style.border_width_top = 1
		panel_style.border_width_right = 1
		panel_style.border_width_bottom = 1
		panel_style.border_color = Color(0.4, 0.6, 1.0, 0.8)  # Modern blue accent border
		panel_style.corner_radius_top_left = 12
		panel_style.corner_radius_top_right = 12
		panel_style.corner_radius_bottom_left = 12
		panel_style.corner_radius_bottom_right = 12
		# Add subtle shadow/glow effect
		panel_style.shadow_color = Color(0.0, 0.0, 0.0, 0.3)
		panel_style.shadow_size = 4
		panel_style.shadow_offset = Vector2(2, 2)
		
		panel_container.add_theme_stylebox_override("panel", panel_style)
		
	# Apply margin to MarginContainer (proper padding) - more generous for modern look
	var margin_container = get_node("PanelContainer/MarginContainer")
	if margin_container:
		margin_container.add_theme_constant_override("margin_left", 16)
		margin_container.add_theme_constant_override("margin_right", 16)
		margin_container.add_theme_constant_override("margin_top", 16)
		margin_container.add_theme_constant_override("margin_bottom", 16)
		
	# Apply separation to VBoxContainer (spacing between elements) - more breathing room
	var vbox_container = get_node("PanelContainer/MarginContainer/VBoxContainer")
	if vbox_container:
		vbox_container.add_theme_constant_override("separation", 8)
	
	# Apply modern button styling for better visibility
	_apply_button_styling()
		
	Logger.debug("Applied proper Godot theme-based styling", "debug")

func _apply_button_styling() -> void:
	"""Apply modern button styling that blends well with dark panel theme"""
	var button_style := StyleBoxFlat.new()
	button_style.bg_color = Color(0.15, 0.15, 0.15, 0.8)  # Dark background matching panel theme
	button_style.border_width_left = 1
	button_style.border_width_top = 1
	button_style.border_width_right = 1
	button_style.border_width_bottom = 1
	button_style.border_color = Color(0.3, 0.4, 0.6, 0.4)  # Subtle muted border
	button_style.corner_radius_top_left = 6
	button_style.corner_radius_top_right = 6
	button_style.corner_radius_bottom_left = 6
	button_style.corner_radius_bottom_right = 6
	# Add better padding for text breathing room
	button_style.content_margin_left = 8
	button_style.content_margin_right = 8
	button_style.content_margin_top = 6
	button_style.content_margin_bottom = 6
	
	# Hover style for better interactivity - subtle but noticeable
	var button_hover_style := StyleBoxFlat.new()
	button_hover_style.bg_color = Color(0.2, 0.25, 0.35, 0.9)  # Slightly lighter dark background
	button_hover_style.border_width_left = 1
	button_hover_style.border_width_top = 1
	button_hover_style.border_width_right = 1
	button_hover_style.border_width_bottom = 1
	button_hover_style.border_color = Color(0.4, 0.5, 0.7, 0.6)  # More visible border on hover
	button_hover_style.corner_radius_top_left = 6
	button_hover_style.corner_radius_top_right = 6
	button_hover_style.corner_radius_bottom_left = 6
	button_hover_style.corner_radius_bottom_right = 6
	# Same padding for consistency
	button_hover_style.content_margin_left = 8
	button_hover_style.content_margin_right = 8
	button_hover_style.content_margin_top = 6
	button_hover_style.content_margin_bottom = 6
	
	# Apply to all buttons in the debug panel
	var all_buttons = [
		spawn_at_cursor_btn, spawn_at_player_btn,
		count1_btn, count5_btn, count10_btn,
		kill_btn, heal_btn, damage_btn,
		clear_all_btn, reset_session_btn,
		pause_ai_button
	]
	
	for button in all_buttons:
		if button:
			button.add_theme_stylebox_override("normal", button_style)
			button.add_theme_stylebox_override("hover", button_hover_style)
			# Light gray text for better integration with dark theme
			button.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85, 1.0))
			button.add_theme_color_override("font_hover_color", Color.WHITE)
	
	# Special styling for toggle button (Pause AI) - active state
	if pause_ai_button:
		var active_button_style := StyleBoxFlat.new()
		active_button_style.bg_color = Color(0.6, 0.3, 0.3, 0.8)  # Red-ish background when active
		active_button_style.border_width_left = 1
		active_button_style.border_width_top = 1
		active_button_style.border_width_right = 1
		active_button_style.border_width_bottom = 1
		active_button_style.border_color = Color(0.8, 0.4, 0.4, 0.8)  # Brighter red border
		active_button_style.corner_radius_top_left = 6
		active_button_style.corner_radius_top_right = 6
		active_button_style.corner_radius_bottom_left = 6
		active_button_style.corner_radius_bottom_right = 6
		active_button_style.content_margin_left = 8
		active_button_style.content_margin_right = 8
		active_button_style.content_margin_top = 6
		active_button_style.content_margin_bottom = 6
		
		pause_ai_button.add_theme_stylebox_override("pressed", active_button_style)
		# Update text based on state
		_update_pause_ai_button_text()
	
	# Special styling for toggle buttons (Spawn method and Count) - green active state
	var green_active_style := StyleBoxFlat.new()
	green_active_style.bg_color = Color(0.3, 0.6, 0.3, 0.8)  # Green background when active
	green_active_style.border_width_left = 1
	green_active_style.border_width_top = 1
	green_active_style.border_width_right = 1
	green_active_style.border_width_bottom = 1
	green_active_style.border_color = Color(0.4, 0.8, 0.4, 0.8)  # Brighter green border
	green_active_style.corner_radius_top_left = 6
	green_active_style.corner_radius_top_right = 6
	green_active_style.corner_radius_bottom_left = 6
	green_active_style.corner_radius_bottom_right = 6
	green_active_style.content_margin_left = 8
	green_active_style.content_margin_right = 8
	green_active_style.content_margin_top = 6
	green_active_style.content_margin_bottom = 6
	
	# Apply green active state to spawn method and count toggle buttons
	var toggle_buttons = [
		spawn_at_cursor_btn, spawn_at_player_btn,
		count1_btn, count5_btn, count10_btn
	]
	
	for button in toggle_buttons:
		if button:
			button.add_theme_stylebox_override("pressed", green_active_style)
	

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
	
	# Always try to get reference to DebugSystemControls via DebugManager
	_reacquire_debug_system_controls()
	
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

func _set_performance_stats_visible(_is_visible: bool) -> void:
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
	
	# Get enemy count from multiple sources - highly optimized to prevent memory leaks
	
	# Only count enemies every 5 seconds instead of every second to reduce memory churn
	if stats_update_count % 5 == 0:  # Much less frequent counting - every 5 seconds
		# Count from WaveDirector (mesh enemies) - efficient method
		cached_enemy_count = 0
		
		# Try to get DebugSystemControls from DebugManager if not available
		if not debug_system_controls:
			_reacquire_debug_system_controls()
		
		# Try multiple paths to get WaveDirector for mesh enemy counting
		var wave_dir: WaveDirector = null
		if debug_system_controls and debug_system_controls.wave_director:
			wave_dir = debug_system_controls.wave_director
		elif DebugManager and DebugManager.wave_director:
			wave_dir = DebugManager.wave_director
		else:
			# Fallback: direct autoload access
			wave_dir = get_node_or_null("/root/WaveDirector")
		
		if wave_dir and wave_dir.has_method("get_alive_enemies"):
			var alive_enemies = wave_dir.get_alive_enemies()
			cached_enemy_count = alive_enemies.size()
		
		# Count bosses from EntityTracker instead of expensive scene tree traversal
		cached_boss_count = _count_bosses_from_entity_tracker()
	
	# Increment update counter
	stats_update_count += 1
	
	var total_enemies = cached_enemy_count + cached_boss_count
	
	# Build new stats string using cached values and minimal string operations
	# Build new stats using modern 2-column table format (like entity inspector)
	var new_stats_text := "[table=2]"
	new_stats_text += "[cell][color=#4A90E2]FPS[/color][/cell][cell]%d[/cell]" % fps
	new_stats_text += "[cell][color=#4A90E2]Total Enemies[/color][/cell][cell]%d[/cell]" % total_enemies
	new_stats_text += "[cell][color=#4A90E2]Mesh Enemies[/color][/cell][cell]%d[/cell]" % cached_enemy_count
	new_stats_text += "[cell][color=#4A90E2]Bosses[/color][/cell][cell]%d[/cell]" % cached_boss_count
	new_stats_text += "[cell][color=#4A90E2]Projectiles[/color][/cell][cell]0[/cell]"
	new_stats_text += "[cell][color=#4A90E2]Memory[/color][/cell][cell]%.1f MB[/cell]" % memory_mb
	new_stats_text += "[/table]"
	
	# Only update text if values actually changed to prevent memory leaks
	if new_stats_text != last_stats_text:
		performance_info.text = new_stats_text
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

# DEPRECATED: These recursive methods cause memory churn - kept for fallback only
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

# Efficient boss counting using EntityTracker instead of recursive scene tree traversal
func _count_bosses_from_entity_tracker() -> int:
	if not EntityTracker:
		return 0
	
	# Use EntityTracker's efficient type-based lookup
	var boss_entities = EntityTracker.get_entities_by_type("boss")
	return boss_entities.size()
