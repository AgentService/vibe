class_name AbilityBarComponent
extends BaseHUDComponent

## Ability bar component showing player abilities with cooldowns and hotkeys
## Uses scene-defined ability buttons for easy editor customization

@export var max_abilities: int = 5  # Updated to support all abilities including E key
@export var show_hotkeys: bool = true
@export var show_cooldown_text: bool = true

# Scene node references
@onready var ability_container: HBoxContainer = $AbilityContainer
@onready var ability_nodes: Array[Control] = []
var ability_buttons: Array[Button] = []
var cooldown_overlays: Array[ColorRect] = []
var cooldown_labels: Array[Label] = []
var hotkey_labels: Array[Label] = []
var swing_timer_progress: TextureProgressBar  # Only for LMB slot

# State tracking
var _abilities: Array = []  # All abilities now displayed with 5 slots
var _cooldowns: Dictionary = {}
var _swing_timer: Dictionary = {}  # Track swing timer for LMB

# AAA visual effects
var _button_tweens: Array[Tween] = []
var _glow_effects: Array[ColorRect] = []
var _theme: MainTheme
var _original_styles: Dictionary = {}  # Store original button styles

func _init() -> void:
	super._init()
	component_id = "ability_bar"
	update_frequency = 30.0  # Frequent updates for smooth cooldown animations

func _ready() -> void:
	super._ready()
	# Add to group so Player can find us for cooldown checking
	add_to_group("ability_bar")

func _setup_component() -> void:
	_setup_theme_system()
	_setup_existing_ability_nodes()
	_load_default_abilities()
	_connect_ability_signals()
	_setup_aaa_visual_effects()

func _update_component(delta: float) -> void:
	_update_cooldowns(delta)

func _setup_theme_system() -> void:
	"""Initialize MainTheme integration for AAA styling"""
	if ThemeManager and ThemeManager.current_theme:
		_theme = ThemeManager.current_theme
		Logger.debug("AbilityBar: MainTheme system initialized for AAA effects", "ui")
	else:
		Logger.warn("AbilityBar: MainTheme not available, using fallback styling", "ui")

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
					# Store original style for restoration
					_original_styles[i] = {
						"theme": button.theme
					}
					# Connect button signals
					button.pressed.connect(_on_ability_button_pressed.bind(i))
					button.mouse_entered.connect(_on_ability_button_hover_entered.bind(i))
					button.mouse_exited.connect(_on_ability_button_hover_exited.bind(i))
					button.button_down.connect(_on_ability_button_press_started.bind(i))
					button.button_up.connect(_on_ability_button_press_ended.bind(i))
				
				if overlay:
					cooldown_overlays.append(overlay)
					overlay.visible = false  # Hidden by default
				
				if cooldown_label:
					cooldown_labels.append(cooldown_label)
					cooldown_label.visible = false  # Hidden by default
				
				if hotkey_label:
					hotkey_labels.append(hotkey_label)
					hotkey_label.visible = show_hotkeys
				
				# Get swing timer progress bar for LMB (first slot only)
				if i == 0:  # First ability is LMB
					var swing_progress = ability_node.get_node_or_null("SwingTimer") as TextureProgressBar
					if swing_progress:
						swing_timer_progress = swing_progress
						swing_timer_progress.visible = false  # Hidden by default

func _load_default_abilities() -> void:
	# Updated abilities for animation-input foundation - LMB uses swing timer, others use cooldowns
	_abilities = [
		{
			"id": "primary_attack",
			"name": "Melee Attack",
			"hotkey": "LMB",
			"type": "swing_timer"  # Special type for swing timer instead of cooldown
		},
		{
			"id": "bow_attack", 
			"name": "Bow Shot",
			"hotkey": "RMB",
			"cooldown": 0.3,
			"type": "cooldown"
		},
		{
			"id": "dash",
			"name": "Dash",
			"hotkey": "SPACE",
			"cooldown": 1.0,
			"type": "cooldown"
		},
		{
			"id": "magic_cast",
			"name": "Magic Cast",
			"hotkey": "Q",
			"cooldown": 1.0,
			"type": "cooldown"
		},
		{
			"id": "spear_attack",
			"name": "Spear Attack", 
			"hotkey": "E",
			"cooldown": 0.5,
			"type": "cooldown"
		}
	]
	
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
		# Connect to melee swing timer signal
		if EventBus.has_signal("melee_swing_started"):
			connect_to_signal(EventBus.melee_swing_started, _on_melee_swing_started)

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
	
	# Update swing timer visuals
	for ability_id in _swing_timer:
		var swing_data = _swing_timer[ability_id]
		if swing_data.current > 0:
			swing_data.current -= delta
			swing_data.current = max(0, swing_data.current)
			
			# Find and update corresponding button with swing timer visual
			for i in range(_abilities.size()):
				if _abilities[i].get("id") == ability_id:
					_update_ability_swing_visual(i, swing_data.current, swing_data.total)
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

