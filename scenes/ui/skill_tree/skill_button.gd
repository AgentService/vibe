extends TextureButton
class_name SkillNode

@onready var panel = $Panel
@onready var label = $MarginContainer/Label
@onready var line_2d: Line2D = $Line2D
@onready var border_highlight: ColorRect
@onready var inner_shadow: ColorRect
@onready var inner_shadow_layer2: ColorRect

# Tooltip system
var tooltip_panel: Panel
var tooltip_label: Label
var tooltip_visible: bool = false

# Skill tree line styling constants
const LINE_ACTIVE_COLOR = Color(0.8, 0.2, 0.8, 1.0)         # Bright purple for active connections
const LINE_INACTIVE_COLOR = Color(0.45, 0.1, 0.45, 1.0)     # Medium purple for available connections
const LINE_DISABLED_COLOR = Color(0.2, 0.0, 0.2, 1.0)       # Dark purple for disabled connections
const LINE_WIDTH = 3.0
const LINE_CONNECTION_MARGIN = 60.0  # Preferred pixel distance from node edges
const MIN_LINE_LENGTH = 10.0  # Minimum visible line length

# Border highlight colors for purple breach theme
const BORDER_UNALLOCATED = Color(0.15, 0.1, 0.15, 0.6)       # Dark purple/grey for unallocated skills
const BORDER_ALLOCATED = Color(0.275, 0.0, 0.267, 0.8)       # 460044 - Bright purple for allocated skills
const BORDER_REMOVABLE = Color.DARK_RED                       # Dark red - can be removed in reset mode

# Inner shadow for unallocated state indication
const SHADOW_DEFAULT = Color(0.051, 0.055, 0.047, 0.88)      # 0d0e0c82 - Dark inner shadow for unallocated skills


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
	# Initialize border highlight and shadow layer references
	border_highlight = $BorderHighlight
	inner_shadow = $InnerShadow
	inner_shadow_layer2 = $InnerShadowLayer2

	if border_highlight:
		border_highlight.color = BORDER_UNALLOCATED

	# Initialize all shadow layers with default shadow color
	_set_all_shadow_layers(SHADOW_DEFAULT)

	_update_label()  # Initialize label
	_update_skill_state()  # Apply initial state

	# Connect to pressed signal for button input
	pressed.connect(_on_pressed)

	# Connect mouse events for tooltip
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)

	# Setup line connections with padding
	if get_parent() is SkillNode:
		_setup_line_connection()

	# Create tooltip
	_create_tooltip()
 
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
		if level > 0:
			label.text = "✓"
			label.modulate = Color.GREEN
		else:
			label.text = ""
			label.modulate = Color.WHITE

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
		# Exit reset mode - return to appropriate border based on allocation, restore shadow
		_update_border_for_level()
		_update_allocation_shadow()
	else:
		# In reset mode - show red border only for removable nodes
		if level > 0 and can_remove:
			# Red border for removable nodes
			border_highlight.color = BORDER_REMOVABLE
		else:
			# Use appropriate border based on allocation state
			if level > 0:
				border_highlight.color = BORDER_ALLOCATED
			else:
				border_highlight.color = BORDER_UNALLOCATED

		# Hide all inner shadow layers in reset mode for clarity
		_set_all_shadow_layers(Color.TRANSPARENT)

func set_border_highlight(border_type: String) -> void:
	"""Set border highlight for various states"""
	if not border_highlight:
		return

	match border_type:
		"removable":
			border_highlight.color = BORDER_REMOVABLE
		"default", _:
			border_highlight.color = BORDER_UNALLOCATED

func _update_border_for_level() -> void:
	"""Update border based on current level (when not in reset mode)"""
	if not border_highlight or _reset_mode_active:
		return

	# Set border color based on allocation state
	if level > 0:
		border_highlight.color = BORDER_ALLOCATED
	else:
		border_highlight.color = BORDER_UNALLOCATED

	# Update allocation shadow
	_update_allocation_shadow()

func _set_all_shadow_layers(shadow_color: Color) -> void:
	"""Set color for all shadow layers"""
	if inner_shadow:
		inner_shadow.color = shadow_color
	if inner_shadow_layer2:
		inner_shadow_layer2.color = Color(shadow_color.r, shadow_color.g, shadow_color.b, shadow_color.a * 0.57)  # 0.4/0.7 ratio

func _update_allocation_shadow() -> void:
	"""Update inner shadow based on allocation state"""
	if _reset_mode_active:
		return

	if level > 0:
		# Hide shadow for allocated skills (clean look)
		_set_all_shadow_layers(Color.TRANSPARENT)
	else:
		# Show dark inner shadow for unallocated skills
		_set_all_shadow_layers(SHADOW_DEFAULT)

