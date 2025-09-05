extends Control

## Debug Panel UI Controller
## Handles user interactions with the debug interface
## Communicates with DebugManager for actual debug operations

@onready var enemy_type_dropdown: OptionButton = $MainContainer/SpawnerSection/EnemyTypeDropdown
@onready var spawn_at_cursor_btn: Button = $MainContainer/SpawnerSection/SpawnButtons/SpawnAtCursor
@onready var spawn_at_player_btn: Button = $MainContainer/SpawnerSection/SpawnButtons/SpawnAtPlayer
@onready var count1_btn: Button = $MainContainer/SpawnerSection/CountButtons/Count1
@onready var count5_btn: Button = $MainContainer/SpawnerSection/CountButtons/Count5
@onready var count10_btn: Button = $MainContainer/SpawnerSection/CountButtons/Count10
@onready var count100_btn: Button = $MainContainer/SpawnerSection/CountButtons/Count100
@onready var entity_info: RichTextLabel = $MainContainer/InspectorSection/EntityInfo
@onready var kill_btn: Button = $MainContainer/InspectorSection/EntityActions/KillButton
@onready var heal_btn: Button = $MainContainer/InspectorSection/EntityActions/HealButton
@onready var damage_btn: Button = $MainContainer/InspectorSection/EntityActions/DamageButton
@onready var abilities_label: Label = $MainContainer/InspectorSection/AbilitySection/AbilitiesLabel
@onready var ability_buttons_container: VBoxContainer = $MainContainer/InspectorSection/AbilitySection/AbilityButtons

var selected_count: int = 1
var available_enemy_types: Array[String] = []
var background_panel: PanelContainer
var ability_buttons: Array[Button] = []
var current_entity_abilities: Array[String] = []

func _ready() -> void:
	# Create and setup background panel
	_create_background_panel()
	
	# Connect button signals
	spawn_at_cursor_btn.pressed.connect(_on_spawn_at_cursor_pressed)
	spawn_at_player_btn.pressed.connect(_on_spawn_at_player_pressed)
	
	count1_btn.pressed.connect(_on_count_selected.bind(1))
	count5_btn.pressed.connect(_on_count_selected.bind(5))
	count10_btn.pressed.connect(_on_count_selected.bind(10))
	count100_btn.pressed.connect(_on_count_selected.bind(100))
	
	kill_btn.pressed.connect(_on_kill_pressed)
	heal_btn.pressed.connect(_on_heal_pressed)
	damage_btn.pressed.connect(_on_damage_pressed)
	
	# Connect to DebugManager signals
	if DebugManager:
		DebugManager.entity_inspected.connect(_on_entity_inspected)
	
	# Load enemy types into dropdown
	_populate_enemy_dropdown()
	
	# Set initial count selection
	_on_count_selected(1)
	
	# Set initial entity inspector text
	entity_info.text = "[b]Entity Inspector[/b]\n\n[color=#FFD700]Ctrl+Click[/color] on an entity to inspect"
	_set_entity_buttons_enabled(false)
	
	# Hide abilities section initially
	abilities_label.visible = false
	ability_buttons_container.visible = false
	
	# Update button text to show shortcuts
	spawn_at_cursor_btn.text = "Spawn at Cursor (B)"
	
	Logger.debug("DebugPanel initialized", "debug")
	
	# Start timer to update ability cooldowns periodically
	var cooldown_timer := Timer.new()
	cooldown_timer.wait_time = 0.1  # Update every 100ms for smooth countdown
	cooldown_timer.timeout.connect(_update_ability_cooldowns)
	cooldown_timer.autostart = true
	add_child(cooldown_timer)

func _input(event: InputEvent) -> void:
	# Only handle input if debug panel is visible and debug mode is active
	if not visible or not DebugManager or not DebugManager.is_debug_mode_active():
		return
		
	if event is InputEventKey and event.pressed:
		var key_event := event as InputEventKey
		
		# B key: Spawn at cursor (same as clicking "Spawn at Cursor" button)
		if key_event.keycode == KEY_B:
			_on_spawn_at_cursor_pressed()
			get_viewport().set_input_as_handled()

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
	count100_btn.button_pressed = (count == 100)
	
	Logger.debug("Selected spawn count: %d" % count, "debug")

func _get_selected_enemy_type() -> String:
	var selected_index := enemy_type_dropdown.selected
	if selected_index < 0 or selected_index >= available_enemy_types.size():
		return ""
	return available_enemy_types[selected_index]

func _on_entity_inspected(entity_data: Dictionary) -> void:
	if entity_data.is_empty():
		entity_info.text = "[b]Entity Inspector[/b]\n\n[color=#FFD700]Ctrl+Click[/color] on an entity to inspect"
		_set_entity_buttons_enabled(false)
		_clear_ability_buttons()
		return
	
	# Format entity information for display
	var info_text := "[b]Selected: %s[/b]\n" % entity_data.get("id", "Unknown")
	info_text += "Type: %s\n" % entity_data.get("type", "unknown")
	info_text += "Health: %d/%d\n" % [entity_data.get("hp", 0), entity_data.get("max_hp", 100)]
	info_text += "Position: %s\n" % entity_data.get("pos", Vector2.ZERO)
	info_text += "Alive: %s\n" % ("Yes" if entity_data.get("alive", false) else "No")
	
	entity_info.text = info_text
	_set_entity_buttons_enabled(entity_data.get("alive", false))
	
	# Update ability buttons for the selected entity
	_update_ability_buttons(entity_data.get("id", ""))

