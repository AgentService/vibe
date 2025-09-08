extends Control
class_name CardItem

## CardItem - Reusable card component with responsive design and accessibility
## Displays card information with hover effects, keyboard navigation, and adaptive sizing

@export var card_resource: CardResource : set = set_card_resource
@export var card_index: int = 0
@export var theme_override: Theme

@onready var aspect_container: AspectRatioContainer = $AspectRatioContainer
@onready var card_panel: Panel = $AspectRatioContainer/CardPanel
@onready var content_container: VBoxContainer = $AspectRatioContainer/CardPanel/ContentContainer
@onready var top_spacer: Control = $AspectRatioContainer/CardPanel/ContentContainer/TopSpacer
@onready var icon_container: CenterContainer = $AspectRatioContainer/CardPanel/ContentContainer/IconContainer
@onready var icon_label: Label = $AspectRatioContainer/CardPanel/ContentContainer/IconContainer/IconLabel
@onready var title_label: Label = $AspectRatioContainer/CardPanel/ContentContainer/TitleLabel
@onready var description_margin: MarginContainer = $AspectRatioContainer/CardPanel/ContentContainer/DescriptionMargin
@onready var description_label: Label = $AspectRatioContainer/CardPanel/ContentContainer/DescriptionMargin/DescriptionLabel
@onready var bottom_spacer: Control = $AspectRatioContainer/CardPanel/ContentContainer/BottomSpacer
@onready var card_button: Button = $AspectRatioContainer/CardPanel/CardButton
@onready var level_badge: Panel = $AspectRatioContainer/CardPanel/LevelBadge
@onready var level_label: Label = $AspectRatioContainer/CardPanel/LevelBadge/LevelLabel

# Responsive properties
var viewport_size: Vector2
var current_card_size: Vector2
var scale_factor: float = 1.0

# State tracking
var is_hovered: bool = false
var is_focused: bool = false
var original_card_style: StyleBox
var hover_card_style: StyleBox
var focus_card_style: StyleBox

# Card colors for different indices
var card_colors: Array[Color] = [
	Color(0.15, 0.25, 0.4, 0.95),  # Deep blue
	Color(0.25, 0.15, 0.4, 0.95),  # Purple
	Color(0.4, 0.2, 0.15, 0.95),   # Dark red/brown
	Color(0.15, 0.4, 0.25, 0.95),  # Forest green
	Color(0.4, 0.35, 0.15, 0.95),  # Gold/bronze
]

signal card_selected(card_item: CardItem)
signal card_hovered(card_item: CardItem, is_hovered: bool)
signal card_focused(card_item: CardItem, is_focused: bool)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	
	# Load theme if available
	if theme_override:
		theme = theme_override
	elif ResourceLoader.exists("res://data/themes/card_selection_theme.tres"):
		theme = load("res://data/themes/card_selection_theme.tres")
	
	# Setup responsive design
	_setup_responsive_design()
	
	# Setup button signals
	_setup_signals()
	
	# Apply initial styling
	_apply_styling()
	
	# Setup accessibility
	_setup_accessibility()
	
	# Update card display if card_resource is already set
	if card_resource:
		_update_card_display()

func _setup_responsive_design() -> void:
	"""Initialize responsive design based on current viewport."""
	viewport_size = ResponsiveUI.get_viewport_size(self)
	scale_factor = ResponsiveUI.get_ui_scale_factor(viewport_size)
	current_card_size = ResponsiveUI.get_card_size(viewport_size)
	
	# Set aspect ratio for consistent card proportions
	aspect_container.ratio = current_card_size.x / current_card_size.y
	
	# Apply responsive sizing
	custom_minimum_size = current_card_size
	
	# Set responsive font sizes if theme is available
	_apply_responsive_fonts()
	
	# Setup responsive spacing
	_setup_responsive_spacing()

func _apply_responsive_fonts() -> void:
	"""Apply responsive font sizes based on scale factor."""
	if not theme:
		return
	
	# Apply themed font sizes with responsive scaling (adjusted for smaller card size)
	icon_label.add_theme_font_size_override("font_size", ResponsiveUI.get_responsive_font_size(36, viewport_size))
	title_label.add_theme_font_size_override("font_size", ResponsiveUI.get_responsive_font_size(22, viewport_size))
	description_label.add_theme_font_size_override("font_size", ResponsiveUI.get_responsive_font_size(16, viewport_size))
	level_label.add_theme_font_size_override("font_size", ResponsiveUI.get_responsive_font_size(12, viewport_size))
	
	# Apply themed colors
	icon_label.add_theme_color_override("font_color", theme.get_color("font_color", "CardIcon"))
	title_label.add_theme_color_override("font_color", theme.get_color("font_color", "CardTitle"))
	description_label.add_theme_color_override("font_color", theme.get_color("font_color", "CardDescription"))
	level_label.add_theme_color_override("font_color", theme.get_color("font_color", "BadgeLabel"))