func _create_tooltip() -> void:
	"""Create tooltip UI elements"""
	# Create tooltip panel
	tooltip_panel = Panel.new()
	tooltip_panel.z_index = 100
	tooltip_panel.visible = false
	tooltip_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE  # Critical: Don't block mouse input!

	# Style the panel
	var style_box = StyleBoxFlat.new()
	style_box.bg_color = Color(0.1, 0.1, 0.15, 0.95)
	style_box.border_width_top = 2
	style_box.border_width_bottom = 2
	style_box.border_width_left = 2
	style_box.border_width_right = 2
	style_box.border_color = BORDER_ALLOCATED
	style_box.corner_radius_top_left = 4
	style_box.corner_radius_top_right = 4
	style_box.corner_radius_bottom_left = 4
	style_box.corner_radius_bottom_right = 4
	tooltip_panel.add_theme_stylebox_override("panel", style_box)

	# Create tooltip label
	tooltip_label = Label.new()
	tooltip_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tooltip_label.text = ""
	tooltip_label.add_theme_font_size_override("font_size", 14)
	tooltip_label.add_theme_color_override("font_color", Color.WHITE)
	tooltip_label.mouse_filter = Control.MOUSE_FILTER_IGNORE  # Don't block input

	# Add margin container for padding
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_bottom", 6)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE  # Don't block input

	# Setup hierarchy
	tooltip_panel.add_child(margin)
	margin.add_child(tooltip_label)

	# Add to the skill tree root to ensure it appears above everything
	var skill_tree = get_tree().get_first_node_in_group("skill_trees")
	if not skill_tree:
		skill_tree = get_parent()
		while skill_tree and not skill_tree.name.contains("SkillTree"):
			skill_tree = skill_tree.get_parent()

	if skill_tree:
		skill_tree.add_child(tooltip_panel)

func _on_mouse_entered() -> void:
	"""Show tooltip on mouse enter"""
	if tooltip_panel and not tooltip_visible:
		_update_tooltip_content()
		_position_tooltip()
		tooltip_panel.visible = true
		tooltip_visible = true

func _on_mouse_exited() -> void:
	"""Hide tooltip on mouse exit"""
	if tooltip_panel and tooltip_visible:
		tooltip_panel.visible = false
		tooltip_visible = false

func _update_tooltip_content() -> void:
	"""Update tooltip text with skill information"""
	if not tooltip_label:
		return

	# Check if we have a valid passive_id
	if passive_id == "":
		tooltip_label.text = "No skill data"
		return

	# Get skill information from EventMasterySystem autoload
	var mastery_system = EventMasterySystem.mastery_system_instance
	if not mastery_system:
		tooltip_label.text = "Skill system unavailable"
		return

	var passive_data = mastery_system.get_passive_info(passive_id)
	if not passive_data or passive_data.is_empty():
		tooltip_label.text = "Unknown skill: " + passive_id
		return

	var tooltip_text = passive_data.name + "\n\n" + passive_data.description

	# Add allocation status
	if level > 0:
		tooltip_text += "\n\n[color=green]✓ Allocated[/color]"
	else:
		tooltip_text += "\n\n[color=gray]Not allocated[/color]"
		if passive_data.has("cost") and passive_data.cost > 0:
			tooltip_text += " (Cost: " + str(passive_data.cost) + ")"

	tooltip_label.text = tooltip_text

func _position_tooltip() -> void:
	"""Position tooltip near the skill node"""
	if not tooltip_panel:
		return

	# Calculate tooltip size with fixed width
	tooltip_label.custom_minimum_size = Vector2(250, 0)

	# Force size calculation by calling get_combined_minimum_size
	var tooltip_size = Vector2(260, 100)  # Default size estimate

	var node_pos = global_position
	var node_size = size

	# Position to the right of the node by default
	var tooltip_pos = Vector2(node_pos.x + node_size.x + 10, node_pos.y)

	# Check if tooltip would go off-screen and adjust
	var viewport_size = get_viewport().get_visible_rect().size
	if tooltip_pos.x + tooltip_size.x > viewport_size.x:
		# Position to the left instead
		tooltip_pos.x = node_pos.x - tooltip_size.x - 10

	if tooltip_pos.y + tooltip_size.y > viewport_size.y:
		# Move up if too low
		tooltip_pos.y = viewport_size.y - tooltip_size.y - 10

	# Ensure tooltip stays on screen
	tooltip_pos.x = max(10, tooltip_pos.x)
	tooltip_pos.y = max(10, tooltip_pos.y)

	tooltip_panel.position = tooltip_pos

func _exit_tree() -> void:
	"""Clean up tooltip when node is removed"""
	if tooltip_panel and is_instance_valid(tooltip_panel):
		tooltip_panel.queue_free()
