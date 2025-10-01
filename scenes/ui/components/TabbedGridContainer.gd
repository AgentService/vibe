## TabbedGridContainer - Tabbed interface with grid + details per tab
## Extends GridWithDetailsContainer to add tab navigation
extends GridWithDetailsContainer
class_name TabbedGridContainer

## Tab configuration
@export var tab_names: Array[String] = ["Tab 1", "Tab 2", "Tab 3"]:
	set(value):
		tab_names = value
		if is_inside_tree():
			_rebuild_tabs()

@export var tab_button_size: Vector2 = Vector2(120, 40):
	set(value):
		tab_button_size = value
		if _tabs_container:
			for button in _tabs_container.get_children():
				if button is Button:
					button.custom_minimum_size = value

## Internal nodes
var _tabs_container: HBoxContainer
var _tab_buttons: Array[Button] = []
var _tab_grids: Dictionary = {}  # tab_name -> GridContainer
var _tab_scroll_containers: Dictionary = {}  # tab_name -> ScrollContainer
var _current_tab: String = ""

signal tab_changed(tab_name: String)

func _ready() -> void:
	# Don't call super._ready() directly - we'll override grid setup
	# Call BaseMenuContainer and TitledMenuContainer ready manually
	if not is_inside_tree():
		await ready

	_setup_container()
	_update_background_style()
	_update_margins()
	_setup_title()
	_setup_tabs()
	_setup_details_panel()

func _setup_tabs() -> void:
	# Create tabs container
	_tabs_container = HBoxContainer.new()
	_tabs_container.name = "TabsContainer"
	_tabs_container.alignment = BoxContainer.ALIGNMENT_CENTER
	_content_container.add_child(_tabs_container)

	# Move tabs after title
	_content_container.move_child(_tabs_container, 1)

	# Build tab buttons
	_rebuild_tabs()

func _rebuild_tabs() -> void:
	# Clear existing tabs
	for button in _tab_buttons:
		button.queue_free()
	_tab_buttons.clear()
	_tab_grids.clear()
	_tab_scroll_containers.clear()

	if not _tabs_container:
		return

	# Create tab buttons and grids
	for i in range(tab_names.size()):
		var tab_name = tab_names[i]

		# Create tab button
		var button = Button.new()
		button.name = tab_name + "Tab"
		button.text = tab_name
		button.custom_minimum_size = tab_button_size
		button.toggle_mode = true
		button.button_pressed = (i == 0)  # First tab active by default
		button.pressed.connect(_on_tab_pressed.bind(tab_name))
		_tabs_container.add_child(button)
		_tab_buttons.append(button)

		# Create scroll container for this tab
		var scroll = ScrollContainer.new()
		scroll.name = tab_name + "ScrollContainer"
		scroll.custom_minimum_size = grid_min_size
		scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		scroll.visible = (i == 0)
		_content_container.add_child(scroll)
		_tab_scroll_containers[tab_name] = scroll

		# Create grid for this tab
		var grid = GridContainer.new()
		grid.name = tab_name + "GridContainer"
		grid.custom_minimum_size = Vector2(grid_min_size.x, 0)
		grid.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		grid.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		grid.columns = grid_columns
		grid.add_theme_constant_override("h_separation", grid_h_separation)
		grid.add_theme_constant_override("v_separation", grid_v_separation)
		scroll.add_child(grid)
		_tab_grids[tab_name] = grid

	# Set first tab as current
	if tab_names.size() > 0:
		_current_tab = tab_names[0]

func _on_tab_pressed(tab_name: String) -> void:
	# Deselect all tabs
	for button in _tab_buttons:
		button.button_pressed = false

	# Select pressed tab
	for button in _tab_buttons:
		if button.text == tab_name:
			button.button_pressed = true

	# Hide all grids
	for scroll in _tab_scroll_containers.values():
		scroll.visible = false

	# Show selected grid
	if _tab_scroll_containers.has(tab_name):
		_tab_scroll_containers[tab_name].visible = true

	_current_tab = tab_name
	tab_changed.emit(tab_name)

## Get the grid for a specific tab
func get_tab_grid(tab_name: String) -> GridContainer:
	return _tab_grids.get(tab_name, null)

## Get the currently active tab name
func get_current_tab() -> String:
	return _current_tab

## Get the grid for the current tab
func get_current_grid() -> GridContainer:
	return get_tab_grid(_current_tab)

## Switch to a specific tab
func switch_to_tab(tab_name: String) -> void:
	if _tab_grids.has(tab_name):
		_on_tab_pressed(tab_name)

## Override parent's get_grid_container to return current tab's grid
func get_grid_container() -> GridContainer:
	return get_current_grid()

## Get all tab names
func get_tab_names() -> Array[String]:
	return tab_names
