extends Node
class_name CardSystem

## Manages card selection and stat modification for level-up rewards.
## Loads weighted card pools from .tres resources and applies stat modifications to RunManager.

var card_pool: CardPool

func _ready() -> void:
	_load_card_pool()

func _load_card_pool() -> void:
	var file_path: String = "res://data/cards/card_pool.tres"
	Logger.debug("Loading card pool from: " + file_path, "player")
	
	if not ResourceLoader.exists(file_path):
		push_error("Card pool file not found: " + file_path)
		return
	
	var loaded_resource = ResourceLoader.load(file_path)
	if not loaded_resource:
		push_error("Failed to load card pool resource: " + file_path)
		return
	
	card_pool = loaded_resource as CardPool
	if not card_pool:
		push_error("Loaded resource is not a CardPool: " + file_path)
		return
	
	Logger.info("Card pool loaded with " + str(card_pool.get_card_count()) + " cards", "player")

func roll_three() -> Array:
	if not card_pool or card_pool.pool.is_empty():
		push_error("Card pool is empty or malformed")
		return []
	
	var selected_cards: Array = []
	var current_level: int = RunManager.stats.get("level", 1)
	
	# Filter cards based on current level
	var available_cards: Array = card_pool.get_available_cards_at_level(current_level)
	
	if available_cards.is_empty():
		push_error("No cards available for level " + str(current_level))
		return []
	
	# Calculate total weight from available cards
	var total_weight: float = 0.0
	for card in available_cards:
		total_weight += card.weight
	
	# Select 3 unique cards from available cards
	var used_indices: Array[int] = []
	while selected_cards.size() < 3 and used_indices.size() < available_cards.size():
		var random_value: float = RNG.randf_range("loot", 0.0, total_weight)
		var current_weight: float = 0.0
		
		for i in range(available_cards.size()):
			if i in used_indices:
				continue
			
			var card = available_cards[i]
			current_weight += card.weight
			
			if random_value <= current_weight:
				selected_cards.append(card)
				used_indices.append(i)
				break
	
	return selected_cards

func apply(card) -> void:
	if not card.stat_modifiers:
		push_warning("Card has no stat_modifiers: " + str(card))
		return
	
	var stat_mods: Dictionary = card.stat_modifiers
	
	for stat_name in stat_mods:
		if not RunManager.stats.has(stat_name):
			push_warning("Unknown stat: " + stat_name)
			continue
		
		var mod_value = stat_mods[stat_name]
		
		# Handle different modification types
		if stat_name.ends_with("_add"):
			RunManager.stats[stat_name] += mod_value
		elif stat_name.ends_with("_mult"):
			RunManager.stats[stat_name] *= mod_value
		elif typeof(mod_value) == TYPE_BOOL:
			# Boolean values should be set directly, not added
			RunManager.stats[stat_name] = mod_value
		else:
			# Default to additive for numeric values
			RunManager.stats[stat_name] += mod_value
	
	Logger.info("Applied card: " + str(card.description) + " | Stats: " + str(RunManager.stats), "player")
