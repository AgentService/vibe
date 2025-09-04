class_name SystemInjectionManager
extends Node

# Centralizes all system injection logic and dependency management
# Reduces Arena.gd boilerplate and provides clean injection interface

# Type imports needed for system injection
const ArenaSystem := preload("res://scripts/systems/ArenaSystem.gd")
const CameraSystem := preload("res://scripts/systems/CameraSystem.gd")

# Arena references needed for system setup
var arena_ref: Node
var _injected: Dictionary = {}

func setup(arena: Node) -> void:
	arena_ref = arena
	Logger.info("SystemInjectionManager initialized", "systems")

# Phase 5: Centralized system injection collector
# Provides dictionary-based injection while maintaining backward compatibility
func inject_systems(systems: Dictionary) -> void:
	_injected = systems.duplicate()
	Logger.info("Arena: Centralized system injection completed with " + str(_injected.size()) + " systems", "systems")
	
	# Optional: connect signals here centrally if needed in future
	# For now, individual set_* methods handle their own connections

func set_card_system(injected_card_system: CardSystem) -> void:
	arena_ref.card_system = injected_card_system
	_injected["CardSystem"] = injected_card_system
	Logger.info("CardSystem injected into Arena", "cards")
	
	# Complete the card system setup through UI manager
	if arena_ref.ui_manager:
		arena_ref.ui_manager.setup_card_system(arena_ref.card_system)
		Logger.debug("Card system connected to ArenaUIManager", "cards")

func set_ability_system(injected_ability_system: AbilitySystem) -> void:
	arena_ref.ability_system = injected_ability_system
	_injected["AbilitySystem"] = injected_ability_system
	Logger.info("AbilitySystem injected into Arena", "systems")
	
	injected_ability_system.process_mode = Node.PROCESS_MODE_PAUSABLE
	injected_ability_system.projectiles_updated.connect(arena_ref.multimesh_manager.update_projectiles)

func set_arena_system(injected_arena_system: ArenaSystem) -> void:
	arena_ref.arena_system = injected_arena_system
	_injected["ArenaSystem"] = injected_arena_system
	Logger.info("ArenaSystem injected into Arena", "systems")
	
	injected_arena_system.process_mode = Node.PROCESS_MODE_PAUSABLE
	injected_arena_system.arena_loaded.connect(arena_ref._on_arena_loaded)

func set_camera_system(injected_camera_system: CameraSystem) -> void:
	arena_ref.camera_system = injected_camera_system
	_injected["CameraSystem"] = injected_camera_system
	Logger.info("CameraSystem injected into Arena", "systems")
	
	injected_camera_system.process_mode = Node.PROCESS_MODE_PAUSABLE
	if arena_ref.player:
		injected_camera_system.setup_camera(arena_ref.player)

func set_wave_director(injected_wave_director: WaveDirector) -> void:
	arena_ref.wave_director = injected_wave_director
	_injected["WaveDirector"] = injected_wave_director
	Logger.info("WaveDirector injected into Arena", "systems")
	
	injected_wave_director.process_mode = Node.PROCESS_MODE_PAUSABLE
	injected_wave_director.enemies_updated.connect(arena_ref.multimesh_manager.update_enemies)
	
	# Inject WaveDirector into visual effects manager if it exists
	if arena_ref.visual_effects_manager:
		arena_ref.visual_effects_manager.configure_enemy_feedback_dependencies(null, injected_wave_director)

func set_melee_system(injected_melee_system: MeleeSystem) -> void:
	arena_ref.melee_system = injected_melee_system
	_injected["MeleeSystem"] = injected_melee_system
	Logger.info("MeleeSystem injected into Arena", "systems")
	
	injected_melee_system.process_mode = Node.PROCESS_MODE_PAUSABLE
	injected_melee_system.melee_attack_started.connect(arena_ref.player_attack_handler.on_melee_attack_started)

func set_damage_system(injected_damage_system: DamageSystem) -> void:
	arena_ref.damage_system = injected_damage_system
	_injected["DamageSystem"] = injected_damage_system
	Logger.info("DamageSystem injected into Arena", "systems")
	
	injected_damage_system.process_mode = Node.PROCESS_MODE_PAUSABLE

# Provide access to injected systems for DebugController
func get_injected_systems() -> Dictionary:
	return _injected.duplicate()

# Setup method specifically for DebugController integration
func setup_debug_controller() -> void:
	if arena_ref.debug_controller:
		arena_ref.debug_controller.setup(arena_ref, _injected)
		Logger.info("DebugController setup complete with " + str(_injected.size()) + " injected systems", "systems")
	else:
		Logger.warn("DebugController not available for setup", "systems")
