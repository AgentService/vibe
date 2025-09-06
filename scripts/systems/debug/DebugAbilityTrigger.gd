extends Node

## DebugAbilityTrigger - Force-trigger entity abilities for debugging
## Integrates with EntitySelector and provides manual ability triggering

class_name DebugAbilityTrigger

# Boss class references for type checking
const AncientLich = preload("res://scenes/bosses/AncientLich.gd")
const DragonLord = preload("res://scenes/bosses/DragonLord.gd")

# Ability definitions for different entity types
var entity_abilities: Dictionary = {
	"boss": ["attack", "special_ability"],
	"enemy": ["attack", "charge", "stomp"]
}

# Cooldown tracking for debug abilities
var ability_cooldowns: Dictionary = {}

signal ability_triggered(entity_id: String, ability_name: String)
signal ability_failed(entity_id: String, ability_name: String, reason: String)

func _ready() -> void:
	Logger.debug("DebugAbilityTrigger initialized", "debug")

# Get available abilities for an entity
func get_entity_abilities(entity_id: String) -> Array[String]:
	var entity_data := EntityTracker.get_entity(entity_id)
	if not entity_data.has("type"):
		return []
	
	var entity_type: String = entity_data["type"]
	
	# Map entity types to their available abilities
	match entity_type:
		"boss":
			return _get_boss_abilities(entity_id)
		"enemy":
			return _get_enemy_abilities(entity_id)
		_:
			return []

# Get boss-specific abilities
func _get_boss_abilities(entity_id: String) -> Array[String]:
	var boss_node := _find_boss_node(entity_id)
	if not boss_node:
		return []
	
	var abilities: Array[String] = []
	
	# Check if boss has common abilities
	if boss_node.has_method("_perform_attack"):
		abilities.append("attack")
	
	# Boss-specific abilities based on type
	if boss_node is AncientLich:
		abilities.append("wake_up")
		abilities.append("aggro")
	elif boss_node is DragonLord:
		abilities.append("fire_breath")  # Example ability
	
	return abilities

# Get enemy-specific abilities (for future enemy system expansion)
func _get_enemy_abilities(entity_id: String) -> Array[String]:
	# For now, return generic enemy abilities
	# This can be expanded when enemy ability system is implemented
	return ["attack", "charge"]

# Trigger an ability on an entity
func trigger_ability(entity_id: String, ability_name: String) -> bool:
	Logger.info("Triggering ability '%s' on entity '%s'" % [ability_name, entity_id], "debug")
	
	var entity_data := EntityTracker.get_entity(entity_id)
	if not entity_data.has("type"):
		Logger.warn("Entity not found for ability trigger: %s" % entity_id, "debug")
		ability_failed.emit(entity_id, ability_name, "Entity not found")
		return false
	
	var entity_type: String = entity_data["type"]
	
	match entity_type:
		"boss":
			return _trigger_boss_ability(entity_id, ability_name)
		"enemy":
			return _trigger_enemy_ability(entity_id, ability_name)
		_:
			Logger.warn("Unknown entity type for ability trigger: %s" % entity_type, "debug")
			ability_failed.emit(entity_id, ability_name, "Unknown entity type")
			return false

