extends Node

## Debug/Cheat system for development and testing.
## Provides god mode, spawn control, and silent pause functionality.

# Cheat states
var god_mode: bool = true  # Enable godmode by default
var spawn_disabled: bool = false  # Ensure spawning is enabled

func _ready() -> void:
	# Always process, even during pause
	process_mode = Node.PROCESS_MODE_ALWAYS
	Logger.info("CheatSystem initialized", "debug")

func _input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed:
		return
	
	var key_event := event as InputEventKey
	
	# Ctrl+1: Toggle God Mode
	if key_event.ctrl_pressed and key_event.keycode == KEY_1:
		toggle_god_mode()
		get_viewport().set_input_as_handled()
	
	# Ctrl+2: Toggle Spawn Disabled
	elif key_event.ctrl_pressed and key_event.keycode == KEY_2:
		toggle_spawn_disabled()
		get_viewport().set_input_as_handled()
	
	# F10: Silent Pause
	elif key_event.keycode == KEY_F10:
		toggle_silent_pause()
		get_viewport().set_input_as_handled()

func toggle_god_mode() -> void:
	god_mode = not god_mode
	
	# Emit event for systems that need to react
	var payload := EventBus.CheatTogglePayload_Type.new("god_mode", god_mode)
	EventBus.cheat_toggled.emit(payload)

func toggle_spawn_disabled() -> void:
	spawn_disabled = not spawn_disabled
	var status := "disabled" if spawn_disabled else "enabled"
	Logger.info("Enemy spawning " + status, "debug")
	
	# Emit event for systems that need to react
	var payload := EventBus.CheatTogglePayload_Type.new("spawn_disabled", spawn_disabled)
	EventBus.cheat_toggled.emit(payload)

func toggle_silent_pause() -> void:
	if PauseManager:
		PauseManager.silent_pause()
		var status := "paused" if PauseManager.is_paused() else "unpaused"
		Logger.info("Silent pause: " + status, "debug")

# Public getters for systems to check cheat states
func is_god_mode_active() -> bool:
	return god_mode

func is_spawn_disabled() -> bool:
	return spawn_disabled