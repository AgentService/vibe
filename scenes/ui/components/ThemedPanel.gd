extends Panel
class_name ThemedPanel
## Enhanced panel component with automatic theming and desktop-optimized styling
##
## Provides consistent panel appearance across the game with automatic theme
## application, rounded corners, borders, and variant styling support.

@export_group("Panel Properties") 
@export var panel_variant: String = ""   # modal, dark, medium, light, card
@export var auto_theme: bool = true      # Automatically apply theme on ready
@export var show_border: bool = true     # Show panel border
@export var rounded_corners: bool = true # Use rounded corners

@export_group("Visual Effects")
@export var drop_shadow: bool = false    # Add drop shadow effect (future)
@export var glow_effect: bool = false    # Add glow effect for important panels
@export var hover_highlight: bool = false # Highlight on mouse hover

# Internal state
var main_theme: MainTheme
var original_modulate: Color = Color.WHITE
var hover_tween: Tween

# Enhanced signals for interactive panels
signal panel_clicked()
signal panel_hovered(is_hovering: bool)
signal panel_focused(is_focused: bool)

func _ready() -> void:
	# Store original modulate
	original_modulate = modulate
	
	# Load theme if auto theming is enabled
	if auto_theme:
		load_theme_from_manager()
	
	# Setup hover detection if enabled
	if hover_highlight:
		setup_hover_detection()
	
	# Register for theme changes
	if ThemeManager:
		ThemeManager.add_theme_listener(_on_theme_changed)
	
	Logger.debug("ThemedPanel initialized (variant: %s)" % panel_variant, "ui")

func load_theme_from_manager() -> void:
	"""Load and apply theme from ThemeManager."""
	if ThemeManager:
		main_theme = ThemeManager.get_theme()
		apply_panel_theme()
	else:
		Logger.warn("ThemeManager not available for ThemedPanel", "ui")

func apply_panel_theme() -> void:
	"""Apply MainTheme to this panel."""
	if main_theme:
		# Apply theme variant
		main_theme.apply_panel_theme(self, panel_variant)
		
		# Apply styled StyleBox if needed
		if show_border or rounded_corners:
			apply_styled_background()
		
		Logger.debug("Applied theme variant '%s' to panel" % panel_variant, "ui")

func apply_styled_background() -> void:
	"""Apply custom StyleBox with theme-based styling."""
	if not main_theme:
		return
	
	var style_box_name = "panel"
	if panel_variant == "card":
		style_box_name = "card_panel"
	
	var style_box = main_theme.get_themed_style_box(style_box_name)
	
	# Customize based on properties
	if not show_border and style_box is StyleBoxFlat:
		var flat_style = style_box as StyleBoxFlat
		flat_style.set_border_width_all(0)
	
	if not rounded_corners and style_box is StyleBoxFlat:
		var flat_style = style_box as StyleBoxFlat
		flat_style.set_corner_radius_all(0)
	
	add_theme_stylebox_override("panel", style_box)

# ============================================================================
# HOVER EFFECTS
# ============================================================================

func setup_hover_detection() -> void:
	"""Setup mouse hover detection for interactive panels."""
	mouse_filter = Control.MOUSE_FILTER_PASS
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)

func _on_mouse_entered() -> void:
	"""Handle mouse enter."""
	panel_hovered.emit(true)
	
	if hover_highlight:
		animate_hover(true)

func _on_mouse_exited() -> void:
	"""Handle mouse exit."""
	panel_hovered.emit(false)
	
	if hover_highlight:
		animate_hover(false)

func animate_hover(hover_in: bool) -> void:
	"""Animate hover highlight effect."""
	if hover_tween:
		hover_tween.kill()
	
	hover_tween = create_tween()
	hover_tween.set_ease(Tween.EASE_OUT)
	hover_tween.set_trans(Tween.TRANS_QUART)
	
	var target_modulate = original_modulate
	if hover_in and main_theme:
		# Slightly brighten on hover
		target_modulate = original_modulate * 1.1
	
	hover_tween.tween_property(self, "modulate", target_modulate, 0.2)

func _gui_input(event: InputEvent) -> void:
	"""Handle panel input for interactive panels."""
	if event is InputEventMouseButton:
		var mouse_event = event as InputEventMouseButton
		if mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT:
			panel_clicked.emit()

# ============================================================================
# VISUAL EFFECTS
# ============================================================================

