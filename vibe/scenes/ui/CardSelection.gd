extends Control
class_name CardSelection

## Modern card selection UI with full-screen overlay and hover effects.
## Displays 3 cards horizontally with smooth animations and modern styling.

@onready var background: ColorRect = $Background
@onready var card_container: HBoxContainer = $CenterContainer/VBoxContainer/CardContainer
@onready var title_label: Label = $CenterContainer/VBoxContainer/TitleLabel
@onready var instruction_label: Label = $CenterContainer/VBoxContainer/InstructionLabel

var card_system: CardSystem
var available_cards: Array[CardResource] = []
var card_containers: Array[Control] = []

signal card_selected(card: CardResource)

func _ready() -> void:
	# CardSelection should work during pause
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	hide()
	
	# Setup background with subtle gradient effect
	background.color = Color(0.05, 0.05, 0.15, 0.85)  # Deep blue-black
	
	# Setup labels with modern styling
	title_label.text = "Choose Your Upgrade"
	title_label.add_theme_font_size_override("font_size", 48)
	title_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))
	title_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.5))
	title_label.add_theme_constant_override("shadow_offset_x", 2)
	title_label.add_theme_constant_override("shadow_offset_y", 2)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	
	instruction_label.text = "Select a card to enhance your abilities"
	instruction_label.add_theme_font_size_override("font_size", 20)
	instruction_label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.95, 1.0))
	instruction_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

func setup_card_system(card_sys: CardSystem) -> void:
	card_system = card_sys
	if card_system:
		Logger.debug("CardSelection connected to CardSystem", "ui")

func open_with_cards(cards: Array[CardResource]) -> void:
	if cards.is_empty():
		Logger.warn("No cards provided to CardSelection", "ui")
		return
	
	Logger.info("CardSelection opening with " + str(cards.size()) + " cards", "ui")
	Logger.debug("Game paused state: " + str(get_tree().paused), "ui")
	
	available_cards = cards
	_populate_cards()
	show()
	
	# Animate in
	modulate.a = 0.0
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.3)
	
	Logger.info("CardSelection opened and visible: " + str(visible), "ui")

func _populate_cards() -> void:
	# Clear existing card containers
	for container in card_containers:
		if container:
			container.queue_free()
	card_containers.clear()
	
	# Create card containers for each card with proper spacing
	for i in range(available_cards.size()):
		var card: CardResource = available_cards[i]
		
		# Create margin container for spacing
		var margin_container: MarginContainer = MarginContainer.new()
		margin_container.add_theme_constant_override("margin_left", 40)
		margin_container.add_theme_constant_override("margin_right", 40)
		
		# Create the actual card
		var card_cont: Control = _create_card_button(card, i)
		margin_container.add_child(card_cont)
		
		card_container.add_child(margin_container)
		card_containers.append(margin_container)
	
	Logger.debug("Created " + str(card_containers.size()) + " card containers", "ui")

