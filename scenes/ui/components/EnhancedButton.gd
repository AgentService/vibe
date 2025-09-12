extends Button
class_name EnhancedButton
## Enhanced button component with theming, animations, and desktop interactions
##
## Provides consistent button behavior across the game with hover effects,
## press animations, keyboard shortcuts, and automatic theme integration.

@export_group("Enhanced Button Properties")
@export var button_variant: String = ""  # primary, secondary, success, warning, error
@export var auto_theme: bool = true      # Automatically apply theme on ready
@export var hover_animation: bool = true # Enable hover scale animation
@export var press_animation: bool = true # Enable press feedback animation
@export var keyboard_shortcut: String = "" # Optional keyboard shortcut (e.g., "enter", "space")

@export_group("Animation Settings")
@export var hover_scale: float = 1.05    # Scale factor on hover
@export var press_scale: float = 0.95    # Scale factor on press
@export var animation_speed: float = 0.1  # Animation duration

# Internal state
var main_theme: MainTheme
var original_scale: Vector2 = Vector2.ONE
var is_hovering: bool = false
var is_pressing: bool = false
var hover_tween: Tween
var press_tween: Tween

# Enhanced signals
signal enhanced_pressed()          # Emitted with button data
signal long_pressed()             # Emitted on long press (future)
signal right_clicked()            # Emitted on right-click

func _ready() -> void:
	# Store original scale
	original_scale = scale
	
	# Load theme if auto theming is enabled
	if auto_theme:
		load_theme_from_manager()
	
	# Connect to hover events
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	button_down.connect(_on_button_down)
	button_up.connect(_on_button_up)
	
	# Enhanced pressed signal
	pressed.connect(_on_enhanced_pressed)
	
	# Register for theme changes
	if ThemeManager:
		ThemeManager.add_theme_listener(_on_theme_changed)
	
	# Setup keyboard shortcuts
	if not keyboard_shortcut.is_empty():
		setup_keyboard_shortcut()
	
	Logger.debug("EnhancedButton initialized: %s (variant: %s)" % [text, button_variant], "ui")

func load_theme_from_manager() -> void:
	"""Load and apply theme from ThemeManager."""
	if ThemeManager:
		main_theme = ThemeManager.get_theme()
		apply_button_theme()
	else:
		Logger.warn("ThemeManager not available for EnhancedButton", "ui")

func apply_button_theme() -> void:
	"""Apply MainTheme to this button."""
	if main_theme:
		main_theme.apply_button_theme(self, button_variant)
		Logger.debug("Applied theme variant '%s' to button: %s" % [button_variant, text], "ui")

func setup_keyboard_shortcut() -> void:
	"""Setup keyboard shortcut handling."""
	# This would integrate with a global keyboard shortcut system
	# For now, just log the shortcut
	Logger.debug("Keyboard shortcut '%s' registered for button: %s" % [keyboard_shortcut, text], "ui")

# ============================================================================
# HOVER ANIMATIONS
# ============================================================================

func _on_mouse_entered() -> void:
	"""Handle mouse enter with hover animation."""
	is_hovering = true
	
	if hover_animation and not is_pressing:
		animate_hover(true)

func _on_mouse_exited() -> void:
	"""Handle mouse exit with hover animation."""
	is_hovering = false
	
	if hover_animation and not is_pressing:
		animate_hover(false)

func animate_hover(hover_in: bool) -> void:
	"""Animate hover effect."""
	if hover_tween:
		hover_tween.kill()
	
	hover_tween = create_tween()
	hover_tween.set_ease(Tween.EASE_OUT)
	hover_tween.set_trans(Tween.TRANS_QUART)
	
	var target_scale = original_scale * hover_scale if hover_in else original_scale
	hover_tween.tween_property(self, "scale", target_scale, animation_speed)

# ============================================================================
# PRESS ANIMATIONS  
# ============================================================================

func _on_button_down() -> void:
	"""Handle button press start."""
	is_pressing = true
	
	if press_animation:
		animate_press(true)

func _on_button_up() -> void:
	"""Handle button press end."""
	is_pressing = false
	
	if press_animation:
		animate_press(false)
	
	# Return to hover state if still hovering
	if is_hovering and hover_animation:
		call_deferred("animate_hover", true)

func animate_press(press_in: bool) -> void:
	"""Animate press effect."""
	if press_tween:
		press_tween.kill()
	
	press_tween = create_tween()
	press_tween.set_ease(Tween.EASE_OUT)
	press_tween.set_trans(Tween.TRANS_QUART)
	
	var target_scale = original_scale * press_scale if press_in else original_scale
	press_tween.tween_property(self, "scale", target_scale, animation_speed * 0.5)

