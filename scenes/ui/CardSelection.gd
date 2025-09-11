extends Control
class_name CardSelection

## Modern responsive card selection UI with accessibility and keyboard navigation
## Uses CardItem components and ResponsiveUI for adaptive layouts across all screen sizes

@onready var background: ColorRect = $Background
@onready var center_container: CenterContainer = $CenterContainer
@onready var vbox_container: VBoxContainer = $CenterContainer/VBoxContainer
@onready var title_label: Label = $CenterContainer/VBoxContainer/TitleLabel
@onready var instruction_label: Label = $CenterContainer/VBoxContainer/InstructionLabel
@onready var spacer: Control = $CenterContainer/VBoxContainer/Spacer
@onready var card_margin: MarginContainer = $CenterContainer/VBoxContainer/CardMargin
@onready var card_container: HBoxContainer = $CenterContainer/VBoxContainer/CardMargin/CardContainer

# Theme and responsive properties  
var viewport_size: Vector2
var scale_factor: float = 1.0
var main_theme: MainTheme

# Card system reference and data
var card_system: CardSystem
var available_cards: Array[CardResource] = []
var card_items: Array[CardItem] = []


# Constants
const CARD_ITEM_SCENE = preload("res://scenes/ui/CardItem.tscn")

signal card_selected(card: CardResource)

func _ready() -> void:
	# CardSelection should work during pause
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	hide()
	
	# Setup responsive design
	_setup_responsive_design()
	
	# Load theme from ThemeManager
	_load_theme_from_manager()
	
	# Setup UI styling
	_setup_ui_styling()
	
	
	# Register for theme changes
	if ThemeManager:
		ThemeManager.add_theme_listener(_on_theme_changed)
	
	Logger.info("CardSelection initialized with responsive design", "ui")

func _setup_responsive_design() -> void:
	"""Initialize responsive design system."""
	viewport_size = ResponsiveUI.get_viewport_size(self)
	scale_factor = ResponsiveUI.get_ui_scale_factor(viewport_size)
	
	Logger.debug("CardSelection responsive setup - viewport: " + str(viewport_size) + ", scale: " + str(scale_factor), "ui")
	
	
	# Setup responsive margins
	_setup_responsive_margins()

func _load_theme_from_manager() -> void:
	"""Load theme from ThemeManager."""
	if ThemeManager:
		main_theme = ThemeManager.get_theme()
		Logger.debug("MainTheme loaded from ThemeManager", "ui")
	else:
		Logger.warn("ThemeManager not available, using fallback styling", "ui")

func _setup_ui_styling() -> void:
	"""Apply styling to UI elements using MainTheme."""
	if main_theme:
		# Background styling with theme color
		background.color = main_theme.background_overlay
		
		# Apply MainTheme styling with responsive font sizes
		var title_size = ResponsiveUI.get_responsive_font_size(main_theme.font_size_large, viewport_size)
		var instruction_size = ResponsiveUI.get_responsive_font_size(main_theme.font_size_body, viewport_size)
		
		# Title label - using "title" variant
		main_theme.apply_label_theme(title_label, "title")
		title_label.add_theme_font_size_override("font_size", title_size)
		
		# Instruction label - using "secondary" variant  
		main_theme.apply_label_theme(instruction_label, "secondary")
		instruction_label.add_theme_font_size_override("font_size", instruction_size)
		
		Logger.debug("Applied MainTheme styling to CardSelection", "ui")
	else:
		# Fallback styling
		background.color = Color(0.05, 0.05, 0.15, 0.85)  # Deep blue-black
		title_label.add_theme_font_size_override("font_size", int(48 * scale_factor))
		instruction_label.add_theme_font_size_override("font_size", int(20 * scale_factor))
		title_label.add_theme_color_override("font_color", Color.WHITE)
		instruction_label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.95, 1.0))
		
		Logger.warn("Using fallback styling for CardSelection", "ui")
	
	# Text content and alignment
	title_label.text = "Choose Your Upgrade"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	
	instruction_label.text = "Select a card to enhance your abilities"
	instruction_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


func _setup_responsive_margins() -> void:
	"""Setup responsive margins around card container."""
	var margins = ResponsiveUI.get_safe_area_margins(viewport_size)
	
	card_margin.add_theme_constant_override("margin_left", int(margins.left))
	card_margin.add_theme_constant_override("margin_right", int(margins.right))
	card_margin.add_theme_constant_override("margin_top", int(margins.top * 0.5))
	card_margin.add_theme_constant_override("margin_bottom", int(margins.bottom * 0.5))
	
	# Setup card container spacing (increased for better separation)
	var spacing = ResponsiveUI.calculate_responsive_spacing(60.0, viewport_size)  # Tripled from 20.0
	card_container.add_theme_constant_override("h_separation", int(spacing))
	card_container.add_theme_constant_override("v_separation", int(spacing))


func setup_card_system(card_sys: CardSystem) -> void:
	card_system = card_sys
	if card_system:
		Logger.debug("CardSelection connected to CardSystem", "ui")