func _setup_responsive_spacing() -> void:
	"""Setup responsive spacing and margins (adjusted for smaller card size)."""
	var base_margin = 15.0 * scale_factor  # Reduced from 20.0
	var base_spacing = 12.0 * scale_factor  # Reduced from 16.0
	
	# Content container spacing
	content_container.add_theme_constant_override("separation", int(base_spacing))
	
	# Spacer sizes (smaller to fit content better)
	top_spacer.custom_minimum_size = Vector2(0, base_margin)
	bottom_spacer.custom_minimum_size = Vector2(0, base_margin)
	icon_container.custom_minimum_size = Vector2(0, 60.0 * scale_factor)  # Reduced from 80.0
	
	# Description margins (tighter spacing)
	var margin_size = int(base_margin * 0.8)  # Even tighter for text margins
	description_margin.add_theme_constant_override("margin_left", margin_size)
	description_margin.add_theme_constant_override("margin_right", margin_size)
	description_margin.add_theme_constant_override("margin_top", int(15.0 * scale_factor))  # Reduced from 10.0
	description_margin.add_theme_constant_override("margin_bottom", int(15.0 * scale_factor))  # Reduced from 10.0

func _setup_signals() -> void:
	"""Connect button and interaction signals."""
	card_button.pressed.connect(_on_card_pressed)
	card_button.mouse_entered.connect(_on_mouse_entered)
	card_button.mouse_exited.connect(_on_mouse_exited)
	card_button.focus_entered.connect(_on_focus_entered)
	card_button.focus_exited.connect(_on_focus_exited)

func _apply_styling() -> void:
	"""Apply visual styling to card elements."""
	if not theme:
		_apply_fallback_styling()
		return
	
	# Get card color for this index
	var card_color = card_colors[card_index % card_colors.size()]
	
	# Create card styles
	original_card_style = theme.get_stylebox("normal", "CardPanel").duplicate()
	hover_card_style = theme.get_stylebox("hover", "CardPanel").duplicate()
	focus_card_style = theme.get_stylebox("focus", "CardPanel").duplicate()
	
	# Apply card-specific color
	if original_card_style is StyleBoxFlat:
		(original_card_style as StyleBoxFlat).bg_color = card_color
	if hover_card_style is StyleBoxFlat:
		var hover_color = card_color.lightened(0.1)
		(hover_card_style as StyleBoxFlat).bg_color = hover_color
	if focus_card_style is StyleBoxFlat:
		var focus_color = card_color.lightened(0.1)
		(focus_card_style as StyleBoxFlat).bg_color = focus_color
	
	# Apply initial style
	card_panel.add_theme_stylebox_override("panel", original_card_style)
	
	# Style button (invisible)
	card_button.flat = true
	card_button.add_theme_stylebox_override("normal", theme.get_stylebox("normal", "CardButton"))
	card_button.add_theme_stylebox_override("hover", theme.get_stylebox("hover", "CardButton"))
	card_button.add_theme_stylebox_override("pressed", theme.get_stylebox("pressed", "CardButton"))
	card_button.add_theme_stylebox_override("focus", theme.get_stylebox("focus", "CardButton"))
	
	# Style level badge
	level_badge.add_theme_stylebox_override("panel", theme.get_stylebox("panel", "BadgePanel"))

func _apply_fallback_styling() -> void:
	"""Apply fallback styling when no theme is available."""
	var card_color = card_colors[card_index % card_colors.size()]
	
	# Create basic StyleBox
	var style = StyleBoxFlat.new()
	style.bg_color = card_color
	style.corner_radius_top_left = 16
	style.corner_radius_top_right = 16
	style.corner_radius_bottom_left = 16
	style.corner_radius_bottom_right = 16
	style.border_width_left = 3
	style.border_width_right = 3
	style.border_width_top = 3
	style.border_width_bottom = 3
	style.border_color = Color(0.8, 0.8, 0.9, 0.8)
	
	card_panel.add_theme_stylebox_override("panel", style)
	
	# Basic button styling
	card_button.flat = true

func _setup_accessibility() -> void:
	"""Setup accessibility features."""
	# Make button focusable
	card_button.focus_mode = Control.FOCUS_ALL
	
	# TODO: Hover tooltip disabled to avoid duplicate descriptions
	# Description is already shown on the card itself
	# if card_resource:
	#	card_button.tooltip_text = card_resource.description

func set_card_resource(value: CardResource) -> void:
	"""Set the card resource and update display."""
	card_resource = value
	if is_node_ready():
		_update_card_display()

