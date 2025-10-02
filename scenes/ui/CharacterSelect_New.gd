extends Control
## NEW Character Select - Styled replacement for character selection flow
## Work in progress - placeholder for testing scene transitions

@onready var back_button: Button = Button.new()
@onready var placeholder_label: Label = Label.new()

func _ready() -> void:
	# Setup placeholder UI
	_setup_placeholder_ui()
	
	# Connect back button
	back_button.pressed.connect(_on_back_pressed)
	
	Logger.info("CharacterSelect_New loaded (placeholder)", "ui")

func _setup_placeholder_ui() -> void:
	"""Create basic placeholder UI to verify scene transition"""
	# Add centered label
	placeholder_label.text = "CHARACTER SELECT (New UI)\n\nPlaceholder - Scene transition test"
	placeholder_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	placeholder_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	placeholder_label.add_theme_font_size_override("font_size", 24)
	placeholder_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(placeholder_label)
	
	# Add back button
	back_button.text = "← Back to Main Menu"
	back_button.custom_minimum_size = Vector2(200, 50)
	back_button.position = Vector2(50, 50)
	add_child(back_button)

func _on_back_pressed() -> void:
	"""Return to MeasureAtlas main menu"""
	Logger.info("Back pressed - returning to MeasureAtlas", "ui")
	get_tree().change_scene_to_file("res://scenes/ui/MeasureAtlas.tscn")
