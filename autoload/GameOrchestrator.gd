extends Node

## Central game orchestration system managing system initialization and lifecycle.
## Handles proper dependency injection and initialization order for all game systems.

# Import system classes - using _Type suffix to avoid conflicts with class names
const CardSystem_Type = preload("res://scripts/systems/CardSystem.gd")
const WaveDirector_Type = preload("res://scripts/systems/WaveDirector.gd")
const RadarSystem_Type = preload("res://scripts/systems/RadarSystem.gd")
# TODO: Phase 2 - Remove when replaced with AbilityModule autoload
# const AbilitySystem_Type = preload("res://scripts/systems/AbilitySystem.gd")
const MeleeSystem_Type = preload("res://scripts/systems/MeleeSystem.gd")
const ArenaSystem = preload("res://scripts/systems/ArenaSystem.gd")
const CameraSystem = preload("res://scripts/systems/CameraSystem.gd")

# Core orchestration events
signal systems_initialized()
@warning_ignore("unused_signal")
signal world_ready()

# System references - will be populated during initialization
var systems: Dictionary = {}
var initialization_phase: String = "idle"

# System instances that will be created here and injected to Arena
var card_system: CardSystem_Type
var wave_director: WaveDirector_Type
var radar_system: RadarSystem_Type
# TODO: Phase 2 - Remove ability_system when replaced with AbilityModule autoload
# var ability_system: AbilitySystem_Type
var melee_system: MeleeSystem_Type
var arena_system: ArenaSystem
var camera_system: CameraSystem

func _ready() -> void:
	Logger.info("GameOrchestrator initializing", "orchestrator")
	# Don't initialize systems yet - this will be done when called by Main/Arena
	process_mode = Node.PROCESS_MODE_ALWAYS  # Always process input, even when paused
	
	# Connect to StateManager for state-driven orchestration
	StateManager.state_changed.connect(_on_state_changed)
	
	# Connect to mode_changed for global cleanup safety net
	EventBus.mode_changed.connect(_on_mode_changed)

func _input(event: InputEvent) -> void:
	"""Handle global input - centralized escape handling for pause functionality."""
	if event.is_action_pressed("ui_cancel") and event is InputEventKey:
		Logger.info("ESC key detected in GameOrchestrator", "orchestrator")
		_try_toggle_pause()
		get_viewport().set_input_as_handled()  # Mark input as handled

func _try_toggle_pause() -> void:
	"""Attempt to toggle pause if allowed by current state."""
	if StateManager.is_pause_allowed():
		# Check if already paused - if so, unpause; if not, pause
		if PauseManager.is_paused():
			PauseManager.pause_game(false)
			Logger.info("Game unpaused via GameOrchestrator", "orchestrator")
		else:
			PauseManager.pause_game(true)
			Logger.info("Game paused via GameOrchestrator", "orchestrator")
	else:
		Logger.debug("Pause not allowed in current state: %s" % StateManager.get_current_state_string(), "orchestrator")

func initialize_core_loop() -> void:
	if initialization_phase != "idle":
		Logger.warn("GameOrchestrator already initialized", "orchestrator")
		return
	
	initialization_phase = "initializing"
	Logger.info("Starting core loop initialization", "orchestrator")
	
	# Phase 1: Core singletons are already loaded via autoload
	
	# Phase 2: Initialize game systems in dependency order
	_initialize_systems()
	
	# Phase 3: Setup world (handled by Arena after injection)
	
	# Phase 4: Start gameplay (handled by systems)
	
	initialization_phase = "complete"
	systems_initialized.emit()
	Logger.info("Core loop initialization complete", "orchestrator")