# Trigger boss abilities
func _trigger_boss_ability(entity_id: String, ability_name: String) -> bool:
	var boss_node := _find_boss_node(entity_id)
	if not boss_node:
		Logger.warn("Boss node not found for ability trigger: %s" % entity_id, "debug")
		ability_failed.emit(entity_id, ability_name, "Boss node not found")
		return false
	
	var success := false
	
	match ability_name:
		"attack":
			if boss_node.has_method("_perform_attack"):
				# Force attack regardless of cooldown
				boss_node._perform_attack()
				# Reset attack cooldown for immediate ability
				if boss_node.has("last_attack_time"):
					boss_node.last_attack_time = 0.0
				success = true
			else:
				Logger.warn("Boss does not have _perform_attack method: %s" % entity_id, "debug")
		
		"wake_up":
			if boss_node is AncientLich:
				var lich := boss_node as AncientLich
				if lich.has_method("_aggro"):
					lich._aggro()
					success = true
			
		"aggro":
			if boss_node.has_method("_aggro"):
				boss_node._aggro()
				success = true
		
		"fire_breath":
			# Example dragon ability - can be implemented later
			Logger.info("Fire breath ability not yet implemented", "debug")
		
		_:
			Logger.warn("Unknown boss ability: %s" % ability_name, "debug")
	
	if success:
		ability_triggered.emit(entity_id, ability_name)
		Logger.debug("Successfully triggered ability '%s' on boss '%s'" % [ability_name, entity_id], "debug")
	else:
		ability_failed.emit(entity_id, ability_name, "Ability not available")
	
	return success

# Trigger enemy abilities (future implementation)
func _trigger_enemy_ability(entity_id: String, ability_name: String) -> bool:
	Logger.info("Enemy abilities not yet implemented - would trigger '%s' on '%s'" % [ability_name, entity_id], "debug")
	
	# For now, just emit success for testing
	ability_triggered.emit(entity_id, ability_name)
	return true

# Get ability cooldown information
func get_ability_cooldown(entity_id: String, ability_name: String) -> Dictionary:
	var entity_data := EntityTracker.get_entity(entity_id)
	if not entity_data.has("type"):
		return {"ready": false, "cooldown_remaining": 0.0}
	
	var entity_type: String = entity_data["type"]
	
	if entity_type == "boss":
		var boss_node := _find_boss_node(entity_id)
		if boss_node:
			return _get_boss_ability_cooldown(boss_node, ability_name)
	
	# Default: ability is ready
	return {"ready": true, "cooldown_remaining": 0.0}

# Get boss ability cooldown information
func _get_boss_ability_cooldown(boss_node: Node, ability_name: String) -> Dictionary:
	match ability_name:
		"attack":
			if boss_node.has("attack_cooldown") and boss_node.has("last_attack_time"):
				var cooldown_time: float = boss_node.get("attack_cooldown")
				var last_attack: float = boss_node.get("last_attack_time")
				var remaining: float = max(0.0, cooldown_time - last_attack)
				
				return {
					"ready": remaining <= 0.0,
					"cooldown_remaining": remaining,
					"cooldown_total": cooldown_time
				}
		_:
			# Most abilities are instant/always ready
			return {"ready": true, "cooldown_remaining": 0.0}
	
	return {"ready": true, "cooldown_remaining": 0.0}

# Helper function to find boss node by entity ID
func _find_boss_node(entity_id: String) -> Node:
	var scene_tree := get_tree()
	if not scene_tree:
		return null
	
	var current_scene := scene_tree.current_scene
	if not current_scene:
		return null
	
	return _search_for_boss_recursive(current_scene, entity_id)

func _search_for_boss_recursive(node: Node, target_id: String) -> Node:
	# Check if this node is our target boss
	if _node_matches_boss_id(node, target_id):
		return node
	
	# Search children recursively
	for child in node.get_children():
		var result := _search_for_boss_recursive(child, target_id)
		if result:
			return result
	
	return null

func _node_matches_boss_id(node: Node, target_id: String) -> bool:
	# Check by position match (most reliable for boss entities)
	var entity_data := EntityTracker.get_entity(target_id)
	if entity_data.has("pos") and node.has("global_position"):
		var entity_pos: Vector2 = entity_data["pos"]
		var node_pos: Vector2 = node.global_position
		var distance := entity_pos.distance_to(node_pos)
		
		# If positions match closely and it's a boss-like node
		if distance < 50.0 and _is_boss_node(node):
			return true
	
	return false

func _is_boss_node(node: Node) -> bool:
	# Check if node is a boss type
	return node is AncientLich or node is DragonLord or node.is_in_group("bosses")