func _create_card_button(card: CardResource, index: int) -> Control:
	# Create main card container
	var main_card: Control = Control.new()
	main_card.custom_minimum_size = Vector2(320, 450)
	main_card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	
	# Create background panel
	var panel: Panel = Panel.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	main_card.add_child(panel)
	
	# Modern card styling with gradient-like effect
	var card_colors = [
		Color(0.15, 0.25, 0.4, 0.95),  # Deep blue
		Color(0.25, 0.15, 0.4, 0.95),  # Purple
		Color(0.4, 0.2, 0.15, 0.95),   # Dark red/brown
		Color(0.15, 0.4, 0.25, 0.95),  # Forest green
		Color(0.4, 0.35, 0.15, 0.95),  # Gold/bronze
	]
	
	var style_normal: StyleBoxFlat = StyleBoxFlat.new()
	style_normal.bg_color = card_colors[index % card_colors.size()]
	style_normal.border_width_left = 3
	style_normal.border_width_right = 3
	style_normal.border_width_top = 3
	style_normal.border_width_bottom = 3
	style_normal.border_color = Color(0.8, 0.8, 0.9, 0.8)
	style_normal.corner_radius_top_left = 16
	style_normal.corner_radius_top_right = 16
	style_normal.corner_radius_bottom_left = 16
	style_normal.corner_radius_bottom_right = 16
	style_normal.shadow_color = Color(0, 0, 0, 0.3)
	style_normal.shadow_size = 8
	style_normal.shadow_offset = Vector2(4, 4)
	panel.add_theme_stylebox_override("panel", style_normal)
	
	# Create content layout
	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 16)
	main_card.add_child(vbox)
	
	# Add top spacer for padding
	var top_spacer: Control = Control.new()
	top_spacer.custom_minimum_size = Vector2(0, 20)
	vbox.add_child(top_spacer)
	
	# Create visual icon area (no background circle)
	var icon_container: CenterContainer = CenterContainer.new()
	icon_container.custom_minimum_size = Vector2(0, 80)
	vbox.add_child(icon_container)
	
	# Add icon symbol directly without background - much bigger
	var icon_label: Label = Label.new()
	icon_label.text = _get_card_icon_symbol(card)
	icon_label.add_theme_font_size_override("font_size", 48)
	icon_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.9))
	icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	icon_container.add_child(icon_label)
	
	# Card title
	var card_title_label: Label = Label.new()
	card_title_label.text = card.name
	card_title_label.add_theme_font_size_override("font_size", 24)
	card_title_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))
	card_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card_title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(card_title_label)
	
	# Description with proper padding
	var desc_container: MarginContainer = MarginContainer.new()
	desc_container.add_theme_constant_override("margin_left", 20)
	desc_container.add_theme_constant_override("margin_right", 20)
	desc_container.add_theme_constant_override("margin_top", 10)
	desc_container.add_theme_constant_override("margin_bottom", 10)
	vbox.add_child(desc_container)
	
	var description_label: Label = Label.new()
	description_label.text = card.description
	description_label.add_theme_font_size_override("font_size", 16)
	description_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9, 1.0))
	description_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	desc_container.add_child(description_label)
	
	# Level requirement badge if > 1
	if card.level_requirement > 1:
		var level_badge: Panel = Panel.new()
		level_badge.custom_minimum_size = Vector2(60, 24)
		level_badge.position = Vector2(main_card.size.x - 70, 10)
		main_card.add_child(level_badge)
		
		var badge_style: StyleBoxFlat = StyleBoxFlat.new()
		badge_style.bg_color = Color(0.8, 0.4, 0.0, 0.9)
		badge_style.corner_radius_top_left = 12
		badge_style.corner_radius_top_right = 12
		badge_style.corner_radius_bottom_left = 12
		badge_style.corner_radius_bottom_right = 12
		level_badge.add_theme_stylebox_override("panel", badge_style)
		
		var level_label: Label = Label.new()
		level_label.text = "Lv " + str(card.level_requirement)
		level_label.add_theme_font_size_override("font_size", 12)
		level_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))
		level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		level_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		level_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		level_badge.add_child(level_label)
	
	# Add bottom spacer
	var bottom_spacer: Control = Control.new()
	bottom_spacer.custom_minimum_size = Vector2(0, 20)
	vbox.add_child(bottom_spacer)
	
	# Create invisible button for click detection
	var button: Button = Button.new()
	button.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	button.flat = true
	button.text = ""
	main_card.add_child(button)
	
	# Connect signals
	button.pressed.connect(_on_card_selected.bind(index))
	button.mouse_entered.connect(_on_card_hover_start.bind(main_card, panel, style_normal))
	button.mouse_exited.connect(_on_card_hover_end.bind(main_card, panel, style_normal))
	
	return main_card

func _on_card_selected(card_index: int) -> void:
	Logger.debug("Card selection callback triggered for index: " + str(card_index), "ui")
	
	if card_index < 0 or card_index >= available_cards.size():
		Logger.error("Invalid card index selected: " + str(card_index), "ui")
		return
	
	var selected_card: CardResource = available_cards[card_index]
	Logger.info("Card selected: " + selected_card.name, "ui")
	
	# Animate out
	Logger.debug("Starting card selection close animation", "ui")
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.2)
	tween.tween_callback(func(): 
		hide()
		Logger.debug("Card selection hidden", "ui")
		# Emit selection and unpause AFTER UI is hidden
		Logger.debug("Emitting card_selected signal and unpausing", "ui")
		card_selected.emit(selected_card)
		PauseManager.pause_game(false)
	)

func _get_card_icon_symbol(card: CardResource) -> String:
	# Return appropriate symbols based on card type
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

func _on_card_hover_start(main_card: Control, panel: Panel, original_style: StyleBoxFlat) -> void:
	# Enhanced hover animation
	var tween = create_tween()
	tween.parallel().tween_property(main_card, "scale", Vector2(1.08, 1.08), 0.2)
	tween.parallel().tween_property(main_card, "rotation", 0.015, 0.2)
	
	# Brighten the card on hover
	var hover_style: StyleBoxFlat = original_style.duplicate()
	hover_style.bg_color = Color(hover_style.bg_color.r + 0.1, hover_style.bg_color.g + 0.1, hover_style.bg_color.b + 0.1, hover_style.bg_color.a)
	hover_style.border_color = Color(1.0, 1.0, 1.0, 1.0)
	hover_style.shadow_size = 12
	panel.add_theme_stylebox_override("panel", hover_style)

func _on_card_hover_end(main_card: Control, panel: Panel, original_style: StyleBoxFlat) -> void:
	# Return to normal
	var tween = create_tween()
	tween.parallel().tween_property(main_card, "scale", Vector2.ONE, 0.2)
	tween.parallel().tween_property(main_card, "rotation", 0.0, 0.2)
	
	# Restore original style
	panel.add_theme_stylebox_override("panel", original_style)

func close() -> void:
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.2)
	tween.tween_callback(func(): hide())
	
	PauseManager.pause_game(false)
