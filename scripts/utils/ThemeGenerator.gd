extends RefCounted
class_name ThemeGenerator

## ThemeGenerator - Utility for creating consistent UI themes
## Generates StyleBox resources and theme configurations for the card selection UI

static func create_card_selection_theme() -> Theme:
	"""Create comprehensive theme for card selection UI."""
	var theme = Theme.new()
	
	# Font sizes for different elements
	theme.set_font_size("font_size", "TitleLabel", 48)
	theme.set_font_size("font_size", "SubtitleLabel", 20) 
	theme.set_font_size("font_size", "CardTitle", 24)
	theme.set_font_size("font_size", "CardDescription", 16)
	theme.set_font_size("font_size", "CardIcon", 48)
	theme.set_font_size("font_size", "BadgeLabel", 12)
	
	# Colors
	theme.set_color("font_color", "TitleLabel", Color.WHITE)
	theme.set_color("font_shadow_color", "TitleLabel", Color(0, 0, 0, 0.5))
	theme.set_color("font_color", "SubtitleLabel", Color(0.85, 0.85, 0.95, 1.0))
	theme.set_color("font_color", "CardTitle", Color.WHITE)
	theme.set_color("font_color", "CardDescription", Color(0.9, 0.9, 0.9, 1.0))
	theme.set_color("font_color", "CardIcon", Color(1.0, 1.0, 1.0, 0.9))
	theme.set_color("font_color", "BadgeLabel", Color.WHITE)
	
	# Constants
	theme.set_constant("shadow_offset_x", "TitleLabel", 2)
	theme.set_constant("shadow_offset_y", "TitleLabel", 2)
	theme.set_constant("separation", "CardContainer", 20)
	
	# Background StyleBox
	var bg_style = create_background_stylebox()
	theme.set_stylebox("panel", "BackgroundPanel", bg_style)
	
	# Card StyleBoxes
	var card_styles = create_card_styleboxes()
	theme.set_stylebox("normal", "CardPanel", card_styles.normal)
	theme.set_stylebox("hover", "CardPanel", card_styles.hover)
	theme.set_stylebox("focus", "CardPanel", card_styles.focus)
	theme.set_stylebox("pressed", "CardPanel", card_styles.pressed)
	
	# Badge StyleBox
	var badge_style = create_badge_stylebox()
	theme.set_stylebox("panel", "BadgePanel", badge_style)
	
	# Button StyleBoxes (for invisible card buttons)
	var button_style = create_invisible_button_stylebox()
	theme.set_stylebox("normal", "CardButton", button_style)
	theme.set_stylebox("hover", "CardButton", button_style)
	theme.set_stylebox("pressed", "CardButton", button_style)
	theme.set_stylebox("focus", "CardButton", create_focus_button_stylebox())
	
	return theme

static func create_background_stylebox() -> StyleBoxFlat:
	"""Create background overlay stylebox."""
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.05, 0.15, 0.85)  # Deep blue-black
	return style

