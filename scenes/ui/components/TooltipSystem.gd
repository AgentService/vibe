extends Control
class_name TooltipSystem
## Advanced tooltip system optimized for desktop gaming
##
## Provides rich, multi-line tooltips with smart positioning, theme integration,
## and performance optimization. Designed for precise mouse interaction patterns
## common in desktop gaming.

# Tooltip configuration
@export_group("Tooltip Behavior")
@export var show_delay: float = 0.5         # Delay before showing tooltip
@export var hide_delay: float = 0.1         # Delay before hiding tooltip
@export var follow_mouse: bool = true       # Follow mouse position
@export var smart_positioning: bool = true  # Avoid screen edges
@export var max_width: int = 300            # Maximum tooltip width
@export var fade_animations: bool = true    # Enable fade in/out

# Tooltip UI elements
@onready var tooltip_panel: ThemedPanel = $TooltipPanel
@onready var content_margin: MarginContainer = $TooltipPanel/ContentMargin
@onready var tooltip_vbox: VBoxContainer = $TooltipPanel/ContentMargin/TooltipVBox
@onready var title_label: Label = $TooltipPanel/ContentMargin/TooltipVBox/TitleLabel
@onready var separator: HSeparator = $TooltipPanel/ContentMargin/TooltipVBox/Separator
@onready var body_label: RichTextLabel = $TooltipPanel/ContentMargin/TooltipVBox/BodyLabel
@onready var footer_label: Label = $TooltipPanel/ContentMargin/TooltipVBox/FooterLabel

# Internal state
var main_theme: MainTheme
var show_timer: Timer
var hide_timer: Timer
var current_target: Control
var is_visible: bool = false
var fade_tween: Tween

# Tooltip registry for automatic management
var registered_tooltips: Dictionary = {}

func _ready() -> void:
	# Initially hidden
	visible = false
	modulate.a = 0.0
	
	# Setup timers
	setup_timers()
	
	# Load theme
	load_theme_from_manager()
	
	# Register for theme changes
	if ThemeManager:
		ThemeManager.add_theme_listener(_on_theme_changed)
	
	# Ensure tooltip appears above everything
	z_index = 1000
	
	Logger.debug("TooltipSystem initialized", "ui")

func setup_timers() -> void:
	"""Setup show/hide delay timers."""
	show_timer = Timer.new()
	show_timer.wait_time = show_delay
	show_timer.one_shot = true
	show_timer.timeout.connect(_on_show_timer_timeout)
	add_child(show_timer)
	
	hide_timer = Timer.new()
	hide_timer.wait_time = hide_delay
	hide_timer.one_shot = true
	hide_timer.timeout.connect(_on_hide_timer_timeout)
	add_child(hide_timer)

func load_theme_from_manager() -> void:
	"""Load and apply theme from ThemeManager."""
	if ThemeManager:
		main_theme = ThemeManager.get_theme()
		apply_tooltip_theme()
	else:
		Logger.warn("ThemeManager not available for TooltipSystem", "ui")

func apply_tooltip_theme() -> void:
	"""Apply theme to tooltip elements."""
	if not main_theme:
		return
	
	# Apply tooltip panel theme
	if tooltip_panel:
		var style_box = main_theme.get_themed_style_box("tooltip")
		tooltip_panel.add_theme_stylebox_override("panel", style_box)
	
	# Apply text theming
	if title_label:
		main_theme.apply_label_theme(title_label, "header")
	
	if body_label:
		# Apply theme to rich text label
		body_label.add_theme_color_override("default_color", main_theme.text_primary)
		body_label.add_theme_font_size_override("normal_font_size", main_theme.font_size_tooltip)
	
	if footer_label:
		main_theme.apply_label_theme(footer_label, "caption")
	
	if separator:
		separator.add_theme_color_override("separator", main_theme.border_color)
	
	Logger.debug("Applied theme to TooltipSystem", "ui")

# ============================================================================
# TOOLTIP REGISTRATION
# ============================================================================

func register_tooltip(control: Control, tooltip_data: Dictionary) -> void:
	"""Register a control for automatic tooltip management."""
	if not control:
		return
	
	registered_tooltips[control] = tooltip_data
	
	# Connect mouse events
	if not control.mouse_entered.is_connected(_on_control_mouse_entered):
		control.mouse_entered.connect(_on_control_mouse_entered.bind(control))
	if not control.mouse_exited.is_connected(_on_control_mouse_exited):
		control.mouse_exited.connect(_on_control_mouse_exited.bind(control))
	
	Logger.debug("Registered tooltip for control: %s" % control.name, "ui")

func unregister_tooltip(control: Control) -> void:
	"""Unregister a control from tooltip management."""
	if control in registered_tooltips:
		registered_tooltips.erase(control)
		
		# Disconnect signals if connected
		if control.mouse_entered.is_connected(_on_control_mouse_entered):
			control.mouse_entered.disconnect(_on_control_mouse_entered)
		if control.mouse_exited.is_connected(_on_control_mouse_exited):
			control.mouse_exited.disconnect(_on_control_mouse_exited)
		
		# Hide tooltip if it's showing for this control
		if current_target == control:
			hide_tooltip()

