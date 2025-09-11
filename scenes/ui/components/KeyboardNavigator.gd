extends Node
class_name KeyboardNavigator
## Advanced keyboard navigation system for desktop UI
##
## Provides comprehensive keyboard navigation, focus management, and
## accessibility features optimized for desktop gaming interfaces.

@export_group("Navigation Settings")
@export var auto_focus_first: bool = true     # Auto-focus first control on enable
@export var wrap_navigation: bool = true     # Wrap around when reaching end
@export var highlight_focused: bool = true   # Visual highlight for focused controls
@export var play_navigation_sounds: bool = false # Audio feedback for navigation

@export_group("Key Bindings")
@export var tab_forward: String = "ui_focus_next"      # Tab forward action
@export var tab_backward: String = "ui_focus_prev"     # Tab backward action
@export var activate: String = "ui_accept"             # Activate focused control
@export var cancel: String = "ui_cancel"               # Cancel/escape action

@export_group("Visual Settings")
@export var focus_outline_color: Color = Color.CYAN
@export var focus_outline_width: float = 2.0
@export var focus_animation_speed: float = 0.2

# Navigation state
var navigable_controls: Array[Control] = []
var current_focus_index: int = -1
var is_navigation_active: bool = false
var focus_container: Control

# Focus highlighting
var focus_highlight: Control
var focus_tween: Tween

# Keyboard shortcuts registry
var shortcuts: Dictionary = {}

# Navigation history for complex UIs
var focus_history: Array[Control] = []
var max_history_size: int = 10

signal navigation_activated(control: Control)
signal navigation_deactivated()
signal focus_changed(old_control: Control, new_control: Control)
signal shortcut_triggered(shortcut: String, control: Control)

func _ready() -> void:
	# Setup focus highlighting if enabled
	if highlight_focused:
		setup_focus_highlighting()
	
	# Auto-discover navigable controls if container is set
	if focus_container:
		discover_navigable_controls()
	
	Logger.debug("KeyboardNavigator initialized", "ui")

func _input(event: InputEvent) -> void:
	"""Handle keyboard navigation input."""
	if not is_navigation_active:
		return
	
	if event is InputEventKey and event.pressed:
		var handled = false
		
		# Handle navigation keys
		if event.is_action(tab_forward):
			navigate_next()
			handled = true
		elif event.is_action(tab_backward):
			navigate_previous()
			handled = true
		elif event.is_action(activate):
			activate_focused_control()
			handled = true
		elif event.is_action(cancel):
			handle_cancel()
			handled = true
		else:
			# Check for registered shortcuts
			handled = handle_shortcuts(event)
		
		if handled:
			get_viewport().set_input_as_handled()

# ============================================================================
# NAVIGATION CONTROL
# ============================================================================

func activate_navigation(container: Control = null) -> void:
	"""Activate keyboard navigation for a container."""
	focus_container = container if container else focus_container
	
	if not focus_container:
		Logger.warn("No focus container set for KeyboardNavigator", "ui")
		return
	
	is_navigation_active = true
	discover_navigable_controls()
	
	if auto_focus_first and not navigable_controls.is_empty():
		set_focus_index(0)
	
	navigation_activated.emit(get_focused_control())
	Logger.debug("Keyboard navigation activated with %d controls" % navigable_controls.size(), "ui")

func deactivate_navigation() -> void:
	"""Deactivate keyboard navigation."""
	is_navigation_active = false
	clear_focus_highlight()
	
	if get_focused_control():
		get_focused_control().release_focus()
	
	current_focus_index = -1
	navigation_deactivated.emit()
	Logger.debug("Keyboard navigation deactivated", "ui")

func discover_navigable_controls() -> void:
	"""Discover all navigable controls in the focus container."""
	navigable_controls.clear()
	
	if not focus_container:
		return
	
	_find_navigable_controls_recursive(focus_container)
	
	# Sort by position for logical navigation order
	navigable_controls.sort_custom(_compare_controls_by_position)
	
	Logger.debug("Discovered %d navigable controls" % navigable_controls.size(), "ui")

func _find_navigable_controls_recursive(node: Node) -> void:
	"""Recursively find all navigable controls."""
	if node is Control:
		var control = node as Control
		if _is_control_navigable(control):
			navigable_controls.append(control)
	
	for child in node.get_children():
		_find_navigable_controls_recursive(child)

func _is_control_navigable(control: Control) -> bool:
	"""Check if a control can be navigated to."""
	return (
		control.visible and
		control.focus_mode != Control.FOCUS_NONE and
		not control.is_disabled() if control.has_method("is_disabled") else true
	)

func _compare_controls_by_position(a: Control, b: Control) -> bool:
	"""Compare controls by position for navigation order."""
	var pos_a = a.global_position
	var pos_b = b.global_position
	
	# Sort by Y position first, then X position
	if abs(pos_a.y - pos_b.y) > 20:  # Row threshold
		return pos_a.y < pos_b.y
	else:
		return pos_a.x < pos_b.x

