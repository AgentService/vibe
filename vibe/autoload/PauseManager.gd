extends Node

## Centralized pause system using Godot's built-in pause functionality.
## Replaces manual pause checks with proper process_mode management.

enum PauseGroup {
	GAME,      # Game systems that should pause
	UI,        # UI elements that work during pause
	ALWAYS     # Debug/logging that never pauses
}

var _pause_state: bool = false

func _ready() -> void:
	# Set ourselves to always process
	process_mode = Node.PROCESS_MODE_ALWAYS
	Logger.info("PauseManager initialized", "ui")

func pause_game(paused: bool) -> void:
	if _pause_state == paused:
		return  # No change needed
	
	_pause_state = paused
	get_tree().paused = paused
	
	# Emit signal for systems that need to react
	var payload := EventBus.GamePausedChangedPayload_Type.new(paused)
	EventBus.game_paused_changed.emit(payload)
	
	Logger.info("Game " + ("paused" if paused else "resumed"), "ui")

func is_paused() -> bool:
	return _pause_state

func toggle_pause() -> void:
	pause_game(not _pause_state)

func silent_pause() -> void:
	_pause_state = not _pause_state
	get_tree().paused = _pause_state
	
	# Don't emit EventBus signal for silent pause
	Logger.info("Game " + ("silently paused" if _pause_state else "silently resumed"), "debug")

## Configure a node's pause behavior
func set_pause_group(node: Node, group: PauseGroup) -> void:
	match group:
		PauseGroup.GAME:
			node.process_mode = Node.PROCESS_MODE_PAUSABLE
		PauseGroup.UI:
			node.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
		PauseGroup.ALWAYS:
			node.process_mode = Node.PROCESS_MODE_ALWAYS

## Convenience methods for common pause groups
func set_game_pausable(node: Node) -> void:
	set_pause_group(node, PauseGroup.GAME)

func set_ui_pausable(node: Node) -> void:
	set_pause_group(node, PauseGroup.UI)

func set_always_process(node: Node) -> void:
	set_pause_group(node, PauseGroup.ALWAYS)

## Legacy compatibility - will be phased out
func get_legacy_paused() -> bool:
	return _pause_state