func _set_entity_buttons_enabled(enabled: bool) -> void:
	kill_btn.disabled = not enabled
	heal_btn.disabled = not enabled
	damage_btn.disabled = not enabled

func _on_kill_pressed() -> void:
	var selected_entity := DebugManager.get_selected_entity()
	if selected_entity.is_empty():
		Logger.warn("No entity selected for kill", "debug")
		return
	
	if DebugManager:
		DebugManager.kill_entity(selected_entity)

func _on_heal_pressed() -> void:
	var selected_entity := DebugManager.get_selected_entity()
	if selected_entity.is_empty():
		Logger.warn("No entity selected for heal", "debug")
		return
	
	if DebugManager:
		DebugManager.heal_entity(selected_entity)

func _on_damage_pressed() -> void:
	var selected_entity := DebugManager.get_selected_entity()
	if selected_entity.is_empty():
		Logger.warn("No entity selected for damage", "debug")
		return
	
	if DebugManager:
		DebugManager.damage_entity(selected_entity, 10)

# Ability button management functions
func _update_ability_buttons(entity_id: String) -> void:
	# Clear existing ability buttons
	_clear_ability_buttons()
	
	if entity_id.is_empty():
		return
	
	# Get available abilities for this entity
	var abilities := DebugManager.get_entity_abilities(entity_id)
	current_entity_abilities = abilities
	
	if abilities.is_empty():
		# Hide abilities section if no abilities
		abilities_label.visible = false
		ability_buttons_container.visible = false
		return
	
	# Show abilities section
	abilities_label.visible = true
	ability_buttons_container.visible = true
	
	# Create button for each ability
	for ability_name in abilities:
		var button := Button.new()
		button.text = ability_name.capitalize()
		button.pressed.connect(_on_ability_button_pressed.bind(entity_id, ability_name))
		
		# Set initial cooldown state
		_update_ability_button_state(button, entity_id, ability_name)
		
		ability_buttons_container.add_child(button)
		ability_buttons.append(button)
	
	Logger.debug("Created %d ability buttons for entity %s" % [abilities.size(), entity_id], "debug")

func _clear_ability_buttons() -> void:
	# Remove all existing ability buttons
	for button in ability_buttons:
		if button and is_instance_valid(button):
			button.queue_free()
	
	ability_buttons.clear()
	current_entity_abilities.clear()
	
	# Hide abilities section
	abilities_label.visible = false
	ability_buttons_container.visible = false

func _on_ability_button_pressed(entity_id: String, ability_name: String) -> void:
	Logger.info("Ability button pressed: %s on entity %s" % [ability_name, entity_id], "debug")
	
	# Trigger the ability via DebugManager
	var success := DebugManager.trigger_entity_ability(entity_id, ability_name)
	
	if success:
		Logger.info("Successfully triggered ability '%s' on entity '%s'" % [ability_name, entity_id], "debug")
		# Update button states after triggering ability
		_update_all_ability_buttons(entity_id)
	else:
		Logger.warn("Failed to trigger ability '%s' on entity '%s'" % [ability_name, entity_id], "debug")

func _update_ability_button_state(button: Button, entity_id: String, ability_name: String) -> void:
	var cooldown_info := DebugManager.get_ability_cooldown(entity_id, ability_name)
	
	if cooldown_info.get("ready", true):
		# Ability is ready
		button.text = ability_name.capitalize() + " (Ready)"
		button.disabled = false
		button.modulate = Color.WHITE
	else:
		# Ability on cooldown
		var remaining: float = cooldown_info.get("cooldown_remaining", 0.0)
		button.text = ability_name.capitalize() + " (%.1fs)" % remaining
		button.disabled = true
		button.modulate = Color.GRAY

func _update_all_ability_buttons(entity_id: String) -> void:
	# Update all ability buttons for the current entity
	for i in range(ability_buttons.size()):
		if i < current_entity_abilities.size():
			var button := ability_buttons[i]
			var ability_name := current_entity_abilities[i]
			_update_ability_button_state(button, entity_id, ability_name)

func _update_ability_cooldowns() -> void:
	# Periodic update of ability cooldowns for the currently selected entity
	if not visible or not DebugManager or not DebugManager.is_debug_mode_active():
		return
	
	var selected_entity := DebugManager.get_selected_entity()
	if selected_entity.is_empty() or ability_buttons.is_empty():
		return
	
	_update_all_ability_buttons(selected_entity)

func _create_background_panel() -> void:
	# Create background PanelContainer
	background_panel = PanelContainer.new()
	background_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	# Create and apply custom StyleBoxFlat
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.95)  # Semi-transparent black
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.3, 0.3, 0.3, 1.0)  # Dark gray border
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	
	background_panel.add_theme_stylebox_override("panel", style)
	
	# Add background as child (behind other content)
	add_child(background_panel)
	move_child(background_panel, 0)  # Move to back
