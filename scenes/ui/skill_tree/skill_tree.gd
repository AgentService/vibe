extends Control
class_name SimpleSkillTree

## Simple skill tree implementation with basic show/hide/reset functionality
##
## TODO: Features from old SkillTreeUI that could be re-added later:
## - Event type separation (breach, ritual, pack_hunt, boss quadrants)
## - Integration with EventMasterySystem for passive allocation/deallocation
## - Node state management (LOCKED, AVAILABLE, ALLOCATED)
## - Tooltip system with hover/unhover events
## - Mastery points tracking per event type
## - Signal connections to EventBus (mastery_points_earned, passive_allocated, etc.)
## - Dynamic node collection and organization by event type
## - Prerequisites and dependency validation through mastery system
## - SkillTreeNode vs SkillNode architecture decision
## - Automatic node initialization with passive data from ContentDB

signal skill_tree_closed()

var _is_visible: bool = false

# Modal configuration is inherited from BaseModal

# TODO: Old system had these for advanced features:
# var mastery_system
# var skill_nodes: Dictionary = {"breach": [], "ritual": [], "pack_hunt": [], "boss": []}
# var _current_tooltip_node
# @onready var tooltip_container: Control
# @onready var tooltip_label: RichTextLabel

func _ready() -> void:
	# UI should always process (pause-independent)
	process_mode = Node.PROCESS_MODE_ALWAYS

	# Set initial visibility based on context
	_set_initial_visibility()

	# Connect any buttons that might exist
	_connect_ui_buttons()

func _set_initial_visibility() -> void:
	"""Set initial visibility - closed in hideout, visible when testing directly"""
	var scene_tree = get_tree()
	var current_scene = scene_tree.current_scene

	# Check if we're running the skill tree scene directly (for testing)
	var is_testing_directly = (current_scene == self or current_scene.name.contains("SkillTree"))

	if is_testing_directly:
		# Running skill tree directly from editor - keep it visible for testing
		visible = true
		_is_visible = true
		Logger.debug("Skill tree opened directly - keeping visible for testing", "ui")
	else:
		# Running from hideout or other scene - start closed
		visible = false
		_is_visible = false
		Logger.debug("Skill tree in hideout context - starting closed", "ui")


func _connect_ui_buttons() -> void:
	"""Connect UI buttons if they exist"""
	var reset_button = find_child("ResetButton", true, false)
	if reset_button:
		reset_button.pressed.connect(_on_reset_button_pressed)

	var close_button = find_child("CloseButton", true, false)
	if close_button:
		close_button.pressed.connect(hide_ui)

func show_ui() -> void:
	"""Show the skill tree UI"""
	visible = true
	_is_visible = true
	Logger.debug("Skill tree UI shown", "ui")

func hide_ui() -> void:
	"""Hide the skill tree UI"""
	visible = false
	_is_visible = false
	skill_tree_closed.emit()
	Logger.debug("Skill tree UI hidden", "ui")

func toggle_ui() -> void:
	"""Toggle the skill tree UI visibility"""
	if _is_visible:
		hide_ui()
	else:
		show_ui()

func _on_reset_button_pressed() -> void:
	"""Reset all skill points to 0"""
	Logger.info("Resetting all skill points in new skill tree", "ui")

	# Find all SkillNode instances and reset them
	var skill_nodes = _find_skill_nodes_recursive(self)
	Logger.debug("Found %d skill nodes to reset" % skill_nodes.size(), "ui")

	for node in skill_nodes:
		if node and node.has_method("reset_skill"):
			Logger.debug("Resetting skill node: %s" % node.name, "ui")
			node.reset_skill()
		else:
			Logger.warn("Skill node %s doesn't have reset_skill method" % node.name, "ui")

	# TODO: Old system also had:
	# - Integration with mastery_system.deallocate_passive() for each node
	# - EventBus.passive_deallocated.emit() signals
	# - Mastery points refunding per event type
	# - UI refresh to update node states and point counters

func _find_skill_nodes_recursive(parent: Node) -> Array:
	"""Recursively find all SkillNode instances"""
	var nodes: Array = []

	for child in parent.get_children():
		# Check if this child is a SkillNode using is operator (more reliable)
		if child is SkillNode:
			nodes.append(child)

		# Always recurse into children to find nested SkillNodes
		nodes.append_array(_find_skill_nodes_recursive(child))

	return nodes

# TODO: Methods from old SkillTreeUI that could be re-implemented:
# func _initialize_skill_tree() - full system initialization with mastery system
# func _find_mastery_system() - locate EventMasterySystem in scene tree
# func _collect_skill_nodes() - organize nodes by event type into skill_nodes dict
# func _collect_nodes_from_section() - collect from specific quadrant sections
# func _initialize_node_with_passive_data() - set up nodes with ContentDB data
# func _setup_node_connections() - connect all node hover/click signals
# func _on_skill_node_clicked() - handle allocation/deallocation through mastery system
# func _on_skill_node_hovered/_unhovered() - tooltip management
# func _show_tooltip/_hide_tooltip() - tooltip positioning and content
# func _on_mastery_points_earned/_passive_changed() - EventBus signal handlers
# func _refresh_ui/_refresh_all_nodes() - update visual states based on mastery system
# func _refresh_nodes_for_event_type() - update specific event type nodes

func _input(event: InputEvent) -> void:
	"""Handle input when UI is visible - BaseModal handles ESC automatically"""
	if not _is_visible:
		return

	# BaseModal automatically handles ESC key, so we don't need to handle it here
	# Custom skill tree specific inputs can be added here if needed