# ============================================================================
# ENHANCED BUTTON BEHAVIOR
# ============================================================================

func _on_enhanced_pressed() -> void:
	"""Handle enhanced button press with additional data."""
	var button_data = {
		"text": text,
		"variant": button_variant,
		"enabled": not disabled,
		"shortcut": keyboard_shortcut,
		"timestamp": Time.get_ticks_msec()
	}
	
	enhanced_pressed.emit()
	Logger.debug("EnhancedButton pressed: %s" % text, "ui")

func _gui_input(event: InputEvent) -> void:
	"""Handle additional input events."""
	if event is InputEventMouseButton:
		var mouse_event = event as InputEventMouseButton
		
		# Right-click support
		if mouse_event.button_index == MOUSE_BUTTON_RIGHT and mouse_event.pressed:
			right_clicked.emit()
			Logger.debug("EnhancedButton right-clicked: %s" % text, "ui")

func _input(event: InputEvent) -> void:
	"""Handle keyboard shortcuts."""
	if not keyboard_shortcut.is_empty() and has_focus():
		if event.is_action_pressed(keyboard_shortcut):
			_pressed()
			get_viewport().set_input_as_handled()

# ============================================================================
# THEME INTEGRATION
# ============================================================================

func _on_theme_changed(new_theme: MainTheme) -> void:
	"""Handle theme changes."""
	main_theme = new_theme
	if auto_theme:
		apply_button_theme()

func set_button_variant(new_variant: String) -> void:
	"""Change button variant and reapply theme."""
	button_variant = new_variant
	if main_theme and auto_theme:
		apply_button_theme()

# ============================================================================
# PUBLIC API
# ============================================================================

func set_enabled(enabled: bool) -> void:
	"""Set button enabled state with visual feedback."""
	disabled = not enabled
	
	# Visual feedback for disabled state
	modulate.a = 1.0 if enabled else 0.6

func flash_error() -> void:
	"""Flash button red briefly to indicate error."""
	var original_modulate = modulate
	modulate = Color.RED
	
	var flash_tween = create_tween()
	flash_tween.tween_property(self, "modulate", original_modulate, 0.3)

func flash_success() -> void:
	"""Flash button green briefly to indicate success."""
	var original_modulate = modulate
	modulate = Color.GREEN
	
	var flash_tween = create_tween()
	flash_tween.tween_property(self, "modulate", original_modulate, 0.3)

func pulse() -> void:
	"""Pulse the button to draw attention."""
	var pulse_tween = create_tween()
	pulse_tween.set_loops(3)
	pulse_tween.tween_property(self, "scale", original_scale * 1.1, 0.5)
	pulse_tween.tween_property(self, "scale", original_scale, 0.5)

# ============================================================================
# ACCESSIBILITY
# ============================================================================

func set_tooltip_text_enhanced(tooltip: String) -> void:
	"""Set enhanced tooltip with keyboard shortcut info."""
	var enhanced_tooltip = tooltip
	if not keyboard_shortcut.is_empty():
		enhanced_tooltip += " (Shortcut: %s)" % keyboard_shortcut.capitalize()
	
	tooltip_text = enhanced_tooltip

func get_accessibility_info() -> Dictionary:
	"""Get accessibility information for screen readers."""
	return {
		"type": "button",
		"text": text,
		"variant": button_variant,
		"enabled": not disabled,
		"shortcut": keyboard_shortcut,
		"has_focus": has_focus()
	}

# ============================================================================
# FACTORY METHODS
# ============================================================================

static func create_primary_button(button_text: String = "") -> EnhancedButton:
	"""Create a primary button."""
	var button = EnhancedButton.new()
	button.text = button_text
	button.button_variant = "primary"
	return button

static func create_secondary_button(button_text: String = "") -> EnhancedButton:
	"""Create a secondary button."""
	var button = EnhancedButton.new()
	button.text = button_text
	button.button_variant = "secondary"
	return button

static func create_action_button(button_text: String = "", variant: String = "") -> EnhancedButton:
	"""Create an action button with specified variant."""
	var button = EnhancedButton.new()
	button.text = button_text
	button.button_variant = variant
	return button

# ============================================================================
# CLEANUP
# ============================================================================

func _exit_tree() -> void:
	"""Clean up when button is removed."""
	if ThemeManager:
		ThemeManager.remove_theme_listener(_on_theme_changed)
	
	# Clean up tweens
	if hover_tween:
		hover_tween.kill()
	if press_tween:
		press_tween.kill()
	
	Logger.debug("EnhancedButton cleaned up: %s" % text, "ui")