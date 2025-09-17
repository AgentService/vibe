extends Resource
class_name MainTheme
## Comprehensive game-wide theme system
##
## Defines visual styling for all UI elements including modals, cards, HUD,
## and game-specific components. Optimized for desktop gaming with scalable
## design from 1280x720 to 4K resolutions.

# ============================================================================
# CORE COLOR PALETTE
# ============================================================================

# Primary theme colors
@export var primary_color: Color = Color(0.3, 0.6, 1.0, 1.0)  # Bright blue
@export var primary_dark: Color = Color(0.2, 0.4, 0.8, 1.0)
@export var primary_light: Color = Color(0.5, 0.7, 1.0, 1.0)

@export var secondary_color: Color = Color(0.8, 0.4, 0.2, 1.0)  # Warm orange
@export var secondary_dark: Color = Color(0.6, 0.3, 0.1, 1.0)
@export var secondary_light: Color = Color(1.0, 0.6, 0.4, 1.0)

# Background colors
@export var background_dark: Color = Color(0.1, 0.1, 0.1, 1.0)     # Very dark
@export var background_medium: Color = Color(0.15, 0.15, 0.15, 1.0) # Medium dark
@export var background_light: Color = Color(0.2, 0.2, 0.2, 1.0)     # Light dark
@export var background_overlay: Color = Color(0.2, 0.2, 0.2, 0.95)   # Semi-transparent

# Modal specific colors (backward compatibility)
@export var dim_color: Color = Color(0.0, 0.0, 0.0, 0.7)
@export var border_color: Color = Color(0.4, 0.4, 0.4, 1.0)

# ============================================================================
# SEMANTIC COLORS
# ============================================================================

# Status colors
@export var success_color: Color = Color(0.2, 0.8, 0.2, 1.0)    # Green
@export var warning_color: Color = Color(0.9, 0.7, 0.1, 1.0)    # Yellow
@export var error_color: Color = Color(0.9, 0.2, 0.2, 1.0)      # Red
@export var info_color: Color = Color(0.2, 0.6, 0.9, 1.0)       # Blue

# Interactive states
@export var hover_color: Color = Color(0.4, 0.4, 0.4, 1.0)
@export var pressed_color: Color = Color(0.2, 0.2, 0.2, 1.0)
@export var selected_color: Color = Color(0.3, 0.5, 0.8, 1.0)
@export var disabled_color: Color = Color(0.25, 0.25, 0.25, 1.0)

# ============================================================================
# CARD RARITY COLORS
# ============================================================================

@export_group("Card Rarity Colors")
@export var rarity_common: Color = Color(0.6, 0.6, 0.6, 1.0)      # Gray
@export var rarity_uncommon: Color = Color(0.2, 0.8, 0.2, 1.0)    # Green
@export var rarity_rare: Color = Color(0.2, 0.4, 1.0, 1.0)        # Blue
@export var rarity_epic: Color = Color(0.6, 0.2, 0.8, 1.0)        # Purple
@export var rarity_legendary: Color = Color(1.0, 0.6, 0.0, 1.0)   # Orange
@export var rarity_mythic: Color = Color(1.0, 0.2, 0.2, 1.0)      # Red

# ============================================================================
# TEXT COLORS
# ============================================================================

@export_group("Text Colors")
@export var text_primary: Color = Color.WHITE                       # Main text
@export var text_secondary: Color = Color(0.8, 0.8, 0.8, 1.0)     # Secondary text
@export var text_muted: Color = Color(0.6, 0.6, 0.6, 1.0)         # Muted text
@export var text_disabled: Color = Color(0.5, 0.5, 0.5, 1.0)      # Disabled text
@export var text_highlight: Color = Color(1.0, 1.0, 0.6, 1.0)     # Highlighted text
@export var text_link: Color = Color(0.4, 0.8, 1.0, 1.0)          # Link text

# ============================================================================
# TYPOGRAPHY HIERARCHY
# ============================================================================

