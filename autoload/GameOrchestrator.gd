extends Node

## Central game orchestration system managing system initialization and lifecycle.
## Handles proper dependency injection and initialization order for all game systems.

# Import system classes - using _Type suffix to avoid conflicts with class names
const CardSystem_Type = preload("res://scripts/systems/CardSystem.gd")
const SpawnDirector_Type = preload("res://scripts/systems/SpawnDirector.gd")
const RadarSystem_Type = preload("res://scripts/systems/RadarSystem.gd")
# TODO: Phase 2 - Remove when replaced with AbilityModule autoload
# const AbilitySystem_Type = preload("res://scripts/systems/AbilitySystem.gd")
const MeleeSystem_Type = preload("res://scripts/systems/MeleeSystem.gd")
const ArenaSystem = preload("res://scripts/systems/ArenaSystem.gd")
const XpSystem_Type = preload("res://scripts/systems/XpSystem.gd")

# Core orchestration events
signal systems_initialized()
@warning_ignore("unused_signal")
signal world_ready()

# System references - will be populated during initialization
var systems: Dictionary = {}
var initialization_phase: String = "idle"

# System instances that will be created here and injected to Arena
var card_system: CardSystem_Type
var spawn_director: SpawnDirector_Type
var radar_system: RadarSystem_Type
# TODO: Phase 2 - Remove ability_system when replaced with AbilityModule autoload
# var ability_system: AbilitySystem_Type
var melee_system: MeleeSystem_Type
var arena_system: ArenaSystem
var xp_system: XpSystem_Type

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
		# Check if UIManager has an active modal first
		if UIManager and UIManager.has_active_modal():
			Logger.debug("ESC blocked by GameOrchestrator - modal is active", "orchestrator")
			return  # Let UIManager handle it
		
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
	
	# CameraSystem removed - players handle their own cameras
	
	# Phase D: SpawnDirector (no dependencies)
	spawn_director = SpawnDirector_Type.new()
	add_child(spawn_director)
	systems["SpawnDirector"] = spawn_director
	
	# Set ArenaSystem dependency
	if spawn_director.has_method("set_arena_system"):
		spawn_director.set_arena_system(arena_system)
		Logger.info("SpawnDirector initialized with ArenaSystem dependency", "orchestrator")
	else:
		Logger.warn("SpawnDirector doesn't have set_arena_system method", "orchestrator")
	
	# Phase D2: RadarSystem (depends on SpawnDirector)
	radar_system = RadarSystem_Type.new()
	add_child(radar_system)
	systems["RadarSystem"] = radar_system
	
	# Set SpawnDirector dependency
	if radar_system.has_method("setup") and spawn_director:
		radar_system.setup(spawn_director)
		Logger.info("RadarSystem initialized with SpawnDirector dependency", "orchestrator")
	else:
		Logger.warn("RadarSystem dependency injection failed", "orchestrator")
	
	# Phase E: Combat systems with dependencies
	# 5. MeleeSystem (needs SpawnDirector ref)
	melee_system = MeleeSystem_Type.new()
	add_child(melee_system)
	systems["MeleeSystem"] = melee_system
	if melee_system.has_method("set_spawn_director_reference") and spawn_director:
		melee_system.set_spawn_director_reference(spawn_director)
		Logger.info("MeleeSystem initialized with SpawnDirector dependency", "orchestrator")
	else:
		Logger.warn("MeleeSystem dependency injection failed", "orchestrator")
	
	Logger.info("Using DamageService autoload (zero-allocation damage system)", "orchestrator")
	
	# Phase F: XpSystem (needs arena reference - will be injected later)
	# Note: XpSystem requires arena node in constructor, so it will be handled by SystemInjectionManager
	Logger.info("XpSystem will be initialized by Arena via SystemInjectionManager", "orchestrator")

func get_card_system() -> CardSystem_Type:
	return card_system



func get_spawn_director() -> SpawnDirector_Type:
	return spawn_director

func get_radar_system() -> RadarSystem_Type:
	return radar_system

# TODO: Phase 2 - Remove when AbilityModule becomes autoload
# func get_ability_system() -> AbilitySystem_Type:
#	return ability_system

func get_melee_system() -> MeleeSystem_Type:
	return melee_system


func get_arena_system() -> ArenaSystem:
	return arena_system

# get_camera_system removed - players handle their own cameras

# Dependency injection method for Arena
func inject_systems_to_arena(arena) -> void:
	if not arena:
		Logger.error("Cannot inject systems: Arena is null", "orchestrator")
		return
	
	Logger.info("=== SYSTEM INJECTION STARTING === inject_systems_to_arena called", "orchestrator")
	
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
	
	# CameraSystem injection removed - players handle their own cameras
	
	# Phase D: Inject SpawnDirector
	if spawn_director and arena.has_method("set_spawn_director"):
		arena.set_spawn_director(spawn_director)
		Logger.debug("SpawnDirector injected to Arena", "orchestrator")
	
	# Phase E: Inject combat systems
	if melee_system and arena.has_method("set_melee_system"):
		arena.set_melee_system(melee_system)
		Logger.debug("MeleeSystem injected to Arena", "orchestrator")
	
	Logger.debug("Arena will use DamageService autoload (zero-allocation damage system)", "orchestrator")
	
	# Phase F: Create or update XpSystem (needs arena reference)
	Logger.info("Phase F: Starting XpSystem creation/update and injection", "orchestrator")
	
	if not arena:
		Logger.error("Arena reference is null for XpSystem creation", "orchestrator")
	else:
		Logger.info("Arena reference valid, handling XpSystem...", "orchestrator")
		
		if not xp_system or not is_instance_valid(xp_system):
			# Create new XpSystem if it doesn't exist
			Logger.info("Creating new XpSystem instance", "orchestrator")
			xp_system = XpSystem_Type.new(arena)
			add_child(xp_system)
			systems["XpSystem"] = xp_system
			Logger.info("XpSystem instance created and registered", "orchestrator")
		else:
			# Update existing XpSystem with new arena reference
			Logger.info("Updating existing XpSystem arena reference", "orchestrator")
			xp_system.update_arena_reference(arena)
			Logger.info("XpSystem arena reference updated", "orchestrator")
		
		if arena.has_method("set_xp_system"):
			Logger.info("Arena has set_xp_system method, calling it...", "orchestrator")
			arena.set_xp_system(xp_system)
			Logger.info("XpSystem successfully injected to Arena", "orchestrator")
		else:
			Logger.error("Arena doesn't have set_xp_system method - XpSystem injection failed!", "orchestrator")
	
	# Phase G: Setup DebugController (after all systems are injected)
	if arena.has_method("setup_debug_controller"):
		arena.setup_debug_controller()
		Logger.debug("DebugController setup complete", "orchestrator")

# STATE-DRIVEN SCENE MANAGEMENT

func _on_state_changed(prev: StateManager.State, next: StateManager.State, context: Dictionary) -> void:
	"""Handle state changes by orchestrating scene transitions and system management."""
	Logger.info("GameOrchestrator: State changed %d -> %d" % [prev, next], "orchestrator")
	
	# Stop combat systems when leaving arena
	if prev == StateManager.State.ARENA and spawn_director and spawn_director.has_method("stop"):
		spawn_director.stop()
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
