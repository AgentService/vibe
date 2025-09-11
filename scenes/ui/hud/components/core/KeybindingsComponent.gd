extends Panel
class_name KeybindingsComponent

## Keybindings display component showing current control scheme
## Styled to match radar panel with consistent UI theme
## Note: Extends Panel directly for background styling, implements BaseHUDComponent interface

@onready var container: VBoxContainer = $VBoxContainer/VBoxContainer2
@onready var title_label: Label = $VBoxContainer/VBoxContainer2/TitleLabel

# BaseHUDComponent interface implementation
@export var component_id: String = ""
@export var update_frequency: float = 0.0
@export var enable_performance_monitoring: bool = false

signal component_ready(component_id: String)
signal component_destroyed(component_id: String)

# Static keybinding display - labels are defined in scene

func _ready() -> void:
	if component_id.is_empty():
		component_id = "keybindings_display"
	
	_setup_component()
	_register_with_hud_manager()
	component_ready.emit(component_id)

func _exit_tree() -> void:
	_unregister_from_hud_manager()
	component_destroyed.emit(component_id)

func _setup_component() -> void:
	_style_panel()
	# Defer label styling to ensure @onready variables are ready
	call_deferred("_style_labels")

func bind_events() -> void:
	# Keybindings are static, no EventBus signals needed
	# Could add input remapping signals in future
	pass

func _register_with_hud_manager() -> void:
	if HUDManager:
		call_deferred("_do_register")

func _do_register() -> void:
	if HUDManager:
		HUDManager.register_component(component_id, self)

func _unregister_from_hud_manager() -> void:
	if HUDManager:
		HUDManager.unregister_component(component_id)

func apply_anchor_config(config: Dictionary) -> void:
	# No programmatic positioning - respect editor settings
	pass

func set_component_visible(visible_state: bool) -> void:
	visible = visible_state

func set_component_scale(new_scale: Vector2) -> void:
	scale = new_scale

func _style_panel() -> void:
	# Apply MainTheme styling for keybindings panel
	if not ThemeManager or not ThemeManager.current_theme:
		Logger.warn("KeybindingsComponent: MainTheme not available", "ui")
		_apply_fallback_panel_styling()
		return
	
	var theme_res = ThemeManager.current_theme
	
	# Style the panel background using theme colors
	var style_box := StyleBoxFlat.new()
	style_box.bg_color = theme_res.background_overlay
	style_box.border_width_left = 2
	style_box.border_width_right = 2
	style_box.border_width_top = 2
	style_box.border_width_bottom = 2
	style_box.border_color = theme_res.border_color
	style_box.corner_radius_top_left = 4
	style_box.corner_radius_top_right = 4
	style_box.corner_radius_bottom_left = 4
	style_box.corner_radius_bottom_right = 4
	style_box.content_margin_left = 8
	style_box.content_margin_right = 8
	style_box.content_margin_top = 8
	style_box.content_margin_bottom = 8
	
	# Apply panel style
	add_theme_stylebox_override("panel", style_box)

func _apply_fallback_panel_styling() -> void:
	# Fallback styling if MainTheme unavailable
	var style_box := StyleBoxFlat.new()
	style_box.bg_color = Color(0.1, 0.1, 0.1, 0.9)
	style_box.border_width_left = 2
	style_box.border_width_right = 2
	style_box.border_width_top = 2
	style_box.border_width_bottom = 2
	style_box.border_color = Color(0.6, 0.5, 0.4, 1.0)
	style_box.corner_radius_top_left = 4
	style_box.corner_radius_top_right = 4
	style_box.corner_radius_bottom_left = 4
	style_box.corner_radius_bottom_right = 4
	style_box.content_margin_left = 8
	style_box.content_margin_right = 8
	style_box.content_margin_top = 8
	style_box.content_margin_bottom = 8
	
	add_theme_stylebox_override("panel", style_box)

func _style_labels() -> void:
	# Check if container is ready
	if not container:
		Logger.warn("KeybindingsComponent: Container not ready for styling", "ui")
		return
		
	# Style the title label
	if title_label:
		title_label.text = "CONTROLS"
		title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_style_title_label(title_label)
	
	# Style all other labels in the container
	for child in container.get_children():
		if child != title_label and child is Label:
			_style_keybinding_label(child as Label)

func _style_title_label(label: Label) -> void:
	# Apply MainTheme styling for title label
	if not ThemeManager or not ThemeManager.current_theme:
		_apply_fallback_title_styling(label)
		return
	
	var theme_res = ThemeManager.current_theme
	var theme = Theme.new()
	theme.set_color("font_color", "Label", theme_res.warning_color)  # Use warning color for title prominence
	theme.set_constant("shadow_offset_x", "Label", 1)
	theme.set_constant("shadow_offset_y", "Label", 1)
	theme.set_color("font_shadow_color", "Label", theme_res.background_dark)
	label.theme = theme

func _style_keybinding_label(label: Label) -> void:
	# Apply MainTheme styling for keybinding labels
	if not ThemeManager or not ThemeManager.current_theme:
		_apply_fallback_keybinding_styling(label)
		return
	
	var theme_res = ThemeManager.current_theme
	var theme = Theme.new()
	theme.set_color("font_color", "Label", theme_res.text_primary)
	theme.set_constant("shadow_offset_x", "Label", 1)
	theme.set_constant("shadow_offset_y", "Label", 1)
	theme.set_color("font_shadow_color", "Label", theme_res.background_dark)
	label.theme = theme

func _apply_fallback_title_styling(label: Label) -> void:
	# Fallback styling for title if MainTheme unavailable
	var theme = Theme.new()
	theme.set_color("font_color", "Label", Color.YELLOW)
	theme.set_constant("shadow_offset_x", "Label", 1)
	theme.set_constant("shadow_offset_y", "Label", 1)
	theme.set_color("font_shadow_color", "Label", Color.BLACK)
	label.theme = theme

func _apply_fallback_keybinding_styling(label: Label) -> void:
	# Fallback styling for keybinding labels if MainTheme unavailable
	var theme = Theme.new()
	theme.set_color("font_color", "Label", Color.WHITE)
	theme.set_constant("shadow_offset_x", "Label", 1)
	theme.set_constant("shadow_offset_y", "Label", 1)
	theme.set_color("font_shadow_color", "Label", Color.BLACK)
	label.theme = theme

# Public API
func refresh_keybindings() -> void:
	"""Refresh keybinding display - useful if input map changes"""
	_style_labels()
	Logger.debug("KeybindingsComponent: Refreshed keybinding display", "ui")

func set_keybindings_visible(visible: bool) -> void:
	self.visible = visible
	if visible:
		Logger.debug("KeybindingsComponent: Shown", "ui")
	else:
		Logger.debug("KeybindingsComponent: Hidden", "ui")

func get_keybinding_stats() -> Dictionary:
	return {
		"total_labels": container.get_child_count(),
		"visible": visible,
		"component_id": component_id
	}
