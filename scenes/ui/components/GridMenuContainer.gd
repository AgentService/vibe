## GridMenuContainer - Menu container with title and grid section
## Extends TitledMenuContainer to add a scrollable grid container
extends TitledMenuContainer
class_name GridMenuContainer

## Exported properties
@export var grid_min_size: Vector2 = Vector2(600, 400):
	set(value):
		grid_min_size = value
		if _scroll_container:
			_scroll_container.custom_minimum_size = value

@export var grid_columns: int = 8:
	set(value):
		grid_columns = value
		if _grid_container:
			_grid_container.columns = value

@export var grid_h_separation: int = 10:
	set(value):
		grid_h_separation = value
		if _grid_container:
			_grid_container.add_theme_constant_override("h_separation", value)

@export var grid_v_separation: int = 10:
	set(value):
		grid_v_separation = value
		if _grid_container:
			_grid_container.add_theme_constant_override("v_separation", value)

## Internal nodes
var _scroll_container: ScrollContainer
var _grid_container: GridContainer

func _ready() -> void:
	super._ready()
	_setup_grid()

func _setup_grid() -> void:
	# Create scroll container
	_scroll_container = ScrollContainer.new()
	_scroll_container.name = "GridScrollContainer"
	_scroll_container.custom_minimum_size = grid_min_size
	_scroll_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll_container.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_content_container.add_child(_scroll_container)

	# Create grid container
	_grid_container = GridContainer.new()
	_grid_container.name = "GridContainer"
	_grid_container.custom_minimum_size = Vector2(grid_min_size.x, 0)
	_grid_container.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_grid_container.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_grid_container.columns = grid_columns
	_grid_container.add_theme_constant_override("h_separation", grid_h_separation)
	_grid_container.add_theme_constant_override("v_separation", grid_v_separation)
	_scroll_container.add_child(_grid_container)

## Get the grid container for adding items
func get_grid_container() -> GridContainer:
	return _grid_container

## Get the scroll container for advanced control
func get_scroll_container() -> ScrollContainer:
	return _scroll_container
