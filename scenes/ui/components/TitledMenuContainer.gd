## TitledMenuContainer - Menu container with title section
## Extends BaseMenuContainer to add a styled title label
extends BaseMenuContainer
class_name TitledMenuContainer

## Exported properties
@export var title_text: String = "TITLE":
	set(value):
		title_text = value
		if _title_label:
			_title_label.text = value

@export var title_font_size: int = 24:
	set(value):
		title_font_size = value
		if _title_label:
			_title_label.add_theme_font_size_override("font_size", value)

@export var title_alignment: HorizontalAlignment = HORIZONTAL_ALIGNMENT_CENTER:
	set(value):
		title_alignment = value
		if _title_label:
			_title_label.horizontal_alignment = value

## Internal nodes
var _title_label: Label

func _ready() -> void:
	super._ready()
	_setup_title()

func _setup_title() -> void:
	# Create title label
	_title_label = Label.new()
	_title_label.name = "TitleLabel"
	_title_label.text = title_text
	_title_label.horizontal_alignment = title_alignment
	_title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", title_font_size)

	# Add to content container (first child)
	_content_container.add_child(_title_label)
	_content_container.move_child(_title_label, 0)

## Get the title label for further customization
func get_title_label() -> Label:
	return _title_label
