extends TextureButton
class_name SkillNode

@onready var panel = $Panel
@onready var label = $MarginContainer/Label
@onready var line_2d: Line2D = $Line2D

@export var max_level: int = 3  # Configurable max level per skill button

func _ready():
	_update_label()  # Initialize label with correct max level
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
 
 
 
func _gui_input(event: InputEvent):
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_on_left_click()

func _on_left_click():
	# Check if we can allocate a point (parent prerequisites met)
	if _can_allocate_point():
		level = min(level + 1, max_level)  # Increase level
		_update_skill_state()

func _update_skill_state():
	panel.show_behind_parent = true

	# Update line color based on level - simple logic only
	if level > 0:
		line_2d.default_color = Color(1, 1, 0.24705882370472)  # Yellow when active
		modulate = Color.WHITE  # Skills with points are always normal appearance
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
	if disabled and level == 0:
		# Skill is disabled (parent has no points) - dim it significantly
		modulate = Color(0.5, 0.5, 0.5, 1.0)
	elif level == 0:
		# Skill has no points but is enabled - normal appearance
		modulate = Color.WHITE
	# If skill has points (level > 0), it's always enabled and normal appearance

func _on_pressed():
	# Keep this for backward compatibility, but _gui_input handles clicks now
	pass
