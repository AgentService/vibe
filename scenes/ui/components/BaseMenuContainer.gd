## BaseMenuContainer - Foundation for all menu containers
## Provides consistent border + background styling with customizable size
extends PanelContainer
class_name BaseMenuContainer

## Exported properties for customization
@export var container_size: Vector2 = Vector2(650, 650):
	set(value):
		container_size = value
		custom_minimum_size = value

@export var background_color: Color = Color(0, 0.152, 0.24, 1.0):
	set(value):
		background_color = value
		_update_background_style()

@export var corner_radius: int = 8:
	set(value):
		corner_radius = value
		_update_background_style()

@export var padding: int = 20:
	set(value):
		padding = value
		_update_margins()

## Internal nodes
var _margin_container: MarginContainer
var _content_container: VBoxContainer

func _ready() -> void:
	_setup_container()
	_update_background_style()
	_update_margins()

func _setup_container() -> void:
	# Create margin container for padding
	_margin_container = MarginContainer.new()
	_margin_container.name = "MarginContainer"
	add_child(_margin_container)

	# Create content container for child content
	_content_container = VBoxContainer.new()
	_content_container.name = "ContentContainer"
	_content_container.set("theme_override_constants/separation", 20)
	_margin_container.add_child(_content_container)

func _update_background_style() -> void:
	if not is_inside_tree():
		return

	var style_box = StyleBoxFlat.new()
	style_box.bg_color = background_color
	style_box.corner_radius_top_left = corner_radius
	style_box.corner_radius_top_right = corner_radius
	style_box.corner_radius_bottom_left = corner_radius
	style_box.corner_radius_bottom_right = corner_radius

	add_theme_stylebox_override("panel", style_box)

func _update_margins() -> void:
	if not _margin_container:
		return

	_margin_container.add_theme_constant_override("margin_left", padding)
	_margin_container.add_theme_constant_override("margin_top", padding)
	_margin_container.add_theme_constant_override("margin_right", padding)
	_margin_container.add_theme_constant_override("margin_bottom", padding)

## Get the content container for adding child nodes
func get_content_container() -> VBoxContainer:
	return _content_container
