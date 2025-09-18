extends Control
class_name SkillTreeNode

## Individual skill tree node component for the Event Mastery Tree
## Represents a single passive skill with visual states and interaction

signal node_clicked(node: SkillTreeNode)
signal node_hovered(node: SkillTreeNode)
signal node_unhovered(node: SkillTreeNode)

# Node configuration
@export var passive_id: StringName = ""
@export var event_type: StringName = ""
@export var node_title: String = ""
@export var node_description: String = ""
@export var point_cost: int = 1

# Visual components (assigned via @onready)
@onready var background: NinePatchRect = $Background
@onready var icon: TextureRect = $Icon
@onready var state_indicator: ColorRect = $StateIndicator
@onready var hover_effect: ColorRect = $HoverEffect
@onready var click_area: Button = $ClickArea
@onready var connection_point: Marker2D = $ConnectionPoint
@onready var connection_indicator: ColorRect = $ConnectionPoint/ConnectionIndicator
@onready var title_label: Label = $TitleLabel

# Node states
enum NodeState {
	LOCKED,      # Cannot be allocated (insufficient points or prerequisites)
	AVAILABLE,   # Can be allocated
	ALLOCATED,   # Already allocated
	HOVER        # Mouse hover state
}

var current_state: NodeState = NodeState.LOCKED
var previous_state: NodeState = NodeState.LOCKED
var is_root_node: bool = false

# Theme colors (will be set from main theme)
var event_colors: Dictionary = {
	"breach": Color(0.8, 0.2, 0.8, 1),    # Purple
	"ritual": Color(0.2, 0.8, 0.2, 1),    # Green
	"pack_hunt": Color(0.8, 0.6, 0.2, 1), # Orange
	"boss": Color(0.8, 0.2, 0.2, 1)       # Red
}

func _ready() -> void:
	# Set up click area to cover the entire node
	click_area.pressed.connect(_on_node_clicked)
	click_area.mouse_entered.connect(_on_node_hovered)
	click_area.mouse_exited.connect(_on_node_unhovered)

	# Make click area transparent but functional
	click_area.flat = true
	click_area.focus_mode = Control.FOCUS_NONE

	# Initialize visual state
	_update_visual_state()

	Logger.debug("SkillTreeNode initialized: %s (%s)" % [passive_id, event_type], "ui")

func setup_node(p_passive_id: StringName, p_event_type: StringName, p_title: String, p_description: String, p_cost: int = 1) -> void:
	"""Configure the node with passive data"""
	passive_id = p_passive_id
	event_type = p_event_type
	node_title = p_title
	node_description = p_description
	point_cost = p_cost

	# Update visual elements if they exist
	if icon:
		_setup_icon()
	if title_label:
		title_label.text = node_title
	_update_visual_state()

func set_state(new_state: NodeState) -> void:
	"""Update the node's visual state"""
	if current_state != new_state:
		# Store previous state before changing (but not if we're hovering)
		if new_state == NodeState.HOVER:
			previous_state = current_state
		current_state = new_state
		_update_visual_state()

		# Note: Particle effects removed as requested

func get_event_color() -> Color:
	"""Get the color associated with this node's event type"""
	return event_colors.get(event_type, Color.WHITE)

func _setup_icon() -> void:
	"""Set up the icon based on event type (placeholder for now)"""
	if not icon:
		return

	# For now, use a simple colored rectangle as icon
	# In future, this could load actual icon textures
	icon.modulate = get_event_color()

func _update_visual_state() -> void:
	"""Update all visual components based on current state"""
	if not background or not state_indicator:
		return

	var bg_color: Color
	var indicator_color: Color
	var hover_visible: bool = false

	match current_state:
		NodeState.LOCKED:
			bg_color = Color(0.25, 0.25, 0.25, 1)     # Dark gray
			indicator_color = Color(0.15, 0.15, 0.15, 1) # Darker gray
		NodeState.AVAILABLE:
			bg_color = Color(0.4, 0.4, 0.4, 1)        # Medium gray
			indicator_color = get_event_color() * 0.7  # Dimmed event color
		NodeState.ALLOCATED:
			bg_color = get_event_color()               # Full event color
			indicator_color = Color.WHITE              # Bright center
		NodeState.HOVER:
			bg_color = Color(0.5, 0.5, 0.5, 1)        # Light gray
			indicator_color = get_event_color()        # Event color
			hover_visible = true

	# Apply colors
	background.modulate = bg_color
	state_indicator.color = indicator_color

	# Show/hide hover effect
	if hover_effect:
		hover_effect.visible = hover_visible
		hover_effect.color = get_event_color() * 0.5

	# Update connection indicator color to match event type
	if connection_indicator:
		connection_indicator.color = get_event_color() * 0.8


func _on_node_clicked() -> void:
	"""Handle node click"""
	if current_state == NodeState.AVAILABLE or current_state == NodeState.ALLOCATED:
		node_clicked.emit(self)

func _on_node_hovered() -> void:
	"""Handle mouse enter"""
	if current_state != NodeState.LOCKED:
		set_state(NodeState.HOVER)
		node_hovered.emit(self)

func _on_node_unhovered() -> void:
	"""Handle mouse exit"""
	if current_state == NodeState.HOVER:
		# Restore the previous state
		set_state(previous_state)
		node_unhovered.emit(self)

func get_connection_position() -> Vector2:
	"""Get the world position for connecting lines"""
	if connection_point:
		return connection_point.global_position
	return global_position + size / 2

func can_allocate() -> bool:
	"""Check if this node can be allocated"""
	return current_state == NodeState.AVAILABLE

func is_allocated() -> bool:
	"""Check if this node is allocated"""
	return current_state == NodeState.ALLOCATED

func get_skill_tooltip_text() -> String:
	"""Generate tooltip text for this node"""
	var tooltip = "[b]%s[/b]\n" % node_title
	tooltip += "%s\n\n" % node_description
	tooltip += "[color=yellow]Cost: %d point%s[/color]" % [point_cost, "s" if point_cost != 1 else ""]

	match current_state:
		NodeState.LOCKED:
			tooltip += "\n[color=red]Insufficient points[/color]"
		NodeState.AVAILABLE:
			tooltip += "\n[color=green]Click to allocate[/color]"
		NodeState.ALLOCATED:
			tooltip += "\n[color=cyan]Allocated - Click to deallocate[/color]"

	return tooltip
