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

var selected_count: int = 1
var available_enemy_types: Array[String] = []

func _ready() -> void:
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
	
	Logger.debug("DebugPanel initialized", "debug")

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
		entity_info.text = "[b]Entity Inspector[/b]\n\n[color=yellow]Ctrl+Click[/color] on an entity to inspect"
		_set_entity_buttons_enabled(false)
		return
	
	# Format entity information for display
	var info_text := "[b]Selected: %s[/b]\n" % entity_data.get("id", "Unknown")
	info_text += "Type: %s\n" % entity_data.get("type", "unknown")
	info_text += "Health: %d/%d\n" % [entity_data.get("hp", 0), entity_data.get("max_hp", 100)]
	info_text += "Position: %s\n" % entity_data.get("pos", Vector2.ZERO)
	info_text += "Alive: %s\n" % ("Yes" if entity_data.get("alive", false) else "No")
	
	entity_info.text = info_text
	_set_entity_buttons_enabled(entity_data.get("alive", false))

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