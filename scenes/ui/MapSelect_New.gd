extends Control
## NEW Map Selection - Styled replacement for map/tier selection flow
## Work in progress - building styled UI with real map data

@onready var back_button: Button = $BackButton

func _ready() -> void:
	# Connect back button
	back_button.pressed.connect(_on_back_pressed)

	Logger.info("MapSelect_New loaded", "ui")

func _on_back_pressed() -> void:
	"""Return to CharacterSelect_New"""
	Logger.info("Back pressed - returning to CharacterSelect_New", "ui")
	get_tree().change_scene_to_file("res://scenes/ui/CharacterSelect_New.tscn")