@export_group("Typography")
# Main text sizes (scalable)
@export var font_size_huge: int = 36        # Page titles, hero text
@export var font_size_large: int = 28       # Section headers
@export var font_size_title: int = 24       # Modal titles
@export var font_size_header: int = 18      # Panel headers
@export var font_size_body: int = 14        # Normal text
@export var font_size_caption: int = 12     # Small text
@export var font_size_tiny: int = 10        # Micro text

# UI specific font sizes
@export var font_size_button: int = 14      # Button text
@export var font_size_tooltip: int = 12     # Tooltip text
@export var font_size_label: int = 12       # UI labels

# ============================================================================
# COMPONENT SIZING
# ============================================================================

@export_group("Component Sizing")
# Button sizing
@export var button_height_small: int = 32
@export var button_height_medium: int = 40
@export var button_height_large: int = 48

@export var button_padding_horizontal: int = 16
@export var button_padding_vertical: int = 8

# Card sizing
@export var card_width: int = 180
@export var card_height: int = 240
@export var card_margin: int = 8

# Panel sizing
@export var panel_padding: int = 16
@export var panel_margin: int = 12

# ============================================================================
# SPACING SYSTEM
# ============================================================================

@export_group("Spacing")
# Spacing scale (8px base unit for consistent rhythm)
@export var space_xs: int = 4      # 0.25x
@export var space_sm: int = 8      # 0.5x  
@export var space_md: int = 16     # 1x - base spacing
@export var space_lg: int = 24     # 1.5x
@export var space_xl: int = 32     # 2x
@export var space_xxl: int = 48    # 3x

# Legacy spacing (backward compatibility)
@export var modal_margin: int = 40
@export var content_padding: int = 20
@export var element_spacing: int = 10
@export var section_spacing: int = 20

# ============================================================================
# VISUAL PROPERTIES
# ============================================================================

@export_group("Visual Properties")
# Border and corner radius
@export var corner_radius_small: int = 4
@export var corner_radius_medium: int = 8
@export var corner_radius_large: int = 12

@export var border_width_thin: int = 1
@export var border_width_medium: int = 2
@export var border_width_thick: int = 3

# Legacy properties (backward compatibility)
@export var corner_radius: int = 8
@export var border_width: int = 1
@export var button_corner_radius: int = 6

# ============================================================================
# ANIMATION SETTINGS
# ============================================================================

@export_group("Animation")
# Animation durations optimized for desktop
@export var animation_instant: float = 0.0
@export var animation_fast: float = 0.15      # Quick interactions
@export var animation_normal: float = 0.3     # Standard animations
@export var animation_slow: float = 0.5       # Dramatic effects

# Legacy animation properties (backward compatibility)
@export var animation_duration: float = 0.3
@export var fast_animation_duration: float = 0.15

# Animation easing presets
enum EasePreset {
	EASE_IN,
	EASE_OUT, 
	EASE_IN_OUT,
	EASE_BOUNCE,
	EASE_ELASTIC
}

# ============================================================================
# THEME APPLICATION METHODS
# ============================================================================

func apply_to_control(control: Control, style_variant: String = "") -> void:
	"""Apply theme to a control with optional style variant"""
	if not control:
		return
	
	# Apply styling based on control type and variant
	match control.get_class():
		"Panel":
			apply_panel_theme(control, style_variant)
		"Label":
			apply_label_theme(control, style_variant)
		"Button":
			apply_button_theme(control, style_variant)
		"LineEdit":
			apply_line_edit_theme(control, style_variant)
		"TextEdit":
			apply_text_edit_theme(control, style_variant)
		_:
			# Apply basic theming for unrecognized controls
			apply_basic_theme(control)

func apply_panel_theme(panel: Panel, variant: String = "") -> void:
	"""Apply panel theming with variants"""
	match variant:
		"modal":
			panel.add_theme_color_override("panel", background_overlay)
		"dark":
			panel.add_theme_color_override("panel", background_dark)
		"medium":
			panel.add_theme_color_override("panel", background_medium)
		"card":
			panel.add_theme_color_override("panel", background_light)
			# Add border styling for cards
			var style = get_themed_style_box("card_panel")
			panel.add_theme_stylebox_override("panel", style)
		_:
			panel.add_theme_color_override("panel", background_medium)

