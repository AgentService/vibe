extends RefCounted

## Payload for interaction_prompt_changed signal - UI interaction prompts.
## Provides compile-time type safety for interactive object communication.

class_name InteractionPromptChangedPayload

var object_id: String
var object_type: String
var show: bool

func _init(obj_id: String, obj_type: String, show_prompt: bool) -> void:
	object_id = obj_id
	object_type = obj_type
	show = show_prompt

func _to_string() -> String:
	return "InteractionPromptChangedPayload(id=%s, type=%s, show=%s)" % [object_id, object_type, show]