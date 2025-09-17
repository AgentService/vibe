extends Node

## Global event bus for cross-system communication.
## All cross-system signals flow through here to maintain loose coupling.
## See ARCHITECTURE.md Signals Matrix for detailed contracts.
##
## NOTE: Signals marked as "unused" by Godot editor are FALSE POSITIVES.
## These signals ARE emitted by various systems throughout the codebase.
## The warning occurs because signals are emitted by other classes, not this EventBus class itself.

# Preload all payload classes - using _Type suffix to avoid conflicts with class names
const CombatStepPayload_Type = preload("res://scripts/domain/signal_payloads/CombatStepPayload.gd")
const DamageAppliedPayload_Type = preload("res://scripts/domain/signal_payloads/DamageAppliedPayload.gd")
const DamageBatchAppliedPayload_Type = preload("res://scripts/domain/signal_payloads/DamageBatchAppliedPayload.gd")
const EntityKilledPayload_Type = preload("res://scripts/domain/signal_payloads/EntityKilledPayload.gd")
const EnemyKilledPayload_Type = preload("res://scripts/domain/signal_payloads/EnemyKilledPayload.gd")
const XpChangedPayload_Type = preload("res://scripts/domain/signal_payloads/XpChangedPayload.gd")
const LevelUpPayload_Type = preload("res://scripts/domain/signal_payloads/LevelUpPayload.gd")
const GamePausedChangedPayload_Type = preload("res://scripts/domain/signal_payloads/GamePausedChangedPayload.gd")
const ArenaBoundsChangedPayload_Type = preload("res://scripts/domain/signal_payloads/ArenaBoundsChangedPayload.gd")
const PlayerPositionChangedPayload_Type = preload("res://scripts/domain/signal_payloads/PlayerPositionChangedPayload.gd")
const DamageDealtPayload_Type = preload("res://scripts/domain/signal_payloads/DamageDealtPayload.gd")
const InteractionPromptChangedPayload_Type = preload("res://scripts/domain/signal_payloads/InteractionPromptChangedPayload.gd")
const LootGeneratedPayload_Type = preload("res://scripts/domain/signal_payloads/LootGeneratedPayload.gd")
const CheatTogglePayload_Type = preload("res://scripts/domain/signal_payloads/CheatTogglePayload.gd")

# Object pools for high-frequency payloads to reduce allocations
const ObjectPool = preload("res://scripts/utils/ObjectPool.gd")
var _damage_applied_pool: ObjectPool
var _damage_dealt_pool: ObjectPool

# TIMING SIGNALS
## Emitted by RunManager at fixed 30Hz for deterministic combat updates
@warning_ignore("unused_signal")
signal combat_step(payload)

# DAMAGE SIGNALS
# NOTE: damage_requested signal removed - use DamageService.apply_damage() directly

## Single damage instance applied - emitted by DamageSystem after calculation
@warning_ignore("unused_signal")
signal damage_applied(payload)

## Batch damage applied - emitted by DamageSystem for AoE/multi-target abilities
@warning_ignore("unused_signal")
signal damage_batch_applied(payload)

## Damage entity sync - emitted by DamageRegistry V3 for unified entity HP updates
@warning_ignore("unused_signal")
signal damage_entity_sync(payload)

## Legacy damage_taken signal removed - damage handled via unified DamageService system

## Player died - emitted when HP reaches 0
@warning_ignore("unused_signal")
signal player_died()

# MELEE ATTACK SIGNALS
## Melee attack performed - emitted by MeleeSystem when attack starts
@warning_ignore("unused_signal")
signal melee_attack_started(payload)

## Melee attack hit enemies - emitted by MeleeSystem when enemies are hit
@warning_ignore("unused_signal")
signal melee_enemies_hit(payload)

## Melee swing timer started - emitted by Player for swing duration indicator
@warning_ignore("unused_signal")
signal melee_swing_started(duration: float)

## Bow attack started - emitted by Player when bow attack is triggered
@warning_ignore("unused_signal")
signal bow_attack_started(payload)

## Magic cast started - emitted by Player when magic cast is triggered  
@warning_ignore("unused_signal")
signal magic_cast_started(payload)

## Spear attack started - emitted by Player when spear attack is triggered
@warning_ignore("unused_signal")
signal spear_attack_started(payload)

# ENTITY LIFECYCLE SIGNALS  
## Entity killed - emitted when HP reaches 0
@warning_ignore("unused_signal")
signal entity_killed(payload)