func apply_button_theme(button: Button, variant: String = "") -> void:
	"""Apply button theming with variants"""
	# Base button colors
	button.add_theme_color_override("font_color", text_primary)
	button.add_theme_color_override("font_color_hover", text_primary)
	button.add_theme_color_override("font_color_pressed", text_primary)
	button.add_theme_color_override("font_color_disabled", text_disabled)
	
	# Font size
	button.add_theme_font_size_override("font_size", font_size_button)
	
	# Apply variant-specific styling
	match variant:
		"primary":
			button.add_theme_color_override("button_color", primary_color)
			button.add_theme_color_override("button_color_hover", primary_light)
			button.add_theme_color_override("button_color_pressed", primary_dark)
		"secondary":
			button.add_theme_color_override("button_color", secondary_color)
			button.add_theme_color_override("button_color_hover", secondary_light)
			button.add_theme_color_override("button_color_pressed", secondary_dark)
		"success":
			button.add_theme_color_override("button_color", success_color)
		"warning":
			button.add_theme_color_override("button_color", warning_color)
		"error":
			button.add_theme_color_override("button_color", error_color)
		_:
			# Default button colors
			button.add_theme_color_override("button_color", background_light)
			button.add_theme_color_override("button_color_hover", hover_color)
			button.add_theme_color_override("button_color_pressed", pressed_color)
	
	button.add_theme_color_override("button_color_disabled", disabled_color)

func apply_label_theme(label: Label, variant: String = "") -> void:
	"""Apply label theming with variants"""
	match variant:
		"title":
			label.add_theme_color_override("font_color", text_primary)
			label.add_theme_font_size_override("font_size", font_size_title)
		"header":
			label.add_theme_color_override("font_color", text_primary)
			label.add_theme_font_size_override("font_size", font_size_header)
		"secondary":
			label.add_theme_color_override("font_color", text_secondary)
			label.add_theme_font_size_override("font_size", font_size_body)
		"muted":
			label.add_theme_color_override("font_color", text_muted)
			label.add_theme_font_size_override("font_size", font_size_body)
		"highlight":
			label.add_theme_color_override("font_color", text_highlight)
			label.add_theme_font_size_override("font_size", font_size_body)
		"caption":
			label.add_theme_color_override("font_color", text_muted)
			label.add_theme_font_size_override("font_size", font_size_caption)
		_:
			label.add_theme_color_override("font_color", text_primary)
			label.add_theme_font_size_override("font_size", font_size_body)

func apply_line_edit_theme(line_edit: LineEdit, variant: String = "") -> void:
	"""Apply line edit theming"""
	line_edit.add_theme_color_override("font_color", text_primary)
	line_edit.add_theme_color_override("font_placeholder_color", text_muted)
	line_edit.add_theme_font_size_override("font_size", font_size_body)

func apply_text_edit_theme(text_edit: TextEdit, variant: String = "") -> void:
	"""Apply text edit theming"""
	text_edit.add_theme_color_override("font_color", text_primary)
	text_edit.add_theme_font_size_override("font_size", font_size_body)

func apply_basic_theme(control: Control) -> void:
	"""Apply basic theming to unrecognized controls"""
	# Try to apply color if the control supports it
	control.add_theme_color_override("font_color", text_primary)
	control.add_theme_font_size_override("font_size", font_size_body)

# ============================================================================
# CARD-SPECIFIC THEMING
# ============================================================================

func get_card_color(rarity: String) -> Color:
	"""Get color for card rarity"""
	match rarity.to_lower():
		"common": return rarity_common
		"uncommon": return rarity_uncommon
		"rare": return rarity_rare
		"epic": return rarity_epic
		"legendary": return rarity_legendary
		"mythic": return rarity_mythic
		_: return rarity_common

