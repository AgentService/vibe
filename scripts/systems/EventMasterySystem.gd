class_name EventMasterySystem
extends Node

## Event mastery system for applying passive modifiers and tracking progression.
## Manages EventMasteryTree progression and applies passive bonuses to event configuration.
## Integrates with SpawnDirector for modified event spawning behavior.

var mastery_tree
var _event_definitions: Dictionary = {} ## event_type -> EventDefinition

# Passive definitions with costs and effects
var passive_definitions: Dictionary = {
	# Breach event passives
	"breach_density_1": {
		"name": "Breach Density I",
		"description": "Breaches spawn 25% more monsters",
		"cost": 1,
		"event_type": "breach",
		"modifiers": {"monster_count": 1.25}
	},
	"breach_duration_1": {
		"name": "Breach Duration I",
		"description": "Breaches last 5 seconds longer",
		"cost": 1,
		"event_type": "breach",
		"modifiers": {"duration": 5.0}  # Added duration, not multiplied
	},
	"breach_rewards_1": {
		"name": "Breach Rewards I",
		"description": "Breach enemies grant 30% more XP",
		"cost": 1,
		"event_type": "breach",
		"modifiers": {"xp_multiplier": 1.3}
	},

	# Ritual event passives
	"ritual_area_1": {
		"name": "Ritual Area I",
		"description": "Ritual circles are 50% larger",
		"cost": 1,
		"event_type": "ritual",
		"modifiers": {"circle_radius": 1.5}
	},
	"ritual_spawn_rate_1": {
		"name": "Ritual Spawn Rate I",
		"description": "Ritual enemies spawn 25% faster",
		"cost": 1,
		"event_type": "ritual",
		"modifiers": {"spawn_interval": 0.75}  # Multiplier (faster spawning)
	},
	"ritual_defense_1": {
		"name": "Ritual Defense I",
		"description": "Ritual objectives have 50% more health",
		"cost": 1,
		"event_type": "ritual",
		"modifiers": {"objective_health": 1.5}
	},

	# Pack Hunt event passives
	"pack_density_1": {
		"name": "Pack Density I",
		"description": "Pack hunts spawn 1 additional rare companion",
		"cost": 1,
		"event_type": "pack_hunt",
		"modifiers": {"rare_companions": 1}  # Additive
	},
	"pack_rewards_1": {
		"name": "Pack Rewards I",
		"description": "Pack hunt enemies grant 40% more XP",
		"cost": 1,
		"event_type": "pack_hunt",
		"modifiers": {"xp_multiplier": 1.4}
	},
	"pack_tracking_1": {
		"name": "Pack Tracking I",
		"description": "Pack hunts reveal enemy locations longer",
		"cost": 1,
		"event_type": "pack_hunt",
		"modifiers": {"reveal_duration": 2.0}  # Added duration
	},

	# Boss event passives
	"boss_rewards_1": {
		"name": "Boss Rewards I",
		"description": "Boss encounters grant 50% more XP",
		"cost": 1,
		"event_type": "boss",
		"modifiers": {"xp_multiplier": 1.5}
	},
	"boss_mechanics_1": {
		"name": "Boss Mechanics I",
		"description": "Boss encounters spawn 2 additional elite guards",
		"cost": 1,
		"event_type": "boss",
		"modifiers": {"elite_guards": 2}  # Additive
	}
}

func _ready() -> void:
	# Load or create mastery tree
	_load_mastery_tree()

	# Load event definitions
	_load_event_definitions()

	# Connect to event completion signals
	EventBus.event_completed.connect(_on_event_completed)

	Logger.info("EventMasterySystem initialized with %d passives" % passive_definitions.size(), "events")

func _load_mastery_tree() -> void:
	"""Load existing mastery tree or create new one"""
	var save_path = "user://mastery_tree.tres"

	if ResourceLoader.exists(save_path):
		mastery_tree = ResourceLoader.load(save_path)
		if mastery_tree and mastery_tree.is_valid():
			Logger.info("Loaded mastery tree: %d total points, %d passives allocated" % [
				mastery_tree.get_total_points(),
				mastery_tree.get_allocated_passives_count()
			], "events")
		else:
			Logger.warn("Invalid mastery tree loaded, creating new one", "events")
			var EventMasteryTreeClass = preload("res://scripts/resources/EventMasteryTree.gd")
			mastery_tree = EventMasteryTreeClass.new()
	else:
		var EventMasteryTreeClass = preload("res://scripts/resources/EventMasteryTree.gd")
		mastery_tree = EventMasteryTreeClass.new()
		Logger.info("Created new mastery tree", "events")

func _load_event_definitions() -> void:
	"""Load event definitions from content directory"""
	var event_dir = "res://data/content/events/"
	var event_types = ["breach", "ritual", "pack_hunt", "boss"]

	for event_type in event_types:
		var file_path = event_dir + event_type + "_basic.tres"
		if ResourceLoader.exists(file_path):
			var event_def = ResourceLoader.load(file_path)
			if event_def and event_def.is_valid():
				_event_definitions[event_type] = event_def
				Logger.debug("Loaded event definition: %s" % event_type, "events")
			else:
				Logger.warn("Invalid event definition: %s" % file_path, "events")
		else:
			Logger.warn("Event definition not found: %s" % file_path, "events")

