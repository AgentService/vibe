extends Control
class_name CardWidget
## Reusable card widget component with theming and animation support
##
## Provides a consistent card display across the game for abilities, items,
## characters, and other card-based content with rarity colors and hover effects.

@export_group("Card Properties")
@export var card_title: String = "Card Title":
	set(value):
		card_title = value
		if title_label:
			title_label.text = value
			
@export var card_description: String = "Card description text":
	set(value):
		card_description = value
		if description_label:
			description_label.text = value

@export var card_rarity: String = "common":  # common, uncommon, rare, epic, legendary, mythic
	set(value):
		card_rarity = value
		if main_theme:
			update_rarity_styling()

@export var card_icon: Texture2D:
	set(value):
		card_icon = value
		if icon_texture:
			icon_texture.texture = value

@export_group("Card Behavior")
@export var selectable: bool = true         # Can be selected/clicked
@export var hoverable: bool = true         # Shows hover effects
@export var auto_theme: bool = true        # Automatically apply theme
@export var show_rarity_glow: bool = true  # Show glow effect for higher rarities

@export_group("Animation Settings")
@export var hover_lift: float = -8.0       # Pixels to lift on hover
@export var hover_scale: float = 1.02      # Scale factor on hover
@export var animation_speed: float = 0.2   # Animation duration

# UI References
@onready var card_panel: ThemedPanel = $CardPanel
@onready var content_margin: MarginContainer = $CardPanel/ContentMargin
@onready var main_vbox: VBoxContainer = $CardPanel/ContentMargin/MainVBox

@onready var header_container: HBoxContainer = $CardPanel/ContentMargin/MainVBox/HeaderContainer
@onready var icon_texture: TextureRect = $CardPanel/ContentMargin/MainVBox/HeaderContainer/IconTexture
@onready var title_label: Label = $CardPanel/ContentMargin/MainVBox/HeaderContainer/TitleLabel

@onready var description_label: Label = $CardPanel/ContentMargin/MainVBox/DescriptionLabel
@onready var footer_container: HBoxContainer = $CardPanel/ContentMargin/MainVBox/FooterContainer
@onready var rarity_label: Label = $CardPanel/ContentMargin/MainVBox/FooterContainer/RarityLabel

# Internal state
var main_theme: MainTheme
var original_position: Vector2
var is_hovering: bool = false
var is_selected: bool = false
var hover_tween: Tween
var select_tween: Tween

# Card signals
signal card_selected(card_widget: CardWidget)
signal card_hovered(card_widget: CardWidget, is_hovering: bool)
signal card_right_clicked(card_widget: CardWidget)

func _ready() -> void:
	# Store original position for hover animations
	original_position = position
	
	# Load theme if auto theming is enabled
	if auto_theme:
		load_theme_from_manager()
	
	# Setup interactivity
	if selectable or hoverable:
		setup_mouse_interaction()
	
	# Register for theme changes
	if ThemeManager:
		ThemeManager.add_theme_listener(_on_theme_changed)
	
	# Apply initial values to UI elements
	update_card_display()
	
	Logger.debug("CardWidget initialized: %s (%s)" % [card_title, card_rarity], "ui")

func load_theme_from_manager() -> void:
	"""Load and apply theme from ThemeManager."""
	if ThemeManager:
		main_theme = ThemeManager.get_theme()
		apply_card_theme()
	else:
		Logger.warn("ThemeManager not available for CardWidget", "ui")

func apply_card_theme() -> void:
	"""Apply MainTheme to this card widget."""
	if not main_theme:
		return
	
	# Apply card panel theming
	if card_panel:
		card_panel.set_panel_variant("card")
	
	# Apply text theming
	if title_label:
		main_theme.apply_label_theme(title_label, "header")
	
	if description_label:
		main_theme.apply_label_theme(description_label, "")
	
	if rarity_label:
		main_theme.apply_label_theme(rarity_label, "caption")
	
	# Apply rarity-specific styling
	update_rarity_styling()
	
	Logger.debug("Applied theme to card: %s" % card_title, "ui")

