extends Node2D

## Isolated card system test - card selection UI and application.
## Tests card pools, selection mechanics, and card application to stats.

@onready var info_label: Label = $UILayer/HUD/InfoLabel
@onready var card_display: Control = $UILayer/CardDisplay
@onready var card_container: VBoxContainer = $UILayer/CardDisplay/CardContainer

var card_system: CardSystem
var current_level: int = 1
var available_cards: Array = []
var selected_card: int = -1

# Mock RunManager for testing
var mock_stats: Dictionary = {
	"melee_damage": 25.0,
	"melee_attack_speed": 1.0,
	"melee_range": 50.0,
	"health": 100.0,
	"movement_speed": 300.0,
	"melee_cone_angle": 90.0
}

func _ready():
	print("=== CardSystem_Isolated Test Started ===")
	print("Controls: Space to get cards, 1-3 to select card, + - to change level")
	
	_setup_card_system()
	_setup_ui()
	

func _setup_card_system():
	card_system = CardSystem.new()
	add_child(card_system)
	
	# Connect to card events
	if card_system.has_signal("card_pools_loaded"):
		card_system.card_pools_loaded.connect(_on_card_pools_loaded)
	if card_system.has_signal("cards_selected"):
		card_system.cards_selected.connect(_on_cards_selected)
	
	# Setup fallback if no pools load
	call_deferred("_check_fallback_setup")

func _check_fallback_setup():
	if card_system.card_pools.is_empty():
		print("No card pools loaded, creating fallback cards")
		_setup_fallback_cards()

func _setup_fallback_cards():
	# Create fallback card definitions
	var fallback_cards = [
		{
			"name": "Damage Boost",
			"description": "Increases melee damage by 10",
			"level_required": 1,
			"effects": {"melee_damage": 10.0}
		},
		{
			"name": "Attack Speed",
			"description": "Increases attack speed by 0.2",
			"level_required": 1,
			"effects": {"melee_attack_speed": 0.2}
		},
		{
			"name": "Extended Reach",
			"description": "Increases melee range by 15",
			"level_required": 2,
			"effects": {"melee_range": 15.0}
		},
		{
			"name": "Vitality",
			"description": "Increases health by 25",
			"level_required": 1,
			"effects": {"health": 25.0}
		},
		{
			"name": "Swift Movement",
			"description": "Increases movement speed by 50",
			"level_required": 3,
			"effects": {"movement_speed": 50.0}
		}
	]
	
	# Store fallback cards for selection
	card_system.fallback_cards = fallback_cards

func _setup_ui():
	# Setup card display container
	card_display.anchors_preset = Control.PRESET_CENTER
	card_display.size = Vector2(600, 400)
	card_display.visible = false
	
	# Add background to card display
	var bg = ColorRect.new()
	bg.color = Color(0.1, 0.1, 0.1, 0.8)
	bg.anchors_preset = Control.PRESET_FULL_RECT
	card_display.add_child(bg)
	card_display.move_child(bg, 0)  # Move to back

func _unhandled_input(event):
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_SPACE:
				_get_card_selection()
			KEY_ESCAPE:
				_close_card_display()
			KEY_1:
				_select_card(0)
			KEY_2:
				_select_card(1)
			KEY_3:
				_select_card(2)
			KEY_EQUAL, KEY_PLUS:
				current_level = min(current_level + 1, 10)
				print("Level increased to: ", current_level)
			KEY_MINUS:
				current_level = max(current_level - 1, 1)
				print("Level decreased to: ", current_level)

func _get_card_selection():
	print("Getting card selection for level: ", current_level)
	
	# Clear previous selection
	available_cards.clear()
	selected_card = -1
	
	# Try to get cards from card system
	if card_system.has_method("get_card_selection"):
		available_cards = card_system.get_card_selection(current_level, 3)
	
	# Fallback to manual selection if no cards from system
	if available_cards.is_empty() and card_system.has("fallback_cards"):
		available_cards = _get_fallback_selection(current_level, 3)
	
	if available_cards.is_empty():
		print("No cards available at level ", current_level)
		return
	
	_show_card_selection()

func _get_fallback_selection(level: int, count: int) -> Array:
	if not card_system.has("fallback_cards"):
		return []
	
	var suitable_cards = card_system.fallback_cards.filter(
		func(card): return card["level_required"] <= level
	)
	
	# Shuffle and take up to count cards
	suitable_cards.shuffle()
	return suitable_cards.slice(0, min(count, suitable_cards.size()))

func _show_card_selection():
	card_display.visible = true
	
	# Clear previous cards
	for child in card_container.get_children():
		child.queue_free()
	
	# Create card buttons
	for i in range(available_cards.size()):
		var card = available_cards[i]
		var card_button = _create_card_button(card, i)
		card_container.add_child(card_button)

