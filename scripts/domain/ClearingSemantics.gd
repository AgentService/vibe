extends Node

## Semantic group constants for object clearing behavior
## Objects declare their clearing intent through these groups
## This separates lifecycle management from clearing semantics

# Combat-related objects that should be cleared when clearing enemies
const CLEAR_WITH_ENEMIES: String = "clear_with_enemies"

# Temporary effects and projectiles from enemy actions
const CLEAR_WITH_ENEMY_EFFECTS: String = "clear_with_enemy_effects"

# Transient pickups and temporary items
const CLEAR_WITH_TRANSIENTS: String = "clear_with_transients"

# Map events and features that persist across enemy clears
const PERSIST_ACROSS_ENEMY_CLEARS: String = "persist_across_enemy_clears"

# Session-level objects that only clear on full session reset
const PERSIST_ACROSS_SESSION: String = "persist_across_session"

# Objects that should never be automatically cleared
const NEVER_AUTO_CLEAR: String = "never_auto_clear"

## Helper method to add object to appropriate semantic group
func add_semantic_group(node: Node, semantic: String) -> void:
	if not node:
		Logger.warn("Cannot add semantic group to null node", "clearing")
		return

	node.add_to_group(semantic)
	Logger.debug("Added semantic group '%s' to %s" % [semantic, node.name], "clearing")

## Helper method to check if object has semantic group
func has_semantic_group(node: Node, semantic: String) -> bool:
	if not node:
		return false
	return node.is_in_group(semantic)

## Get all semantic groups for a node (for debugging)
func get_semantic_groups(node: Node) -> Array[String]:
	if not node:
		return []

	var semantic_groups: Array[String] = []
	var all_semantics = [
		CLEAR_WITH_ENEMIES,
		CLEAR_WITH_ENEMY_EFFECTS,
		CLEAR_WITH_TRANSIENTS,
		PERSIST_ACROSS_ENEMY_CLEARS,
		PERSIST_ACROSS_SESSION,
		NEVER_AUTO_CLEAR
	]

	for semantic in all_semantics:
		if node.is_in_group(semantic):
			semantic_groups.append(semantic)

	return semantic_groups