func set_glow_effect(enabled: bool) -> void:
	"""Enable/disable glow effect for important panels."""
	glow_effect = enabled
	
	if enabled and main_theme:
		# Add subtle glow using outline
		modulate = Color(1.1, 1.1, 1.1, 1.0)
	else:
		modulate = original_modulate

func flash_highlight(color: Color = Color.WHITE, duration: float = 0.5) -> void:
	"""Flash the panel with a color briefly."""
	var flash_tween = create_tween()
	flash_tween.tween_property(self, "modulate", color, duration * 0.3)
	flash_tween.tween_property(self, "modulate", original_modulate, duration * 0.7)

func pulse_attention() -> void:
	"""Pulse the panel to draw attention."""
	var pulse_tween = create_tween()
	pulse_tween.set_loops(3)
	pulse_tween.tween_property(self, "scale", Vector2.ONE * 1.02, 0.5)
	pulse_tween.tween_property(self, "scale", Vector2.ONE, 0.5)

# ============================================================================
# LAYOUT HELPERS
# ============================================================================

func add_margin_container(margin: int = -1) -> MarginContainer:
	"""Add a margin container as child with theme-based margins."""
	var container = MarginContainer.new()
	var actual_margin = margin
	
	if margin < 0 and main_theme:
		actual_margin = main_theme.panel_padding
	elif margin < 0:
		actual_margin = 16  # Fallback
	
	container.add_theme_constant_override("margin_left", actual_margin)
	container.add_theme_constant_override("margin_right", actual_margin)
	container.add_theme_constant_override("margin_top", actual_margin)
	container.add_theme_constant_override("margin_bottom", actual_margin)
	
	add_child(container)
	return container

func add_titled_content(title: String, content_scene: PackedScene = null) -> VBoxContainer:
	"""Add title and content area to panel."""
	var vbox = VBoxContainer.new()
	add_child(vbox)
	
	# Add title label
	var title_label = Label.new()
	title_label.text = title
	if main_theme:
		main_theme.apply_label_theme(title_label, "header")
	vbox.add_child(title_label)
	
	# Add separator
	var separator = HSeparator.new()
	if main_theme:
		separator.add_theme_color_override("separator", main_theme.border_color)
	vbox.add_child(separator)
	
	# Add content if provided
	if content_scene:
		var content = content_scene.instantiate()
		vbox.add_child(content)
	
	return vbox

# ============================================================================
# THEME INTEGRATION
# ============================================================================

func _on_theme_changed(new_theme: MainTheme) -> void:
	"""Handle theme changes."""
	main_theme = new_theme
	if auto_theme:
		apply_panel_theme()

func set_panel_variant(new_variant: String) -> void:
	"""Change panel variant and reapply theme."""
	panel_variant = new_variant
	if main_theme and auto_theme:
		apply_panel_theme()

# ============================================================================
# FACTORY METHODS
# ============================================================================

static func create_modal_panel() -> ThemedPanel:
	"""Create a modal-styled panel."""
	var panel = ThemedPanel.new()
	panel.panel_variant = "modal"
	return panel

static func create_card_panel() -> ThemedPanel:
	"""Create a card-styled panel."""
	var panel = ThemedPanel.new()
	panel.panel_variant = "card"
	panel.show_border = true
	panel.rounded_corners = true
	return panel

static func create_content_panel() -> ThemedPanel:
	"""Create a standard content panel."""
	var panel = ThemedPanel.new()
	panel.panel_variant = "medium"
	return panel

static func create_interactive_panel() -> ThemedPanel:
	"""Create an interactive panel with hover effects."""
	var panel = ThemedPanel.new()
	panel.hover_highlight = true
	return panel

# ============================================================================
# ACCESSIBILITY AND DEBUG
# ============================================================================

func get_panel_info() -> Dictionary:
	"""Get panel information for debugging."""
	return {
		"variant": panel_variant,
		"auto_theme": auto_theme,
		"show_border": show_border,
		"rounded_corners": rounded_corners,
		"hover_highlight": hover_highlight,
		"glow_effect": glow_effect,
		"theme_available": main_theme != null
	}

# ============================================================================
# CLEANUP
# ============================================================================

func _exit_tree() -> void:
	"""Clean up when panel is removed."""
	if ThemeManager:
		ThemeManager.remove_theme_listener(_on_theme_changed)
	
	# Clean up tweens
	if hover_tween:
		hover_tween.kill()
	
	Logger.debug("ThemedPanel cleaned up", "ui")