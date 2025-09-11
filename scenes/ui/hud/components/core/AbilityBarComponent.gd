class_name AbilityBarComponent
extends BaseHUDComponent

## Ability bar component showing player abilities with cooldowns and hotkeys
## Displays up to 6 abilities with visual cooldown indicators and key bindings

@export var max_abilities: int = 6
@export var ability_button_size: Vector2 = Vector2(48, 48)
@export var spacing: int = 8
@export var show_hotkeys: bool = true
@export var show_cooldown_text: bool = true

# UI Elements
var _ability_container: HBoxContainer
var _ability_buttons: Array = []

# State tracking
var _abilities: Array = []
var _cooldowns: Dictionary = {}

# Inner class for individual ability buttons
class AbilityButton extends Control:
	var button: Button
	var cooldown_overlay: ColorRect
	var cooldown_label: Label
	var hotkey_label: Label
	var ability_data: Dictionary = {}
	var cooldown_progress: float = 0.0
	var is_on_cooldown: bool = false
	
	func _init(ability_info: Dictionary, button_size: Vector2, show_hotkey: bool, show_cooldown: bool):
		ability_data = ability_info
		custom_minimum_size = button_size
		size = button_size
		
		_create_ability_button(button_size, show_hotkey, show_cooldown)
	
	func _create_ability_button(button_size: Vector2, show_hotkey: bool, show_cooldown: bool):
		# Main button
		button = Button.new()
		button.name = "AbilityButton"
		button.custom_minimum_size = button_size
		button.size = button_size
		button.flat = true
		button.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		add_child(button)
		
		# Apply ability icon if available
		var icon_path = ability_data.get("icon_path", "")
		if icon_path != "" and ResourceLoader.exists(icon_path):
			button.icon = load(icon_path)
		else:
			# Fallback: create simple colored background
			var style = StyleBoxFlat.new()
			style.bg_color = ability_data.get("color", Color.BLUE)
			style.corner_radius_top_left = 4
			style.corner_radius_top_right = 4
			style.corner_radius_bottom_left = 4
			style.corner_radius_bottom_right = 4
			button.add_theme_stylebox_override("normal", style)
		
		# Cooldown overlay
		cooldown_overlay = ColorRect.new()
		cooldown_overlay.name = "CooldownOverlay"
		cooldown_overlay.color = Color(0.0, 0.0, 0.0, 0.6)
		cooldown_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cooldown_overlay.visible = false
		cooldown_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		add_child(cooldown_overlay)
		
		# Cooldown text
		if show_cooldown:
			cooldown_label = Label.new()
			cooldown_label.name = "CooldownLabel"
			cooldown_label.text = "0"
			cooldown_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			cooldown_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			cooldown_label.add_theme_color_override("font_color", Color.WHITE)
			cooldown_label.add_theme_color_override("font_shadow_color", Color.BLACK)
			cooldown_label.add_theme_constant_override("shadow_offset_x", 1)
			cooldown_label.add_theme_constant_override("shadow_offset_y", 1)
			cooldown_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
			cooldown_label.visible = false
			cooldown_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			add_child(cooldown_label)
		
		# Hotkey label
		if show_hotkey:
			hotkey_label = Label.new()
			hotkey_label.name = "HotkeyLabel"
			hotkey_label.text = ability_data.get("hotkey", "")
			hotkey_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			hotkey_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
			hotkey_label.add_theme_color_override("font_color", Color.WHITE)
			hotkey_label.add_theme_color_override("font_shadow_color", Color.BLACK)
			hotkey_label.add_theme_constant_override("shadow_offset_x", 1)
			hotkey_label.add_theme_constant_override("shadow_offset_y", 1)
			hotkey_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
			hotkey_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			hotkey_label.offset_right = -4
			hotkey_label.offset_bottom = -4
			add_child(hotkey_label)
	
	func update_cooldown(current_time: float, total_time: float):
		if total_time <= 0:
			_clear_cooldown()
			return
		
		cooldown_progress = 1.0 - (current_time / total_time)
		is_on_cooldown = current_time > 0
		
		# Update visual indicators
		cooldown_overlay.visible = is_on_cooldown
		if cooldown_label:
			cooldown_label.visible = is_on_cooldown
			cooldown_label.text = str(ceil(current_time))
		
		# Update overlay height based on cooldown progress
		if is_on_cooldown:
			var overlay_height = size.y * cooldown_progress
			cooldown_overlay.size.y = overlay_height
			cooldown_overlay.position.y = size.y - overlay_height
	
	func _clear_cooldown():
		is_on_cooldown = false
		cooldown_progress = 0.0
		cooldown_overlay.visible = false
		if cooldown_label:
			cooldown_label.visible = false
	
	func set_ability_enabled(enabled: bool):
		button.disabled = not enabled
		modulate.a = 1.0 if enabled else 0.5

