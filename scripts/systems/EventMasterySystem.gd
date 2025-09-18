class_name EventMasterySystemImpl
extends Node

## Event mastery system for applying passive modifiers and tracking progression.
## Manages EventMasteryTree progression and applies passive bonuses to event configuration.
## Integrates with SpawnDirector for modified event spawning behavior.

var mastery_tree
var _event_definitions: Dictionary = {} ## event_type -> EventDefinition

# Passive definitions with costs and effects
var passive_definitions: Dictionary = {
	# Breach event passives - Multi-level format
	"breach_density": {
		"name": "Breach Density",
		"description": "Breaches spawn more monsters",
		"max_level": 3,
		"cost_per_level": [1, 1, 2],  # Level 1: 1pt, Level 2: 1pt, Level 3: 2pts
		"event_type": "breach",
		"modifiers_per_level": [
			{"monster_count": 1.15},  # Level 1: +15%
			{"monster_count": 1.30},  # Level 2: +30%
			{"monster_count": 1.50}   # Level 3: +50%
		]
	},
	"breach_duration": {
		"name": "Breach Duration",
		"description": "Breaches last longer",
		"max_level": 3,
		"cost_per_level": [1, 1, 2],
		"event_type": "breach",
		"modifiers_per_level": [
			{"duration": 3.0},   # Level 1: +3 seconds
			{"duration": 6.0},   # Level 2: +6 seconds
			{"duration": 10.0}   # Level 3: +10 seconds
		]
	},
	"breach_rewards": {
		"name": "Breach Rewards",
		"description": "Breach enemies grant more XP",
		"max_level": 3,
		"cost_per_level": [1, 1, 2],
		"event_type": "breach",
		"modifiers_per_level": [
			{"xp_multiplier": 1.20},  # Level 1: +20%
			{"xp_multiplier": 1.40},  # Level 2: +40%
			{"xp_multiplier": 1.60}   # Level 3: +60%
		]
	},
	"breach_power": {
		"name": "Breach Power",
		"description": "Deal more damage during breach events",
		"max_level": 3,
		"cost_per_level": [1, 1, 2],
		"event_type": "breach",
		"modifiers_per_level": [
			{"damage_multiplier": 1.10},  # Level 1: +10%
			{"damage_multiplier": 1.20},  # Level 2: +20%
			{"damage_multiplier": 1.35}   # Level 3: +35%
		]
	},
	"breach_defense": {
		"name": "Breach Defense",
		"description": "Take less damage during breach events",
		"max_level": 3,
		"cost_per_level": [1, 1, 2],
		"event_type": "breach",
		"modifiers_per_level": [
			{"damage_reduction": 0.95},  # Level 1: 5% reduction
			{"damage_reduction": 0.90},  # Level 2: 10% reduction
			{"damage_reduction": 0.82}   # Level 3: 18% reduction
		]
	},
	"breach_mobility": {
		"name": "Breach Mobility",
		"description": "Move faster during breach events",
		"max_level": 3,
		"cost_per_level": [1, 1, 2],
		"event_type": "breach",
		"modifiers_per_level": [
			{"movement_speed": 1.10},  # Level 1: +10%
			{"movement_speed": 1.20},  # Level 2: +20%
			{"movement_speed": 1.35}   # Level 3: +35%
		]
	},
	"breach_mastery": {
		"name": "Breach Mastery",
		"description": "All breach bonuses are more effective",
		"max_level": 2,
		"cost_per_level": [2, 3],  # Higher cost keystone passive
		"event_type": "breach",
		"modifiers_per_level": [
			{"breach_effectiveness": 1.15},  # Level 1: +15%
			{"breach_effectiveness": 1.35}   # Level 2: +35%
		]
	},
	"breach_overflow": {
		"name": "Breach Overflow",
		"description": "Breach events have extended duration",
		"max_level": 2,
		"cost_per_level": [1, 2],
		"event_type": "breach",
		"modifiers_per_level": [
			{"event_duration": 1.25},  # Level 1: +25%
			{"event_duration": 1.50}   # Level 2: +50%
		]
	},
	"breach_cascade": {
		"name": "Breach Cascade",
		"description": "Defeating enemies during breach extends duration",
		"max_level": 2,
		"cost_per_level": [2, 3],  # Premium passive
		"event_type": "breach",
		"modifiers_per_level": [
			{"cascade_chance": 0.08},  # Level 1: 8% chance
			{"cascade_chance": 0.15}   # Level 2: 15% chance
		]
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

		# Get modifiers based on passive type (multi-level vs legacy)
		var modifiers = {}
		if passive_def.has("modifiers_per_level"):
			# Multi-level passive - get modifiers for current level
			var current_level = get_passive_level(passive_id)
			if current_level > 0:
				var modifiers_per_level = passive_def.get("modifiers_per_level", [])
				var level_index = current_level - 1  # Convert to 0-based index
				if level_index < modifiers_per_level.size():
					modifiers = modifiers_per_level[level_index]
					Logger.debug("Multi-level passive %s (level %d): %s" % [passive_id, current_level, modifiers], "events")
		else:
			# Legacy single-level passive
			modifiers = passive_def.get("modifiers", {})

		# Apply each modifier from this passive
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
	"""Check if passive can be allocated (next level)"""
	var passive_def = passive_definitions.get(passive_id)
	if not passive_def:
		return false

	# Check if passive supports multi-level
	if passive_def.has("max_level"):
		var current_level = get_passive_level(passive_id)
		if current_level >= passive_def.max_level:
			return false  # Already at max level

		# Get cost for next level (current_level is 0-indexed for cost array)
		var cost_per_level = passive_def.get("cost_per_level", [1])
		var next_level_cost = 1
		if current_level < cost_per_level.size():
			next_level_cost = cost_per_level[current_level]
		else:
			next_level_cost = cost_per_level[-1]  # Use last cost if beyond array

		return mastery_tree.has_enough_points(passive_def.event_type, next_level_cost)
	else:
		# Legacy single-level passive
		return mastery_tree.can_allocate_passive(
			passive_id,
			passive_def.cost,
			passive_def.event_type
		)

func get_passive_level(passive_id: StringName) -> int:
	"""Get current level of a passive (0 = not allocated)"""
	return mastery_tree.get_passive_level(passive_id)

func allocate_passive(passive_id: StringName) -> bool:
	"""Allocate next level of a passive if requirements are met"""
	var passive_def = passive_definitions.get(passive_id)
	if not passive_def:
		return false

	# Check if passive supports multi-level
	if passive_def.has("max_level"):
		var current_level = get_passive_level(passive_id)
		if current_level >= passive_def.max_level:
			return false  # Already at max level

		# Get cost for next level
		var cost_per_level = passive_def.get("cost_per_level", [1])
		var next_level_cost = 1
		if current_level < cost_per_level.size():
			next_level_cost = cost_per_level[current_level]
		else:
			next_level_cost = cost_per_level[-1]

		# Allocate next level
		if mastery_tree.increment_passive_level(passive_id, next_level_cost, passive_def.event_type):
			_save_mastery_tree()
			EventBus.passive_allocated.emit(passive_id)
			Logger.info("Passive level up: %s (level %d)" % [passive_def.name, current_level + 1], "events")
			return true
	else:
		# Legacy single-level passive
		if mastery_tree.allocate_passive(passive_id, passive_def.cost, passive_def.event_type):
			_save_mastery_tree()
			EventBus.passive_allocated.emit(passive_id)
			Logger.info("Passive allocated: %s (%s)" % [passive_def.name, passive_id], "events")
			return true

	return false

func deallocate_passive(passive_id: StringName) -> void:
	"""Deallocate one level of a passive (respec)"""
	var passive_def = passive_definitions.get(passive_id)
	if not passive_def:
		return

	var current_level = get_passive_level(passive_id)
	if current_level <= 0:
		return  # Nothing to deallocate

	# Check if passive supports multi-level
	if passive_def.has("max_level"):
		# Get cost that was paid for current level
		var cost_per_level = passive_def.get("cost_per_level", [1])
		var current_level_cost = 1
		if (current_level - 1) < cost_per_level.size():
			current_level_cost = cost_per_level[current_level - 1]
		else:
			current_level_cost = cost_per_level[-1]

		# Decrement level and refund points
		if mastery_tree.decrement_passive_level(passive_id, current_level_cost, passive_def.event_type):
			_save_mastery_tree()
			EventBus.passive_deallocated.emit(passive_id)
			Logger.info("Passive level down: %s (level %d)" % [passive_def.name, current_level - 1], "events")
	else:
		# Legacy single-level passive
		if mastery_tree.is_passive_allocated(passive_id):
			mastery_tree.deallocate_passive(passive_id)
			_save_mastery_tree()
			EventBus.passive_deallocated.emit(passive_id)
			Logger.info("Passive deallocated: %s" % passive_id, "events")

func calculate_reset_cost(event_type: StringName) -> int:
	"""Calculate cost to reset all passives for an event type (placeholder for future implementation)"""
	var allocated_passives = get_all_passives_for_event_type(event_type)
	var total_spent_points = 0

	for passive_info in allocated_passives:
		if passive_info.allocated:
			# For multi-level passives, calculate total cost spent
			var passive_def = passive_definitions.get(passive_info.id, {})
			if passive_def.has("cost_per_level"):
				var cost_per_level = passive_def.get("cost_per_level", [1])
				var current_level = passive_info.get("current_level", 0)
				for i in range(current_level):
					if i < cost_per_level.size():
						total_spent_points += cost_per_level[i]
					else:
						total_spent_points += cost_per_level[-1]
			else:
				# Legacy single-level passive
				total_spent_points += passive_def.get("cost", 1)

	# TODO: Implement actual reset cost calculation
	# For now, return 0 (free reset) - can be changed to percentage of spent points later
	# Example: return int(total_spent_points * 0.25)  # 25% of spent points as reset cost
	return 0

func reset_all_passives() -> void:
	"""Reset all allocated passives (full respec)"""
	var count = mastery_tree.get_allocated_passives_count()
	mastery_tree.reset_all_passives()
	_save_mastery_tree()
	Logger.info("All passives reset: %d passives deallocated" % count, "events")

func reset_passives_for_event_type(event_type: StringName) -> void:
	"""Reset all passives for a specific event type"""
	var reset_count = 0
	var event_passives = get_all_passives_for_event_type(event_type)

	for passive_info in event_passives:
		if passive_info.allocated:
			var passive_id = passive_info.id
			var current_level = mastery_tree.get_passive_level(passive_id)

			# Reset to level 0
			if current_level > 0:
				mastery_tree.allocated_passives.erase(passive_id)
				reset_count += 1

	if reset_count > 0:
		_save_mastery_tree()
		Logger.info("Reset %d passives for %s event type" % [reset_count, event_type], "events")

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
	var current_level = get_passive_level(passive_id)
	var can_allocate = can_allocate_passive(passive_id)

	# Handle multi-level vs legacy passives
	var allocated = current_level > 0
	var max_level = passive_def.get("max_level", 1)
	var cost = 0

	if passive_def.has("cost_per_level"):
		# Get cost for next level
		var cost_per_level = passive_def.get("cost_per_level", [1])
		if current_level < cost_per_level.size():
			cost = cost_per_level[current_level]
		else:
			cost = cost_per_level[-1] if cost_per_level.size() > 0 else 1
	else:
		# Legacy single-level passive
		cost = passive_def.get("cost", 0)

	return {
		"id": passive_id,
		"name": passive_def.get("name", "Unknown"),
		"description": passive_def.get("description", ""),
		"cost": cost,  # Cost for next level
		"event_type": passive_def.get("event_type", ""),
		"allocated": allocated,
		"current_level": current_level,
		"max_level": max_level,
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
