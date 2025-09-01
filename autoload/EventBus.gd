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
const DamageRequestPayload_Type = preload("res://scripts/domain/signal_payloads/DamageRequestPayload.gd")
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

# TIMING SIGNALS
## Emitted by RunManager at fixed 30Hz for deterministic combat updates
signal combat_step(payload)

# DAMAGE SIGNALS
## Request damage calculation - emitted by projectile/ability systems
signal damage_requested(payload)

## Single damage instance applied - emitted by DamageSystem after calculation
signal damage_applied(payload)

## Batch damage applied - emitted by DamageSystem for AoE/multi-target abilities
signal damage_batch_applied(payload)

## Damage entity sync - emitted by DamageRegistry V3 for unified entity HP updates
signal damage_entity_sync(payload)

## Player takes damage - emitted when enemies hit player
signal damage_taken(damage: int)

## Player died - emitted when HP reaches 0
signal player_died()

# MELEE ATTACK SIGNALS
## Melee attack performed - emitted by MeleeSystem when attack starts
signal melee_attack_started(payload)

## Melee attack hit enemies - emitted by MeleeSystem when enemies are hit
signal melee_enemies_hit(payload)

# ENTITY LIFECYCLE SIGNALS  
## Entity killed - emitted when HP reaches 0
signal entity_killed(payload)

## Legacy enemy killed signal - marked deprecated, migrate to entity_killed
signal enemy_killed(payload)

# PROGRESSION SIGNALS
## XP values changed - emitted by XpSystem
signal xp_changed(payload)

## Player leveled up - emitted by XpSystem, triggers pause + card selection
signal level_up(payload)

# GAME STATE SIGNALS
## Game pause state changed - emitted by RunManager
signal game_paused_changed(payload)

# CAMERA SIGNALS
## Arena bounds changed - emitted by ArenaSystem when new arena loads
signal arena_bounds_changed(payload)

## Player position updated - emitted by PlayerState for camera following
signal player_position_changed(payload)

## Damage dealt for camera shake - emitted by DamageSystem
signal damage_dealt(payload)

# INTERACTION SIGNALS
## Interaction prompt visibility changed - no longer used after arena simplification
signal interaction_prompt_changed(payload)

## Loot generated - emitted by arena systems for treasure chests
signal loot_generated(payload)

# DEBUG/CHEAT SIGNALS
## Cheat toggled - emitted when debug cheats are toggled
signal cheat_toggled(payload)

func _ready() -> void:
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