func _init() -> void:
	super._init()
	component_id = "ability_bar"
	update_frequency = 30.0  # Frequent updates for smooth cooldown animations

func _setup_component() -> void:
	_create_ability_bar_ui()
	_load_default_abilities()
	_connect_ability_signals()

func _update_component(delta: float) -> void:
	_update_cooldowns(delta)

func _create_ability_bar_ui() -> void:
	# Create horizontal container for abilities
	_ability_container = HBoxContainer.new()
	_ability_container.name = "AbilityContainer"
	_ability_container.add_theme_constant_override("separation", spacing)
	_ability_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_ability_container)

func _load_default_abilities() -> void:
	# Default abilities with placeholder data
	# In a real game, this would load from player data or ability system
	var default_abilities = [
		{
			"id": "primary_attack",
			"name": "Primary Attack",
			"hotkey": "LMB",
			"cooldown": 0.0,
			"color": Color.RED
		},
		{
			"id": "secondary_attack", 
			"name": "Secondary Attack",
			"hotkey": "RMB",
			"cooldown": 2.0,
			"color": Color.BLUE
		},
		{
			"id": "dash",
			"name": "Dash",
			"hotkey": "SPACE",
			"cooldown": 3.0,
			"color": Color.GREEN
		},
		{
			"id": "special_ability",
			"name": "Special",
			"hotkey": "Q",
			"cooldown": 8.0,
			"color": Color.PURPLE
		}
	]
	
	set_abilities(default_abilities)

func _connect_ability_signals() -> void:
	# Connect to ability-related EventBus signals
	if EventBus:
		# These signals would be implemented in the ability system
		if EventBus.has_signal("ability_used"):
			connect_to_signal(EventBus.ability_used, _on_ability_used)
		if EventBus.has_signal("ability_cooldown_updated"):
			connect_to_signal(EventBus.ability_cooldown_updated, _on_ability_cooldown_updated)

# Public API
func set_abilities(abilities: Array) -> void:
	_abilities = abilities
	_rebuild_ability_buttons()

func _rebuild_ability_buttons() -> void:
	# Clear existing buttons
	for button in _ability_buttons:
		if is_instance_valid(button):
			button.queue_free()
	_ability_buttons.clear()
	
	# Create new buttons
	for i in range(min(_abilities.size(), max_abilities)):
		var ability_data = _abilities[i]
		var ability_button = AbilityButton.new(ability_data, ability_button_size, show_hotkeys, show_cooldown_text)
		_ability_container.add_child(ability_button)
		_ability_buttons.append(ability_button)
		
		# Connect button signals
		if ability_button.button:
			ability_button.button.pressed.connect(_on_ability_button_pressed.bind(i))
	
	# Update component size based on content
	_update_component_size()

func _update_component_size() -> void:
	var total_width = (_ability_buttons.size() * ability_button_size.x) + (((_ability_buttons.size() - 1) * spacing))
	custom_minimum_size = Vector2(total_width, ability_button_size.y)

func _update_cooldowns(delta: float) -> void:
	# Update cooldown timers and visuals
	for ability_id in _cooldowns:
		var cooldown_data = _cooldowns[ability_id]
		if cooldown_data.current > 0:
			cooldown_data.current -= delta
			cooldown_data.current = max(0, cooldown_data.current)
			
			# Find and update corresponding button
			for i in range(_ability_buttons.size()):
				if _ability_buttons[i].ability_data.get("id") == ability_id:
					_ability_buttons[i].update_cooldown(cooldown_data.current, cooldown_data.total)
					break

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
