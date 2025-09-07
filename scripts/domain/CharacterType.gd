extends Resource
class_name CharacterType

## CharacterType - Resource defining character classes and their base stats
## Used for data-driven character creation and selection

@export var id: StringName
@export var display_name: String
@export var description: String
@export var base_hp: float
@export var base_damage: float
@export var base_speed: float
@export var starting_abilities: Array[StringName] = []

func _init(
	p_id: StringName = &"",
	p_display_name: String = "",
	p_description: String = "",
	p_base_hp: float = 100.0,
	p_base_damage: float = 25.0,
	p_base_speed: float = 1.0,
	p_starting_abilities: Array[StringName] = []
) -> void:
	id = p_id
	display_name = p_display_name
	description = p_description
	base_hp = p_base_hp
	base_damage = p_base_damage
	base_speed = p_base_speed
	starting_abilities = p_starting_abilities

func get_stats() -> Dictionary:
	"""Return character stats in the format expected by existing systems."""
	return {
		"hp": base_hp,
		"damage": base_damage,
		"speed": base_speed
	}

func get_character_data() -> Dictionary:
	"""Return character data in the format expected by CharacterSelect."""
	return {
		"name": display_name,
		"description": description,
		"stats": get_stats()
	}