extends Node

## Central game orchestration system managing system initialization and lifecycle.
## Handles proper dependency injection and initialization order for all game systems.

# Import system classes
const CardSystem = preload("res://scripts/systems/CardSystem.gd")
const EnemyRegistry = preload("res://scripts/systems/EnemyRegistry.gd")
const WaveDirector = preload("res://scripts/systems/WaveDirector.gd")
const AbilitySystem = preload("res://scripts/systems/AbilitySystem.gd")
const MeleeSystem = preload("res://scripts/systems/MeleeSystem.gd")
const DamageSystem = preload("res://scripts/systems/DamageSystem.gd")
const ArenaSystem = preload("res://scripts/systems/ArenaSystem.gd")
const CameraSystem = preload("res://scripts/systems/CameraSystem.gd")

# Core orchestration events
signal systems_initialized()
signal world_ready()

# System references - will be populated during initialization
var systems: Dictionary = {}
var initialization_phase: String = "idle"

# System instances that will be created here and injected to Arena
var card_system: CardSystem
var enemy_registry: EnemyRegistry
var wave_director: WaveDirector
var ability_system: AbilitySystem
var melee_system: MeleeSystem
var damage_system: DamageSystem
var arena_system: ArenaSystem
var camera_system: CameraSystem

func _ready() -> void:
	Logger.info("GameOrchestrator initializing", "orchestrator")
	# Don't initialize systems yet - this will be done when called by Main/Arena
	process_mode = Node.PROCESS_MODE_PAUSABLE

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
	# Phase B: Initialize CardSystem (no dependencies)
	card_system = CardSystem.new()
	add_child(card_system)
	systems["CardSystem"] = card_system
	Logger.info("CardSystem initialized by GameOrchestrator", "orchestrator")
	
	# Other systems will be moved in later phases:
	# 1. EnemyRegistry (no deps)
	# 3. WaveDirector (needs EnemyRegistry)
	# 4. AbilitySystem (no deps)
	# 5. MeleeSystem (needs WaveDirector ref)
	# 6. DamageSystem (needs AbilitySystem, WaveDirector refs)
	# 7. ArenaSystem (no deps)
	# 8. CameraSystem (no deps)

func get_card_system() -> CardSystem:
	return card_system

func get_enemy_registry() -> EnemyRegistry:
	return enemy_registry

func get_wave_director() -> WaveDirector:
	return wave_director

func get_ability_system() -> AbilitySystem:
	return ability_system

func get_melee_system() -> MeleeSystem:
	return melee_system

func get_damage_system() -> DamageSystem:
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