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
	# Phase B: CardSystem (no dependencies)
	card_system = CardSystem.new()
	add_child(card_system)
	systems["CardSystem"] = card_system
	Logger.info("CardSystem initialized by GameOrchestrator", "orchestrator")
	
	# Phase C: Non-dependent systems
	# 1. EnemyRegistry (no deps)
	enemy_registry = EnemyRegistry.new()
	add_child(enemy_registry)
	systems["EnemyRegistry"] = enemy_registry
	Logger.info("EnemyRegistry initialized by GameOrchestrator", "orchestrator")
	
	# 4. AbilitySystem (no deps)
	ability_system = AbilitySystem.new()
	add_child(ability_system)
	systems["AbilitySystem"] = ability_system
	Logger.info("AbilitySystem initialized by GameOrchestrator", "orchestrator")
	
	# 7. ArenaSystem (no deps)
	arena_system = ArenaSystem.new()
	add_child(arena_system)
	systems["ArenaSystem"] = arena_system
	Logger.info("ArenaSystem initialized by GameOrchestrator", "orchestrator")
	
	# 8. CameraSystem (no deps)
	camera_system = CameraSystem.new()
	add_child(camera_system)
	systems["CameraSystem"] = camera_system
	Logger.info("CameraSystem initialized by GameOrchestrator", "orchestrator")
	
	# Phase D: WaveDirector (needs EnemyRegistry dependency)
	wave_director = WaveDirector.new()
	add_child(wave_director)
	systems["WaveDirector"] = wave_director
	# Set EnemyRegistry dependency
	if wave_director.has_method("set_enemy_registry"):
		wave_director.set_enemy_registry(enemy_registry)
		Logger.info("WaveDirector initialized with EnemyRegistry dependency", "orchestrator")
	else:
		Logger.warn("WaveDirector doesn't have set_enemy_registry method", "orchestrator")
	
	# Phase E: Combat systems with dependencies
	# 5. MeleeSystem (needs WaveDirector ref)
	melee_system = MeleeSystem.new()
	add_child(melee_system)
	systems["MeleeSystem"] = melee_system
	if melee_system.has_method("set_wave_director_reference") and wave_director:
		melee_system.set_wave_director_reference(wave_director)
		Logger.info("MeleeSystem initialized with WaveDirector dependency", "orchestrator")
	else:
		Logger.warn("MeleeSystem dependency injection failed", "orchestrator")
	
	# 6. DamageSystem (needs AbilitySystem, WaveDirector refs)
	damage_system = DamageSystem.new()
	add_child(damage_system)
	systems["DamageSystem"] = damage_system
	if damage_system.has_method("set_references") and ability_system and wave_director:
		damage_system.set_references(ability_system, wave_director)
		Logger.info("DamageSystem initialized with AbilitySystem and WaveDirector dependencies", "orchestrator")
	else:
		Logger.warn("DamageSystem dependency injection failed", "orchestrator")

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
	
	# Phase C: Inject non-dependent systems
	if enemy_registry and arena.has_method("set_enemy_registry"):
		arena.set_enemy_registry(enemy_registry)
		Logger.debug("EnemyRegistry injected to Arena", "orchestrator")
	
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