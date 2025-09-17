extends Control
class_name SkillTreeUI

## Full-screen skill tree UI with four independent event trees
## Uses SkillTreeNode components arranged in quadrants

signal skill_tree_closed()

# Tree sections (assigned via @onready)
@onready var breach_section: Control = $TreeContainer/BreachTreeSection
@onready var ritual_section: Control = $TreeContainer/RitualTreeSection
@onready var pack_section: Control = $TreeContainer/PackTreeSection
@onready var boss_section: Control = $TreeContainer/BossTreeSection

# UI elements (assigned via @onready)
@onready var background: ColorRect = $Background
@onready var tree_container: Control = $TreeContainer
@onready var ui_panel: Panel = $UIPanel
# Labels removed from scene - will create them separately if needed
@onready var close_button: Button = $UIPanel/VBoxContainer/CloseButton
@onready var tooltip_container: Control = $TooltipContainer
@onready var tooltip_label: RichTextLabel = $TooltipContainer/TooltipPanel/TooltipLabel

# Node references organized by event type
var skill_nodes: Dictionary = {
	"breach": [],
	"ritual": [],
	"pack_hunt": [],
	"boss": []
}

# System references
var mastery_system
var _is_initialized: bool = false
var _current_tooltip_node: SkillTreeNode = null

# Preload the SkillTreeNode scene
var skill_node_scene = preload("res://scenes/ui/skill_tree/SkillTreeNode.tscn")

func _ready() -> void:
	# UI should always process (pause-independent)
	process_mode = Node.PROCESS_MODE_ALWAYS

	# Hide initially
	visible = false

	# Initialize UI
	call_deferred("_initialize_skill_tree")

func _initialize_skill_tree() -> void:
	if _is_initialized:
		return

	Logger.info("Initializing four-quadrant skill tree UI", "ui")

	# Find mastery system
	if not mastery_system:
		mastery_system = _find_mastery_system()

	# Set up UI elements from scene
	_setup_background_and_panels()
	_collect_skill_nodes()
	_setup_node_connections()
	_connect_ui_signals()

	# Initialize tooltip as hidden
	if tooltip_container:
		tooltip_container.visible = false

	_is_initialized = true
	Logger.info("Skill tree UI initialization complete", "ui")

func _find_mastery_system():
	"""Find the EventMasterySystem in the scene tree"""
	# Check SpawnDirector for mastery system
	var spawn_directors = get_tree().get_nodes_in_group("wave_directors")
	for director in spawn_directors:
		if "mastery_system" in director and director.mastery_system:
			return director.mastery_system
	return null

func _setup_background_and_panels() -> void:
	"""Set up the visual appearance of background and UI panels"""
	if background:
		# Solid dark background
		background.color = Color(0.15, 0.15, 0.15, 1.0)

	# Note: All positioning is now handled in the scene, not programmatically

func _collect_skill_nodes() -> void:
	"""Collect all SkillTreeNode instances and organize by event type"""
	# Clear existing collections
	for event_type in skill_nodes.keys():
		skill_nodes[event_type].clear()

	# Collect nodes from each section
	_collect_nodes_from_section(breach_section, "breach")
	_collect_nodes_from_section(ritual_section, "ritual")
	_collect_nodes_from_section(pack_section, "pack_hunt")
	_collect_nodes_from_section(boss_section, "boss")

	Logger.debug("Collected skill nodes: Breach=%d, Ritual=%d, Pack=%d, Boss=%d" % [
		skill_nodes["breach"].size(),
		skill_nodes["ritual"].size(),
		skill_nodes["pack_hunt"].size(),
		skill_nodes["boss"].size()
	], "ui")

func _collect_nodes_from_section(section: Control, event_type: String) -> void:
	"""Collect SkillTreeNode instances from a specific section"""
	if not section:
		return

	var nodes = _find_skill_tree_nodes_recursive(section)
	for node in nodes:
		if node.event_type == event_type or node.event_type == "":
			node.event_type = event_type
			_initialize_node_with_passive_data(node, event_type)
			skill_nodes[event_type].append(node)

func _find_skill_tree_nodes_recursive(parent: Node) -> Array[SkillTreeNode]:
	"""Recursively find all SkillTreeNode instances under a parent"""
	var nodes: Array[SkillTreeNode] = []

	for child in parent.get_children():
		if child is SkillTreeNode:
			nodes.append(child as SkillTreeNode)
		else:
			nodes.append_array(_find_skill_tree_nodes_recursive(child))

	return nodes

func _initialize_node_with_passive_data(node: SkillTreeNode, event_type: String) -> void:
	"""Initialize a node with passive data from mastery system"""
	if not mastery_system:
		# Set default values for testing
		var default_title = event_type.capitalize() + " Node"
		var default_description = "Improves " + event_type + " events"
		node.setup_node(node.passive_id, event_type, default_title, default_description, 1)
		node.set_state(SkillTreeNode.NodeState.AVAILABLE)  # Make it visible and clickable
		return

	# Get passive definitions from mastery system
	var passives = mastery_system.passive_definitions
	if not passives:
		return

	# Try to match with existing passive definition
	var passive_id = node.passive_id
	if passive_id.is_empty():
		# Assign a default passive ID based on position
		var section_nodes = skill_nodes.get(event_type, [])
		passive_id = event_type + "_node_" + str(section_nodes.size() + 1)

	var passive_data = passives.get(passive_id, {})
	if passive_data.is_empty():
		# Create default passive data
		var default_title = event_type.capitalize() + " Enhancement"
		var default_description = "Improves " + event_type + " event effectiveness"
		node.setup_node(passive_id, event_type, default_title, default_description, 1)
	else:
		# Use actual passive data
		node.setup_node(
			passive_id,
			event_type,
			passive_data.get("name", "Unknown"),
			passive_data.get("description", "No description"),
			passive_data.get("cost", 1)
		)

	# Set initial state to AVAILABLE so nodes are visible and clickable
	node.set_state(SkillTreeNode.NodeState.AVAILABLE)

