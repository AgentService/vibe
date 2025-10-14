extends Control
class_name CharacterSelectButton

## Reusable character selection button component
## Used in CharacterSelect screen to display character portrait and name

signal character_selected(character_id: String)

@onready var portrait: TextureRect = %CharacterPortrait
@onready var name_label: Label = %CharacterNameLabel
@onready var button: Button = %SelectButton

var character_id: String = ""
var _is_initialized: bool = false

# Store data if setup() is called before _ready()
var _pending_char_data: Variant = null  # Duck typing: CharacterType or BaseCharacter
var _pending_portrait: Texture2D = null

func _ready() -> void:
	# Connect button signal only once during _ready
	if button and not button.pressed.is_connected(_on_button_pressed):
		button.pressed.connect(_on_button_pressed)

	# Apply pending data if setup() was called before _ready()
	if _pending_char_data:
		_apply_data(_pending_char_data, _pending_portrait)
		_pending_char_data = null
		_pending_portrait = null

func setup(char_id: String, char_data: Variant, portrait_texture: Texture2D) -> void:
	"""Initialize the button with character data.

	Args:
		char_id: Unique character identifier
		char_data: CharacterType (legacy) or BaseCharacter (unified) via duck typing
		portrait_texture: Character portrait texture
	"""
	character_id = char_id
	_is_initialized = true

	# If nodes are ready, apply immediately
	if name_label and portrait:
		_apply_data(char_data, portrait_texture)
	else:
		# Store for later (will be applied in _ready())
		_pending_char_data = char_data
		_pending_portrait = portrait_texture

func _apply_data(char_data: Variant, portrait_texture: Texture2D) -> void:
	"""Apply character data to UI elements.

	Duck typing: Supports both CharacterType and BaseCharacter
	- CharacterType: uses display_name
	- BaseCharacter: uses display_name (compatibility alias for character_name)
	"""
	name_label.text = char_data.display_name if "display_name" in char_data else "Unknown"
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