# ============================================================================
# TOOLTIP DISPLAY
# ============================================================================

func show_tooltip(tooltip_data: Dictionary, target: Control = null) -> void:
	"""Show tooltip with provided data."""
	current_target = target
	
	# Cancel any pending hide
	hide_timer.stop()
	
	# Setup tooltip content
	setup_tooltip_content(tooltip_data)
	
	# Position tooltip
	if target:
		position_tooltip_near_target(target)
	else:
		position_tooltip_at_mouse()
	
	# Show with animation
	if fade_animations:
		animate_show()
	else:
		visible = true
		is_visible = true
		modulate.a = 1.0

func hide_tooltip() -> void:
	"""Hide the current tooltip."""
	current_target = null
	show_timer.stop()
	
	if is_visible:
		if fade_animations:
			animate_hide()
		else:
			visible = false
			is_visible = false

func setup_tooltip_content(data: Dictionary) -> void:
	"""Setup tooltip content from data dictionary."""
	# Title
	if data.has("title") and not data.title.is_empty():
		title_label.text = data.title
		title_label.visible = true
		separator.visible = true
	else:
		title_label.visible = false
		separator.visible = false
	
	# Body content (supports rich text)
	if data.has("body"):
		body_label.text = data.body
		body_label.visible = true
	else:
		body_label.visible = false
	
	# Footer (usually for shortcuts or additional info)
	if data.has("footer") and not data.footer.is_empty():
		footer_label.text = data.footer
		footer_label.visible = true
	else:
		footer_label.visible = false
	
	# Apply max width constraint
	custom_minimum_size.x = min(max_width, custom_minimum_size.x)

# ============================================================================
# POSITIONING
# ============================================================================

func position_tooltip_near_target(target: Control) -> void:
	"""Position tooltip near a target control with smart positioning."""
	if not target:
		return
	
	var target_rect = target.get_global_rect()
	var tooltip_size = get_tooltip_size()
	var viewport_size = get_viewport().get_visible_rect().size
	
	# Default position: below and to the right of target
	var pos = Vector2(
		target_rect.position.x,
		target_rect.position.y + target_rect.size.y + 8
	)
	
	if smart_positioning:
		# Adjust if tooltip would go off-screen
		if pos.x + tooltip_size.x > viewport_size.x:
			pos.x = target_rect.position.x + target_rect.size.x - tooltip_size.x
		
		if pos.y + tooltip_size.y > viewport_size.y:
			pos.y = target_rect.position.y - tooltip_size.y - 8
		
		# Ensure tooltip stays on screen
		pos.x = max(8, min(pos.x, viewport_size.x - tooltip_size.x - 8))
		pos.y = max(8, min(pos.y, viewport_size.y - tooltip_size.y - 8))
	
	global_position = pos

func position_tooltip_at_mouse() -> void:
	"""Position tooltip at mouse cursor with smart positioning."""
	var mouse_pos = get_global_mouse_position()
	var tooltip_size = get_tooltip_size()
	var viewport_size = get_viewport().get_visible_rect().size
	
	# Offset from cursor to avoid covering it
	var pos = mouse_pos + Vector2(15, -10)
	
	if smart_positioning:
		# Adjust if tooltip would go off-screen
		if pos.x + tooltip_size.x > viewport_size.x:
			pos.x = mouse_pos.x - tooltip_size.x - 15
		
		if pos.y + tooltip_size.y > viewport_size.y:
			pos.y = mouse_pos.y - tooltip_size.y - 15
		
		# Ensure tooltip stays on screen
		pos.x = max(8, min(pos.x, viewport_size.x - tooltip_size.x - 8))
		pos.y = max(8, min(pos.y, viewport_size.y - tooltip_size.y - 8))
	
	global_position = pos

func get_tooltip_size() -> Vector2:
	"""Get the size the tooltip will be when displayed."""
	# Force a layout update to get accurate size
	if not visible:
		visible = true
		call_deferred("_get_size_and_hide")
	
	return get_rect().size

func _get_size_and_hide() -> void:
	"""Helper to get size and hide tooltip."""
	visible = false

# ============================================================================
# MOUSE TRACKING
# ============================================================================

func _process(_delta: float) -> void:
	"""Update tooltip position if following mouse."""
	if is_visible and follow_mouse and not current_target:
		position_tooltip_at_mouse()

# ============================================================================
# EVENT HANDLERS
# ============================================================================

func _on_control_mouse_entered(control: Control) -> void:
	"""Handle mouse enter on registered control."""
	if control in registered_tooltips:
		var tooltip_data = registered_tooltips[control]
		show_timer.start()
		
		# Store which control we're showing for
		current_target = control

