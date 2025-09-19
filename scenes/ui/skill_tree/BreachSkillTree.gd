extends Control
class_name BreachSkillTree

## Data-driven skill tree component that can load different event type skill configurations.
## Reuses the existing SkillNode architecture but loads layout and passive data from resources.

signal passive_allocated(passive_id: StringName)
signal passive_deallocated(passive_id: StringName)

@export var skill_tree_data: Resource ## SkillTreeData resource containing tree configuration
@export var event_type: StringName = "breach" ## Event type this tree represents

var _mastery_system: Node
var _skill_nodes: Dictionary = {} ## passive_id -> SkillNode mapping
var _reset_mode: bool = false ## Reset mode for deallocation

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_find_mastery_system()

	if skill_tree_data:
		_initialize_from_data()
	else:
		# For MVP, initialize with breach event type even without explicit data
		if event_type == "breach":
			_initialize_from_data()
		else:
			Logger.warn("BreachSkillTree has no skill_tree_data configured for event type: %s" % event_type, "ui")

func _find_mastery_system() -> void:
	"""Locate the EventMasterySystem autoload"""
	_mastery_system = EventMasterySystem.mastery_system_instance
	if _mastery_system:
		Logger.debug("Found EventMasterySystem autoload", "ui")
	else:
		Logger.error("EventMasterySystem autoload not available", "ui")

func _initialize_from_data() -> void:
	"""Initialize the skill tree using the loaded data resource"""
	# For MVP, we'll work with the existing hardcoded layout
	# and map the existing SkillNodes to passive IDs from EventMasterySystem

	_collect_existing_skill_nodes()

	_map_nodes_to_passives()
	_connect_node_signals()
	_validate_passive_assignments()
	_refresh_all_nodes()
	Logger.info("BreachSkillTree initialized for %s event type" % event_type, "ui")

	_connect_ui_buttons()

func _collect_existing_skill_nodes() -> void:
	"""Collect all SkillNode instances and map them using explicit passive_id assignments"""
	var nodes = _find_skill_nodes_recursive(self)
	Logger.debug("Found %d skill nodes in tree" % nodes.size(), "ui")

	# Map nodes using their explicit passive_id export property
	for node in nodes:
		if node.passive_id != "":
			# Node has explicit passive ID - use it
			_skill_nodes[node.passive_id] = node
			Logger.debug("Mapped node %s to passive %s (explicit)" % [node.name, node.passive_id], "ui")
		else:
			# Node has no passive ID - remains unmapped (visual-only)
			Logger.debug("Node %s has no passive_id - will use visual-only behavior" % node.name, "ui")

func _get_breach_passive_ids() -> Array[StringName]:
	"""Get the breach passive IDs from EventMasterySystem (used for validation)"""
	if not _mastery_system:
		return []

	# Extract breach passives from EventMasterySystem
	var breach_passives: Array[StringName] = []
	for passive_id in _mastery_system.passive_definitions:
		var passive_def = _mastery_system.passive_definitions[passive_id]
		if passive_def.event_type == "breach":
			breach_passives.append(passive_id)

	return breach_passives

func _validate_passive_assignments() -> void:
	"""Validate that all nodes have proper passive assignments and report issues"""
	var all_nodes = _find_skill_nodes_recursive(self)
	var unmapped_nodes: Array[String] = []
	var invalid_passives: Array[String] = []
	var valid_breach_passives = _get_breach_passive_ids()

	for node in all_nodes:
		if node.passive_id == "":
			unmapped_nodes.append(node.name)
		elif node.passive_id not in valid_breach_passives:
			invalid_passives.append("%s (passive: %s)" % [node.name, node.passive_id])

	# Report unmapped nodes
	if unmapped_nodes.size() > 0:
		Logger.warn("Nodes without passive_id assignment: %s" % str(unmapped_nodes), "ui")

	# Report invalid passive IDs
	if invalid_passives.size() > 0:
		Logger.error("Nodes with invalid passive_id: %s" % str(invalid_passives), "ui")

	# Report mapping summary
	Logger.info("Passive mapping: %d mapped nodes, %d unmapped nodes" % [_skill_nodes.size(), unmapped_nodes.size()], "ui")

func _find_skill_nodes_recursive(parent: Node) -> Array:
	"""Recursively find all SkillNode instances"""
	var nodes: Array = []

	for child in parent.get_children():
		if child is SkillNode:
			nodes.append(child)
		nodes.append_array(_find_skill_nodes_recursive(child))

	return nodes