func apply_event_modifiers(event_def) -> Dictionary:
	"""Apply mastery passive modifiers to event configuration"""
	var modified_config = event_def.base_config.duplicate()
	var modified_duration = event_def.duration

	# Apply all allocated passives for this event type
	for passive_id in mastery_tree.allocated_passives:
		if not mastery_tree.is_passive_allocated(passive_id):
			continue

		var passive_def = passive_definitions.get(passive_id)
		if not passive_def or passive_def.event_type != event_def.event_type:
			continue

		# Apply each modifier from this passive
		var modifiers = passive_def.get("modifiers", {})
		for modifier_key in modifiers:
			var modifier_value = modifiers[modifier_key]

			if modifier_key == "duration":
				# Duration modifiers are additive
				modified_duration += modifier_value
			elif modified_config.has(modifier_key):
				var current_value = modified_config[modifier_key]

				# Determine if modifier is additive or multiplicative
				if modifier_key in ["rare_companions", "elite_guards"]:
					# Additive modifiers
					modified_config[modifier_key] = current_value + modifier_value
				else:
					# Multiplicative modifiers
					if current_value is int:
						modified_config[modifier_key] = int(current_value * modifier_value)
					elif current_value is float:
						modified_config[modifier_key] = current_value * modifier_value
			else:
				# New modifier key - add directly
				modified_config[modifier_key] = modifier_value

	# Add duration to config if modified
	if modified_duration != event_def.duration:
		modified_config["duration"] = modified_duration

	return modified_config

func get_event_definition(event_type: StringName):
	"""Get event definition for specified type"""
	return _event_definitions.get(event_type)

func can_allocate_passive(passive_id: StringName) -> bool:
	"""Check if passive can be allocated"""
	var passive_def = passive_definitions.get(passive_id)
	if not passive_def:
		return false

	return mastery_tree.can_allocate_passive(
		passive_id,
		passive_def.cost,
		passive_def.event_type
	)

func allocate_passive(passive_id: StringName) -> bool:
	"""Allocate a passive if requirements are met"""
	var passive_def = passive_definitions.get(passive_id)
	if not passive_def:
		return false

	if mastery_tree.allocate_passive(passive_id, passive_def.cost, passive_def.event_type):
		_save_mastery_tree()
		EventBus.passive_allocated.emit(passive_id)
		Logger.info("Passive allocated: %s (%s)" % [passive_def.name, passive_id], "events")
		return true

	return false

func deallocate_passive(passive_id: StringName) -> void:
	"""Deallocate a passive (respec)"""
	if mastery_tree.is_passive_allocated(passive_id):
		mastery_tree.deallocate_passive(passive_id)
		_save_mastery_tree()
		EventBus.passive_deallocated.emit(passive_id)
		Logger.info("Passive deallocated: %s" % passive_id, "events")

func reset_all_passives() -> void:
	"""Reset all allocated passives (full respec)"""
	var count = mastery_tree.get_allocated_passives_count()
	mastery_tree.reset_all_passives()
	_save_mastery_tree()
	Logger.info("All passives reset: %d passives deallocated" % count, "events")

func _on_event_completed(event_type: StringName, performance_data: Dictionary) -> void:
	"""Handle event completion - award mastery points"""
	# Award mastery points (1 per completion)
	mastery_tree.add_mastery_points(event_type, 1)
	_save_mastery_tree()

	# Emit mastery points earned signal
	EventBus.mastery_points_earned.emit(event_type, 1)

	var total_points = mastery_tree.get_points_for_event_type(event_type)
	Logger.info("Event completed: %s (+1 point, total: %d)" % [event_type, total_points], "events")

func _save_mastery_tree() -> void:
	"""Save mastery tree to persistent storage"""
	var save_path = "user://mastery_tree.tres"
	var result = ResourceSaver.save(mastery_tree, save_path)
	if result != OK:
		Logger.error("Failed to save mastery tree: %s" % save_path, "events")

func get_passive_info(passive_id: StringName) -> Dictionary:
	"""Get passive information for UI display"""
	var passive_def = passive_definitions.get(passive_id, {})
	var allocated = mastery_tree.is_passive_allocated(passive_id)
	var can_allocate = can_allocate_passive(passive_id)

	return {
		"id": passive_id,
		"name": passive_def.get("name", "Unknown"),
		"description": passive_def.get("description", ""),
		"cost": passive_def.get("cost", 0),
		"event_type": passive_def.get("event_type", ""),
		"allocated": allocated,
		"can_allocate": can_allocate,
		"available_points": mastery_tree.get_points_for_event_type(passive_def.get("event_type", ""))
	}

func get_all_passives_for_event_type(event_type: StringName) -> Array[Dictionary]:
	"""Get all passive information for specific event type"""
	var passives: Array[Dictionary] = []

	for passive_id in passive_definitions:
		var passive_def = passive_definitions[passive_id]
		if passive_def.event_type == event_type:
			passives.append(get_passive_info(passive_id))

	return passives