func _on_control_mouse_exited(control: Control) -> void:
	"""Handle mouse exit on registered control."""
	if current_target == control:
		show_timer.stop()
		if is_visible:
			hide_timer.start()

func _on_show_timer_timeout() -> void:
	"""Show tooltip after delay."""
	if current_target and current_target in registered_tooltips:
		var tooltip_data = registered_tooltips[current_target]
		show_tooltip(tooltip_data, current_target)

func _on_hide_timer_timeout() -> void:
	"""Hide tooltip after delay."""
	hide_tooltip()

# ============================================================================
# ANIMATIONS
# ============================================================================

func animate_show() -> void:
	"""Animate tooltip appearance."""
	if fade_tween:
		fade_tween.kill()
	
	visible = true
	is_visible = true
	modulate.a = 0.0
	
	fade_tween = create_tween()
	fade_tween.set_ease(Tween.EASE_OUT)
	fade_tween.tween_property(self, "modulate:a", 1.0, 0.2)

func animate_hide() -> void:
	"""Animate tooltip disappearance."""
	if fade_tween:
		fade_tween.kill()
	
	fade_tween = create_tween()
	fade_tween.set_ease(Tween.EASE_IN)
	fade_tween.tween_property(self, "modulate:a", 0.0, 0.15)
	fade_tween.tween_callback(func(): 
		visible = false
		is_visible = false
	)

# ============================================================================
# CONVENIENCE METHODS
# ============================================================================

func show_simple_tooltip(text: String, target: Control = null) -> void:
	"""Show a simple text tooltip."""
	var data = {"body": text}
	show_tooltip(data, target)

func show_item_tooltip(item_data: Dictionary, target: Control = null) -> void:
	"""Show a rich tooltip for an item."""
	var tooltip_data = {
		"title": item_data.get("name", "Unknown Item"),
		"body": _format_item_tooltip(item_data),
		"footer": item_data.get("shortcut_hint", "")
	}
	show_tooltip(tooltip_data, target)

func show_ability_tooltip(ability_data: Dictionary, target: Control = null) -> void:
	"""Show a rich tooltip for an ability."""
	var tooltip_data = {
		"title": ability_data.get("name", "Unknown Ability"),
		"body": _format_ability_tooltip(ability_data),
		"footer": ability_data.get("shortcut_hint", "")
	}
	show_tooltip(tooltip_data, target)

func _format_item_tooltip(item_data: Dictionary) -> String:
	"""Format item data into rich text tooltip."""
	var text = ""
	
	if item_data.has("description"):
		text += item_data.description + "\n\n"
	
	if item_data.has("stats") and item_data.stats is Dictionary:
		text += "[b]Stats:[/b]\n"
		for stat in item_data.stats:
			text += "• %s: %s\n" % [stat.capitalize(), item_data.stats[stat]]
	
	return text

func _format_ability_tooltip(ability_data: Dictionary) -> String:
	"""Format ability data into rich text tooltip."""
	var text = ""
	
	if ability_data.has("description"):
		text += ability_data.description + "\n\n"
	
	if ability_data.has("cooldown"):
		text += "[b]Cooldown:[/b] %s seconds\n" % ability_data.cooldown
	
	if ability_data.has("damage"):
		text += "[b]Damage:[/b] %s\n" % ability_data.damage
	
	return text

# ============================================================================
# THEME INTEGRATION
# ============================================================================

func _on_theme_changed(new_theme: MainTheme) -> void:
	"""Handle theme changes."""
	main_theme = new_theme
	apply_tooltip_theme()

# ============================================================================
# GLOBAL TOOLTIP MANAGER
# ============================================================================

# Static tooltip manager instance
static var _global_instance: TooltipSystem

static func get_global_tooltip() -> TooltipSystem:
	"""Get the global tooltip instance."""
	return _global_instance

static func set_global_tooltip(tooltip_system: TooltipSystem) -> void:
	"""Set the global tooltip instance."""
	_global_instance = tooltip_system

# Convenience static methods for global tooltip
static func show_global_tooltip(data: Dictionary, target: Control = null) -> void:
	"""Show tooltip using global instance."""
	if _global_instance:
		_global_instance.show_tooltip(data, target)

static func hide_global_tooltip() -> void:
	"""Hide tooltip using global instance."""
	if _global_instance:
		_global_instance.hide_tooltip()

static func register_global_tooltip(control: Control, data: Dictionary) -> void:
	"""Register tooltip using global instance."""
	if _global_instance:
		_global_instance.register_tooltip(control, data)

# ============================================================================
# CLEANUP
# ============================================================================

func _exit_tree() -> void:
	"""Clean up when tooltip system is removed."""
	if ThemeManager:
		ThemeManager.remove_theme_listener(_on_theme_changed)
	
	# Clean up tweens
	if fade_tween:
		fade_tween.kill()
	
	# Clear global reference if this was the global instance
	if _global_instance == self:
		_global_instance = null
	
	Logger.debug("TooltipSystem cleaned up", "ui")