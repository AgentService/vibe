extends Resource
class_name CardPool

## Contains the complete pool of available cards for selection.
## Provides filtering and weighted selection functionality.

@export var pool: Array = []


func get_available_cards_at_level(level: int) -> Array:
	var available: Array = []
	for card in pool:
		if card.is_available_at_level(level):
			available.append(card)
	return available

func get_total_weight_at_level(level: int) -> int:
	var total: int = 0
	for card in pool:
		if card.is_available_at_level(level):
			total += card.weight
	return total

func get_card_count() -> int:
	return pool.size()

func add_card(card) -> void:
	pool.append(card)

func remove_card(card_id: String) -> bool:
	for i in range(pool.size()):
		if pool[i].card_id == card_id:
			pool.remove_at(i)
			return true
	return false