func _map_nodes_to_passives() -> void:
	"""Map SkillNode visual states to EventMasterySystem passive states"""
	if not _mastery_system:
		return

	for passive_id in _skill_nodes:
		var node = _skill_nodes[passive_id]
		var passive_info = _mastery_system.get_passive_info(passive_id)

		# Set node level from passive info (single-level system)
		node.level = passive_info.get("current_level", 0)

		Logger.debug("Mapped %s: level %d" % [passive_id, node.level], "ui")

func _connect_node_signals() -> void:
	"""Connect SkillNode click events to passive allocation logic"""
	# Get all skill nodes (both mapped and unmapped)
	var all_nodes = _find_skill_nodes_recursive(self)

	for node in all_nodes:
		# CRITICAL: Disconnect SkillNode's internal pressed handler to prevent conflict
		if node.pressed.is_connected(node._on_pressed):
			node.pressed.disconnect(node._on_pressed)
			Logger.debug("Disconnected internal SkillNode handler for %s" % node.name, "events")

		# Connect BreachSkillTree handler for EventMasterySystem integration
		if not node.pressed.is_connected(_on_node_pressed):
			node.pressed.connect(_on_node_pressed.bind(node))
			Logger.debug("Connected BreachSkillTree handler for %s" % node.name, "events")

func _on_node_pressed(node) -> void:
	"""Handle any skill node press - route to appropriate handler"""
	# Find if this node is mapped to a passive
	var mapped_passive_id: StringName = ""
	for passive_id in _skill_nodes:
		if _skill_nodes[passive_id] == node:
			mapped_passive_id = passive_id
			break

	if mapped_passive_id != "":
		# This is a mapped node - use EventMasterySystem integration
		_on_skill_node_clicked(mapped_passive_id, node)
	else:
		# This is an unmapped node - use visual behavior with reset mode awareness
		Logger.debug("Handling unmapped node %s with visual behavior (reset_mode: %s)" % [node.name, _reset_mode], "events")
		if _reset_mode:
			# Reset mode - only try to deallocate if node has points
			if node.level > 0:
				if _can_unmapped_node_be_removed(node):
					node.level = 0  # Deallocate completely in single-level system
					node._update_skill_state()
					Logger.info("Deallocated unmapped node: %s" % node.name, "events")
				else:
					Logger.info("Cannot deallocate unmapped node %s - child dependencies exist" % node.name, "events")
			else:
				Logger.info("Unmapped node %s already deallocated" % node.name, "events")
		else:
			# Normal mode - toggle allocation (handled by SkillNode's _on_left_click)
			node._on_left_click()

func _connect_ui_buttons() -> void:
	"""Connect UI buttons in the BreachSkillTree"""
	# Reset and close buttons removed - functionality now handled by AtlasTreeUI panel
	pass

func _on_skill_node_clicked(passive_id: StringName, node) -> void:
	"""Handle skill node clicks for passive allocation/deallocation with single-level binary system"""
	# Check if this node is mapped to EventMasterySystem
	if passive_id in _skill_nodes and _mastery_system:
		var passive_info = _mastery_system.get_passive_info(passive_id)
		var current_level = passive_info.current_level

		if _reset_mode:
			# Reset mode - deallocate if allocated
			if current_level > 0:
				if _can_deallocate_with_prerequisites(passive_id):
					_mastery_system.deallocate_passive(passive_id)
					node.level = 0
					passive_deallocated.emit(passive_id)
					Logger.info("Deallocated passive: %s" % passive_id, "events")
				else:
					Logger.info("Cannot deallocate passive %s - child dependencies exist" % passive_id, "events")
			else:
				Logger.info("Passive %s already deallocated" % passive_id, "events")
		else:
			# Normal mode - toggle allocation (0 <-> 1)
			if current_level == 0:
				# Not allocated - try to allocate
				if _can_allocate_with_prerequisites(passive_id):
					if _mastery_system.allocate_passive(passive_id):
						node.level = 1
						passive_allocated.emit(passive_id)
						Logger.info("Allocated passive: %s" % passive_id, "events")
				else:
					var parent_id = _get_node_parent(passive_id)
					if parent_id != "":
						Logger.info("Cannot allocate passive %s - parent %s requires allocation" % [passive_id, parent_id], "events")
					else:
						Logger.info("Cannot allocate passive %s - insufficient points" % passive_id, "events")
			else:
				# Already allocated - try to deallocate
				if _can_deallocate_with_prerequisites(passive_id):
					_mastery_system.deallocate_passive(passive_id)
					node.level = 0
					passive_deallocated.emit(passive_id)
					Logger.info("Deallocated passive: %s" % passive_id, "events")
				else:
					Logger.info("Cannot deallocate passive %s - child dependencies exist" % passive_id, "events")

		# Refresh UI after allocation changes
		_refresh_all_nodes()

