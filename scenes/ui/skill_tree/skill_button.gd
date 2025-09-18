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
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			_on_right_click()

func _on_left_click():
	# Check if we can allocate a point (parent prerequisites met)
	if _can_allocate_point():
		level = min(level + 1, max_level)  # Increase level
		_update_skill_state()

func _on_right_click():
	# Check if we can safely remove a point without violating dependencies
	if _can_remove_point():
		level = max(level - 1, 0)  # Decrease level, minimum 0
		_update_skill_state()

func _update_skill_state():
	panel.show_behind_parent = true

	# Update line color based on level - simple logic only
	if level > 0:
		line_2d.default_color = Color(1, 1, 0.24705882370472)  # Yellow when active
	else:
		line_2d.default_color = Color(0.266575, 0.266575, 0.266575, 1)  # Gray when inactive

	# Update child skills availability
	var skills = get_children()
	for skill in skills:
		if skill is SkillNode:
			skill.disabled = level < 1  # Enable children only if this skill has at least 1 point

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

func _can_remove_point() -> bool:
	# Can't remove if already at 0
	if level <= 0:
		return false

	# If removing this point would take us to 0, check if any children have points
	if level == 1:
		return not _has_children_with_points()

	# Otherwise it's safe to remove (we'd still have points left)
	return true

func _has_children_with_points() -> bool:
	# Check all child SkillNodes to see if any ha ve points allocated
	var children = get_children()
	for child in children:
		if child is SkillNode and child.level > 0:
			return true
	return false

func _on_pressed():
	# Keep this for backward compatibility, but _gui_input handles clicks now
	pass
