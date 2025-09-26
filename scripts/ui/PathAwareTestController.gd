extends Node2D

@onready var arena_generator: PathAwareArenaGenerator = $PathAwareArenaGenerator
@onready var regenerate_button: Button = $UI/Controls/RegenerateButton
@onready var toggle_markers_button: Button = $UI/Controls/ToggleMarkersButton
@onready var toggle_lines_button: Button = $UI/Controls/ToggleLinesButton

func _ready():
	# Connect UI buttons
	if regenerate_button:
		regenerate_button.pressed.connect(_on_regenerate_pressed)

	if toggle_markers_button:
		toggle_markers_button.pressed.connect(_on_toggle_markers_pressed)

	if toggle_lines_button:
		toggle_lines_button.pressed.connect(_on_toggle_lines_pressed)

func _input(event):
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_SPACE:
				_regenerate_arena()
			KEY_M:
				_toggle_markers()
			KEY_L:
				_toggle_lines()

func _on_regenerate_pressed():
	_regenerate_arena()

func _on_toggle_markers_pressed():
	_toggle_markers()

func _on_toggle_lines_pressed():
	_toggle_lines()

func _regenerate_arena():
	if arena_generator:
		arena_generator.generate_with_new_seed()
		print("Arena regenerated with seed: ", arena_generator.generation_seed)

func _toggle_markers():
	if arena_generator:
		arena_generator.show_debug_markers = not arena_generator.show_debug_markers
		arena_generator.generate_path_aware_arena()  # Regenerate to apply change
		print("Debug markers: ", "ON" if arena_generator.show_debug_markers else "OFF")

func _toggle_lines():
	if arena_generator:
		arena_generator.show_path_connections = not arena_generator.show_path_connections
		arena_generator.generate_path_aware_arena()  # Regenerate to apply change
		print("Path connections: ", "ON" if arena_generator.show_path_connections else "OFF")