func _create_card_button(card, index: int) -> Control:
	var card_panel = PanelContainer.new()
	card_panel.custom_minimum_size = Vector2(180, 100)
	
	var vbox = VBoxContainer.new()
	card_panel.add_child(vbox)
	
	# Card name
	var name_label = Label.new()
	if card is Dictionary and card.has("name"):
		name_label.text = card["name"]
	elif card is CardResource and card.name != "":
		name_label.text = card.name
	elif card.has_method("get_display_name"):
		name_label.text = card.get_display_name()
	else:
		name_label.text = "Unknown Card"
	name_label.add_theme_font_size_override("font_size", 16)
	vbox.add_child(name_label)
	
	# Card description
	var desc_label = Label.new()
	if card is Dictionary and card.has("description"):
		desc_label.text = card["description"]
	elif card is CardResource and card.description != "":
		desc_label.text = card.description
	elif card.has_method("get_description"):
		desc_label.text = card.get_description()
	else:
		desc_label.text = "No description"
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.add_theme_font_size_override("font_size", 12)
	vbox.add_child(desc_label)
	
	# Selection key
	var key_label = Label.new()
	key_label.text = "Press " + str(index + 1) + " to select"
	key_label.add_theme_font_size_override("font_size", 10)
	key_label.modulate = Color.GRAY
	vbox.add_child(key_label)
	
	return card_panel

func _select_card(index: int):
	if index < 0 or index >= available_cards.size():
		return
	
	selected_card = index
	var card = available_cards[index]
	
	print("Selected card: ", _get_card_name(card))
	_apply_card(card)
	_close_card_display()

func _apply_card(card):
	print("Applying card: ", _get_card_name(card))
	
	# Apply card effects to mock stats
	var effects: Dictionary
	if card is Dictionary and card.has("effects"):
		effects = card["effects"]
	elif card is CardResource and not card.modifiers.is_empty():
		effects = card.modifiers
	elif card.has_method("get_effects"):
		effects = card.get_effects()
	else:
		print("Card has no effects to apply")
		return
	
	for modifier_key in effects.keys():
		# Map CardResource modifier keys to mock stats
		var stat_key = _map_modifier_to_stat(modifier_key)
		if stat_key != "":
			var old_value = mock_stats.get(stat_key, 0.0)
			var new_value: float
			
			# Handle different modifier types
			if modifier_key.ends_with("_mult"):
				# Multiplicative modifier (e.g., 1.2 = 20% increase)
				new_value = old_value * effects[modifier_key]
			else:
				# Additive modifier (default)
				new_value = old_value + effects[modifier_key]
			
			mock_stats[stat_key] = new_value
			var modifier_type = "mult" if modifier_key.ends_with("_mult") else "add"
			print("  ", modifier_key, " (", modifier_type, ") -> ", stat_key, ": ", old_value, " -> ", new_value)
		else:
			print("  Unknown modifier: ", modifier_key)

func _close_card_display():
	card_display.visible = false
	available_cards.clear()
	selected_card = -1

func _map_modifier_to_stat(modifier_key: String) -> String:
	# Map CardResource modifier keys to mock stats keys
	var mapping = {
		"melee_damage_add": "melee_damage",
		"melee_damage_mult": "melee_damage",
		"melee_attack_speed_add": "melee_attack_speed",
		"melee_attack_speed_mult": "melee_attack_speed", 
		"melee_range_add": "melee_range",
		"melee_range_mult": "melee_range",
		"health_add": "health",
		"health_mult": "health",
		"movement_speed_add": "movement_speed",
		"movement_speed_mult": "movement_speed",
		"melee_cone_angle_add": "melee_cone_angle"  # New stat for cone angle
	}
	
	return mapping.get(modifier_key, "")

func _test_card_selection():
	# Call this in a few frames to allow card selection to complete
	call_deferred("_delayed_test")

func _delayed_test():
	if available_cards.size() > 0:
		print("=== Testing Card Selection ===")
		print("Available cards: ", available_cards.size())
		
		# Select the first card for testing
		_select_card(0)
		
		print("=== Final Stats ===")
		for stat in mock_stats.keys():
			print("  ", stat, ": ", mock_stats[stat])

func _get_card_name(card) -> String:
	if card is Dictionary and card.has("name"):
		return card["name"]
	elif card is CardResource and card.name != "":
		return card.name
	elif card.has_method("get_display_name"):
		return card.get_display_name()
	else:
		return "Unknown Card"

func _on_card_pools_loaded():
	print("Card pools loaded successfully")
	var pool_names = card_system.get_pool_names() if card_system.has_method("get_pool_names") else []
	print("Available pools: ", pool_names)

func _on_cards_selected(cards: Array):
	print("Cards selected from system: ", cards.size())

func _process(_delta):
	_update_info_display()

func _update_info_display():
	var pool_count = 0
	var pool_names: Array = []
	
	if card_system.has_method("get_pool_count"):
		pool_count = card_system.get_pool_count()
	if card_system.has_method("get_pool_names"):
		pool_names = card_system.get_pool_names()
	
	info_label.text = "Card System Test\n"
	info_label.text += "Space: Get card selection\n"
	info_label.text += "1-3: Select card\n"
	info_label.text += "+/-: Change level\n"
	info_label.text += "ESC: Close card display\n\n"
	info_label.text += "Current level: " + str(current_level) + "\n"
	info_label.text += "Card pools: " + str(pool_count) + "\n"
	info_label.text += "Pool names: " + str(pool_names) + "\n\n"
	info_label.text += "Current Stats:\n"
	for stat in mock_stats.keys():
		info_label.text += "  " + stat + ": " + str(mock_stats[stat]) + "\n"
