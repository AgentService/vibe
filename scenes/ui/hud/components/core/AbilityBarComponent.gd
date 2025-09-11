class_name AbilityBarComponent
extends BaseHUDComponent

## Ability bar component showing player abilities with cooldowns and hotkeys
## Uses scene-defined ability buttons for easy editor customization

@export var max_abilities: int = 4
@export var show_hotkeys: bool = true
@export var show_cooldown_text: bool = true

# Scene node references
@onready var ability_container: HBoxContainer = $AbilityContainer
@onready var ability_nodes: Array[Control] = []
var ability_buttons: Array[Button] = []
var cooldown_overlays: Array[ColorRect] = []
var cooldown_labels: Array[Label] = []
var hotkey_labels: Array[Label] = []

# State tracking
var _abilities: Array = []
var _cooldowns: Dictionary = {}

func _init() -> void:
	super._init()
	component_id = "ability_bar"
	update_frequency = 30.0  # Frequent updates for smooth cooldown animations

func _setup_component() -> void:
	_setup_existing_ability_nodes()
	_load_default_abilities()
	_connect_ability_signals()

func _update_component(delta: float) -> void:
	_update_cooldowns(delta)

func _setup_existing_ability_nodes() -> void:
	# Find all ability nodes in the container
	if ability_container:
		for i in range(ability_container.get_child_count()):
			var ability_node = ability_container.get_child(i) as Control
			if ability_node:
				ability_nodes.append(ability_node)
				
				# Get child components
				var button = ability_node.get_node_or_null("AbilityButton") as Button
				var overlay = ability_node.get_node_or_null("CooldownOverlay") as ColorRect
				var cooldown_label = ability_node.get_node_or_null("CooldownLabel") as Label
				var hotkey_label = ability_node.get_node_or_null("HotkeyLabel") as Label
				
				if button:
					ability_buttons.append(button)
					# Connect button signal
					button.pressed.connect(_on_ability_button_pressed.bind(i))
				
				if overlay:
					cooldown_overlays.append(overlay)
					overlay.visible = false  # Hidden by default
				
				if cooldown_label:
					cooldown_labels.append(cooldown_label)
					cooldown_label.visible = false  # Hidden by default
				
				if hotkey_label:
					hotkey_labels.append(hotkey_label)
					hotkey_label.visible = show_hotkeys

func _load_default_abilities() -> void:
	# Default abilities matching the scene structure
	var default_abilities = [
		{
			"id": "primary_attack",
			"name": "Primary Attack",
			"hotkey": "LMB",
			"cooldown": 0.0
		},
		{
			"id": "secondary_attack", 
			"name": "Secondary Attack",
			"hotkey": "RMB",
			"cooldown": 2.0
		},
		{
			"id": "dash",
			"name": "Dash",
			"hotkey": "SPACE",
			"cooldown": 3.0
		},
		{
			"id": "special_ability",
			"name": "Special",
			"hotkey": "Q",
			"cooldown": 8.0
		}
	]
	
	_abilities = default_abilities
	
	# Initialize ability data for existing buttons
	for i in range(min(_abilities.size(), ability_buttons.size())):
		var ability_data = _abilities[i]
		
		# Set hotkey text
		if i < hotkey_labels.size() and hotkey_labels[i]:
			hotkey_labels[i].text = ability_data.get("hotkey", "")

func _connect_ability_signals() -> void:
	# Connect to ability-related EventBus signals
	if EventBus:
		# These signals would be implemented in the ability system
		if EventBus.has_signal("ability_used"):
			connect_to_signal(EventBus.ability_used, _on_ability_used)
		if EventBus.has_signal("ability_cooldown_updated"):
			connect_to_signal(EventBus.ability_cooldown_updated, _on_ability_cooldown_updated)

func _update_cooldowns(delta: float) -> void:
	# Update cooldown timers and visuals
	for ability_id in _cooldowns:
		var cooldown_data = _cooldowns[ability_id]
		if cooldown_data.current > 0:
			cooldown_data.current -= delta
			cooldown_data.current = max(0, cooldown_data.current)
			
			# Find and update corresponding button
			for i in range(_abilities.size()):
				if _abilities[i].get("id") == ability_id:
					_update_ability_cooldown_visual(i, cooldown_data.current, cooldown_data.total)
					break

func _update_ability_cooldown_visual(ability_index: int, current_time: float, total_time: float) -> void:
	if ability_index >= ability_nodes.size():
		return
	
	var is_on_cooldown = current_time > 0
	
	# Update cooldown overlay
	if ability_index < cooldown_overlays.size() and cooldown_overlays[ability_index]:
		var overlay = cooldown_overlays[ability_index]
		overlay.visible = is_on_cooldown
		
		if is_on_cooldown and total_time > 0:
			# Update overlay height based on cooldown progress
			var progress = 1.0 - (current_time / total_time)
			var full_height = ability_nodes[ability_index].size.y
			var overlay_height = full_height * progress
			overlay.size.y = overlay_height
			overlay.position.y = full_height - overlay_height
	
	# Update cooldown text
	if ability_index < cooldown_labels.size() and cooldown_labels[ability_index]:
		var label = cooldown_labels[ability_index]
		label.visible = is_on_cooldown and show_cooldown_text
		if is_on_cooldown:
			label.text = str(ceil(current_time))

func start_ability_cooldown(ability_id: String, cooldown_time: float) -> void:
	_cooldowns[ability_id] = {
		"current": cooldown_time,
		"total": cooldown_time
	}

func get_ability_cooldown_remaining(ability_id: String) -> float:
	var cooldown_data = _cooldowns.get(ability_id, {})
	return cooldown_data.get("current", 0.0)

func is_ability_on_cooldown(ability_id: String) -> bool:
	return get_ability_cooldown_remaining(ability_id) > 0

# Signal handlers
func _on_ability_used(ability_id: String, cooldown_time: float) -> void:
	start_ability_cooldown(ability_id, cooldown_time)
	Logger.debug("Ability used: %s, cooldown: %.1fs" % [ability_id, cooldown_time], "ui")

func _on_ability_cooldown_updated(ability_id: String, remaining_time: float) -> void:
	if _cooldowns.has(ability_id):
		_cooldowns[ability_id].current = remaining_time

func _on_ability_button_pressed(ability_index: int) -> void:
	if ability_index < _abilities.size():
		var ability_data = _abilities[ability_index]
		var ability_id = ability_data.get("id", "")
		
		# Check if ability is available
		if not is_ability_on_cooldown(ability_id):
			# Emit signal for ability system to handle
			if EventBus and EventBus.has_signal("ability_triggered"):
				EventBus.ability_triggered.emit(ability_id)
			Logger.debug("Ability triggered: " + ability_id, "ui")
			
			# Start cooldown for demo purposes
			var cooldown_time = ability_data.get("cooldown", 0.0)
			if cooldown_time > 0:
				start_ability_cooldown(ability_id, cooldown_time)
		else:
			Logger.debug("Ability on cooldown: " + ability_id, "ui")

func get_ability_stats() -> Dictionary:
	var stats = {
		"total_abilities": _abilities.size(),
		"active_cooldowns": 0,
		"abilities": []
	}
	
	for ability in _abilities:
		var ability_id = ability.get("id", "")
		var cooldown_remaining = get_ability_cooldown_remaining(ability_id)
		stats.abilities.append({
			"id": ability_id,
			"name": ability.get("name", ""),
			"cooldown_remaining": cooldown_remaining,
			"on_cooldown": cooldown_remaining > 0
		})
		
		if cooldown_remaining > 0:
			stats.active_cooldowns += 1
	
	return stats