func update_rarity_styling() -> void:
	"""Update styling based on card rarity."""
	if not main_theme:
		return
	
	var rarity_color = main_theme.get_card_color(card_rarity)
	
	# Apply rarity color to panel border
	if card_panel:
		var style_box = main_theme.get_themed_style_box("card_panel").duplicate()
		if style_box is StyleBoxFlat:
			var flat_style = style_box as StyleBoxFlat
			flat_style.border_color = rarity_color
			# Increase border width for higher rarities
			var border_width = _get_rarity_border_width(card_rarity)
			flat_style.set_border_width_all(border_width)
		card_panel.add_theme_stylebox_override("panel", style_box)
	
	# Update rarity label
	if rarity_label:
		rarity_label.text = card_rarity.capitalize()
		rarity_label.add_theme_color_override("font_color", rarity_color)
	
	# Apply glow effect for higher rarities
	if show_rarity_glow:
		apply_rarity_glow(card_rarity)

func _get_rarity_border_width(rarity: String) -> int:
	"""Get border width based on rarity."""
	match rarity.to_lower():
		"common": return 1
		"uncommon": return 2
		"rare": return 2
		"epic": return 3
		"legendary": return 3
		"mythic": return 4
		_: return 1

func apply_rarity_glow(rarity: String) -> void:
	"""Apply glow effect based on rarity."""
	match rarity.to_lower():
		"epic", "legendary", "mythic":
			# Add subtle glow for high-tier cards
			modulate = Color(1.05, 1.05, 1.05, 1.0)
		_:
			modulate = Color.WHITE

# ============================================================================
# MOUSE INTERACTION
# ============================================================================

func setup_mouse_interaction() -> void:
	"""Setup mouse interaction for hoverable/selectable cards."""
	mouse_filter = Control.MOUSE_FILTER_PASS
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)

func _gui_input(event: InputEvent) -> void:
	"""Handle card input events."""
	if event is InputEventMouseButton:
		var mouse_event = event as InputEventMouseButton
		
		if mouse_event.pressed:
			if mouse_event.button_index == MOUSE_BUTTON_LEFT and selectable:
				select_card()
			elif mouse_event.button_index == MOUSE_BUTTON_RIGHT:
				card_right_clicked.emit(self)

func _on_mouse_entered() -> void:
	"""Handle mouse enter."""
	if not hoverable:
		return
	
	is_hovering = true
	card_hovered.emit(self, true)
	
	animate_hover(true)

func _on_mouse_exited() -> void:
	"""Handle mouse exit."""
	if not hoverable:
		return
	
	is_hovering = false
	card_hovered.emit(self, false)
	
	if not is_selected:
		animate_hover(false)

# ============================================================================
# ANIMATIONS
# ============================================================================

func animate_hover(hover_in: bool) -> void:
	"""Animate hover effect."""
	if hover_tween:
		hover_tween.kill()
	
	hover_tween = create_tween()
	hover_tween.set_parallel(true)
	hover_tween.set_ease(Tween.EASE_OUT)
	hover_tween.set_trans(Tween.TRANS_QUART)
	
	var target_position = original_position
	var target_scale = Vector2.ONE
	
	if hover_in:
		target_position = original_position + Vector2(0, hover_lift)
		target_scale = Vector2.ONE * hover_scale
	
	hover_tween.tween_property(self, "position", target_position, animation_speed)
	hover_tween.tween_property(self, "scale", target_scale, animation_speed)

func animate_select() -> void:
	"""Animate card selection."""
	if select_tween:
		select_tween.kill()
	
	select_tween = create_tween()
	select_tween.set_ease(Tween.EASE_OUT)
	select_tween.set_trans(Tween.TRANS_BACK)
	
	# Quick scale up and down
	select_tween.tween_property(self, "scale", Vector2.ONE * 1.1, 0.1)
	select_tween.tween_property(self, "scale", Vector2.ONE * hover_scale, 0.1)

# ============================================================================
# CARD ACTIONS
# ============================================================================