func _initialize_systems() -> void:
	Logger.info("Initializing game systems", "orchestrator")
	
	# Initialize systems in dependency order (from plan):
	# Phase B: CardSystem (no dependencies)
	card_system = CardSystem_Type.new()
	add_child(card_system)
	systems["CardSystem"] = card_system
	Logger.info("CardSystem initialized by GameOrchestrator", "orchestrator")
	
	# Phase C: Non-dependent systems
	
	# TODO: Phase 2 - Remove AbilitySystem initialization when replaced with AbilityModule autoload
	# 4. AbilitySystem (no deps)
	# ability_system = AbilitySystem_Type.new()
	# add_child(ability_system)
	# systems["AbilitySystem"] = ability_system
	# Logger.info("AbilitySystem initialized by GameOrchestrator", "orchestrator")
	
	# 7. ArenaSystem (no deps)
	arena_system = ArenaSystem.new()
	# Load and set the arena config
	var arena_config = load("res://data/content/default_arena.tres") as ArenaConfig
	arena_system.arena_config = arena_config
	add_child(arena_system)
	systems["ArenaSystem"] = arena_system
	Logger.info("ArenaSystem initialized by GameOrchestrator", "orchestrator")
	
	# 8. CameraSystem (no deps)
	camera_system = CameraSystem.new()
	add_child(camera_system)
	systems["CameraSystem"] = camera_system
	Logger.info("CameraSystem initialized by GameOrchestrator", "orchestrator")
	
	# Phase D: WaveDirector (no dependencies)
	wave_director = WaveDirector_Type.new()
	add_child(wave_director)
	systems["WaveDirector"] = wave_director
	
	# Set ArenaSystem dependency
	if wave_director.has_method("set_arena_system"):
		wave_director.set_arena_system(arena_system)
		Logger.info("WaveDirector initialized with ArenaSystem dependency", "orchestrator")
	else:
		Logger.warn("WaveDirector doesn't have set_arena_system method", "orchestrator")
	
	# Phase D2: RadarSystem (depends on WaveDirector)
	radar_system = RadarSystem_Type.new()
	add_child(radar_system)
	systems["RadarSystem"] = radar_system
	
	# Set WaveDirector dependency
	if radar_system.has_method("setup") and wave_director:
		radar_system.setup(wave_director)
		Logger.info("RadarSystem initialized with WaveDirector dependency", "orchestrator")
	else:
		Logger.warn("RadarSystem dependency injection failed", "orchestrator")
	
	# Phase E: Combat systems with dependencies
	# 5. MeleeSystem (needs WaveDirector ref)
	melee_system = MeleeSystem_Type.new()
	add_child(melee_system)
	systems["MeleeSystem"] = melee_system
	if melee_system.has_method("set_wave_director_reference") and wave_director:
		melee_system.set_wave_director_reference(wave_director)
		Logger.info("MeleeSystem initialized with WaveDirector dependency", "orchestrator")
	else:
		Logger.warn("MeleeSystem dependency injection failed", "orchestrator")
	
	Logger.info("Using DamageService autoload (zero-allocation damage system)", "orchestrator")

func get_card_system() -> CardSystem_Type:
	return card_system



func get_wave_director() -> WaveDirector_Type:
	return wave_director

func get_radar_system() -> RadarSystem_Type:
	return radar_system

# TODO: Phase 2 - Remove when AbilityModule becomes autoload
# func get_ability_system() -> AbilitySystem_Type:
#	return ability_system

func get_melee_system() -> MeleeSystem_Type:
	return melee_system


func get_arena_system() -> ArenaSystem:
	return arena_system

func get_camera_system() -> CameraSystem:
	return camera_system

# Dependency injection method for Arena
func inject_systems_to_arena(arena) -> void:
	if not arena:
		Logger.error("Cannot inject systems: Arena is null", "orchestrator")
		return
	
	Logger.info("Injecting systems to Arena", "orchestrator")
	
	# Phase B: Inject CardSystem
	if card_system and arena.has_method("set_card_system"):
		arena.set_card_system(card_system)
		Logger.debug("CardSystem injected to Arena", "orchestrator")
	else:
		Logger.warn("Arena doesn't have set_card_system method", "orchestrator")
	
	# Phase C: Inject non-dependent systems
	
	# TODO: Phase 2 - Remove AbilitySystem injection when replaced with AbilityModule autoload
	# if ability_system and arena.has_method("set_ability_system"):
	#	arena.set_ability_system(ability_system)
	#	Logger.debug("AbilitySystem injected to Arena", "orchestrator")
	
	if arena_system and arena.has_method("set_arena_system"):
		arena.set_arena_system(arena_system)
		Logger.debug("ArenaSystem injected to Arena", "orchestrator")
	
	if camera_system and arena.has_method("set_camera_system"):
		arena.set_camera_system(camera_system)
		Logger.debug("CameraSystem injected to Arena", "orchestrator")
	
	# Phase D: Inject WaveDirector
	if wave_director and arena.has_method("set_wave_director"):
		arena.set_wave_director(wave_director)
		Logger.debug("WaveDirector injected to Arena", "orchestrator")
	
	# Phase E: Inject combat systems
	if melee_system and arena.has_method("set_melee_system"):
		arena.set_melee_system(melee_system)
		Logger.debug("MeleeSystem injected to Arena", "orchestrator")
	
	Logger.debug("Arena will use DamageService autoload (zero-allocation damage system)", "orchestrator")
	
	# Phase F: Setup DebugController (after all systems are injected)
	if arena.has_method("setup_debug_controller"):
		arena.setup_debug_controller()
		Logger.debug("DebugController setup complete", "orchestrator")