func set_reset_mode(active: bool) -> void:
	"""Set reset mode for deallocation clicks"""
	_reset_mode = active
	_update_reset_mode_highlighting(active)
	Logger.debug("Reset mode %s for %s tree" % ["activated" if active else "deactivated", event_type], "events")

func _update_reset_mode_highlighting(active: bool) -> void:
	"""Update highlighting for all skill nodes based on reset mode state"""
	# Get all skill nodes (both mapped and unmapped)
	var all_nodes = _find_skill_nodes_recursive(self)

	for node in all_nodes:
		if not node is SkillNode:
			continue

		if not active:
			# Exit reset mode - clear all highlighting
			node.set_reset_mode_highlight(false)
		else:
			# Enter reset mode - determine if this node can be removed
			var can_remove = false

			# Check if this is a mapped node (connected to EventMasterySystem)
			var mapped_passive_id: StringName = ""
			for passive_id in _skill_nodes:
				if _skill_nodes[passive_id] == node:
					mapped_passive_id = passive_id
					break

			if mapped_passive_id != "":
				# Mapped node - use EventMasterySystem validation
				can_remove = _can_deallocate_with_prerequisites(mapped_passive_id)
			else:
				# Unmapped node - use simple logic (has points and no children with points)
				can_remove = _can_unmapped_node_be_removed(node)

			node.set_reset_mode_highlight(true, can_remove)

	Logger.debug("Updated reset mode highlighting for %d nodes" % all_nodes.size(), "events")

func _can_unmapped_node_be_removed(node) -> bool:
	"""Check if an unmapped skill node can be removed (leaf-only logic)"""
	if node.level <= 0:
		return false  # No points to remove

	# Only check that this node's subtree is empty - siblings don't matter
	return _is_unmapped_subtree_empty(node)

func _has_unmapped_siblings_with_points(node) -> bool:
	"""Check if this unmapped node has siblings that still have points"""
	var parent = node.get_parent()
	if not parent is SkillNode:
		return false  # Root node has no siblings

	var siblings = parent.get_children()
	for sibling in siblings:
		if sibling is SkillNode and sibling != node:  # Don't check self
			if sibling.level > 0:
				return true  # Found a sibling with points

	return false  # No siblings have points

func _is_unmapped_subtree_empty(node) -> bool:
	"""Check if entire unmapped subtree has no allocated points (recursive)"""
	var child_nodes = node.get_children()

	# Check direct children
	for child in child_nodes:
		if child is SkillNode:
			if child.level > 0:
				return false  # Direct child has points

			# Recursively check child's subtree
			if not _is_unmapped_subtree_empty(child):
				return false  # Descendant has points

	return true  # No allocated descendants found

func _get_node_children(passive_id: StringName) -> Array[StringName]:
	"""Get all child passive IDs for a given passive"""
	var children: Array[StringName] = []
	var parent_node = _skill_nodes.get(passive_id)
	if not parent_node:
		return children

	# Find all skill nodes that are children of this node
	for child_passive_id in _skill_nodes:
		var child_node = _skill_nodes[child_passive_id]
		if child_node.get_parent() == parent_node:
			children.append(child_passive_id)

	return children

func _get_node_parent(passive_id: StringName) -> StringName:
	"""Get parent passive ID for a given passive"""
	var node = _skill_nodes.get(passive_id)
	if not node:
		return ""

	var parent_node = node.get_parent()
	if not parent_node or not parent_node is SkillNode:
		return ""  # Root node or invalid parent

	# Find the passive ID that corresponds to this parent node
	for parent_passive_id in _skill_nodes:
		if _skill_nodes[parent_passive_id] == parent_node:
			return parent_passive_id

	return ""

func _can_allocate_with_prerequisites(passive_id: StringName) -> bool:
	"""Check if passive can be allocated considering parent prerequisites"""
	if not _mastery_system.can_allocate_passive(passive_id):
		return false  # Basic checks failed

	# Check parent requirement
	var parent_id = _get_node_parent(passive_id)
	if parent_id != "":
		var parent_level = _mastery_system.get_passive_level(parent_id)
		if parent_level < 1:
			Logger.debug("Cannot allocate %s - parent %s has no points" % [passive_id, parent_id], "events")
			return false

	return true