## Enemy killed signal - uses direct parameters for memory efficiency
@warning_ignore("unused_signal")
signal enemy_killed(pos: Vector2, xp_value: int)

# PROGRESSION SIGNALS
## XP values changed - emitted by XpSystem
@warning_ignore("unused_signal")
signal xp_changed(payload)

## Player leveled up - emitted by XpSystem, triggers pause + card selection
@warning_ignore("unused_signal")
signal level_up(payload)

## NEW PROGRESSION SIGNALS (PlayerProgression system)
## XP gained - emitted when player gains experience points
@warning_ignore("unused_signal")
signal xp_gained(amount: float, new_total: float)

## Player leveled up - emitted when player levels up (new system)
@warning_ignore("unused_signal")
signal leveled_up(new_level: int, prev_level: int)

## Progression state changed - emitted when any progression state changes
## Contains both UI display data (current level progress) and save data (total accumulated XP)
@warning_ignore("unused_signal")
signal progression_changed(state: Dictionary)

# HUD COMPONENT SIGNALS
## Health changed - emitted when player health changes
@warning_ignore("unused_signal")
signal health_changed(current_health: float, max_health: float)

## Shield changed - emitted when player shield changes
@warning_ignore("unused_signal")
signal shield_changed(current_shield: float, max_shield: float)

## Resource changed - emitted when player resources change (mana, energy, etc.)
@warning_ignore("unused_signal")
signal resource_changed(resource_type: String, current: float, max_value: float)

## Ability cooldown started - emitted when ability goes on cooldown
@warning_ignore("unused_signal")
signal ability_cooldown_started(ability_id: String, duration: float)

## Ability ready - emitted when ability cooldown finishes
@warning_ignore("unused_signal")
signal ability_ready(ability_id: String)

## Damage numbers requested - emitted for floating damage text display
@warning_ignore("unused_signal")
signal damage_numbers_requested(amount: int, damage_type: String, position: Vector2)

## Item picked up - emitted for pickup notifications
@warning_ignore("unused_signal")
signal item_picked_up(item: Resource, position: Vector2)

## Wave started - emitted when new wave begins
@warning_ignore("unused_signal")
signal wave_started(wave_number: int, enemy_count: int)

## Boss spawned - emitted when boss appears
@warning_ignore("unused_signal")
signal boss_spawned(boss_name: String)

## Notification requested - emitted to show system messages
@warning_ignore("unused_signal")
signal notification_requested(message: String, type: String, duration: float)

# CHARACTER MANAGEMENT SIGNALS
## Characters list changed - emitted when character list is updated (create/delete)
@warning_ignore("unused_signal")
signal characters_list_changed(profiles: Array[Dictionary])

## Character created - emitted when a new character is created
@warning_ignore("unused_signal")
signal character_created(profile: Dictionary)

## Character deleted - emitted when a character is deleted
@warning_ignore("unused_signal")
signal character_deleted(character_id: StringName)

## Character selected - emitted when a character is selected for play
@warning_ignore("unused_signal")
signal character_selected(profile: Dictionary)

# GAME STATE SIGNALS
## Game pause state changed - emitted by RunManager
@warning_ignore("unused_signal")
signal game_paused_changed(payload)

# UI/MODAL SIGNALS
## Modal displayed - emitted by UIManager when a modal is shown
@warning_ignore("unused_signal")
signal modal_displayed(modal_type, modal_instance)

## Modal hidden - emitted by UIManager when a modal is closed
@warning_ignore("unused_signal")
signal modal_hidden(modal_instance)

# CAMERA SIGNALS
## Arena bounds changed - emitted by ArenaSystem when new arena loads
@warning_ignore("unused_signal")
signal arena_bounds_changed(payload)

## Player position updated - emitted by PlayerState for camera following
@warning_ignore("unused_signal")
signal player_position_changed(payload)

## Damage dealt for camera shake - emitted by DamageSystem
@warning_ignore("unused_signal")
signal damage_dealt(payload)

# INTERACTION SIGNALS
## Interaction prompt visibility changed - no longer used after arena simplification
@warning_ignore("unused_signal")
signal interaction_prompt_changed(payload)

## Loot generated - emitted by arena systems for treasure chests
@warning_ignore("unused_signal")
signal loot_generated(payload)

# DEBUG/CHEAT SIGNALS
## Cheat toggled - emitted when debug cheats are toggled
@warning_ignore("unused_signal")
signal cheat_toggled(payload)