# STATE-DRIVEN SCENE MANAGEMENT

func _on_state_changed(prev: StateManager.State, next: StateManager.State, context: Dictionary) -> void:
	"""Handle state changes by orchestrating scene transitions and system management."""
	Logger.info("GameOrchestrator: State changed %d -> %d" % [prev, next], "orchestrator")
	
	# Stop combat systems when leaving arena
	if prev == StateManager.State.ARENA and wave_director and wave_director.has_method("stop"):
		wave_director.stop()
		Logger.info("GameOrchestrator: Stopped combat systems on arena exit", "orchestrator")
		
		# Session resets are now handled directly by StateManager methods
	
	# Emit mode change for global cleanup
	var mode_name = _state_to_mode_name(next)
	EventBus.mode_changed.emit(mode_name)
	
	# Trigger actual scene loading based on target state
	_load_scene_for_state(next, context)

func _load_scene_for_state(state: StateManager.State, context: Dictionary) -> void:
	"""Load appropriate scene for the target state."""
	match state:
		StateManager.State.MENU:
			EventBus.request_enter_map.emit({
				"map_id": "main_menu",
				"source": "state_manager",
				"context": context
			})
		
		StateManager.State.CHARACTER_SELECT:
			EventBus.request_enter_map.emit({
				"map_id": "character_select",
				"source": "state_manager",
				"context": context
			})
		
		StateManager.State.HIDEOUT:
			EventBus.request_return_hideout.emit({
				"spawn_point": context.get("spawn_point", "PlayerSpawnPoint"),
				"source": "state_manager",
				"context": context
			})
		
		StateManager.State.ARENA:
			EventBus.request_enter_map.emit({
				"map_id": context.get("arena_id", "arena"),
				"spawn_point": "PlayerSpawnPoint",
				"source": "state_manager",
				"context": context
			})
		
		StateManager.State.RESULTS:
			EventBus.request_enter_map.emit({
				"map_id": "results",
				"source": "state_manager",
				"context": context
			})
		
		_:
			Logger.warn("GameOrchestrator: No scene mapping for state %d" % state, "orchestrator")

func _state_to_mode_name(state: StateManager.State) -> StringName:
	"""Convert StateManager state to mode name for EventBus compatibility."""
	match state:
		StateManager.State.HIDEOUT:
			return StringName("hideout")
		StateManager.State.ARENA:
			return StringName("arena")
		StateManager.State.MENU, StateManager.State.CHARACTER_SELECT:
			return StringName("menu")
		StateManager.State.RESULTS:
			return StringName("results")
		_:
			return StringName("unknown")

# LEGACY TRANSITION METHODS (deprecated - use StateManager instead)

func go_to_hideout() -> void:
	Logger.warn("GameOrchestrator.go_to_hideout() is deprecated - use StateManager.go_to_hideout()", "orchestrator")
	StateManager.go_to_hideout()

func go_to_arena() -> void:
	Logger.warn("GameOrchestrator.go_to_arena() is deprecated - use StateManager.start_run()", "orchestrator")
	StateManager.start_run(StringName("arena"))

# MODE CHANGE HANDLING - Cleanup delegated to SessionManager

func _on_mode_changed(mode: StringName) -> void:
	"""Handle mode changes - cleanup is now delegated to SessionManager"""
	Logger.info("GameOrchestrator: Mode changed to %s - cleanup handled by SessionManager" % mode, "orchestrator")