static func create_card_styleboxes() -> Dictionary:
	"""Create card panel styleboxes for different states."""
	var styles = {}
	
	# Card color palette
	var card_colors = [
		Color(0.15, 0.25, 0.4, 0.95),  # Deep blue
		Color(0.25, 0.15, 0.4, 0.95),  # Purple
		Color(0.4, 0.2, 0.15, 0.95),   # Dark red/brown
		Color(0.15, 0.4, 0.25, 0.95),  # Forest green
		Color(0.4, 0.35, 0.15, 0.95),  # Gold/bronze
	]
	
	# Normal state
	var normal = StyleBoxFlat.new()
	normal.bg_color = card_colors[0]  # Will be overridden per card
	normal.border_width_left = 3
	normal.border_width_right = 3
	normal.border_width_top = 3
	normal.border_width_bottom = 3
	normal.border_color = Color(0.8, 0.8, 0.9, 0.8)
	normal.corner_radius_top_left = 16
	normal.corner_radius_top_right = 16
	normal.corner_radius_bottom_left = 16
	normal.corner_radius_bottom_right = 16
	normal.shadow_color = Color(0, 0, 0, 0.3)
	normal.shadow_size = 8
	normal.shadow_offset = Vector2(4, 4)
	styles.normal = normal
	
	# Hover state - brighter and enhanced shadow
	var hover = normal.duplicate()
	hover.border_color = Color.WHITE
	hover.shadow_size = 12
	hover.shadow_color = Color(0, 0, 0, 0.4)
	styles.hover = hover
	
	# Focus state - glowing border for keyboard navigation
	var focus = hover.duplicate()
	focus.border_color = Color(0.3, 0.7, 1.0, 1.0)  # Bright blue
	focus.border_width_left = 4
	focus.border_width_right = 4
	focus.border_width_top = 4
	focus.border_width_bottom = 4
	styles.focus = focus
	
	# Pressed state - slightly darker
	var pressed = normal.duplicate()
	var darker_bg = normal.bg_color.darkened(0.1)
	pressed.bg_color = darker_bg
	pressed.shadow_size = 4
	pressed.shadow_offset = Vector2(2, 2)
	styles.pressed = pressed
	
	return styles

static func create_badge_stylebox() -> StyleBoxFlat:
	"""Create level requirement badge stylebox."""
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.8, 0.4, 0.0, 0.9)  # Orange
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	return style

static func create_invisible_button_stylebox() -> StyleBoxEmpty:
	"""Create transparent button stylebox."""
	return StyleBoxEmpty.new()

static func create_focus_button_stylebox() -> StyleBoxFlat:
	"""Create focus ring for keyboard navigation."""
	var style = StyleBoxFlat.new()
	style.bg_color = Color.TRANSPARENT
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.3, 0.7, 1.0, 0.8)  # Bright blue
	style.corner_radius_top_left = 18
	style.corner_radius_top_right = 18
	style.corner_radius_bottom_left = 18
	style.corner_radius_bottom_right = 18
	return style

static func get_card_color_by_index(index: int) -> Color:
	"""Get card background color by index."""
	var card_colors = [
		Color(0.15, 0.25, 0.4, 0.95),  # Deep blue
		Color(0.25, 0.15, 0.4, 0.95),  # Purple
		Color(0.4, 0.2, 0.15, 0.95),   # Dark red/brown
		Color(0.15, 0.4, 0.25, 0.95),  # Forest green
		Color(0.4, 0.35, 0.15, 0.95),  # Gold/bronze
	]
	return card_colors[index % card_colors.size()]

static func create_responsive_theme(viewport_size: Vector2) -> Theme:
	"""Create theme with responsive font sizes and spacing."""
	var theme = create_card_selection_theme()
	
	var scale_factor = ResponsiveUI.get_ui_scale_factor(viewport_size)
	
	# Scale font sizes
	theme.set_font_size("font_size", "TitleLabel", int(48 * scale_factor))
	theme.set_font_size("font_size", "SubtitleLabel", int(20 * scale_factor))
	theme.set_font_size("font_size", "CardTitle", int(24 * scale_factor))
	theme.set_font_size("font_size", "CardDescription", int(16 * scale_factor))
	theme.set_font_size("font_size", "CardIcon", int(48 * scale_factor))
	theme.set_font_size("font_size", "BadgeLabel", int(12 * scale_factor))
	
	# Scale constants
	theme.set_constant("shadow_offset_x", "TitleLabel", int(2 * scale_factor))
	theme.set_constant("shadow_offset_y", "TitleLabel", int(2 * scale_factor))
	theme.set_constant("separation", "CardContainer", int(20 * scale_factor))
	
	return theme

static func save_theme_to_file(theme: Theme, path: String) -> void:
	"""Save theme resource to file."""
	var result = ResourceSaver.save(theme, path)
	if result == OK:
		Logger.info("Theme saved successfully to: " + path, "ui")
	else:
		Logger.error("Failed to save theme to: " + path + " (Error: " + str(result) + ")", "ui")