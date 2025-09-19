extends Node

## EventMasterySystem autoload wrapper
## Provides global access to event mastery functionality from hideout and runtime

var mastery_system_instance: Node

func _ready() -> void:
	# Create the actual EventMasterySystem instance
	mastery_system_instance = EventMasterySystemImpl.new()
	add_child(mastery_system_instance)

	Logger.info("EventMasterySystem autoload wrapper initialized", "events")

# Forward all calls to the actual mastery system instance
func _get(property: StringName):
	if mastery_system_instance and mastery_system_instance.has_method("get"):
		return mastery_system_instance.get(property)
	elif mastery_system_instance:
		return mastery_system_instance.get(property)

func _set(property: StringName, value):
	if mastery_system_instance:
		mastery_system_instance.set(property, value)

func _get_property_list():
	if mastery_system_instance:
		return mastery_system_instance.get_property_list()
	return []

func _missing_method(method: StringName, args: Array):
	if mastery_system_instance and mastery_system_instance.has_method(method):
		return mastery_system_instance.callv(method, args)
	Logger.error("EventMasterySystem method not found: %s" % method, "events")