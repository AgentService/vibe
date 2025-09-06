extends Node

## Central game orchestration system managing system initialization and lifecycle.
## Handles proper dependency injection and initialization order for all game systems.

# Import system classes - using _Type suffix to avoid conflicts with class names
const CardSystem_Type = preload("res://scripts/systems/CardSystem.gd")
const WaveDirector_Type = preload("res://scripts/systems/WaveDirector.gd")
const AbilitySystem_Type = preload("res://scripts/systems/AbilitySystem.gd")
const MeleeSystem_Type = preload("res://scripts/systems/MeleeSystem.gd")
const DamageSystem_Type = preload("res://scripts/systems/DamageSystem.gd")
const ArenaSystem = preload("res://scripts/systems/ArenaSystem.gd")
const CameraSystem = preload("res://scripts/systems/CameraSystem.gd")

# Core orchestration events
signal systems_initialized()
signal world_ready()

# System references - will be populated during initialization
var systems: Dictionary = {}
var initialization_phase: String = "idle"

# System instances that will be created here and injected to Arena
var card_system: CardSystem_Type
var wave_director: WaveDirector_Type
var ability_system: AbilitySystem_Type
var melee_system: MeleeSystem_Type
var damage_system: DamageSystem_Type
var arena_system: ArenaSystem
var camera_system: CameraSystem

func _ready() -> void:
	Logger.info("GameOrchestrator initializing", "orchestrator")
	# Don't initialize systems yet - this will be done when called by Main/Arena
	process_mode = Node.PROCESS_MODE_PAUSABLE
	
	# Connect to mode_changed for global cleanup safety net
	EventBus.mode_changed.connect(_on_mode_changed)

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
	
	# 4. AbilitySystem (no deps)
	ability_system = AbilitySystem_Type.new()
	add_child(ability_system)
	systems["AbilitySystem"] = ability_system
	Logger.info("AbilitySystem initialized by GameOrchestrator", "orchestrator")
	
	# 7. ArenaSystem (no deps)
	arena_system = ArenaSystem.new()
	# Load and set the arena config
	var arena_config = load("res://data/content/arena/default_arena.tres") as ArenaConfig
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
	
	# 6. DamageSystem (needs AbilitySystem, WaveDirector refs)
	damage_system = DamageSystem_Type.new()
	add_child(damage_system)
	systems["DamageSystem"] = damage_system
	if damage_system.has_method("set_references") and ability_system and wave_director:
		damage_system.set_references(ability_system, wave_director)
		Logger.info("DamageSystem initialized with AbilitySystem and WaveDirector dependencies", "orchestrator")
	else:
		Logger.warn("DamageSystem dependency injection failed", "orchestrator")

func get_card_system() -> CardSystem_Type:
	return card_system



func get_wave_director() -> WaveDirector_Type:
	return wave_director

func get_ability_system() -> AbilitySystem_Type:
	return ability_system

func get_melee_system() -> MeleeSystem_Type:
	return melee_system

func get_damage_system() -> DamageSystem_Type:
	return damage_system

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
	
	if ability_system and arena.has_method("set_ability_system"):
		arena.set_ability_system(ability_system)
		Logger.debug("AbilitySystem injected to Arena", "orchestrator")
	
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
	
	if damage_system and arena.has_method("set_damage_system"):
		arena.set_damage_system(damage_system)
		Logger.debug("DamageSystem injected to Arena", "orchestrator")
	
	# Phase F: Setup DebugController (after all systems are injected)
	if arena.has_method("setup_debug_controller"):
		arena.setup_debug_controller()
		Logger.debug("DebugController setup complete", "orchestrator")

# SCENE TRANSITION METHODS

func go_to_hideout() -> void:
	Logger.info("GameOrchestrator: Initiating transition to hideout", "orchestrator")
	
	# Stop combat systems immediately
	if wave_director and wave_director.has_method("stop"):
		wave_director.stop()
	
	# Emit mode change for global cleanup (before transition)
	EventBus.mode_changed.emit("hideout")
	
	# Use existing EventBus system for compatibility with SceneTransitionManager
	# SceneTransitionManager will handle calling on_teardown() on the current scene
	EventBus.request_return_hideout.emit({
		"spawn_point": "PlayerSpawnPoint",
		"source": "orchestrator_transition"
	})
	Logger.info("GameOrchestrator: Initiated transition to hideout", "orchestrator")

func go_to_arena() -> void:
	Logger.info("GameOrchestrator: Initiating transition to arena", "orchestrator")
	
	# Emit mode change for global cleanup (before transition)
	EventBus.mode_changed.emit("arena")
	
	# Use existing EventBus system for compatibility with SceneTransitionManager
	# SceneTransitionManager will handle calling on_teardown() on the current scene
	EventBus.request_enter_map.emit({
		"map_id": "arena",
		"spawn_point": "PlayerSpawnPoint", 
		"source": "orchestrator_transition"
	})
	Logger.info("GameOrchestrator: Initiated transition to arena", "orchestrator")

# GLOBAL CLEANUP SAFETY NET

func _on_mode_changed(mode: StringName) -> void:
	"""Safety net - global purge of arena entities on mode change"""
	Logger.info("GameOrchestrator: Mode changed to %s - applying global cleanup" % mode, "orchestrator")
	
	# Global purge of arena_owned group
	var arena_owned_nodes = get_tree().get_nodes_in_group("arena_owned")
	if arena_owned_nodes.size() > 0:
		Logger.warn("GameOrchestrator: Found %d arena_owned nodes during mode change - purging" % arena_owned_nodes.size(), "orchestrator")
		for node in arena_owned_nodes:
			node.queue_free()
	
	# Global purge of enemies group
	var enemy_nodes = get_tree().get_nodes_in_group("enemies")
	if enemy_nodes.size() > 0:
		Logger.warn("GameOrchestrator: Found %d enemy nodes during mode change - purging" % enemy_nodes.size(), "orchestrator")
		for node in enemy_nodes:
			node.queue_free()
	
	# Force EntityTracker cleanup if switching to hideout
	if mode == "hideout" and EntityTracker:
		EntityTracker.clear("enemy")
		EntityTracker.clear("boss")
	
	Logger.info("GameOrchestrator: Global cleanup completed for mode %s" % mode, "orchestrator")
