extends Control
## NEW Character Select - Styled replacement for character selection flow
## Work in progress - building styled UI with real character data

@onready var confirm_button: Button = $MarginContainer_CharacterSelect2/NinePatchRect/VBoxContainer3/MarginContainer6/VBoxContainer/HBoxContainer/confirm
@onready var back_button: Button = $BackButton

func _ready() -> void:
	# Connect navigation buttons
	confirm_button.pressed.connect(_on_confirm_pressed)
	back_button.pressed.connect(_on_back_pressed)

	Logger.info("CharacterSelect_New loaded", "ui")

func _on_confirm_pressed() -> void:
	"""Proceed to map selection after character is chosen"""
	Logger.info("Confirm pressed - loading map selection", "ui")
	get_tree().change_scene_to_file("res://scenes/ui/MapSelect_New.tscn")

func _on_back_pressed() -> void:
	"""Return to main menu"""
	Logger.info("Back pressed - returning to MeasureAtlas", "ui")
	get_tree().change_scene_to_file("res://scenes/ui/MeasureAtlas.tscn")
