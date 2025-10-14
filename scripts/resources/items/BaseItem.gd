## BaseItem.gd
## Pure gameplay resource for item procs and stat bonuses.
##
## Architecture Pattern (2025-10-13):
##   - BaseItem = Pure gameplay (procs, stats, cooldowns)
##   - ItemMetadata = UI/catalog (display_name, icon, unlock_cost)
##   - File naming: {item_id}_gameplay.tres + {item_id}_metadata.tres
##
## Property-Based System:
##   - @export properties for proc types (lightning, explosion, freeze)
##   - Runtime cooldown tracking (_lightning_cooldown_remaining, etc.)
##   - Stat bonuses applied via Player.runtime_stats
##
## Usage Example:
##   var item = ItemManager.get_base_item("thunder_mitts")
##   if item.on_hit_lightning and item._lightning_cooldown <= 0:
##       EffectSpawner.spawn_lightning(impact_pos, damage * item.lightning_damage_mult)
##       item._lightning_cooldown = item.lightning_cooldown

extends Resource
class_name BaseItem

# ============================================================================
# CORE IDENTITY (Minimal - most UI data in ItemMetadata)
# ============================================================================

@export_group("Core Identity")

## Unique identifier matching ItemMetadata.item_id
@export var item_id: String = ""

## Internal name for debugging (display_name lives in ItemMetadata)
@export var internal_name: String = ""

# ============================================================================
# STAT BONUSES (Applied to Player.runtime_stats)
# ============================================================================

@export_group("Stat Bonuses")

## Additive max HP bonus (flat addition)
@export var max_hp_bonus: int = 0

## Multiplicative movement speed modifier (1.0 = no change, 1.15 = +15%)
@export var movement_speed_mult: float = 1.0

## Multiplicative damage modifier (1.0 = no change, 1.25 = +25%)
@export var damage_mult: float = 1.0

## Multiplicative pickup radius modifier (1.0 = no change)
@export var pickup_radius_mult: float = 1.0

## Additive critical strike chance bonus (0.05 = +5% crit chance)
@export var crit_chance_bonus: float = 0.0

# ============================================================================
# PROC TYPE 1: LIGHTNING (On-Hit Effect)
# ============================================================================

@export_group("Lightning Proc")

## Enable lightning proc on damage dealt
@export var on_hit_lightning: bool = false

## Lightning proc cooldown in seconds (e.g., 10.0 for Thunder Mitts)
@export var lightning_cooldown: float = 10.0

## Lightning damage multiplier (applied to payload.damage)
## Example: 0.5 = lightning deals 50% of triggering hit's damage
@export var lightning_damage_mult: float = 0.5

## Lightning chain count (0 = single target)
@export var lightning_chain_count: int = 0

## Lightning chain range in pixels
@export var lightning_chain_range: float = 200.0

## Runtime cooldown remaining (managed by ItemManager)
var _lightning_cooldown: float = 0.0

# ============================================================================
# PROC TYPE 2: EXPLOSION (On-Hit Chance)
# ============================================================================

@export_group("Explosion Proc")

## Enable explosion proc on damage dealt
@export var on_hit_explosion: bool = false

## Explosion proc chance (0.0-1.0, e.g., 0.25 = 25% like Spicy Meatball)
@export var explosion_chance: float = 0.25

## Explosion damage multiplier (applied to payload.damage)
## Example: 0.65 = explosion deals 65% of triggering hit's damage
@export var explosion_damage_mult: float = 0.65

## Explosion radius in pixels
@export var explosion_radius: float = 100.0

## Runtime explosion proc counter (for debugging)
var _explosion_procs: int = 0

# ============================================================================
# PROC TYPE 3: FREEZE (On-Hit Chance)
# ============================================================================

@export_group("Freeze Proc")

## Enable freeze proc on damage dealt
@export var on_hit_freeze: bool = false

## Freeze proc chance (0.0-1.0, e.g., 0.075 = 7.5%)
@export var freeze_chance: float = 0.075

## Freeze duration in seconds
@export var freeze_duration: float = 2.0

## Freeze slow multiplier (0.0 = full freeze, 0.5 = 50% speed)
@export var freeze_slow_mult: float = 0.0

## Runtime freeze proc counter (for debugging)
var _freeze_procs: int = 0

# ============================================================================
# PROC TYPE 4: POISON (On-Hit Chance)
# ============================================================================

