extends Resource
class_name ModalTheme
## Theme resource class for modal overlays
##
## Defines consistent visual styling for all modal overlays including colors,
## fonts, spacing, and component-specific styles for desktop-optimized display.

# Core color palette
@export var background_color: Color = Color(0.2, 0.2, 0.2, 0.95)
@export var dim_color: Color = Color(0.0, 0.0, 0.0, 0.7)
@export var border_color: Color = Color(0.4, 0.4, 0.4, 1.0)
@export var accent_color: Color = Color(0.3, 0.6, 1.0, 1.0)

# Text colors
@export var text_color: Color = Color.WHITE
@export var text_color_secondary: Color = Color(0.8, 0.8, 0.8, 1.0)
@export var text_color_disabled: Color = Color(0.5, 0.5, 0.5, 1.0)

# Button colors
@export var button_normal_color: Color = Color(0.3, 0.3, 0.3, 1.0)
@export var button_hover_color: Color = Color(0.4, 0.4, 0.4, 1.0)
@export var button_pressed_color: Color = Color(0.2, 0.2, 0.2, 1.0)
@export var button_disabled_color: Color = Color(0.25, 0.25, 0.25, 1.0)

# Panel colors
@export var panel_color: Color = Color(0.15, 0.15, 0.15, 0.98)
@export var panel_border_color: Color = Color(0.4, 0.4, 0.4, 1.0)

# Typography
@export var title_font_size: int = 24
@export var header_font_size: int = 18
@export var body_font_size: int = 14
@export var small_font_size: int = 12

# Spacing and layout
@export var modal_margin: int = 40
@export var content_padding: int = 20
@export var element_spacing: int = 10
@export var section_spacing: int = 20

# Border and corner radius
@export var corner_radius: int = 8
@export var border_width: int = 1

# Animation settings
@export var animation_duration: float = 0.3
@export var fast_animation_duration: float = 0.15

# Component-specific settings
@export var button_corner_radius: int = 6
@export var button_padding_horizontal: int = 16
@export var button_padding_vertical: int = 8

func apply_to_control(control: Control) -> void:
	"""Apply theme to a control - basic implementation"""
	if not control:
		return
	
	# Apply background color to panels
	if control is Panel:
		control.add_theme_color_override("panel", panel_color)
	
	# Apply text color to labels
	elif control is Label:
		control.add_theme_color_override("font_color", text_color)
		control.add_theme_font_size_override("font_size", body_font_size)
	
	# Apply button styling
	elif control is Button:
		apply_button_theme(control)

func apply_button_theme(button: Button) -> void:
	"""Apply button-specific theme styling"""
	button.add_theme_color_override("font_color", text_color)
	button.add_theme_color_override("font_color_hover", text_color)
	button.add_theme_color_override("font_color_pressed", text_color)
	button.add_theme_color_override("font_color_disabled", text_color_disabled)
	
	# Button background colors
	button.add_theme_color_override("button_color", button_normal_color)
	button.add_theme_color_override("button_color_hover", button_hover_color)
	button.add_theme_color_override("button_color_pressed", button_pressed_color)
	button.add_theme_color_override("button_color_disabled", button_disabled_color)
	
	button.add_theme_font_size_override("font_size", body_font_size)

func apply_to_modal(modal: BaseModal) -> void:
	"""Apply theme comprehensively to a modal and its children"""
	if not modal:
		return
	
	# Apply to the modal itself
	apply_to_control(modal)
	
	# Recursively apply to all children
	_apply_to_children(modal)

func _apply_to_children(node: Node) -> void:
	"""Recursively apply theme to all child controls"""
	for child in node.get_children():
		if child is Control:
			apply_to_control(child)
		
		# Continue recursion
		_apply_to_children(child)

func get_themed_style_box(type: String = "panel") -> StyleBox:
	"""Create a themed StyleBox for various UI elements"""
	var style_box = StyleBoxFlat.new()
	
	match type:
		"panel":
			style_box.bg_color = panel_color
			style_box.border_color = panel_border_color
			style_box.set_border_width_all(border_width)
			style_box.set_corner_radius_all(corner_radius)
		
		"button_normal":
			style_box.bg_color = button_normal_color
			style_box.border_color = border_color
			style_box.set_border_width_all(border_width)
			style_box.set_corner_radius_all(button_corner_radius)
			style_box.content_margin_left = button_padding_horizontal
			style_box.content_margin_right = button_padding_horizontal
			style_box.content_margin_top = button_padding_vertical
			style_box.content_margin_bottom = button_padding_vertical
		
		"button_hover":
			style_box.bg_color = button_hover_color
			style_box.border_color = accent_color
			style_box.set_border_width_all(border_width)
			style_box.set_corner_radius_all(button_corner_radius)
			style_box.content_margin_left = button_padding_horizontal
			style_box.content_margin_right = button_padding_horizontal
			style_box.content_margin_top = button_padding_vertical
			style_box.content_margin_bottom = button_padding_vertical
		
		"button_pressed":
			style_box.bg_color = button_pressed_color
			style_box.border_color = accent_color
			style_box.set_border_width_all(border_width + 1)
			style_box.set_corner_radius_all(button_corner_radius)
			style_box.content_margin_left = button_padding_horizontal
			style_box.content_margin_right = button_padding_horizontal
			style_box.content_margin_top = button_padding_vertical
			style_box.content_margin_bottom = button_padding_vertical
		
		_:
			# Default panel style
			style_box.bg_color = background_color
			style_box.border_color = border_color
			style_box.set_border_width_all(border_width)
			style_box.set_corner_radius_all(corner_radius)
	
	return style_box

func create_themed_button() -> Button:
	"""Create a button with theme applied"""
	var button = Button.new()
	apply_button_theme(button)
	return button

func create_themed_panel() -> Panel:
	"""Create a panel with theme applied"""
	var panel = Panel.new()
	apply_to_control(panel)
	return panel

func create_themed_label(text: String = "", font_size: int = -1) -> Label:
	"""Create a label with theme applied"""
	var label = Label.new()
	label.text = text
	apply_to_control(label)
	
	if font_size > 0:
		label.add_theme_font_size_override("font_size", font_size)
	
	return label

# Validation and debugging
func validate_theme() -> bool:
	"""Validate theme configuration"""
	var issues: Array[String] = []
	
	# Check color alpha values
	if background_color.a < 0.5:
		issues.append("background_color alpha too low (may not provide sufficient contrast)")
	
	if dim_color.a < 0.3:
		issues.append("dim_color alpha too low (background may not be properly dimmed)")
	
	# Check font sizes
	if title_font_size <= body_font_size:
		issues.append("title_font_size should be larger than body_font_size")
	
	if header_font_size <= body_font_size:
		issues.append("header_font_size should be larger than body_font_size")
	
	# Check spacing values
	if modal_margin < 20:
		issues.append("modal_margin may be too small for desktop displays")
	
	if not issues.is_empty():
		Logger.warn("ModalTheme validation issues: %s" % ", ".join(issues), "ui")
		return false
	
	return true

func get_theme_info() -> Dictionary:
	"""Get theme information for debugging"""
	return {
		"background_color": background_color,
		"text_color": text_color,
		"accent_color": accent_color,
		"title_font_size": title_font_size,
		"body_font_size": body_font_size,
		"modal_margin": modal_margin,
		"corner_radius": corner_radius,
		"animation_duration": animation_duration
	}