extends Resource
class_name CardPoolResource

## Resource containing a themed collection of cards.
## Supports weighted random selection and level-based filtering.

@export var pool_name: String = ""
@export var theme: String = ""
@export var card_list: Array[CardResource] = []

func get_available_cards_at_level(level: int) -> Array[CardResource]:
	var available: Array[CardResource] = []
	for card in card_list:
		if card.is_available_at_level(level):
			available.append(card)
	return available

func get_total_weight_at_level(level: int) -> int:
	var total: int = 0
	for card in card_list:
		if card.is_available_at_level(level):
			total += card.weight
	return total

func get_card_count() -> int:
	return card_list.size()

func get_available_card_count_at_level(level: int) -> int:
	return get_available_cards_at_level(level).size()

func select_weighted_card(available_cards: Array[CardResource], rng_stream: String) -> CardResource:
	if available_cards.is_empty():
		Logger.warn("No available cards to select from", "cards")
		return null
	
	# Calculate total weight
	var total_weight: float = 0.0
	for card in available_cards:
		total_weight += card.weight
	
	# Select random card based on weight
	var random_value: float = RNG.randf_range(rng_stream, 0.0, total_weight)
	var current_weight: float = 0.0
	
	for card in available_cards:
		current_weight += card.weight
		if random_value <= current_weight:
			return card
	
	# Fallback to last card if rounding errors
	return available_cards[-1]

func select_multiple_cards(level: int, count: int, rng_stream: String) -> Array[CardResource]:
	var available_cards: Array[CardResource] = get_available_cards_at_level(level)
	var selected_cards: Array[CardResource] = []
	var used_cards: Array[CardResource] = []
	
	# Ensure we don't try to select more cards than available
	var max_selections: int = min(count, available_cards.size())
	
	for i in range(max_selections):
		# Remove already selected cards from consideration
		var remaining_cards: Array[CardResource] = []
		for card in available_cards:
			if card not in used_cards:
				remaining_cards.append(card)
		
		if remaining_cards.is_empty():
			break
		
		var selected_card: CardResource = select_weighted_card(remaining_cards, rng_stream)
		if selected_card:
			selected_cards.append(selected_card)
			used_cards.append(selected_card)
	
	if Logger.is_level_enabled(Logger.LogLevel.DEBUG):
		Logger.debug("Selected " + str(selected_cards.size()) + " cards from pool: " + pool_name, "cards")
	return selected_cards