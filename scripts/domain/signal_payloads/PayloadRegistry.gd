extends RefCounted

## Central registry that preloads all signal payload classes for Godot compilation.
## Import this file whenever you need to use payload classes.

class_name PayloadRegistry

# Preload all payload classes to ensure they're available during compilation
const CombatStepPayload = preload("res://scripts/domain/signal_payloads/CombatStepPayload.gd")
const DamageRequestPayload = preload("res://scripts/domain/signal_payloads/DamageRequestPayload.gd")
const DamageAppliedPayload = preload("res://scripts/domain/signal_payloads/DamageAppliedPayload.gd")
const DamageBatchAppliedPayload = preload("res://scripts/domain/signal_payloads/DamageBatchAppliedPayload.gd")
const EntityKilledPayload = preload("res://scripts/domain/signal_payloads/EntityKilledPayload.gd")
const EnemyKilledPayload = preload("res://scripts/domain/signal_payloads/EnemyKilledPayload.gd")
const XpChangedPayload = preload("res://scripts/domain/signal_payloads/XpChangedPayload.gd")
const LevelUpPayload = preload("res://scripts/domain/signal_payloads/LevelUpPayload.gd")
const GamePausedChangedPayload = preload("res://scripts/domain/signal_payloads/GamePausedChangedPayload.gd")
const ArenaBoundsChangedPayload = preload("res://scripts/domain/signal_payloads/ArenaBoundsChangedPayload.gd")
const PlayerPositionChangedPayload = preload("res://scripts/domain/signal_payloads/PlayerPositionChangedPayload.gd")
const DamageDealtPayload = preload("res://scripts/domain/signal_payloads/DamageDealtPayload.gd")
const InteractionPromptChangedPayload = preload("res://scripts/domain/signal_payloads/InteractionPromptChangedPayload.gd")
const LootGeneratedPayload = preload("res://scripts/domain/signal_payloads/LootGeneratedPayload.gd")