func _can_deallocate_with_prerequisites(passive_id: StringName) -> bool:
	"""Check if passive can be deallocated considering child dependencies"""
	var current_level = _mastery_system.get_passive_level(passive_id)
	if current_level <= 0:
		return false  # Nothing to deallocate

	# In single-level system, can only deallocate if no children have points
	if not _is_subtree_empty(passive_id):
		Logger.debug("Cannot deallocate %s - subtree still has allocated descendants" % passive_id, "events")
		return false

	# Also check actual scene tree children (unmapped nodes)
	var node = _skill_nodes.get(passive_id)
	if node and not _is_unmapped_subtree_empty(node):
		Logger.debug("Cannot deallocate %s - scene subtree still has allocated descendants" % passive_id, "events")
		return false

	return true

func _has_siblings_with_points(passive_id: StringName) -> bool:
	"""Check if this passive has siblings (same parent) that still have points"""
	var parent_id = _get_node_parent(passive_id)
	if parent_id == "":
		return false  # Root node has no siblings

	var siblings = _get_node_children(parent_id)
	for sibling_id in siblings:
		if sibling_id != passive_id:  # Don't check self
			var sibling_level = _mastery_system.get_passive_level(sibling_id)
			if sibling_level > 0:
				return true  # Found a sibling with points

	return false  # No siblings have points

func _is_subtree_empty(passive_id: StringName) -> bool:
	"""Check if entire subtree has no allocated points (recursive)"""
	var children = _get_node_children(passive_id)

	# Check direct children
	for child_id in children:
		var child_level = _mastery_system.get_passive_level(child_id)
		if child_level > 0:
			return false  # Direct child has points

		# Recursively check child's subtree
		if not _is_subtree_empty(child_id):
			return false  # Descendant has points

	return true  # No allocated descendants found

func _refresh_all_nodes() -> void:
	"""Refresh all skill nodes to reflect current mastery system state"""
	if not _mastery_system:
		return

	for passive_id in _skill_nodes:
		var node = _skill_nodes[passive_id]
		var passive_info = _mastery_system.get_passive_info(passive_id)
		var new_level = passive_info.get("current_level", 0)

		# Single-level system - no max_level updates needed

		# Update node level from current passive state
		node.level = new_level

		# Update node availability based on prerequisite logic
		node._update_skill_state()

	# Update all child node line connections after all levels are set
	call_deferred("_refresh_all_line_connections")

	# If in reset mode, refresh highlighting to reflect dependency changes
	if _reset_mode:
		_update_reset_mode_highlighting(true)

func _refresh_all_line_connections():
	"""Refresh line connections for all nodes after positions and levels are finalized"""
	for passive_id in _skill_nodes:
		var node = _skill_nodes[passive_id]
		if node.get_parent() is SkillNode:
			node._setup_line_connection()

func reset_all_skills() -> void:
	"""Reset all skills in this tree"""
	if not _mastery_system:
		return

	# Deallocate all passives for this event type (handles mapped nodes)
	var event_passives = _mastery_system.get_all_passives_for_event_type(event_type)
	for passive_info in event_passives:
		if passive_info.current_level > 0:
			# Single deallocate call for single-level system
			_mastery_system.deallocate_passive(passive_info.id)
			passive_deallocated.emit(passive_info.id)

	# Also reset ALL skill nodes directly (handles unmapped nodes)
	var all_skill_nodes = _find_skill_nodes_recursive(self)
	for node in all_skill_nodes:
		if node.has_method("reset_skill"):
			node.reset_skill()

	_refresh_all_nodes()
	Logger.info("Reset all skills for %s event type (reset %d total nodes)" % [event_type, all_skill_nodes.size()], "ui")

func get_available_points() -> int:
	"""Get available points for this event type"""
	if not _mastery_system or not _mastery_system.mastery_tree:
		return 0
	return _mastery_system.mastery_tree.get_points_for_event_type(event_type)

func get_allocated_points() -> int:
	"""Get allocated points for this event type"""
	if not _mastery_system:
		return 0

	var allocated_count = 0
	var event_passives = _mastery_system.get_all_passives_for_event_type(event_type)
	for passive_info in event_passives:
		if passive_info.allocated:
			allocated_count += passive_info.cost

	return allocated_count
