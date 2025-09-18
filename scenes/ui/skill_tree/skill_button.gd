extends TextureButton
class_name SkillNode

@onready var panel = $Panel
@onready var label = $MarginContainer/Label
@onready var line_2d: Line2D = $Line2D
@onready var border_highlight: ColorRect

# Skill tree line styling constants
const LINE_ACTIVE_COLOR = Color(0.946, 0.791, 0.0, 1.0)     # Bright yellow
const LINE_INACTIVE_COLOR = Color(0.7, 0.7, 0.7, 1.0)       # Light gray
const LINE_DISABLED_COLOR = Color(0.3, 0.3, 0.3, 1.0)       # Dark gray
const LINE_WIDTH = 3.0
const LINE_CONNECTION_MARGIN = 50.0  # Preferred pixel distance from node edges
const MIN_LINE_LENGTH = 20.0  # Minimum visible line length

# Border highlight colors for reset mode and general feedback
const BORDER_HIDDEN = Color(1, 1, 1, 0)                      # Transparent - no border
const BORDER_AVAILABLE = Color(0.0, 0.8, 1.0, 0.8)          # Cyan - available for allocation
const BORDER_REMOVABLE = Color(0.2, 1.0, 0.2, 0.9)          # Bright green - can be removed
const BORDER_BLOCKED = Color(1.0, 0.3, 0.3, 0.9)            # Bright red - cannot be removed
const BORDER_ALLOCATED = Color(1.0, 0.8, 0.0, 0.7)          # Golden - currently allocated


# Themed breach skill tree dropdown with hierarchy indicators
enum PassiveType {
	NONE,
	# Support Tree - Safer, Controlled Breaches
	SUPPORT_A_STABILIZATION,    # 🛡️ Support A - Stabilization
	SUPPORT_B_FORTIFICATION,    # 🛡️ Support B - Fortification
	SUPPORT_C_MASTERY,          # 🛡️ Support C - Mastery
	SUPPORT_C_SANCTUARY,        # 🛡️ Support C - Sanctuary
	# Density Tree - High Risk, High Action
	DENSITY_A_DENSITY,          # ⚔️ Density A - Density
	DENSITY_B_CHAOS,            # ⚔️ Density B - Chaos
	DENSITY_C_FRENZY,           # ⚔️ Density C - Frenzy
	# Reward Tree - Fast, Risky, Rewarding
	REWARD_A_VELOCITY,          # 💎 Reward A - Velocity
	REWARD_B_INTENSITY,         # 💎 Reward B - Intensity
	REWARD_C_WINDFALL           # 💎 Reward C - Windfall
}

@export var passive_type: PassiveType = PassiveType.NONE

# Convert enum to StringName for EventMasterySystem
var passive_id: StringName:
	get:
		match passive_type:
			# Support Tree - Safer, Controlled Breaches
			PassiveType.SUPPORT_A_STABILIZATION: return "breach_stabilization"
			PassiveType.SUPPORT_B_FORTIFICATION: return "breach_fortification"
			PassiveType.SUPPORT_C_MASTERY: return "breach_mastery"
			PassiveType.SUPPORT_C_SANCTUARY: return "breach_sanctuary"
			# Density Tree - High Risk, High Action
			PassiveType.DENSITY_A_DENSITY: return "breach_density"
			PassiveType.DENSITY_B_CHAOS: return "breach_chaos"
			PassiveType.DENSITY_C_FRENZY: return "breach_frenzy"
			# Reward Tree - Fast, Risky, Rewarding
			PassiveType.REWARD_A_VELOCITY: return "breach_velocity"
			PassiveType.REWARD_B_INTENSITY: return "breach_intensity"
			PassiveType.REWARD_C_WINDFALL: return "breach_windfall"
			_: return ""

var _reset_mode_active: bool = false
var _can_be_removed: bool = false
var _normal_modulate: Color = Color.WHITE

func _ready():
	# Initialize border highlight reference
	border_highlight = $BorderHighlight

	if border_highlight:
		border_highlight.color = BORDER_HIDDEN

	_update_label()  # Initialize label
	_update_skill_state()  # Apply initial state

	# Connect to pressed signal for button input
	pressed.connect(_on_pressed)

	# Setup line connections with padding
	if get_parent() is SkillNode:
		_setup_line_connection()
 
var level : int = 0:
	set(value):
		# Clamp to 0 or 1 for single-level system
		level = 1 if value > 0 else 0
		_update_label()
		# Update line color when level changes
		if is_inside_tree():
			call_deferred("_update_line_color")
		# Update border based on allocation state (if not in reset mode)
		if is_inside_tree() and not _reset_mode_active:
			_update_border_for_level()

func _update_label():
	if label:
		# Simple allocated/not allocated display
		label.text = "✓" if level > 0 else ""