# ============================================================================
# FOCUS MANAGEMENT
# ============================================================================

func navigate_next() -> void:
	"""Navigate to the next control."""
	if navigable_controls.is_empty():
		return
	
	var old_control = get_focused_control()
	var new_index = current_focus_index + 1
	
	if new_index >= navigable_controls.size():
		new_index = wrap_navigation ? 0 : navigable_controls.size() - 1
	
	set_focus_index(new_index)
	_emit_focus_changed(old_control, get_focused_control())

func navigate_previous() -> void:
	"""Navigate to the previous control."""
	if navigable_controls.is_empty():
		return
	
	var old_control = get_focused_control()
	var new_index = current_focus_index - 1
	
	if new_index < 0:
		new_index = wrap_navigation ? navigable_controls.size() - 1 : 0
	
	set_focus_index(new_index)
	_emit_focus_changed(old_control, get_focused_control())

func set_focus_index(index: int) -> void:
	"""Set focus to control at specific index."""
	if index < 0 or index >= navigable_controls.size():
		return
	
	current_focus_index = index
	var control = navigable_controls[index]
	
	# Focus the control
	control.grab_focus()
	
	# Update visual highlight
	if highlight_focused:
		update_focus_highlight(control)
	
	# Add to history
	add_to_focus_history(control)
	
	Logger.debug("Focus set to control: %s (index: %d)" % [control.name, index], "ui")

func focus_control(control: Control) -> bool:
	"""Focus a specific control if it's navigable."""
	var index = navigable_controls.find(control)
	if index >= 0:
		var old_control = get_focused_control()
		set_focus_index(index)
		_emit_focus_changed(old_control, control)
		return true
	return false

func get_focused_control() -> Control:
	"""Get the currently focused control."""
	if current_focus_index >= 0 and current_focus_index < navigable_controls.size():
		return navigable_controls[current_focus_index]
	return null

func _emit_focus_changed(old_control: Control, new_control: Control) -> void:
	"""Emit focus changed signal."""
	if old_control != new_control:
		focus_changed.emit(old_control, new_control)

# ============================================================================
# FOCUS HIGHLIGHTING
# ============================================================================

func setup_focus_highlighting() -> void:
	"""Setup visual focus highlighting."""
	focus_highlight = Control.new()
	focus_highlight.mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_highlight.z_index = 100  # Appear above other controls
	
	# Create focus outline using a custom draw function
	focus_highlight.draw.connect(_draw_focus_outline)
	
	if focus_container:
		focus_container.add_child(focus_highlight)
	
	focus_highlight.visible = false

func update_focus_highlight(control: Control) -> void:
	"""Update focus highlight position and size."""
	if not focus_highlight or not control:
		return
	
	var control_rect = control.get_global_rect()
	var container_pos = focus_container.global_position if focus_container else Vector2.ZERO
	
	# Position relative to container
	focus_highlight.position = control_rect.position - container_pos - Vector2.ONE * focus_outline_width
	focus_highlight.size = control_rect.size + Vector2.ONE * focus_outline_width * 2
	
	# Animate appearance
	if focus_tween:
		focus_tween.kill()
	
	focus_highlight.visible = true
	focus_highlight.modulate.a = 0.0
	
	focus_tween = create_tween()
	focus_tween.tween_property(focus_highlight, "modulate:a", 1.0, focus_animation_speed)
	
	# Queue redraw for custom outline
	focus_highlight.queue_redraw()

func clear_focus_highlight() -> void:
	"""Clear the focus highlight."""
	if focus_highlight:
		focus_highlight.visible = false

func _draw_focus_outline() -> void:
	"""Custom draw function for focus outline."""
	if not focus_highlight.visible:
		return
	
	var rect = Rect2(Vector2.ZERO, focus_highlight.size)
	
	# Draw outline
	focus_highlight.draw_rect(rect, focus_outline_color, false, focus_outline_width)
	
	# Optional: Draw corners for better visibility
	var corner_size = 8.0
	var corners = [
		rect.position,  # Top-left
		Vector2(rect.position.x + rect.size.x, rect.position.y),  # Top-right
		Vector2(rect.position.x, rect.position.y + rect.size.y),  # Bottom-left
		rect.position + rect.size  # Bottom-right
	]
	
	for corner in corners:
		focus_highlight.draw_circle(corner, corner_size, focus_outline_color)

# ============================================================================
# CONTROL ACTIVATION
# ============================================================================

func activate_focused_control() -> void:
	"""Activate the currently focused control."""
	var control = get_focused_control()
	if not control:
		return
	
	# Try different activation methods based on control type
	if control is Button:
		(control as Button).pressed.emit()
		if play_navigation_sounds:
			play_activation_sound()
	elif control is LineEdit:
		# Enter edit mode or submit if already editing
		if not control.has_focus():
			control.grab_focus()
		else:
			# Simulate enter key
			control.text_submitted.emit(control.text)
	elif control.has_signal("pressed"):
		control.pressed.emit()
	
	Logger.debug("Activated control: %s" % control.name, "ui")

