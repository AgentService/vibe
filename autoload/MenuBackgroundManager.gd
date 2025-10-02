extends CanvasLayer
## Persistent animated background for all menu scenes
## Stays loaded across scene transitions to maintain animation continuity
## Automatically shows/hides based on game state

# Background scene reference
var _background_instance: Node = null

func _ready() -> void:
	# Render behind all UI
	layer = -10

	# Load animated background scene
	var bg_scene = preload("res://scenes/ui/components/MenuBackground.tscn")
	_background_instance = bg_scene.instantiate()
	add_child(_background_instance)

	# Listen for scene transitions to adjust visibility
	StateManager.state_changed.connect(_on_state_changed)

	# Initialize visibility based on current state
	_update_visibility(StateManager.current_state)

	Logger.info("MenuBackgroundManager initialized", "ui")

func _on_state_changed(prev_state: StateManager.State, new_state: StateManager.State, context: Dictionary) -> void:
	"""Handle state changes from StateManager signal."""
	_update_visibility(new_state)

func _update_visibility(state: StateManager.State) -> void:
	"""Update background visibility based on game state."""
	match state:
		StateManager.State.MENU:
			visible = true
			# Force background to refresh when becoming visible
			if _background_instance and _background_instance.has_method("reset_background"):
				_background_instance.reset_background()
		StateManager.State.ARENA, \
		StateManager.State.HIDEOUT, \
		StateManager.State.RESULTS:
			visible = false  # Hide during gameplay
		_:
			visible = false

func fade_out(duration: float = 0.3) -> void:
	"""Smoothly fade out background for transitions."""
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, duration)
	await tween.finished

func fade_in(duration: float = 0.3) -> void:
	"""Smoothly fade in background after transitions."""
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 1.0, duration)
	await tween.finished