func select_card() -> void:
	"""Select this card."""
	is_selected = true
	animate_select()
	card_selected.emit(self)
	
	Logger.debug("Card selected: %s" % card_title, "ui")

func deselect_card() -> void:
	"""Deselect this card."""
	is_selected = false
	if not is_hovering:
		animate_hover(false)

func highlight_card(color: Color = Color.YELLOW, duration: float = 0.5) -> void:
	"""Highlight card with color briefly."""
	var original_modulate = modulate
	
	var highlight_tween = create_tween()
	highlight_tween.tween_property(self, "modulate", color, duration * 0.3)
	highlight_tween.tween_property(self, "modulate", original_modulate, duration * 0.7)

func shake_card(intensity: float = 5.0, duration: float = 0.5) -> void:
	"""Shake card to indicate error or unavailable."""
	var shake_tween = create_tween()
	shake_tween.set_loops(int(duration * 10))
	
	var random_offset = Vector2(randf_range(-intensity, intensity), randf_range(-intensity, intensity))
	shake_tween.tween_property(self, "position", original_position + random_offset, 0.05)
	shake_tween.tween_property(self, "position", original_position, 0.05)

# ============================================================================
# CONTENT MANAGEMENT
# ============================================================================

func update_card_display() -> void:
	"""Update all card display elements."""
	if title_label:
		title_label.text = card_title
	
	if description_label:
		description_label.text = card_description
	
	if icon_texture and card_icon:
		icon_texture.texture = card_icon
		icon_texture.visible = true
	elif icon_texture:
		icon_texture.visible = false
	
	if rarity_label:
		rarity_label.text = card_rarity.capitalize()

func set_card_data(data: Dictionary) -> void:
	"""Set card data from dictionary."""
	if data.has("title"):
		card_title = data.title
	
	if data.has("description"):
		card_description = data.description
	
	if data.has("rarity"):
		card_rarity = data.rarity
	
	if data.has("icon") and data.icon is Texture2D:
		card_icon = data.icon
	
	update_card_display()
	
	if main_theme:
		apply_card_theme()

func get_card_data() -> Dictionary:
	"""Get card data as dictionary."""
	return {
		"title": card_title,
		"description": card_description,
		"rarity": card_rarity,
		"icon": card_icon,
		"selected": is_selected,
		"hovering": is_hovering
	}

# ============================================================================
# THEME INTEGRATION
# ============================================================================

func _on_theme_changed(new_theme: MainTheme) -> void:
	"""Handle theme changes."""
	main_theme = new_theme
	if auto_theme:
		apply_card_theme()

# ============================================================================
# FACTORY METHODS
# ============================================================================

static func create_ability_card(ability_data: Dictionary) -> CardWidget:
	"""Create a card for an ability."""
	var card = CardWidget.new()
	card.set_card_data(ability_data)
	return card

static func create_item_card(item_data: Dictionary) -> CardWidget:
	"""Create a card for an item."""
	var card = CardWidget.new()
	card.set_card_data(item_data)
	return card

static func create_simple_card(title: String, description: String, rarity: String = "common") -> CardWidget:
	"""Create a simple card with basic info."""
	var card = CardWidget.new()
	card.card_title = title
	card.card_description = description
	card.card_rarity = rarity
	return card

# ============================================================================
# ACCESSIBILITY AND DEBUG
# ============================================================================

func get_card_info() -> Dictionary:
	"""Get card information for debugging."""
	return {
		"title": card_title,
		"description": card_description,
		"rarity": card_rarity,
		"selectable": selectable,
		"hoverable": hoverable,
		"selected": is_selected,
		"hovering": is_hovering,
		"theme_available": main_theme != null
	}

# ============================================================================
# CLEANUP
# ============================================================================

func _exit_tree() -> void:
	"""Clean up when card is removed."""
	if ThemeManager:
		ThemeManager.remove_theme_listener(_on_theme_changed)
	
	# Clean up tweens
	if hover_tween:
		hover_tween.kill()
	if select_tween:
		select_tween.kill()
	
	Logger.debug("CardWidget cleaned up: %s" % card_title, "ui")