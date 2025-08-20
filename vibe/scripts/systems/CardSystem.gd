extends Node
class_name CardSystem

## Manages card selection and stat modification for level-up rewards.
## Loads weighted card pools from JSON and applies stat modifications to RunManager.

var card_pool: Dictionary = {}

func _ready() -> void:
	_load_card_pool()

func _load_card_pool() -> void:
	var file_path: String = "res://data/cards/card_pool.json"
	Logger.debug("Loading card pool from: " + file_path, "player")
	
	if not FileAccess.file_exists(file_path):
		push_error("Card pool file not found: " + file_path)
		return
	
	var file: FileAccess = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		push_error("Failed to open card pool file: " + file_path)
		return
	
	var json_string: String = file.get_as_text()
	file.close()
	
	var json: JSON = JSON.new()
	var parse_result: Error = json.parse(json_string)
	
	if parse_result != OK:
		push_error("Failed to parse card pool JSON: " + json.get_error_message())
		return
	
	card_pool = json.data
	Logger.info("Card pool loaded with " + str(card_pool.get("pool", []).size()) + " cards", "player")

func roll_three() -> Array[Dictionary]:
	if not card_pool.has("pool") or card_pool["pool"].is_empty():
		push_error("Card pool is empty or malformed")
		return []
	
	var pool: Array = card_pool["pool"]
	var selected_cards: Array[Dictionary] = []
	var total_weight: float = 0.0
	
	# Calculate total weight
	for card in pool:
		if card.has("weight"):
			total_weight += card["weight"]
	
	# Select 3 unique cards
	var used_indices: Array[int] = []
	while selected_cards.size() < 3 and used_indices.size() < pool.size():
		var random_value: float = RNG.randf_range("loot", 0.0, total_weight)
		var current_weight: float = 0.0
		
		for i in range(pool.size()):
			if i in used_indices:
				continue
			
			var card: Dictionary = pool[i]
			current_weight += card.get("weight", 1.0)
			
			if random_value <= current_weight:
				selected_cards.append(card)
				used_indices.append(i)
				break
	
	return selected_cards

func apply(card: Dictionary) -> void:
	if not card.has("stat_mods"):
		push_warning("Card has no stat_mods: " + str(card))
		return
	
	var stat_mods: Dictionary = card["stat_mods"]
	
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
		else:
			# Default to additive
			RunManager.stats[stat_name] += mod_value
	
	Logger.info("Applied card: " + str(card.get("desc", "Unknown")) + " | Stats: " + str(RunManager.stats), "player")