func _update_ability_swing_visual(ability_index: int, current_time: float, total_time: float) -> void:
	if ability_index >= ability_nodes.size():
		return
	
	var is_swinging = current_time > 0
	
	# For LMB (index 0), use the circular swing timer progress bar
	if ability_index == 0 and swing_timer_progress:
		swing_timer_progress.visible = is_swinging
		
		if is_swinging and total_time > 0:
			# Calculate progress from 0 to 1 (clockwise fill)
			var progress = 1.0 - (current_time / total_time)
			swing_timer_progress.value = progress
		else:
			swing_timer_progress.value = 0.0
	
	# Hide regular cooldown overlay for swing timer abilities
	if ability_index < cooldown_overlays.size() and cooldown_overlays[ability_index]:
		var overlay = cooldown_overlays[ability_index]
		overlay.visible = false
	
	# Hide cooldown text for swing timer (swing is visual only)
	if ability_index < cooldown_labels.size() and cooldown_labels[ability_index]:
		var label = cooldown_labels[ability_index]
		label.visible = false

# ============================================================================
# AAA VISUAL EFFECTS SYSTEM
# ============================================================================

func _setup_aaa_visual_effects() -> void:
	"""Setup advanced visual effects for professional button appearance"""
	if not _theme:
		return
	
	# Initialize tween array for animations
	_button_tweens.resize(ability_buttons.size())
	_glow_effects.resize(ability_buttons.size())
	
	# Setup enhanced button styling and glow effects
	for i in range(ability_buttons.size()):
		if i < ability_nodes.size():
			_setup_button_enhanced_styling(i)
			_setup_button_glow_effect(i)
	
	Logger.debug("AbilityBar: AAA visual effects initialized for %d buttons" % ability_buttons.size(), "ui")

func _setup_button_enhanced_styling(button_index: int) -> void:
	"""Apply enhanced MainTheme-based styling to button"""
	if button_index >= ability_buttons.size() or not _theme:
		return
	
	var button = ability_buttons[button_index]
	var enhanced_theme = Theme.new()
	
	# Create professional gradient styles
	var normal_style = _create_gradient_style_box("normal")
	var hover_style = _create_gradient_style_box("hover")
	var pressed_style = _create_gradient_style_box("pressed")
	
	# Apply to theme
	enhanced_theme.set_stylebox("normal", "Button", normal_style)
	enhanced_theme.set_stylebox("hover", "Button", hover_style)
	enhanced_theme.set_stylebox("pressed", "Button", pressed_style)
	
	# Apply enhanced theme to button
	button.theme = enhanced_theme

func _create_gradient_style_box(state: String) -> StyleBoxFlat:
	"""Create professional gradient StyleBox using MainTheme colors"""
	var style = StyleBoxFlat.new()
	
	match state:
		"normal":
			style.bg_color = Color(_theme.background_light.r + 0.05, _theme.background_light.g + 0.05, _theme.background_light.b + 0.05, 0.95)
			style.border_color = _theme.border_color
			style.shadow_color = Color(0, 0, 0, 0.4)
			style.shadow_size = 3
			style.shadow_offset = Vector2(0, 1)
		"hover":
			style.bg_color = Color(_theme.hover_color.r + 0.1, _theme.hover_color.g + 0.1, _theme.hover_color.b + 0.1, 1.0)
			style.border_color = Color(_theme.primary_color.r, _theme.primary_color.g, _theme.primary_color.b, 0.9)
			style.shadow_color = Color(_theme.primary_color.r * 0.5, _theme.primary_color.g * 0.5, _theme.primary_color.b * 0.8, 0.5)
			style.shadow_size = 4
			style.shadow_offset = Vector2(0, 2)
		"pressed":
			style.bg_color = _theme.pressed_color
			style.border_color = _theme.primary_light
			style.shadow_color = Color(0, 0, 0, 0.7)
			style.shadow_size = 2
			style.shadow_offset = Vector2(0, -1)
	
	# Common properties for all states
	style.set_border_width_all(_theme.border_width_medium)
	style.set_corner_radius_all(_theme.corner_radius_small)
	style.border_blend = true
	style.anti_aliasing = true
	
	return style

func _setup_button_glow_effect(button_index: int) -> void:
	"""Setup glow effect overlay for AAA visual feedback"""
	if button_index >= ability_nodes.size():
		return
	
	var ability_node = ability_nodes[button_index]
	
	# Create glow effect as ColorRect behind button
	var glow_rect = ColorRect.new()
	glow_rect.name = "GlowEffect"
	glow_rect.color = Color(_theme.primary_color.r, _theme.primary_color.g, _theme.primary_color.b, 0.0)
	glow_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# Position glow slightly larger than button
	var button_size = ability_node.size
	var glow_offset = 4
	glow_rect.size = button_size + Vector2(glow_offset * 2, glow_offset * 2)
	glow_rect.position = Vector2(-glow_offset, -glow_offset)
	
	# Add to ability node (behind button)
	ability_node.add_child(glow_rect)
	ability_node.move_child(glow_rect, 0)  # Move to back
	
	_glow_effects[button_index] = glow_rect

# ============================================================================
# INTERACTIVE VISUAL EFFECTS
# ============================================================================

