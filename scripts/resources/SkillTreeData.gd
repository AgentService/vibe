class_name SkillTreeData
extends Resource

## Resource that defines the structure and passive mappings for a skill tree.
## Used by BreachSkillTree to load data-driven skill tree configurations.

@export var event_type: StringName = "breach"
@export var tree_name: String = "Breach Mastery"
@export var description: String = "Passive skills for breach events"

## For MVP, we'll use this to indicate which EventMasterySystem passives
## should be mapped to the existing skill tree layout
@export var passive_mapping: Array[StringName] = []

## Future expansion: could include node positions, connections, etc.
## @export var node_positions: Dictionary = {}
## @export var node_connections: Array[Dictionary] = []