func _update_card_display() -> void:
	"""Update card display with current card resource."""
	if not card_resource:
		return
	
	# Update text content
	title_label.text = card_resource.name
	description_label.text = card_resource.description
	icon_label.text = _get_card_icon_symbol(card_resource)
	
	# Update level badge
	if card_resource.level_requirement > 1:
		level_badge.visible = true
		level_label.text = "Lv " + str(card_resource.level_requirement)
		
		# Position level badge in top-right corner (adjusted for smaller card)
		var badge_size = Vector2(45, 18) * scale_factor  # Reduced from 60x24
		level_badge.custom_minimum_size = badge_size
		level_badge.position = Vector2(current_card_size.x - badge_size.x - 8, 8)  # Reduced margins
	else:
		level_badge.visible = false
	
	# Setup text alignment and wrapping
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	description_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	level_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	
	# Update accessibility
	_setup_accessibility()

func _get_card_icon_symbol(card: CardResource) -> String:
	"""Get appropriate icon symbol for card type."""
	if "projectile" in card.card_id.to_lower():
		return "⚡"
	elif "damage" in card.card_id.to_lower():
		return "⚔"
	elif "speed" in card.card_id.to_lower():
		return "⚡"
	elif "range" in card.card_id.to_lower():
		return "🏹"
	else:
		return "⭐"

func _on_card_pressed() -> void:
	"""Handle card selection."""
	Logger.info("CardItem selected: " + (card_resource.name if card_resource else "Unknown"), "ui")
	card_selected.emit(self)

func _on_mouse_entered() -> void:
	"""Handle mouse hover start."""
	if is_hovered:
		return
	
	is_hovered = true
	_update_visual_state()
	card_hovered.emit(self, true)

func _on_mouse_exited() -> void:
	"""Handle mouse hover end."""
	if not is_hovered:
		return
	
	is_hovered = false
	_update_visual_state()
	card_hovered.emit(self, false)

func _on_focus_entered() -> void:
	"""Handle keyboard focus."""
	is_focused = true
	_update_visual_state()
	card_focused.emit(self, true)

func _on_focus_exited() -> void:
	"""Handle keyboard focus lost."""
	is_focused = false
	_update_visual_state()
	card_focused.emit(self, false)

func _update_visual_state() -> void:
	"""Update visual appearance based on current state."""
	var target_style: StyleBox
	var target_modulate: Color = Color.WHITE
	
	if is_focused:
		target_style = focus_card_style if focus_card_style else original_card_style
		target_modulate = Color(1.1, 1.1, 1.1, 1.0)  # Slight brightness increase
	elif is_hovered:
		target_style = hover_card_style if hover_card_style else original_card_style
		target_modulate = Color(1.05, 1.05, 1.05, 1.0)  # Very subtle brightness increase
	else:
		target_style = original_card_style
		target_modulate = Color.WHITE
	
	# Apply style
	if target_style:
		card_panel.add_theme_stylebox_override("panel", target_style)
	
	# Animate modulation instead of scaling to avoid text pixelation
	var tween = create_tween()
	tween.tween_property(self, "modulate", target_modulate, 0.2)

func update_responsive_design() -> void:
	"""Update responsive design when viewport changes."""
	if not is_node_ready():
		return
	
	_setup_responsive_design()
	_apply_responsive_fonts()
	_setup_responsive_spacing()
	_apply_styling()
	
	if card_resource:
		_update_card_display()

func set_focus_to_button() -> void:
	"""Set focus to card button for keyboard navigation."""
	if card_button:
		card_button.grab_focus()

func get_card_button() -> Button:
	"""Get the card's interactive button."""
	return card_button

func animate_selected() -> void:
	"""Play a fast animation when this card is selected, zooming from card center."""
	# Bring to front with highest z-index
	z_index = 1000
	
	# Set pivot to center of the aspect container for proper zoom effect
	aspect_container.pivot_offset = aspect_container.size / 2
	
	var tween = create_tween()
	tween.set_parallel(true)
	
	# Fast scale pulse from center
	tween.tween_property(aspect_container, "scale", Vector2(1.3, 1.3), 0.06)  # Faster and bigger
	tween.tween_method(_set_selected_glow, 0.0, 1.0, 0.06)
	
	await tween.finished
	
	# Very brief hold
	await get_tree().create_timer(0.04).timeout  # Much shorter hold
	
	# Quick return to normal
	var fade_tween = create_tween()
	fade_tween.set_parallel(true)
	fade_tween.tween_property(aspect_container, "scale", Vector2(1.0, 1.0), 0.08)  # Faster return
	fade_tween.tween_method(_set_selected_glow, 1.0, 0.0, 0.08)

func _set_selected_glow(intensity: float) -> void:
	"""Set glow intensity for selected animation."""
	var glow_color = Color.WHITE
	glow_color.a = intensity * 0.3
	modulate = Color.WHITE.lerp(glow_color + Color.WHITE, intensity * 0.2)
