extends Control
class_name CardPicker

## Card picker UI that displays 3 card options and handles selection.
## Pauses/resumes game flow via RunManager.

@onready var card_container: HBoxContainer = $PanelContainer/VBoxContainer/CardContainer
@onready var title_label: Label = $PanelContainer/VBoxContainer/TitleLabel

var card_system: CardSystem
var available_cards: Array = []

func _ready() -> void:
	# CardPicker should work during pause
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	hide()
	card_system = CardSystem.new()
	add_child(card_system)

func open() -> void:
	Logger.debug("CardPicker opening...", "ui")
	available_cards = card_system.roll_three()
	Logger.debug("Available cards: " + str(available_cards.size()), "ui")
	_populate_cards()
	show()
	Logger.debug("CardPicker visibility: " + str(visible), "ui")

func _populate_cards() -> void:
	# Clear existing buttons
	for child in card_container.get_children():
		child.queue_free()
	
	# Create buttons for each card
	for i in range(available_cards.size()):
		var card = available_cards[i]
		var button: Button = Button.new()
		button.text = card.get_display_text()
		button.custom_minimum_size = Vector2(150, 80)
		button.pressed.connect(_on_card_selected.bind(i))
		card_container.add_child(button)

func _on_card_selected(card_index: int) -> void:
	if card_index < 0 or card_index >= available_cards.size():
		return
	
	var selected_card = available_cards[card_index]
	card_system.apply(selected_card)
	
	PauseManager.pause_game(false)
	hide()
