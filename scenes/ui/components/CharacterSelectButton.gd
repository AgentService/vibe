extends VBoxContainer
class_name CharacterSelectButton

## Reusable character selection button component
## Used in CharacterSelect screen to display character portrait and name

signal character_selected(character_id: String)

@onready var portrait: TextureRect = $Frame/MarginContainer/Button/Layout/Portrait
@onready var name_label: Label = $Frame/MarginContainer/Button/Layout/Name
@onready var button: Button = $Frame/MarginContainer/Button

var character_id: String = ""
var _is_initialized: bool = false

# Store data if setup() is called before _ready()
var _pending_char_type: CharacterType = null
var _pending_portrait: Texture2D = null

func _ready() -> void:
	# Connect button signal only once during _ready
	if button and not button.pressed.is_connected(_on_button_pressed):
		button.pressed.connect(_on_button_pressed)

	# Apply pending data if setup() was called before _ready()
	if _pending_char_type:
		_apply_data(_pending_char_type, _pending_portrait)
		_pending_char_type = null
		_pending_portrait = null

func setup(char_id: String, char_type: CharacterType, portrait_texture: Texture2D) -> void:
	"""Initialize the button with character data."""
	character_id = char_id
	_is_initialized = true

	# If nodes are ready, apply immediately
	if name_label and portrait:
		_apply_data(char_type, portrait_texture)
	else:
		# Store for later (will be applied in _ready())
		_pending_char_type = char_type
		_pending_portrait = portrait_texture

func _apply_data(char_type: CharacterType, portrait_texture: Texture2D) -> void:
	"""Apply character data to UI elements."""
	name_label.text = char_type.display_name
	portrait.texture = portrait_texture

func _on_button_pressed() -> void:
	"""Emit signal when button is clicked."""
	if _is_initialized:
		character_selected.emit(character_id)

func set_selected(selected: bool) -> void:
	"""Update button state when selected/deselected."""
	if button:
		if selected:
			# Apply focus style to show selection
			button.grab_focus()
		else:
			# Release focus when deselected
			if button.has_focus():
				button.release_focus()