func apply_card_theme(card: Control, rarity: String = "common") -> void:
	"""Apply card-specific theming with rarity colors"""
	var card_color = get_card_color(rarity)
	
	# Apply rarity border
	if card.has_method("add_theme_color_override"):
		card.add_theme_color_override("border_color", card_color)
	
	# Apply card styling
	apply_to_control(card, "card")

# ============================================================================
# STYLE BOX GENERATION
# ============================================================================

func get_themed_style_box(type: String = "panel") -> StyleBox:
	"""Create a themed StyleBox for various UI elements"""
	var style_box = StyleBoxFlat.new()
	
	match type:
		"panel":
			style_box.bg_color = background_medium
			style_box.border_color = border_color
			style_box.set_border_width_all(border_width_thin)
			style_box.set_corner_radius_all(corner_radius_medium)
			
		"card_panel":
			style_box.bg_color = background_light
			style_box.border_color = border_color
			style_box.set_border_width_all(border_width_medium)
			style_box.set_corner_radius_all(corner_radius_medium)
			style_box.content_margin_left = space_md
			style_box.content_margin_right = space_md
			style_box.content_margin_top = space_md
			style_box.content_margin_bottom = space_md
			
		"button_normal":
			style_box.bg_color = background_light
			style_box.border_color = border_color
			style_box.set_border_width_all(border_width_thin)
			style_box.set_corner_radius_all(corner_radius_small)
			style_box.content_margin_left = button_padding_horizontal
			style_box.content_margin_right = button_padding_horizontal
			style_box.content_margin_top = button_padding_vertical
			style_box.content_margin_bottom = button_padding_vertical
			
		"button_hover":
			style_box.bg_color = hover_color
			style_box.border_color = primary_color
			style_box.set_border_width_all(border_width_medium)
			style_box.set_corner_radius_all(corner_radius_small)
			style_box.content_margin_left = button_padding_horizontal
			style_box.content_margin_right = button_padding_horizontal
			style_box.content_margin_top = button_padding_vertical
			style_box.content_margin_bottom = button_padding_vertical
			
		"button_pressed":
			style_box.bg_color = pressed_color
			style_box.border_color = primary_color
			style_box.set_border_width_all(border_width_medium)
			style_box.set_corner_radius_all(corner_radius_small)
			style_box.content_margin_left = button_padding_horizontal
			style_box.content_margin_right = button_padding_horizontal
			style_box.content_margin_top = button_padding_vertical
			style_box.content_margin_bottom = button_padding_vertical
			
		"tooltip":
			style_box.bg_color = Color(0.1, 0.1, 0.1, 0.95)
			style_box.border_color = text_secondary
			style_box.set_border_width_all(border_width_thin)
			style_box.set_corner_radius_all(corner_radius_small)
			style_box.content_margin_left = space_sm
			style_box.content_margin_right = space_sm
			style_box.content_margin_top = space_xs
			style_box.content_margin_bottom = space_xs
			
		_:
			# Default style
			style_box.bg_color = background_medium
			style_box.border_color = border_color
			style_box.set_border_width_all(border_width_thin)
			style_box.set_corner_radius_all(corner_radius_medium)
	
	return style_box

# ============================================================================
# COMPONENT FACTORY METHODS
# ============================================================================

func create_themed_button(text: String = "", variant: String = "") -> Button:
	"""Create a button with theme applied"""
	var button = Button.new()
	button.text = text
	apply_button_theme(button, variant)
	return button

func create_themed_panel(variant: String = "") -> Panel:
	"""Create a panel with theme applied"""
	var panel = Panel.new()
	apply_panel_theme(panel, variant)
	return panel

func create_themed_label(text: String = "", variant: String = "") -> Label:
	"""Create a label with theme applied"""
	var label = Label.new()
	label.text = text
	apply_label_theme(label, variant)
	return label

# ============================================================================
# BACKWARD COMPATIBILITY
# ============================================================================

# Legacy properties for ModalTheme compatibility
@export var background_color: Color = Color(0.2, 0.2, 0.2, 0.95):
	get: return background_overlay
@export var accent_color: Color = Color(0.3, 0.6, 1.0, 1.0):
	get: return primary_color
@export var text_color: Color = Color.WHITE:
	get: return text_primary