func _setup_node_connections() -> void:
	"""Connect signals from all skill tree nodes"""
	for event_type in skill_nodes.keys():
		for node in skill_nodes[event_type]:
			if not node.node_clicked.is_connected(_on_skill_node_clicked):
				node.node_clicked.connect(_on_skill_node_clicked)
			if not node.node_hovered.is_connected(_on_skill_node_hovered):
				node.node_hovered.connect(_on_skill_node_hovered)
			if not node.node_unhovered.is_connected(_on_skill_node_unhovered):
				node.node_unhovered.connect(_on_skill_node_unhovered)

func _connect_ui_signals() -> void:
	"""Connect UI button signals"""
	if close_button:
		close_button.pressed.connect(hide_ui)

	# Connect to mastery system signals
	if EventBus:
		EventBus.mastery_points_earned.connect(_on_mastery_points_earned)
		EventBus.passive_allocated.connect(_on_passive_changed)
		EventBus.passive_deallocated.connect(_on_passive_changed)

func _on_skill_node_clicked(node: SkillTreeNode) -> void:
	"""Handle skill node click for allocation/deallocation"""
	if not mastery_system or not node:
		return

	Logger.debug("Skill node clicked: %s (%s)" % [node.passive_id, node.event_type], "ui")

	if node.is_allocated():
		# Deallocate the passive
		mastery_system.deallocate_passive(node.passive_id)
	else:
		# Allocate the passive
		mastery_system.allocate_passive(node.passive_id)

func _on_skill_node_hovered(node: SkillTreeNode) -> void:
	"""Show tooltip when hovering over a node"""
	_current_tooltip_node = node
	_show_tooltip(node)

func _on_skill_node_unhovered(node: SkillTreeNode) -> void:
	"""Hide tooltip when leaving a node"""
	if _current_tooltip_node == node:
		_hide_tooltip()
		_current_tooltip_node = null

func _show_tooltip(node: SkillTreeNode) -> void:
	"""Display tooltip for a skill node"""
	if not tooltip_container or not tooltip_label or not node:
		return

	tooltip_label.text = node.get_skill_tooltip_text()
	tooltip_container.visible = true

	# Position tooltip near the mouse
	var mouse_pos = get_global_mouse_position()
	tooltip_container.position = mouse_pos + Vector2(10, 10)

func _hide_tooltip() -> void:
	"""Hide the tooltip"""
	if tooltip_container:
		tooltip_container.visible = false

func _on_mastery_points_earned(event_type: StringName, points: int) -> void:
	"""Refresh UI when mastery points are earned"""
	_refresh_ui()

func _on_passive_changed(passive_id: StringName) -> void:
	"""Refresh UI when a passive is allocated/deallocated"""
	_refresh_ui()

func _refresh_ui() -> void:
	"""Update all UI elements based on current mastery state"""
	if not mastery_system:
		return

	# Update each node's state
	_refresh_all_nodes()

func _refresh_all_nodes() -> void:
	"""Update the visual state of all skill nodes"""
	for event_type in skill_nodes.keys():
		_refresh_nodes_for_event_type(event_type)

func _refresh_nodes_for_event_type(event_type: String) -> void:
	"""Update nodes for a specific event type"""
	if not mastery_system:
		return

	var available_points = mastery_system.mastery_tree.get_points_for_event_type(event_type)

	for node in skill_nodes[event_type]:
		var passive_info = mastery_system.get_passive_info(node.passive_id)

		if passive_info.get("allocated", false):
			node.set_state(SkillTreeNode.NodeState.ALLOCATED)
		elif passive_info.get("can_allocate", false):
			node.set_state(SkillTreeNode.NodeState.AVAILABLE)
		else:
			node.set_state(SkillTreeNode.NodeState.LOCKED)

func show_ui() -> void:
	"""Show the skill tree UI"""
	visible = true
	_refresh_ui()
	Logger.debug("Skill tree UI shown", "ui")

func hide_ui() -> void:
	"""Hide the skill tree UI"""
	visible = false
	_hide_tooltip()
	skill_tree_closed.emit()
	Logger.debug("Skill tree UI hidden", "ui")

func toggle_ui() -> void:
	"""Toggle the skill tree UI visibility"""
	if visible:
		hide_ui()
	else:
		show_ui()

func _input(event: InputEvent) -> void:
	"""Handle input when UI is visible"""
	if not visible:
		return

	if event.is_action_pressed("ui_cancel"):
		hide_ui()
		get_viewport().set_input_as_handled()

func _gui_input(event: InputEvent) -> void:
	"""Handle mouse movement for tooltip positioning"""
	if event is InputEventMouseMotion and _current_tooltip_node:
		_show_tooltip(_current_tooltip_node)
