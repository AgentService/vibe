extends Control
class_name SkillNode

@onready var button_texture: TextureButton = $CircularMask/ButtonTexture
@onready var panel = $Panel
@onready var label = $MarginContainer/Label
@onready var line_2d: Line2D = $Line2D

@export var max_level: int = 3  # Configurable max level per skill button

func _ready():
	_update_label()  # Initialize label with correct max level
	if get_parent() is SkillNode:
		line_2d.add_point(global_position + size/2)
		line_2d.add_point(get_parent().global_position + size/2)

	# Connect the button texture's gui_input to handle clicks
	if button_texture:
		button_texture.gui_input.connect(_on_button_gui_input)
 
var level : int = 0:
	set(value):
		level = value
		_update_label()

func _update_label():
	if label:
		label.text = str(level) + "/" + str(max_level)
 
 
 
func _on_button_gui_input(event: InputEvent):
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
			_set_disabled(parent.level < 1)
		else:
			_set_disabled(false)  # Root nodes are never disabled

		# Update visual appearance for disabled state
		_update_disabled_visual_state()

	# Update child skills availability
	var skills = get_children()
	for skill in skills:
		if skill is SkillNode:
			var should_be_disabled = level < 1
			if skill._is_disabled() != should_be_disabled:
				skill._set_disabled(should_be_disabled)
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

func _set_disabled(value: bool):
	"""Set disabled state for the button"""
	if button_texture:
		button_texture.disabled = value

func _is_disabled() -> bool:
	"""Get disabled state of the button"""
	if button_texture:
		return button_texture.disabled
	return false

func _update_disabled_visual_state():
	"""Update visual appearance based on disabled state"""
	if _is_disabled() and level == 0:
		# Skill is disabled (parent has no points) - dim it significantly
		modulate = Color(0.5, 0.5, 0.5, 1.0)
	elif level == 0:
		# Skill has no points but is enabled - normal appearance
		modulate = Color.WHITE
	# If skill has points (level > 0), it's always enabled and normal appearance

func _on_pressed():
	# Keep this for backward compatibility, but _gui_input handles clicks now
	pass
