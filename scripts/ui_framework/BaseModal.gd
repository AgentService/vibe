extends Control
class_name BaseModal
## Base class for all modal overlays in the unified overlay system
##
## Provides standardized modal behavior, event handling, and lifecycle management
## optimized for desktop gaming with mouse/keyboard interaction patterns.

# Modal configuration
@export var modal_type: UIManager.ModalType
@export var dims_background: bool = true
@export var pauses_game: bool = false
@export var closeable_with_escape: bool = true
@export var keyboard_navigable: bool = true
@export var has_tooltips: bool = true
@export var default_focus_control: Control

# Modal size and positioning
@export var modal_size: Vector2 = Vector2(600, 500)  # Default modal size
@export var auto_center: bool = true  # Automatically center the modal

# Modal lifecycle signals
signal modal_opened()
signal modal_closed()
signal tooltip_requested(text: String, position: Vector2)

# Internal state
var modal_data: Dictionary = {}
var is_modal_open: bool = false
var initialization_complete: bool = false
var modal_owns_pause: bool = false  # Track if this modal controls pause state

func _ready() -> void:
	setup_modal_base()
	Logger.debug("BaseModal ready: %s" % name, "ui")

func _process(_delta: float) -> void:
	# Re-assert pause state if modal should be paused but game was unpaused externally
	if is_modal_open and pauses_game and modal_owns_pause and not get_tree().paused:
		Logger.warn("Modal re-asserting pause state - external system unpaused game while modal active", "ui")
		get_tree().paused = true

func setup_modal_base() -> void:
	# Ensure modal fills the screen for proper input blocking
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	
	# CRITICAL: Allow modal to process when game is paused
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	
	# Setup automatic centering if enabled
	if auto_center:
		call_deferred("center_modal_content")
	
	# Setup keyboard handling
	if keyboard_navigable:
		setup_keyboard_navigation()
	
	# Connect escape key handling
	if closeable_with_escape:
		setup_escape_handling()
	
	# Ensure all child controls can process when paused
	call_deferred("_setup_pause_mode_for_children")

func setup_keyboard_navigation() -> void:
	# Enable focus handling for keyboard navigation
	focus_mode = Control.FOCUS_ALL
	
	# Set default focus if specified
	if default_focus_control and default_focus_control.focus_mode != Control.FOCUS_NONE:
		call_deferred("set_default_focus")

func set_default_focus() -> void:
	if default_focus_control and is_inside_tree():
		default_focus_control.grab_focus()

func setup_escape_handling() -> void:
	# Will be connected to input handling in UIManager
	pass

func initialize(data: Dictionary = {}) -> void:
	"""Initialize modal with provided data - override in subclasses"""
	modal_data = data
	
	# Perform subclass-specific initialization
	_initialize_modal_content(data)
	
	initialization_complete = true
	Logger.debug("Modal initialized: %s with data keys: %s" % [name, data.keys()], "ui")

func _initialize_modal_content(data: Dictionary) -> void:
	"""Override in subclasses to handle specific initialization"""
	pass

func open_modal(context: Dictionary = {}) -> void:
	"""Called by UIManager when modal is being opened"""
	if is_modal_open:
		Logger.warn("Modal already open: %s" % name, "ui")
		return
	
	is_modal_open = true
	
	# Ensure modal is visible
	visible = true
	modulate.a = 1.0  # Ensure not transparent
	
	# Perform open actions first
	_on_modal_opened(context)
	modal_opened.emit()
	
	# Handle pause behavior AFTER modal is set up - defer to next frame
	if pauses_game and PauseManager:
		call_deferred("_pause_for_modal")
	
	# Debug visibility
	Logger.info("Modal visibility: %s, modulate: %s, global_pos: %s" % [visible, modulate, global_position], "ui")

func _pause_for_modal() -> void:
	"""Pause the game after modal is fully displayed"""
	if is_modal_open and pauses_game:
		get_tree().paused = true
		modal_owns_pause = true
		Logger.info("Modal paused game: %s" % name, "ui")
	elif is_modal_open:
		Logger.info("Modal opened without pause: %s" % name, "ui")

func close_modal() -> void:
	"""Request modal closure - will be handled by UIManager"""
	if not is_modal_open:
		return
	
	# Perform pre-close validation
	if not _can_close_modal():
		Logger.debug("Modal close prevented by validation: %s" % name, "ui")
		return
	
	is_modal_open = false
	
	# Handle unpause behavior - only unpause if modal owns the pause state
	if pauses_game and modal_owns_pause:
		get_tree().paused = false
		modal_owns_pause = false
		Logger.debug("Modal unpaused game silently", "ui")
	
	# Perform close actions
	_on_modal_closing()
	modal_closed.emit()
	
	Logger.info("Modal closed: %s" % name, "ui")

func _on_modal_opened(context: Dictionary) -> void:
	"""Override in subclasses for open behavior"""
	pass

func _on_modal_closing() -> void:
	"""Override in subclasses for close behavior"""
	pass

func _can_close_modal() -> bool:
	"""Override in subclasses to prevent closure under certain conditions"""
	return true

func _input(event: InputEvent) -> void:
	if not is_modal_open or not is_visible_in_tree():
		return
	
	# Handle tab navigation only (ESC is handled by UIManager)
	if keyboard_navigable and event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_TAB:
				var direction = -1 if event.shift_pressed else 1
				if on_tab_navigation(direction):
					get_viewport().set_input_as_handled()

