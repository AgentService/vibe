## GridWithDetailsContainer - Grid container with toggleable details panel
## Extends GridMenuContainer to add a details panel below the grid
extends GridMenuContainer
class_name GridWithDetailsContainer

## Exported properties
@export var details_panel_size: Vector2 = Vector2(600, 140):
	set(value):
		details_panel_size = value
		if _details_panel:
			_details_panel.custom_minimum_size = value

@export var details_visible: bool = true:
	set(value):
		details_visible = value
		if _details_panel:
			_details_panel.visible = value

@export var details_left_panel_width: int = 385:
	set(value):
		details_left_panel_width = value
		if _details_left_panel:
			_details_left_panel.custom_minimum_size.x = value

@export var details_right_panel_width: int = 155:
	set(value):
		details_right_panel_width = value
		if _details_right_panel:
			_details_right_panel.custom_minimum_size.x = value

@export var details_panel_padding: int = 15:
	set(value):
		details_panel_padding = value
		if _details_margin_container:
			_details_margin_container.add_theme_constant_override("margin_left", value)
			_details_margin_container.add_theme_constant_override("margin_top", value)
			_details_margin_container.add_theme_constant_override("margin_right", value)
			_details_margin_container.add_theme_constant_override("margin_bottom", value)

## Internal nodes
var _details_panel: PanelContainer
var _details_margin_container: MarginContainer
var _details_hbox: HBoxContainer
var _details_left_panel: VBoxContainer
var _details_right_panel: VBoxContainer

func _ready() -> void:
	super._ready()
	_setup_details_panel()

func _setup_details_panel() -> void:
	# Create details panel container
	_details_panel = PanelContainer.new()
	_details_panel.name = "DetailsPanel"
	_details_panel.custom_minimum_size = details_panel_size
	_details_panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_details_panel.visible = details_visible
	_content_container.add_child(_details_panel)

	# Create margin container for padding
	_details_margin_container = MarginContainer.new()
	_details_margin_container.name = "MarginContainer"
	_details_margin_container.add_theme_constant_override("margin_left", details_panel_padding)
	_details_margin_container.add_theme_constant_override("margin_top", details_panel_padding)
	_details_margin_container.add_theme_constant_override("margin_right", details_panel_padding)
	_details_margin_container.add_theme_constant_override("margin_bottom", details_panel_padding)
	_details_panel.add_child(_details_margin_container)

	# Create HBox for left/right split
	_details_hbox = HBoxContainer.new()
	_details_hbox.name = "HBoxContainer"
	_details_hbox.add_theme_constant_override("separation", 15)
	_details_margin_container.add_child(_details_hbox)

	# Create left panel (70% - main info)
	_details_left_panel = VBoxContainer.new()
	_details_left_panel.name = "LeftPanel"
	_details_left_panel.custom_minimum_size = Vector2(details_left_panel_width, 110)
	_details_left_panel.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_details_left_panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_details_left_panel.add_theme_constant_override("separation", 8)
	_details_hbox.add_child(_details_left_panel)

	# Create right panel (30% - actions/progress)
	_details_right_panel = VBoxContainer.new()
	_details_right_panel.name = "RightPanel"
	_details_right_panel.custom_minimum_size = Vector2(details_right_panel_width, 110)
	_details_right_panel.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_details_right_panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_details_right_panel.add_theme_constant_override("separation", 8)
	_details_hbox.add_child(_details_right_panel)

## Get the details panel container
func get_details_panel() -> PanelContainer:
	return _details_panel

## Get the left panel for adding details content
func get_details_left_panel() -> VBoxContainer:
	return _details_left_panel

## Get the right panel for adding action buttons/progress
func get_details_right_panel() -> VBoxContainer:
	return _details_right_panel

## Show/hide the details panel
func set_details_visible(visible: bool) -> void:
	details_visible = visible