@export var text_color_secondary: Color = Color(0.8, 0.8, 0.8, 1.0):
	get: return text_secondary
@export var text_color_disabled: Color = Color(0.5, 0.5, 0.5, 1.0):
	get: return text_disabled

# Button colors (legacy)
@export var button_normal_color: Color = Color(0.3, 0.3, 0.3, 1.0):
	get: return background_light
@export var button_hover_color: Color = Color(0.4, 0.4, 0.4, 1.0):
	get: return hover_color
@export var button_pressed_color: Color = Color(0.2, 0.2, 0.2, 1.0):
	get: return pressed_color
@export var button_disabled_color: Color = Color(0.25, 0.25, 0.25, 1.0):
	get: return disabled_color

# Panel colors (legacy)
@export var panel_color: Color = Color(0.15, 0.15, 0.15, 0.98):
	get: return background_medium
@export var panel_border_color: Color = Color(0.4, 0.4, 0.4, 1.0):
	get: return border_color

# Font sizes (legacy)
@export var title_font_size: int = 24:
	get: return font_size_title
@export var header_font_size: int = 18:
	get: return font_size_header
@export var body_font_size: int = 14:
	get: return font_size_body
@export var small_font_size: int = 12:
	get: return font_size_caption

# Legacy methods for compatibility with existing ModalTheme usage
func apply_to_modal(modal: BaseModal) -> void:
	"""Apply theme comprehensively to a modal and its children (legacy compatibility)"""
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

# ============================================================================
# VALIDATION AND DEBUGGING
# ============================================================================

func validate_theme() -> bool:
	"""Validate theme configuration"""
	var issues: Array[String] = []
	
	# Check color contrast
	if background_overlay.a < 0.5:
		issues.append("background_overlay alpha too low (may not provide sufficient contrast)")
	
	if dim_color.a < 0.3:
		issues.append("dim_color alpha too low (background may not be properly dimmed)")
	
	# Check font size hierarchy
	if font_size_title <= font_size_body:
		issues.append("font_size_title should be larger than font_size_body")
	
	if font_size_header <= font_size_body:
		issues.append("font_size_header should be larger than font_size_body")
	
	# Check spacing consistency
	if space_md <= 0:
		issues.append("space_md must be positive (base spacing unit)")
	
	if card_width <= 0 or card_height <= 0:
		issues.append("Card dimensions must be positive")
	
	if not issues.is_empty():
		Logger.warn("MainTheme validation issues: %s" % ", ".join(issues), "ui")
		return false
	
	return true

func get_theme_info() -> Dictionary:
	"""Get comprehensive theme information for debugging"""
	return {
		"primary_color": primary_color,
		"secondary_color": secondary_color,
		"background_colors": {
			"dark": background_dark,
			"medium": background_medium,
			"light": background_light,
			"overlay": background_overlay
		},
		"text_colors": {
			"primary": text_primary,
			"secondary": text_secondary,
			"muted": text_muted,
			"disabled": text_disabled,
			"highlight": text_highlight
		},
		"font_sizes": {
			"huge": font_size_huge,
			"large": font_size_large,
			"title": font_size_title,
			"header": font_size_header,
			"body": font_size_body,
			"caption": font_size_caption
		},
		"spacing": {
			"xs": space_xs,
			"sm": space_sm,
			"md": space_md,
			"lg": space_lg,
			"xl": space_xl,
			"xxl": space_xxl
		},
		"card_colors": {
			"common": rarity_common,
			"uncommon": rarity_uncommon,
			"rare": rarity_rare,
			"epic": rarity_epic,
			"legendary": rarity_legendary,
			"mythic": rarity_mythic
		}
	}

func get_color_palette() -> Array[Color]:
	"""Get all theme colors for palette display"""
	return [
		primary_color, primary_dark, primary_light,
		secondary_color, secondary_dark, secondary_light,
		success_color, warning_color, error_color, info_color,
		rarity_common, rarity_uncommon, rarity_rare,
		rarity_epic, rarity_legendary, rarity_mythic
	]