func on_escape_pressed() -> bool:
	"""Handle escape key press - override for custom behavior"""
	return true  # Default: allow close

func on_tab_navigation(direction: int) -> bool:
	"""Handle tab navigation - override for custom behavior"""
	# Default implementation: find next/previous focusable control
	var focusable_controls = get_focusable_controls()
	if focusable_controls.is_empty():
		return false
	
	var current_focus = get_viewport().gui_get_focus_owner()
	var current_index = focusable_controls.find(current_focus)
	
	if current_index == -1:
		# No current focus, focus first control
		focusable_controls[0].grab_focus()
		return true
	
	# Calculate next index
	var next_index = (current_index + direction) % focusable_controls.size()
	if next_index < 0:
		next_index = focusable_controls.size() - 1
	
	focusable_controls[next_index].grab_focus()
	return true

func get_focusable_controls() -> Array[Control]:
	"""Get all focusable controls in this modal"""
	var focusable: Array[Control] = []
	_find_focusable_controls(self, focusable)
	return focusable

func _find_focusable_controls(node: Node, focusable: Array[Control]) -> void:
	"""Recursively find focusable controls"""
	if node is Control:
		var control = node as Control
		if control.focus_mode != Control.FOCUS_NONE and control.visible:
			focusable.append(control)
	
	for child in node.get_children():
		_find_focusable_controls(child, focusable)

func setup_keyboard_shortcuts() -> void:
	"""Override in subclasses to setup modal-specific shortcuts"""
	pass

func center_modal_content() -> void:
	"""Automatically center the first child control that looks like modal content"""
	if get_child_count() == 0:
		return
	
	# Look for a child control that should be centered (Panel, VBoxContainer, etc.)
	var content_control: Control = null
	
	# Find the main content control - typically a Panel or VBoxContainer
	for child in get_children():
		if child is Control and child.visible:
			# Skip background elements (usually ColorRect with dark colors)
			if child is ColorRect:
				var color_rect = child as ColorRect
				if color_rect.color.a > 0.5:  # Likely a background dimmer
					continue
			
			content_control = child as Control
			break
	
	if not content_control:
		Logger.debug("BaseModal: No content control found to center", "ui")
		return
	
	# Set size and center the content control
	content_control.custom_minimum_size = modal_size
	content_control.size = modal_size
	content_control.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	
	Logger.debug("BaseModal: Centered content control '%s' with size %s" % [content_control.name, modal_size], "ui")

# Tooltip support methods
func request_tooltip(text: String, position: Vector2 = Vector2.ZERO) -> void:
	"""Request tooltip display at position"""
	if has_tooltips:
		var tooltip_position = position if position != Vector2.ZERO else get_global_mouse_position()
		tooltip_requested.emit(text, tooltip_position)

func hide_tooltip() -> void:
	"""Hide any active tooltip"""
	if has_tooltips:
		tooltip_requested.emit("", Vector2.ZERO)

# Utility methods for modal content
func get_modal_data(key: String, default_value: Variant = null) -> Variant:
	"""Get data passed to modal during initialization"""
	return modal_data.get(key, default_value)

func set_modal_data(key: String, value: Variant) -> void:
	"""Set modal data - useful for state tracking"""
	modal_data[key] = value

func apply_modal_theme(theme_resource: Theme = null) -> void:
	"""Apply theme to modal - will be enhanced with theme system"""
	if theme_resource:
		theme = theme_resource
	
	# Apply default modal styling
	_apply_default_modal_styling()

func _apply_default_modal_styling() -> void:
	"""Apply basic modal styling - will be enhanced with theme system"""
	# For now, just ensure proper layering and background
	if not has_theme_color_override("panel"):
		add_theme_color_override("panel", Color(0.2, 0.2, 0.2, 0.95))

func _setup_pause_mode_for_children() -> void:
	"""Recursively set all child controls to process when paused"""
	_set_pause_mode_recursive(self)
	Logger.info("Modal pause mode configured for all children: %s" % name, "ui")

func _set_pause_mode_recursive(node: Node) -> void:
	"""Recursively set pause mode for node and all children"""
	if node is Control or node is Button:
		node.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	
	for child in node.get_children():
		_set_pause_mode_recursive(child)

# Debug and validation methods
func validate_modal_setup() -> bool:
	"""Validate modal configuration - useful for debugging"""
	var issues: Array[String] = []
	
	if not modal_type:
		issues.append("modal_type not set")
	
	if keyboard_navigable and get_focusable_controls().is_empty():
		issues.append("keyboard_navigable enabled but no focusable controls found")
	
	if default_focus_control and default_focus_control.focus_mode == Control.FOCUS_NONE:
		issues.append("default_focus_control has FOCUS_NONE")
	
	if not issues.is_empty():
		Logger.warn("Modal setup issues for %s: %s" % [name, ", ".join(issues)], "ui")
		return false
	
	return true

func get_modal_info() -> Dictionary:
	"""Get modal information for debugging"""
	return {
		"name": name,
		"modal_type": UIManager.ModalType.keys()[modal_type] if modal_type else "UNSET",
		"is_open": is_modal_open,
		"dims_background": dims_background,
		"pauses_game": pauses_game,
		"closeable_with_escape": closeable_with_escape,
		"keyboard_navigable": keyboard_navigable,
		"has_tooltips": has_tooltips,
		"focusable_controls_count": get_focusable_controls().size(),
		"modal_data_keys": modal_data.keys()
	}