# SESSION MANAGEMENT SIGNALS
## Session UI reset - emitted by SessionManager for UI systems to reset state
@warning_ignore("unused_signal")
signal session_ui_reset(payload)

# SCENE TRANSITION SIGNALS
## Request to enter a map/arena - emitted by MapDevice or UI elements
@warning_ignore("unused_signal")
signal request_enter_map(data: Dictionary)

## Request to return to hideout - emitted by UI or game systems
@warning_ignore("unused_signal")
signal request_return_hideout(data: Dictionary)

## Mode changed signal - emitted when switching between game modes (arena/hideout)
@warning_ignore("unused_signal")
signal mode_changed(mode: StringName)

# HIDEOUT PHASE 0 TYPED SIGNALS (past-tense)
## Map entry requested - emitted when player requests to enter a specific map
@warning_ignore("unused_signal")
signal enter_map_requested(map_id: StringName)

# EVENT SYSTEM SIGNALS
## Event started - emitted when a new event begins
@warning_ignore("unused_signal")
signal event_started(event_type: StringName, zone: Area2D)

## Event completed - emitted when an event is successfully finished
@warning_ignore("unused_signal")
signal event_completed(event_type: StringName, performance_data: Dictionary)

## Event failed - emitted when an event fails or times out
@warning_ignore("unused_signal")
signal event_failed(event_type: StringName, reason: String)

# MASTERY SYSTEM SIGNALS
## Mastery points earned - emitted when player earns mastery points
@warning_ignore("unused_signal")
signal mastery_points_earned(event_type: StringName, points: int)

## Passive allocated - emitted when a mastery passive is allocated
@warning_ignore("unused_signal")
signal passive_allocated(passive_id: StringName)

## Passive deallocated - emitted when a mastery passive is deallocated (respec)
@warning_ignore("unused_signal")
signal passive_deallocated(passive_id: StringName)

# RADAR SIGNALS
## Simple radar entity data structure for typed enemy information
class RadarEntity:
	var pos: Vector2
	var type: String  # "enemy", "boss"

	func _init(position: Vector2, entity_type: String):
		pos = position
		type = entity_type

## Radar data updated - emitted by RadarSystem with enemy data and player position
@warning_ignore("unused_signal")
signal radar_data_updated(entities: Array[RadarEntity], player_pos: Vector2)


func _ready() -> void:
	# Initialize object pools for high-frequency payloads
	_damage_applied_pool = ObjectPool.new()
	_damage_applied_pool.setup(20, _create_damage_applied_payload, _reset_damage_applied_payload)
	
	_damage_dealt_pool = ObjectPool.new()
	_damage_dealt_pool.setup(10, _create_damage_dealt_payload, _reset_damage_dealt_payload)
	
	# Connect debug logging to relevant signals only
	level_up.connect(_log_level_up)
	entity_killed.connect(_log_entity_killed)
	interaction_prompt_changed.connect(_log_interaction_prompt_changed)
	loot_generated.connect(_log_loot_generated)

func _log_level_up(payload) -> void:
	Logger.debug("Level up: %s" % payload, "signals")

func _log_entity_killed(payload) -> void:
	Logger.debug("Entity killed: %s" % payload, "signals")

func _log_interaction_prompt_changed(payload) -> void:
	Logger.debug("Interaction prompt: %s" % payload, "signals")

func _log_loot_generated(payload) -> void:
	Logger.debug("Loot generated: %s" % payload, "signals")

# Object pool factory and reset functions
func _create_damage_applied_payload() -> DamageAppliedPayload:
	return DamageAppliedPayload_Type.new(EntityId.player(), 0.0, false, PackedStringArray())

func _reset_damage_applied_payload(payload: DamageAppliedPayload) -> void:
	payload.reset()

func _create_damage_dealt_payload() -> DamageDealtPayload:
	return DamageDealtPayload_Type.new(0.0, "", "")

func _reset_damage_dealt_payload(payload: DamageDealtPayload) -> void:
	if payload.has_method("reset"):
		payload.reset()

# Public payload pool access methods
func acquire_damage_applied_payload() -> DamageAppliedPayload:
	return _damage_applied_pool.acquire()

func release_damage_applied_payload(payload: DamageAppliedPayload) -> void:
	_damage_applied_pool.release(payload)

func acquire_damage_dealt_payload() -> DamageDealtPayload:
	return _damage_dealt_pool.acquire()

func release_damage_dealt_payload(payload: DamageDealtPayload) -> void:
	_damage_dealt_pool.release(payload)
