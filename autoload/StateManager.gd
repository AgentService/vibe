extends Node

## Centralized state orchestration for the core game loop.
## Manages all scene transitions and run state changes with typed state enum.
## All scene transitions must go through this manager to maintain proper flow.

enum State {
	BOOT,
	MENU,
	CHARACTER_SELECT,
	HIDEOUT,
	ARENA,
	RESULTS,
	EXIT
}

# State tracking
var current_state: State = State.BOOT
var previous_state: State = State.BOOT

# Typed signals
signal state_changed(prev: State, next: State, context: Dictionary)
signal run_started(run_id: StringName, context: Dictionary)
signal run_ended(result: Dictionary)

func _ready() -> void:
	Logger.info("StateManager initialized - current state: BOOT", "state")
	process_mode = Node.PROCESS_MODE_ALWAYS

## PUBLIC API - Scene Transition Methods

func go_to_menu(context: Dictionary = {}) -> void:
	"""Transition to main menu."""
	_transition_to_state(State.MENU, context)

func go_to_character_select(context: Dictionary = {}) -> void:
	"""Transition to character selection."""
	_transition_to_state(State.CHARACTER_SELECT, context)

func go_to_hideout(context: Dictionary = {}) -> void:
	"""Transition to hideout hub."""
	# Reset session when returning to hideout from arena/results
	if SessionManager and current_state == State.ARENA:
		await SessionManager.reset_hideout_return()
		Logger.info("Session reset completed for hideout return", "state")
	
	_transition_to_state(State.HIDEOUT, context)

func start_run(arena_id: StringName, context: Dictionary = {}) -> void:
	"""Start a new arena run."""
	Logger.info("Starting run - arena_id: %s" % arena_id, "state")
	
	# Reset session before starting new run
	if SessionManager:
		var source = context.get("source", "unknown")
		if source == "results_restart":
			await SessionManager.reset_session(SessionManager.ResetReason.LEVEL_RESTART, context)
		else:
			await SessionManager.reset_session(SessionManager.ResetReason.MAP_TRANSITION, context)
		Logger.info("Session reset completed before starting run", "state")
	
	# Generate unique run ID
	var run_id = StringName("run_%d" % Time.get_ticks_msec())
	context["run_id"] = run_id
	context["arena_id"] = arena_id
	
	# Emit run started signal before state change
	run_started.emit(run_id, context)
	
	# Transition to arena state
	_transition_to_state(State.ARENA, context)

func end_run(result: Dictionary) -> void:
	"""End current run and transition to results."""
	Logger.info("Ending run - result: %s" % result, "state")
	
	# Emit run ended signal
	run_ended.emit(result)
	
	# Transition to results with run data
	_transition_to_state(State.RESULTS, result)

func return_to_menu(reason: StringName, context: Dictionary = {}) -> void:
	"""Return to main menu from any state."""
	Logger.info("Returning to menu - reason: %s" % reason, "state")
	
	# Reset session when returning to menu from arena/results/hideout
	if SessionManager and current_state in [State.ARENA, State.RESULTS, State.HIDEOUT]:
		context["preserve_character"] = false  # Full reset when going to menu
		await SessionManager.reset_session(SessionManager.ResetReason.MAP_TRANSITION, context)
		Logger.info("Session reset completed for menu return", "state")
	
	context["reason"] = reason
	_transition_to_state(State.MENU, context)

## PAUSE MANAGEMENT

func is_pause_allowed() -> bool:
	"""Returns true if pause is allowed in current state."""
	match current_state:
		State.HIDEOUT, State.ARENA, State.RESULTS:
			return true
		_:
			return false

## PRIVATE STATE MANAGEMENT

func _transition_to_state(target_state: State, context: Dictionary = {}) -> void:
	"""Internal state transition with validation and logging."""
	
	# Ignore if same state (unless forced via context)
	if target_state == current_state and not context.get("force_transition", false):
		Logger.warn("Ignoring transition to same state: %s" % _state_to_string(target_state), "state")
		return
	
	# Validate transition
	if not _is_valid_transition(current_state, target_state):
		Logger.error("Invalid state transition: %s -> %s" % [_state_to_string(current_state), _state_to_string(target_state)], "state")
		return
	
	# Log transition
	Logger.info("State transition: %s -> %s (context: %s)" % [_state_to_string(current_state), _state_to_string(target_state), context], "state")
	
	# Update state tracking
	previous_state = current_state
	current_state = target_state
	
	# Emit state changed signal
	state_changed.emit(previous_state, current_state, context)

func _is_valid_transition(from: State, to: State) -> bool:
	"""Validates if transition is allowed between states."""
	
	# BOOT can go anywhere (initial startup)
	if from == State.BOOT:
		return true
	
	# EXIT is terminal
	if from == State.EXIT:
		return false
	
	# Define valid transition rules
	match from:
		State.MENU:
			return to in [State.CHARACTER_SELECT, State.EXIT, State.HIDEOUT]  # Allow direct to hideout for debug
		State.CHARACTER_SELECT:
			return to in [State.MENU, State.HIDEOUT, State.EXIT]
		State.HIDEOUT:
			return to in [State.MENU, State.ARENA, State.CHARACTER_SELECT, State.EXIT]
		State.ARENA:
			return to in [State.RESULTS, State.HIDEOUT, State.MENU, State.EXIT]  # Allow emergency exits
		State.RESULTS:
			return to in [State.MENU, State.HIDEOUT, State.ARENA, State.EXIT]  # Restart run
		_:
			return false

func _state_to_string(state: State) -> String:
	"""Convert state enum to string for logging."""
	match state:
		State.BOOT: return "BOOT"
		State.MENU: return "MENU"
		State.CHARACTER_SELECT: return "CHARACTER_SELECT"
		State.HIDEOUT: return "HIDEOUT"
		State.ARENA: return "ARENA"
		State.RESULTS: return "RESULTS"
		State.EXIT: return "EXIT"
		_: return "UNKNOWN"

## GETTERS

func get_current_state() -> State:
	"""Get current state enum value."""
	return current_state

func get_previous_state() -> State:
	"""Get previous state enum value."""
	return previous_state

func get_current_state_string() -> String:
	"""Get current state as string."""
	return _state_to_string(current_state)