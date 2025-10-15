## BaseItem.gd
## Unified item resource for gameplay and shop metadata (single source of truth).
##
## Architecture Pattern (2025-10-14):
##   - Single-resource pattern (following BaseTome architecture)
##   - BaseItem = Gameplay (procs, stats, cooldowns) + Shop metadata (UI, unlock)
##   - File naming: {item_id}.tres (no _gameplay/_metadata suffixes)
##
## Property-Based System:
##   - @export properties for proc types (lightning, explosion, freeze, poison)
##   - Runtime cooldown tracking (_lightning_cooldown_remaining, etc.)
##   - Stat bonuses applied via Player.runtime_stats
##   - Shop metadata for UnlockShop integration (unlock_cost, flavor_text, icons)
##
## Usage Example:
##   var item = ItemManager.get_base_item("thunder_mitts")
##   if item.on_hit_lightning and item._lightning_cooldown <= 0:
##       EffectSpawner.spawn_lightning(impact_pos, damage * item.lightning_damage_mult)
##       item._lightning_cooldown = item.lightning_cooldown

extends Resource
class_name BaseItem

# ============================================================================
# CORE IDENTITY
# ============================================================================

@export_group("Core Identity")

## Unique identifier for item (used by ItemManager and UnlockShop)
@export var item_id: String = ""

## Display name shown in UI (was in ItemMetadata, now unified)
@export var display_name: String = ""

## Description text for shop/tooltip
@export_multiline var description: String = ""

## Item icon texture (direct Texture2D reference)
@export var icon: Texture2D = null

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
# SCALING CONFIGURATION (2025-10-15)
# ============================================================================

@export_group("Scaling Configuration")

## Damage multiplier scaling type (default: EXPONENTIAL for backward compatibility)
## - LINEAR: 1.2x, 1.4x, 1.6x, 1.8x (additive stacking)
## - EXPONENTIAL: 1.2x, 1.44x, 1.728x, 2.07x (compound growth, CURRENT DEFAULT)
## - HYPERBOLIC: Approaches cap asymptotically (prevents runaway scaling)
@export var damage_scaling_type: ScalingCalculator.ScalingType = ScalingCalculator.ScalingType.EXPONENTIAL

## Per-stack damage bonus (0.0 = auto-derive from damage_mult - 1.0)
## Example: damage_mult = 1.2, per_stack = 0.2 (20% per stack)
@export var damage_per_stack: float = 0.0

## Maximum damage multiplier at infinite stacks (HYPERBOLIC only)
## Example: cap = 3.0 means damage approaches 3.0x at high stacks
@export var damage_hyperbolic_cap: float = 3.0

## Half-cap point for hyperbolic scaling (HYPERBOLIC only)
## Example: k = 5.0 means at 5 stacks, you reach halfway between 1.0x and cap
@export var damage_hyperbolic_k: float = 5.0

## HP bonus scaling type (default: LINEAR for simple additive stacking)
@export var hp_scaling_type: ScalingCalculator.ScalingType = ScalingCalculator.ScalingType.LINEAR

## Per-stack HP bonus (0 = uses max_hp_bonus directly)
@export var hp_per_stack: int = 0

## HP hyperbolic cap (HYPERBOLIC only)
@export var hp_hyperbolic_cap: float = 500.0

## HP hyperbolic k parameter (HYPERBOLIC only)
@export var hp_hyperbolic_k: float = 5.0

## Movement speed scaling type (default: EXPONENTIAL for compound growth)
@export var speed_scaling_type: ScalingCalculator.ScalingType = ScalingCalculator.ScalingType.EXPONENTIAL

## Per-stack speed bonus (0.0 = auto-derive from movement_speed_mult - 1.0)
@export var speed_per_stack: float = 0.0

## Speed hyperbolic cap (HYPERBOLIC only)
@export var speed_hyperbolic_cap: float = 2.5

## Speed hyperbolic k parameter (HYPERBOLIC only)
@export var speed_hyperbolic_k: float = 5.0

## Pickup radius scaling type (default: EXPONENTIAL)
@export var pickup_radius_scaling_type: ScalingCalculator.ScalingType = ScalingCalculator.ScalingType.EXPONENTIAL

## Per-stack pickup radius bonus (0.0 = auto-derive from pickup_radius_mult - 1.0)
@export var pickup_radius_per_stack: float = 0.0

## Crit chance scaling type (default: LINEAR for simple additive)
@export var crit_scaling_type: ScalingCalculator.ScalingType = ScalingCalculator.ScalingType.LINEAR

## Per-stack crit chance bonus (0.0 = uses crit_chance_bonus directly)
@export var crit_per_stack: float = 0.0

# ============================================================================
# CONDITIONAL DAMAGE (Range-Based Bonuses - 2025-10-16)
# ============================================================================

@export_group("Conditional Damage")

## Enable conditional damage bonus (e.g., "damage to nearby enemies")
@export var conditional_damage_enabled: bool = false

## Damage bonus percentage when condition met (0.2 = 20% bonus damage)
@export var conditional_damage_bonus: float = 0.0

## Range in pixels for conditional damage (416.0 = 13 tiles @ 32px/tile)
@export var conditional_damage_range: float = 0.0

## Per-stack conditional damage bonus (0.0 = uses conditional_damage_bonus directly)
@export var conditional_damage_per_stack: float = 0.0

## Conditional damage scaling type (default: LINEAR for additive stacking)
@export var conditional_damage_scaling_type: ScalingCalculator.ScalingType = ScalingCalculator.ScalingType.LINEAR

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

## Explosion proc chance (0.0-1.0, e.g., 0.25 = 25% like Voodoo Doll)
@export var explosion_chance: float = 0.25

## Explosion damage multiplier (applied to payload.damage)
## Example: 0.65 = explosion deals 65% of triggering hit's damage
@export var explosion_damage_mult: float = 0.65

## Explosion radius in pixels
@export var explosion_radius: float = 100.0

## Explosion scene to spawn (allows custom explosion visuals per item)
## Default: null = use PoisonExplosion.tscn
## Examples: VoodooDollExplosion.tscn (dark purple), FrostExplosion.tscn (blue)
@export var explosion_scene: PackedScene = null

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
# SHOP METADATA (UnlockShop Integration)
# ============================================================================

@export_group("Shop Metadata")

## Rift Fragments cost to unlock in shop
@export var unlock_cost: int = 100

## Achievement requirement text for discovery (e.g., "Deal 1,000 damage")
@export_multiline var discovery_requirement: String = ""

## Stat summary for shop display (e.g., "+20 HP", "25% Explosion Chance")
@export var stat_summary: String = ""

## Flavor text for lore/immersion
@export_multiline var flavor_text: String = ""

## Item rarity (common, uncommon, rare, epic, legendary)
@export var rarity: String = "common"

# ============================================================================
# COMPATIBILITY ALIASES (UnlockShop Integration)
# ============================================================================

## Compatibility property for UnlockShop (returns "items")
var category: String:
	get:
		return "items"

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

	if display_name.is_empty():
		errors.append("display_name cannot be empty")

	# Shop metadata validation (warnings only)
	if unlock_cost <= 0:
		errors.append("unlock_cost should be > 0 for shop items")

	if stat_summary.is_empty():
		errors.append("stat_summary recommended for shop display")

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
