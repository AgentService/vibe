extends Control
class_name EventSkillTree

## Data-driven skill tree component that can load different event type skill configurations.
## Reuses the existing SkillNode architecture but loads layout and passive data from resources.

signal passive_allocated(passive_id: StringName)
signal passive_deallocated(passive_id: StringName)

@export var skill_tree_data: Resource ## SkillTreeData resource containing tree configuration
@export var event_type: StringName = "breach" ## Event type this tree represents

var _mastery_system: Node
var _skill_nodes: Dictionary = {} ## passive_id -> SkillNode mapping

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
			Logger.warn("EventSkillTree has no skill_tree_data configured for event type: %s" % event_type, "ui")

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
	_refresh_all_nodes()
	Logger.info("EventSkillTree initialized for %s event type" % event_type, "ui")

	_connect_ui_buttons()

func _collect_existing_skill_nodes() -> void:
	"""Collect all SkillNode instances from the existing tree structure"""
	var nodes = _find_skill_nodes_recursive(self)
	Logger.debug("Found %d skill nodes in tree" % nodes.size(), "ui")

	# For MVP, we'll assign nodes to breach passives based on their position in tree
	# This maintains the existing visual layout while connecting to EventMasterySystem
	for i in range(nodes.size()):
		var node: SkillNode = nodes[i]
		if node and i < _get_breach_passive_ids().size():
			var passive_id = _get_breach_passive_ids()[i]
			_skill_nodes[passive_id] = node
			Logger.debug("Mapped node %s to passive %s" % [node.name, passive_id], "ui")

func _get_breach_passive_ids() -> Array[StringName]:
	"""Get the breach passive IDs from EventMasterySystem in tree order"""
	if not _mastery_system:
		return []

	# Extract breach passives from EventMasterySystem
	var breach_passives: Array[StringName] = []
	for passive_id in _mastery_system.passive_definitions:
		var passive_def = _mastery_system.passive_definitions[passive_id]
		if passive_def.event_type == "breach":
			breach_passives.append(passive_id)

	return breach_passives

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
		var node: SkillNode = _skill_nodes[passive_id]
		var passive_info = _mastery_system.get_passive_info(passive_id)

		# Set node level and max_level from passive info
		node.level = passive_info.get("current_level", 0)
		node.max_level = passive_info.get("max_level", 3)  # Default to 3 if not specified

		Logger.debug("Mapped %s: level %d/%d" % [passive_id, node.level, node.max_level], "ui")

func _connect_node_signals() -> void:
	"""Connect SkillNode click events to passive allocation logic"""
	# Get all skill nodes (both mapped and unmapped)
	var all_nodes = _find_skill_nodes_recursive(self)

	for node in all_nodes:
		# CRITICAL: Disconnect SkillNode's internal pressed handler to prevent conflict
		if node.pressed.is_connected(node._on_pressed):
			node.pressed.disconnect(node._on_pressed)
			Logger.debug("Disconnected internal SkillNode handler for %s" % node.name, "events")

		# Connect EventSkillTree handler for EventMasterySystem integration
		if not node.pressed.is_connected(_on_node_pressed):
			node.pressed.connect(_on_node_pressed.bind(node))
			Logger.debug("Connected EventSkillTree handler for %s" % node.name, "events")

func _on_node_pressed(node: SkillNode) -> void:
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
		# This is an unmapped node - use pure visual behavior (call SkillNode's visual logic)
		Logger.debug("Handling unmapped node %s with visual behavior" % node.name, "events")
		node._on_left_click()  # Call SkillNode's visual allocation logic directly

func _connect_ui_buttons() -> void:
	"""Connect UI buttons in the EventSkillTree"""
	# Reset and close buttons removed - functionality now handled by AtlasTreeUI panel
	pass

func _on_skill_node_clicked(passive_id: StringName, node: SkillNode) -> void:
	"""Handle skill node clicks for passive allocation/deallocation with multi-level support"""
	# Check if this node is mapped to EventMasterySystem
	if passive_id in _skill_nodes and _mastery_system:
		var passive_info = _mastery_system.get_passive_info(passive_id)
		var current_level = passive_info.current_level
		var max_level = passive_info.max_level

		# Determine action based on current level
		# Left-click increments level, reset only via reset button
		if current_level >= max_level:
			# At max level - no action, reset only via button
			Logger.info("Passive %s already at max level (%d/%d) - use reset button to deallocate" % [passive_id, current_level, max_level], "events")
			return
		elif current_level == 0:
			# Not allocated - allocate to level 1
			if _mastery_system.can_allocate_passive(passive_id):
				if _mastery_system.allocate_passive(passive_id):
					node.level = 1
					passive_allocated.emit(passive_id)
					Logger.info("Allocated passive: %s (level 1)" % passive_id, "events")
			else:
				Logger.info("Cannot allocate passive %s - insufficient points" % passive_id, "events")
		else:
			# Has some levels (1 or 2) - try to increment to next level
			if _mastery_system.can_allocate_passive(passive_id):
				if _mastery_system.allocate_passive(passive_id):
					var new_level = _mastery_system.get_passive_level(passive_id)
					node.level = new_level
					passive_allocated.emit(passive_id)
					Logger.info("Leveled up passive: %s (level %d)" % [passive_id, new_level], "events")
			else:
				Logger.info("Cannot level up passive %s - insufficient points" % passive_id, "events")

		# Refresh UI after allocation changes
		_refresh_all_nodes()

func _refresh_all_nodes() -> void:
	"""Refresh all skill nodes to reflect current mastery system state"""
	if not _mastery_system:
		return

	for passive_id in _skill_nodes:
		var node: SkillNode = _skill_nodes[passive_id]
		var passive_info = _mastery_system.get_passive_info(passive_id)

		# Update node level and max_level from current passive state
		node.level = passive_info.get("current_level", 0)
		node.max_level = passive_info.get("max_level", 3)

		# Update node availability based on prerequisite logic
		# The existing SkillNode prerequisite system handles this automatically
		node._update_skill_state()

func reset_all_skills() -> void:
	"""Reset all skills in this tree"""
	if not _mastery_system:
		return

	# Deallocate all passives for this event type (handles mapped nodes)
	var event_passives = _mastery_system.get_all_passives_for_event_type(event_type)
	for passive_info in event_passives:
		if passive_info.allocated:
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
