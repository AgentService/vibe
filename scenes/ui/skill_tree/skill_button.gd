extends TextureButton
class_name SkillNode

@onready var panel = $Panel
@onready var label = $MarginContainer/Label
@onready var line_2d: Line2D = $Line2D

@export var max_level: int = 3  # Configurable max level per skill button
@export var passive_id: StringName = ""  # Explicit passive ID for EventMasterySystem mapping

var _reset_mode_active: bool = false
var _can_be_removed: bool = false
var _normal_modulate: Color = Color.WHITE

func _ready():
	_update_label()  # Initialize label with correct max level
	_update_skill_state()  # Apply initial state

	# Connect to pressed signal for button input
	pressed.connect(_on_pressed)

	if get_parent() is SkillNode:
		line_2d.add_point(global_position + size/2)
		line_2d.add_point(get_parent().global_position + size/2)
 
var level : int = 0:
	set(value):
		level = value
		_update_label()

func _update_label():
	if label:
		label.text = str(level) + "/" + str(max_level)
 
 
 
func _on_left_click():
	# Check if we can allocate a point (parent prerequisites met)
	if _can_allocate_point():
		level = min(level + 1, max_level)  # Increase level
		_update_skill_state()

func _update_skill_state():
	# Store normal modulate for reset mode restoration
	_normal_modulate = Color.WHITE

	# Update line color based on level - simple logic only
	if level > 0:
		line_2d.default_color = Color(1, 1, 0.24705882370472)  # Yellow when active
		if not _reset_mode_active:
			modulate = Color.WHITE  # Skills with points are normal appearance when not in reset mode
	else:
		line_2d.default_color = Color(0.266575, 0.266575, 0.266575, 1)  # Gray when inactive

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
	# Can't allocate if already at max level
	if level >= max_level:
		return false

	# Root nodes (no parent) can always be allocated
	var parent = get_parent()
	if not parent is SkillNode:
		return true

	# Child nodes require parent to have at least 1 point
	return parent.level >= 1

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
	"""Set visual highlighting for reset mode"""
	_reset_mode_active = active
	_can_be_removed = can_remove

	if not active:
		# Exit reset mode - restore normal appearance
		modulate = _normal_modulate
	else:
		# In reset mode - apply highlighting based on removability
		if level > 0:  # Only highlight nodes that have points
			if can_remove:
				# Green tint for removable nodes
				modulate = Color(0.8, 1.0, 0.8, 1.0)
			else:
				# Slight red tint for non-removable nodes with points
				modulate = Color(1.0, 0.8, 0.8, 1.0)
		else:
			# Nodes with no points get dimmed in reset mode
			modulate = Color(0.7, 0.7, 0.7, 1.0)