func handle_cancel() -> void:
	"""Handle cancel/escape key press."""
	var control = get_focused_control()
	
	# Try to find a cancel button or close action
	var cancel_button = find_cancel_button()
	if cancel_button:
		focus_control(cancel_button)
		activate_focused_control()
	else:
		# Default cancel behavior - could emit signal for container to handle
		Logger.debug("Cancel action triggered", "ui")

func find_cancel_button() -> Control:
	"""Find a button that acts as a cancel/close button."""
	for control in navigable_controls:
		if control is Button:
			var button = control as Button
			var text = button.text.to_lower()
			if "cancel" in text or "close" in text or "back" in text:
				return button
	return null

# ============================================================================
# KEYBOARD SHORTCUTS
# ============================================================================

func register_shortcut(key_code: int, control: Control, description: String = "") -> void:
	"""Register a keyboard shortcut for a control."""
	shortcuts[key_code] = {
		"control": control,
		"description": description
	}
	
	Logger.debug("Registered shortcut: %s -> %s" % [key_code, control.name], "ui")

func unregister_shortcut(key_code: int) -> void:
	"""Unregister a keyboard shortcut."""
	if key_code in shortcuts:
		shortcuts.erase(key_code)

func handle_shortcuts(event: InputEventKey) -> bool:
	"""Handle registered keyboard shortcuts."""
	var key_code = event.keycode
	
	if key_code in shortcuts:
		var shortcut_data = shortcuts[key_code]
		var control = shortcut_data.control
		
		if control and _is_control_navigable(control):
			focus_control(control)
			activate_focused_control()
			shortcut_triggered.emit(str(key_code), control)
			return true
	
	return false

func get_shortcuts_for_display() -> Array[Dictionary]:
	"""Get shortcuts formatted for display in help/tooltip."""
	var display_shortcuts: Array[Dictionary] = []
	
	for key_code in shortcuts:
		var data = shortcuts[key_code]
		display_shortcuts.append({
			"key": OS.get_keycode_string(key_code),
			"description": data.get("description", ""),
			"control": data.control.name
		})
	
	return display_shortcuts

# ============================================================================
# FOCUS HISTORY
# ============================================================================

func add_to_focus_history(control: Control) -> void:
	"""Add control to focus history."""
	if control in focus_history:
		focus_history.erase(control)
	
	focus_history.push_front(control)
	
	# Limit history size
	while focus_history.size() > max_history_size:
		focus_history.pop_back()

func focus_previous_in_history() -> bool:
	"""Focus the previously focused control."""
	if focus_history.size() > 1:
		var previous_control = focus_history[1]  # [0] is current
		return focus_control(previous_control)
	return false

# ============================================================================
# ACCESSIBILITY FEATURES
# ============================================================================

func get_navigation_info() -> Dictionary:
	"""Get navigation information for accessibility."""
	return {
		"active": is_navigation_active,
		"total_controls": navigable_controls.size(),
		"current_index": current_focus_index,
		"current_control": get_focused_control().name if get_focused_control() else "none",
		"shortcuts_count": shortcuts.size(),
		"wrap_enabled": wrap_navigation
	}

func announce_focus_change(control: Control) -> void:
	"""Announce focus change for accessibility (future screen reader support)."""
	if control:
		var announcement = "Focused: %s" % control.name
		if control.has_method("get_text"):
			announcement += " - %s" % control.get_text()
		
		Logger.debug("Accessibility: %s" % announcement, "ui")

# ============================================================================
# AUDIO FEEDBACK
# ============================================================================

func play_navigation_sound() -> void:
	"""Play navigation sound effect."""
	if play_navigation_sounds:
		# This would integrate with an audio system
		Logger.debug("Navigation sound played", "ui")

func play_activation_sound() -> void:
	"""Play activation sound effect."""
	if play_navigation_sounds:
		# This would integrate with an audio system
		Logger.debug("Activation sound played", "ui")

# ============================================================================
# UTILITY METHODS
# ============================================================================

func refresh_navigation() -> void:
	"""Refresh the list of navigable controls."""
	var old_control = get_focused_control()
	discover_navigable_controls()
	
	# Try to maintain focus on the same control
	if old_control:
		focus_control(old_control)

func set_container(container: Control) -> void:
	"""Set the focus container and refresh navigation."""
	focus_container = container
	
	if highlight_focused and focus_highlight:
		if focus_highlight.get_parent():
			focus_highlight.get_parent().remove_child(focus_highlight)
		container.add_child(focus_highlight)
	
	if is_navigation_active:
		discover_navigable_controls()

# ============================================================================
# CLEANUP
# ============================================================================

func _exit_tree() -> void:
	"""Clean up when navigator is removed."""
	if focus_tween:
		focus_tween.kill()
	
	if focus_highlight and focus_highlight.get_parent():
		focus_highlight.queue_free()
	
	Logger.debug("KeyboardNavigator cleaned up", "ui")