func _on_ability_button_hover_entered(button_index: int) -> void:
	"""Handle mouse hover entry with smooth glow animation"""
	if button_index >= _glow_effects.size() or not _glow_effects[button_index] or not _theme:
		return
	
	# Kill existing tween
	if _button_tweens[button_index]:
		_button_tweens[button_index].kill()
	
	# Create hover glow animation
	_button_tweens[button_index] = create_tween()
	_button_tweens[button_index].set_ease(Tween.EASE_OUT)
	_button_tweens[button_index].set_trans(Tween.TRANS_QUART)
	
	var glow = _glow_effects[button_index]
	var target_color = Color(_theme.primary_color.r, _theme.primary_color.g, _theme.primary_color.b, 0.3)
	_button_tweens[button_index].tween_property(glow, "color", target_color, _theme.animation_fast)

func _on_ability_button_hover_exited(button_index: int) -> void:
	"""Handle mouse hover exit with smooth fade out"""
	if button_index >= _glow_effects.size() or not _glow_effects[button_index] or not _theme:
		return
	
	# Kill existing tween
	if _button_tweens[button_index]:
		_button_tweens[button_index].kill()
	
	# Create fade out animation
	_button_tweens[button_index] = create_tween()
	_button_tweens[button_index].set_ease(Tween.EASE_IN)
	_button_tweens[button_index].set_trans(Tween.TRANS_QUAD)
	
	var glow = _glow_effects[button_index]
	var target_color = Color(_theme.primary_color.r, _theme.primary_color.g, _theme.primary_color.b, 0.0)
	_button_tweens[button_index].tween_property(glow, "color", target_color, _theme.animation_normal)

func _on_ability_button_press_started(button_index: int) -> void:
	"""Handle button press with enhanced visual feedback"""
	if button_index >= ability_buttons.size() or not _theme:
		return
	
	# Immediate bright glow for press feedback
	if button_index < _glow_effects.size() and _glow_effects[button_index]:
		var glow = _glow_effects[button_index]
		var press_color = Color(_theme.primary_light.r, _theme.primary_light.g, _theme.primary_light.b, 0.5)
		glow.color = press_color
	
	# Scale animation for premium feel
	var button = ability_buttons[button_index]
	if _button_tweens[button_index]:
		_button_tweens[button_index].kill()
	
	_button_tweens[button_index] = create_tween()
	_button_tweens[button_index].set_ease(Tween.EASE_OUT)
	_button_tweens[button_index].set_trans(Tween.TRANS_BACK)
	_button_tweens[button_index].tween_property(button, "scale", Vector2(0.95, 0.95), 0.1)

func _on_ability_button_press_ended(button_index: int) -> void:
	"""Handle button release with smooth restoration"""
	if button_index >= ability_buttons.size() or not _theme:
		return
	
	# Restore button scale
	var button = ability_buttons[button_index]
	if _button_tweens[button_index]:
		_button_tweens[button_index].kill()
	
	_button_tweens[button_index] = create_tween()
	_button_tweens[button_index].set_ease(Tween.EASE_OUT)
	_button_tweens[button_index].set_trans(Tween.TRANS_ELASTIC)
	_button_tweens[button_index].tween_property(button, "scale", Vector2(1.0, 1.0), 0.3)
	
	# Fade glow back to hover state if still hovered
	if button_index < _glow_effects.size() and _glow_effects[button_index]:
		var glow = _glow_effects[button_index]
		if button.is_hovered():
			var hover_color = Color(_theme.primary_color.r, _theme.primary_color.g, _theme.primary_color.b, 0.3)
			_button_tweens[button_index].parallel().tween_property(glow, "color", hover_color, 0.2)
		else:
			var fade_color = Color(_theme.primary_color.r, _theme.primary_color.g, _theme.primary_color.b, 0.0)
			_button_tweens[button_index].parallel().tween_property(glow, "color", fade_color, 0.3)

func start_ability_cooldown(ability_id: String, cooldown_time: float) -> void:
	_cooldowns[ability_id] = {
		"current": cooldown_time,
		"total": cooldown_time
	}

func start_swing_timer(ability_id: String, swing_time: float) -> void:
	_swing_timer[ability_id] = {
		"current": swing_time,
		"total": swing_time
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

func _on_melee_swing_started(duration: float) -> void:
	start_swing_timer("primary_attack", duration)
	Logger.debug("AbilityBar: Started swing timer for primary_attack (%.1fs)" % duration, "ui")

func _on_ability_button_pressed(ability_index: int) -> void:
	if ability_index < _abilities.size():
		var ability_data = _abilities[ability_index]
		var ability_id = ability_data.get("id", "")
		var ability_type = ability_data.get("type", "cooldown")
		
		# Handle different ability types
		if ability_type == "swing_timer":
			# Swing timer abilities are always available (handled by player attack timer)
			if EventBus and EventBus.has_signal("ability_triggered"):
				EventBus.ability_triggered.emit(ability_id)
			Logger.debug("Swing ability triggered: " + ability_id, "ui")
		elif ability_type == "cooldown":
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