func _setup_line_connection():
	"""Setup line connection with dynamic padding to ensure minimum line length"""
	var parent_node = get_parent() as SkillNode
	if not parent_node:
		return

	# Clear existing points
	line_2d.clear_points()

	# Calculate centers
	var button_center = global_position + size / 2
	var parent_center = parent_node.global_position + parent_node.size / 2

	# Calculate distance and direction
	var total_distance = button_center.distance_to(parent_center)
	var direction = (button_center - parent_center).normalized()

	# Calculate dynamic margin to ensure minimum line length
	var total_margin = LINE_CONNECTION_MARGIN * 2
	var actual_margin = LINE_CONNECTION_MARGIN

	if total_distance < total_margin + MIN_LINE_LENGTH:
		# Nodes are too close for full margin, reduce margin to ensure minimum line length
		actual_margin = max(0, (total_distance - MIN_LINE_LENGTH) / 2)

	# Apply dynamic margin from each node edge
	var start_point = parent_center + direction * actual_margin
	var end_point = button_center - direction * actual_margin

	# Set line points
	line_2d.add_point(start_point)
	line_2d.add_point(end_point)

	# Apply styling
	line_2d.width = LINE_WIDTH
	_update_line_color()

func _update_line_color():
	"""Update line color based on current node and parent state"""
	var parent_node = get_parent() as SkillNode
	if not parent_node:
		return

	# Determine line color based on connection state
	if level > 0 and parent_node.level > 0:
		# Both nodes have points - active connection
		line_2d.default_color = LINE_ACTIVE_COLOR
	elif parent_node.level > 0:
		# Parent has points but this node doesn't - available connection
		line_2d.default_color = LINE_INACTIVE_COLOR
	else:
		# Parent has no points - disabled connection
		line_2d.default_color = LINE_DISABLED_COLOR
func _on_left_click():
	# Toggle between 0 and 1 for single-level system
	if level == 0 and _can_allocate_point():
		level = 1  # Allocate the single point
	elif level == 1 and can_be_reset():
		level = 0  # Deallocate the single point
	_update_skill_state()

func _update_skill_state():
	# Store normal modulate for reset mode restoration
	_normal_modulate = Color.WHITE

	# Ensure line connection is properly set up
	if get_parent() is SkillNode:
		# Use call_deferred to ensure positions are finalized
		call_deferred("_setup_line_connection")

	# Check if this skill should be disabled (no parent points)
	var parent = get_parent()
	if parent is SkillNode:
		disabled = parent.level < 1
	else:
		disabled = false  # Root nodes are never disabled

	# Update visual appearance for disabled state
	_update_disabled_visual_state()

	# Reapply reset mode highlighting if active
	if _reset_mode_active:
		set_reset_mode_highlight(true, _can_be_removed)


	# Update child skills availability
	var skills = get_children()
	for skill in skills:
		if skill is SkillNode:
			var should_be_disabled = level < 1
			if skill.disabled != should_be_disabled:
				skill.disabled = should_be_disabled
				skill._update_disabled_visual_state()

func _can_allocate_point() -> bool:
	# Can't allocate if already allocated (single-level system)
	if level >= 1:
		return false

	# Root nodes (no parent) can always be allocated
	var parent = get_parent()
	if not parent is SkillNode:
		return true

	# Child nodes require parent to have at least 1 point
	return parent.level >= 1

func can_be_reset() -> bool:
	"""Check if this node can be reset - no children should have allocated points"""
	if level <= 0:
		return false  # Nothing to reset

	# Check if any child nodes have points allocated
	for child in get_children():
		if child is SkillNode and child.level > 0:
			return false  # Child has points, can't reset parent

	return true

func reset_skill():
	"""Reset this skill to 0 points"""
	level = 0
	_update_skill_state()

func _update_disabled_visual_state():
	"""Update visual appearance based on disabled state"""
	# Don't use modulate for disabled state as it affects shader background
	# Instead, keep all buttons at normal modulate to preserve shader appearance

	# Visual feedback for disabled state is handled through the disabled property
	# which affects button interaction behavior

func _on_pressed():
	_on_left_click()

func set_reset_mode_highlight(active: bool, can_remove: bool = false) -> void:
	"""Set border highlighting for reset mode"""
	_reset_mode_active = active
	_can_be_removed = can_remove

	if not border_highlight:
		return

	if not active:
		# Exit reset mode - hide border
		border_highlight.color = BORDER_HIDDEN
	else:
		# In reset mode - show border based on state
		if level > 0:  # Only highlight nodes that have points
			if can_remove:
				# Green border for removable nodes
				border_highlight.color = BORDER_REMOVABLE
			else:
				# Red border for non-removable nodes with points
				border_highlight.color = BORDER_BLOCKED
		else:
			# Hide border for empty nodes in reset mode
			border_highlight.color = BORDER_HIDDEN

func set_border_highlight(border_type: String) -> void:
	"""Set border highlight for various states"""
	if not border_highlight:
		return

	match border_type:
		"available":
			border_highlight.color = BORDER_AVAILABLE
		"allocated":
			border_highlight.color = BORDER_ALLOCATED
		"removable":
			border_highlight.color = BORDER_REMOVABLE
		"blocked":
			border_highlight.color = BORDER_BLOCKED
		"hidden", _:
			border_highlight.color = BORDER_HIDDEN

func _update_border_for_level() -> void:
	"""Update border based on current level (when not in reset mode)"""
	if not border_highlight or _reset_mode_active:
		return

	if level > 0:
		# Show golden border for allocated skills
		border_highlight.color = BORDER_ALLOCATED
	else:
		# Hide border for unallocated skills
		border_highlight.color = BORDER_HIDDEN