@export_group("Poison Proc")

## Enable poison proc on damage dealt
@export var on_hit_poison: bool = false

## Poison proc chance (0.0-1.0, e.g., 0.4 = 40% like Cheese)
## Stacks multiplicatively: 1 - (1 - chance)^stacks
## 3 items at 40% = 1 - 0.6^3 = 78.4% chance
@export var poison_chance: float = 0.4

## Poison duration in seconds
@export var poison_duration: float = 3.0

## Poison damage multiplier (% of triggering hit dealt over full duration)
## Example: 0.3 = 30% of hit damage as poison, 0.5 = 50% of hit damage
## Overflow stacking: >100% proc chance converts to damage multiplier
@export var poison_damage_per_tick: float = 0.3

## Runtime poison proc counter (for debugging)
var _poison_procs: int = 0

# ============================================================================
# COOLDOWN MANAGEMENT
# ============================================================================

## Update all item cooldowns (called by ItemManager on combat_step)
func update_cooldowns(delta_time: float) -> void:
	if _lightning_cooldown > 0.0:
		_lightning_cooldown -= delta_time

## Reset all cooldowns (called when item equipped or run starts)
func reset_cooldowns() -> void:
	_lightning_cooldown = 0.0
	_explosion_procs = 0
	_freeze_procs = 0
	_poison_procs = 0

# ============================================================================
# VALIDATION
# ============================================================================

## Validate item configuration
## Returns array of error strings (empty = valid)
func validate() -> Array[String]:
	var errors: Array[String] = []

	# Core identity validation
	if item_id.is_empty():
		errors.append("item_id cannot be empty")

	# Stat bonus validation
	if movement_speed_mult < 0.0:
		errors.append("movement_speed_mult must be >= 0.0")

	if damage_mult < 0.0:
		errors.append("damage_mult must be >= 0.0")

	if pickup_radius_mult < 0.0:
		errors.append("pickup_radius_mult must be >= 0.0")

	if crit_chance_bonus < 0.0 or crit_chance_bonus > 1.0:
		errors.append("crit_chance_bonus must be 0.0-1.0")

	# Lightning validation
	if on_hit_lightning:
		if lightning_cooldown <= 0.0:
			errors.append("lightning_cooldown must be > 0.0 when on_hit_lightning enabled")

		if lightning_damage_mult < 0.0:
			errors.append("lightning_damage_mult must be >= 0.0")

		if lightning_chain_count < 0:
			errors.append("lightning_chain_count must be >= 0")

	# Explosion validation
	if on_hit_explosion:
		if explosion_chance < 0.0 or explosion_chance > 1.0:
			errors.append("explosion_chance must be 0.0-1.0")

		if explosion_damage_mult < 0.0:
			errors.append("explosion_damage_mult must be >= 0.0")

		if explosion_radius <= 0.0:
			errors.append("explosion_radius must be > 0.0")

	# Freeze validation
	if on_hit_freeze:
		if freeze_chance < 0.0 or freeze_chance > 1.0:
			errors.append("freeze_chance must be 0.0-1.0")

		if freeze_duration <= 0.0:
			errors.append("freeze_duration must be > 0.0")

		if freeze_slow_mult < 0.0 or freeze_slow_mult > 1.0:
			errors.append("freeze_slow_mult must be 0.0-1.0")

	# Poison validation
	if on_hit_poison:
		if poison_chance < 0.0 or poison_chance > 1.0:
			errors.append("poison_chance must be 0.0-1.0")

		if poison_duration <= 0.0:
			errors.append("poison_duration must be > 0.0")

		if poison_damage_per_tick < 0.0:
			errors.append("poison_damage_per_tick must be >= 0.0")

	return errors

# ============================================================================
# DEBUGGING
# ============================================================================

## Debug representation
func _to_string() -> String:
	var procs: Array[String] = []
	if on_hit_lightning:
		procs.append("lightning")
	if on_hit_explosion:
		procs.append("explosion")
	if on_hit_freeze:
		procs.append("freeze")
	if on_hit_poison:
		procs.append("poison")

	var procs_str = ", ".join(procs) if not procs.is_empty() else "none"

	return "BaseItem(id=%s, procs=[%s], stats=[hp+%d, speed×%.2f, dmg×%.2f])" % [
		item_id, procs_str, max_hp_bonus, movement_speed_mult, damage_mult
	]
