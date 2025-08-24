extends Node
class_name CardSystem

## Modern card system managing multiple themed card pools.
## Handles card selection, application, and pool management.

var card_pools: Dictionary = {}
var current_selection: Array[CardResource] = []

signal card_pools_loaded()
signal cards_selected(cards: Array[CardResource])

func _ready() -> void:
	_load_card_pools()

func _load_card_pools() -> void:
	Logger.info("Loading card pools...", "cards")
	
	# Load melee pool
	var melee_pool_path: String = "res://data/cards/pools/melee_pool.tres"
	if ResourceLoader.exists(melee_pool_path):
		var melee_pool: CardPoolResource = ResourceLoader.load(melee_pool_path) as CardPoolResource
		if melee_pool:
			card_pools["melee"] = melee_pool
			Logger.info("Loaded melee card pool with " + str(melee_pool.get_card_count()) + " cards", "cards")
		else:
			Logger.error("Failed to load melee card pool resource", "cards")
	else:
		Logger.warn("Melee card pool not found at: " + melee_pool_path, "cards")
	
	# Future: Load other pools (ranged, defensive, etc.)
	
	if card_pools.is_empty():
		Logger.error("No card pools loaded!", "cards")
		return
	
	Logger.info("Card system initialized with " + str(card_pools.size()) + " pools", "cards")
	card_pools_loaded.emit()

func get_card_selection(level: int, count: int = 3) -> Array[CardResource]:
	if card_pools.is_empty():
		Logger.error("No card pools available for selection", "cards")
		return []
	
	# For now, use melee pool. Future: smart pool selection based on player build
	var pool_name: String = "melee"
	if not card_pools.has(pool_name):
		Logger.error("Pool not found: " + pool_name, "cards")
		return []
	
	var pool: CardPoolResource = card_pools[pool_name]
	var available_cards: Array[CardResource] = pool.get_available_cards_at_level(level)
	
	if available_cards.is_empty():
		Logger.warn("No cards available at level " + str(level), "cards")
		return []
	
	Logger.debug("Available cards at level " + str(level) + ": " + str(available_cards.size()), "cards")
	
	# Select cards using the pool's weighted selection
	current_selection = pool.select_multiple_cards(level, count, "loot")
	
	Logger.info("Selected " + str(current_selection.size()) + " cards for level " + str(level), "cards")
	cards_selected.emit(current_selection)
	
	return current_selection

func apply_card(card: CardResource) -> void:
	if not card:
		Logger.error("Attempted to apply null card", "cards")
		return
	
	Logger.debug("Applying card: " + card.name, "cards")
	
	# Apply card modifiers to RunManager stats
	card.apply_to_stats(RunManager.stats)
	
	Logger.info("Applied card: " + card.name + " to player stats", "cards")

func get_pool_count() -> int:
	return card_pools.size()

func get_pool_names() -> Array[String]:
	var names: Array[String] = []
	for pool_name in card_pools.keys():
		names.append(pool_name)
	return names

func has_pool(pool_name: String) -> bool:
	return card_pools.has(pool_name)

func get_pool(pool_name: String) -> CardPoolResource:
	return card_pools.get(pool_name, null)