func open_with_cards(cards: Array[CardResource]) -> void:
	"""Open card selection with provided cards using responsive design."""
	if cards.is_empty():
		Logger.warn("No cards provided to CardSelection", "ui")
		return
	
	Logger.info("CardSelection opening with " + str(cards.size()) + " cards", "ui")
	
	available_cards = cards
	
	# Update responsive design in case viewport changed
	_update_responsive_design()
	
	# Populate cards using new system
	_populate_card_items()
	
	
	# Show with animation
	show()
	_animate_in()
	
	Logger.info("CardSelection opened with responsive design", "ui")

func _update_responsive_design() -> void:
	"""Update responsive design if viewport changed."""
	var new_viewport_size = ResponsiveUI.get_viewport_size(self)
	if new_viewport_size != viewport_size:
		viewport_size = new_viewport_size
		scale_factor = ResponsiveUI.get_ui_scale_factor(viewport_size)
		
		_setup_responsive_design()
		_load_theme_from_manager()
		_setup_ui_styling()
		
		# Update existing card items
		for card_item in card_items:
			card_item.update_responsive_design()

func _populate_card_items() -> void:
	"""Create CardItem instances for each available card."""
	# Clear existing card items
	for card_item in card_items:
		if card_item:
			card_item.queue_free()
	card_items.clear()
	
	# Create CardItem instances for each card
	for i in range(available_cards.size()):
		var card: CardResource = available_cards[i]
		
		# Create CardItem from scene
		var card_item = CARD_ITEM_SCENE.instantiate() as CardItem
		card_item.card_resource = card
		card_item.card_index = i
		# Apply theme via ThemeManager instead of responsive_theme
		if main_theme and card_item.has_method("apply_theme"):
			card_item.apply_theme(main_theme)
		
		# Connect signals
		card_item.card_selected.connect(_on_card_item_selected)
		card_item.card_hovered.connect(_on_card_item_hovered)
		
		# Add to container
		card_container.add_child(card_item)
		card_items.append(card_item)
	
	Logger.debug("Created " + str(card_items.size()) + " CardItem instances", "ui")

func _on_card_item_selected(card_item: CardItem) -> void:
	"""Handle CardItem selection event."""
	if not card_item or not card_item.card_resource:
		Logger.error("Invalid CardItem selected", "ui")
		return
	
	var selected_card: CardResource = card_item.card_resource
	Logger.info("Card selected: " + selected_card.name, "ui")
	
	# Disable further input during animation
	set_process_unhandled_input(false)
	
	# Play selected animation on the chosen card
	card_item.animate_selected()
	await get_tree().create_timer(0.18).timeout  # Wait for faster card animation to complete (0.06+0.04+0.08)
	
	# Animate out and close
	Logger.debug("Starting card selection close animation", "ui")
	_animate_out()
	
	# Emit selection signal after animation
	await get_tree().create_timer(0.25).timeout
	Logger.debug("Emitting card_selected signal and unpausing", "ui")
	card_selected.emit(selected_card)
	PauseManager.pause_game(false)

func _on_card_item_hovered(card_item: CardItem, is_hovered: bool) -> void:
	"""Handle CardItem hover events."""
	if is_hovered:
		Logger.debug("Card hovered: " + (card_item.card_resource.name if card_item.card_resource else "Unknown"), "ui")
	else:
		Logger.debug("Card hover ended", "ui")


func _animate_in() -> void:
	"""Animate card selection entrance from center toward user."""
	# Set pivot to center for proper scaling
	pivot_offset = size / 2
	
	# Start completely invisible and at center point (scale 0)
	modulate.a = 0.0
	scale = Vector2.ZERO
	
	# Animate from center point outward toward user
	var tween = create_tween()
	tween.set_parallel(true)
	
	# Fade in quickly
	tween.tween_property(self, "modulate:a", 1.0, 0.2)
	
	# Scale from center with slight overshoot for dramatic effect
	var scale_tween = tween.tween_property(self, "scale", Vector2(1.05, 1.05), 0.3)
	scale_tween.set_trans(Tween.TRANS_BACK)
	scale_tween.set_ease(Tween.EASE_OUT)
	
	# Settle to final size
	await scale_tween.finished
	var settle_tween = create_tween()
	settle_tween.tween_property(self, "scale", Vector2.ONE, 0.1)
	
	# Enable input after animation
	await settle_tween.finished
	set_process_unhandled_input(true)

func _animate_out() -> void:
	"""Animate card selection exit back to center."""
	# Ensure pivot is centered
	pivot_offset = size / 2
	
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "modulate:a", 0.0, 0.2)
	tween.tween_property(self, "scale", Vector2.ZERO, 0.2)
	
	await tween.finished
	hide()


func close() -> void:
	"""Close card selection UI."""
	Logger.info("CardSelection closing", "ui")
	_animate_out()
	PauseManager.pause_game(false)

func _on_theme_changed(new_theme: MainTheme) -> void:
	"""Handle theme changes from ThemeManager."""
	main_theme = new_theme
	_setup_ui_styling()
	
	# Update existing card items with new theme
	for card_item in card_items:
		if card_item and card_item.has_method("apply_theme"):
			card_item.apply_theme(main_theme)
	
	Logger.debug("CardSelection updated with new theme", "ui")

func _exit_tree() -> void:
	"""Clean up theme listener when node is removed."""
	if ThemeManager:
		ThemeManager.remove_theme_listener(_on_theme_changed)
