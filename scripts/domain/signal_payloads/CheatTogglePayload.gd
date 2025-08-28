extends Resource
class_name CheatTogglePayload

## Payload for cheat toggle events

@export var cheat_name: String
@export var enabled: bool

func _init(p_cheat_name: String = "", p_enabled: bool = false) -> void:
	cheat_name = p_cheat_name
	enabled = p_enabled