extends Button
class_name MainButton
## Reusable styled button component used across all UI screens.
## Provides consistent hover, pressed, and normal states with raven_starter.png texture.

signal main_button_pressed()

@export var button_text: String = "Button":
	set(value):
		button_text = value
		if is_node_ready():
			text = button_text

func _ready() -> void:
	text = button_text
	pressed.connect(_on_pressed)

func _on_pressed() -> void:
	main_button_pressed.emit()
