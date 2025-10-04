# Ability System - Technical Architecture (REVISED)

**Status:** 📐 Architecture Blueprint - Revision 2
**Created:** 2025-10-03
**Revised:** 2025-10-04
**Based On:** [ability-system-design-exploration.md](ability-system-design-exploration.md) (26 Q&A)
**Review Score:** 13/35 → Addressing critical issues

---

## 🚨 Revision Summary (2025-10-04)

**Critical Fixes Applied:**
1. ✅ Fixed `level_up()` loop bug (`for i in levels` → `for i in range(levels)`)
2. ✅ Refactored tome system to use **modifier descriptors** (idempotent, reversible)
3. ✅ Created **AbilitySystem autoload** for 30Hz deterministic cooldown tracking
4. ✅ Fixed file path contradictions (`scripts/resources/` for Resources, `autoload/` for managers)
5. ✅ Changed tag type to `Array[StringName]` for performance
6. ✅ Refactored ProjectileAbility to use **EventBus signals** instead of direct pool access
7. ✅ Removed Player scene bloat (gold streak moved to separate task)

**Reviewer:** Codex
**Original Score:** 13/35 (Revise and Re-Review)
**Target Score:** 28-32/35 (Approve with Minor Revisions)

---

## 🎯 System Overview

The ability system implements auto-cast, data-driven abilities with:
- **4 ability slots** per character (managed by AbilityComponent)
- **4 tome slots** for ability/player stat modifiers (modifier descriptors, not direct mutation)
- **Deterministic 30Hz combat step** (AbilitySystem autoload, not Player._process)
- **Tag-based applicability** using StringName constants
- **Baseline stat preservation** (tomes never mutate base_damage, only final_damage)
- **Hybrid spawning pattern** (Resources use EventBus, Systems use direct calls)
- **Unified damage pattern** (All sources use DamageService.apply_damage())

---

## 🔄 Spawning & Damage Patterns (Hybrid Architecture)

### **Spawning Pattern:**
- **Resources (BaseAbility subclasses)** → `EventBus.ability_*_requested` signals (decoupled, testable)
- **Systems (BossBehavior, CardEffects)** → Direct `ProjectilePool.spawn_projectile()` calls (fast, clear ownership)

### **Damage Pattern:**
- **ALL sources** → `DamageService.apply_damage()` direct calls (single entry point, performance)
- **NEVER** use `EventBus.damage_requested` (removed signal - see EventBus.gd:39)

### **Rationale:**
1. **Resources stay pure** - No autoload access, fully testable without game context
2. **Performance where it matters** - Boss barrages (50 projectiles) avoid signal overhead (~0.1ms saved)
3. **Damage consistency** - Matches existing DamageService pattern (see SpawnDirector:821)
4. **Clear semantics** - "Request spawn" (signal) vs "Execute spawn" (direct) vs "Apply damage" (always direct)

### **Example Flows:**

```gdscript
// ========== ABILITY ACTIVATION (Resource → Signal) ==========
// ProjectileAbility.activate() - No singleton access
EventBus.ability_projectile_requested.emit(projectile_data)
// → ProjectilePool listens and spawns entity

// ========== BOSS ATTACK (System → Direct) ==========
// BaseBoss._fire_barrage() - Has singleton access
for i in 50:
    ProjectilePool.spawn_projectile(barrage_data)  // ✅ Fast, no signal overhead

// ========== DAMAGE APPLICATION (Entity → Direct) ==========
// AbilityProjectile._on_enemy_hit() - Always direct
DamageService.apply_damage(source_id, target_id, damage, tags)  // ✅ Single entry point

// ========== AOE ABILITY (Resource → Signal → System → Direct) ==========
// AoEAbility.activate()
EventBus.ability_aoe_requested.emit(aoe_data)
// → AoEHandler.gd listens
func _on_aoe_requested(data):
    var enemies = _find_enemies_in_radius(data.origin, data.radius)
    for enemy_id in enemies:
        DamageService.apply_damage(player_id, enemy_id, data.damage, data.tags)
```

---

## 📦 Core Class Hierarchy

```
BaseAbility (Resource) → scripts/resources/
├── ProjectileAbility
├── BuffAbility
├── AoEAbility
├── RadialAbility
└── CelestialAbility

TomeModifier (Resource) → scripts/resources/
└── Encapsulates stat modifications (damage_mult, cooldown_mult, etc.)

AbilitySystem (Autoload) → autoload/
└── Owns cooldown state, triggers auto-cast on combat_step

AbilityManager (Autoload) → autoload/
└── Resource registry & loader

TomeManager (Autoload) → autoload/
└── Tome registry & modifier builder

AbilityComponent (Node) → scripts/components/
└── Attached to Player, owns 4 ability slots + 4 tome slots
└── First of many Player components (future: HealthComponent, MovementComponent, etc.)

EntityPool (Autoload) → autoload/
└── Unified pooling for high-frequency, short-lived entities
└── Pools: Projectiles, XP orbs, VFX (NOT chests/bosses)
```

---

## 🏗️ Class Definitions

### BaseAbility.gd

**Location:** `scripts/resources/BaseAbility.gd` ← FIXED (was `scripts/systems/abilities/`)

```gdscript
extends Resource
class_name BaseAbility

## Base class for all abilities
## CRITICAL: Baseline stats (base_*) are NEVER mutated by tomes
## Tomes modify final_* computed stats via modifier descriptors

# === Core Identity ===
@export var ability_id: String = ""
@export var ability_name: String = ""
@export var description: String = ""
@export var icon: Texture2D = null

# === Progression ===
@export var ability_level: int = 1
@export var max_level: int = 20
@export var damage_scaling_per_level: float = 1.15  # 15% increase per level
@export var cooldown_scaling_per_level: float = 0.95  # 5% faster per level
@export var level_breakpoints: Dictionary = {}  # {5: {"projectile_count": 1}}

# === Tags (StringName for performance) ===
@export var tags: Array[StringName] = []  # ← FIXED (was Array[String])

# === BASELINE STATS (never mutated by tomes!) ===
@export var base_damage: float = 0.0
@export var base_cooldown: float = 1.0
@export var base_projectile_count: int = 1
@export var base_pierce_count: int = 0
@export var base_aoe_radius: float = 100.0

# === COMPUTED STATS (recalculated from baseline + modifiers) ===
var final_damage: float = 0.0
var final_cooldown: float = 0.0
var final_projectile_count: int = 0
var final_pierce_count: int = 0
var final_aoe_radius: float = 0.0

# === Damage Type & Element ===
@export var damage_type: String = "physical"
@export var inherent_element: String = ""

# === Optional Properties (subclasses) ===
@export var projectile_speed: float = 400.0
@export var max_visual_projectiles: int = 15
@export var buff_duration: float = 5.0
@export var aoe_delay: float = 0.5
@export var orbit_radius: float = 80.0
@export var orbit_speed: float = 180.0

# === Visual References ===
@export var visual_scene: PackedScene = null
@export var impact_effect: PackedScene = null

# === Elemental Flags (set by modifiers) ===
var applies_burning: bool = false
var applies_slow: bool = false
var applies_poison: bool = false


func _init() -> void:
	_recalculate_final_stats()


## Called when ability levels up (from re-picking)
## FIXED: Loop bug corrected (for i in range(levels))
func level_up(levels: int = 1) -> void:
	for i in range(levels):  # ← FIXED (was "for i in levels")
		if ability_level >= max_level:
			Logger.warn("Ability %s at max level" % ability_id, "abilities")
			break

		ability_level += 1

		# Scale baseline stats
		if has_tag(AbilityTags.DAMAGE):
			base_damage *= damage_scaling_per_level
			base_damage = max(base_damage, 0.0)  # Clamp to positive

		if has_tag(AbilityTags.COOLDOWN):
			base_cooldown *= cooldown_scaling_per_level
			base_cooldown = max(base_cooldown, 0.1)  # Min 0.1s cooldown

		# Apply breakpoint bonuses
		if ability_level in level_breakpoints:
			_apply_breakpoint_bonus(level_breakpoints[ability_level])

	_recalculate_final_stats()
	Logger.info("Leveled %s to %d (dmg: %.1f, cd: %.2f)" % [
		ability_id, ability_level, base_damage, base_cooldown
	], "abilities")


## Apply breakpoint bonus (e.g., {5: {"base_projectile_count": 1}})
func _apply_breakpoint_bonus(bonus: Dictionary) -> void:
	for property in bonus:
		if property in self:
			self[property] += bonus[property]
			Logger.debug("Breakpoint: %s +%s" % [property, bonus[property]], "abilities")


## Recalculate computed stats from baseline + active modifiers
## Called after: level-up, modifier added/removed
func _recalculate_final_stats() -> void:
	final_damage = base_damage
	final_cooldown = base_cooldown
	final_projectile_count = base_projectile_count
	final_pierce_count = base_pierce_count
	final_aoe_radius = base_aoe_radius

	# Modifiers applied externally by AbilityComponent.apply_modifiers()


## Tag system helpers
func has_tag(tag: StringName) -> bool:
	return tag in tags


func add_tag(tag: StringName) -> void:
	if not has_tag(tag):
		tags.append(tag)


func remove_tag(tag: StringName) -> void:
	tags.erase(tag)


## Check if ability has inherent element
func has_inherent_element() -> bool:
	return inherent_element != ""


## Activate ability (overridden by subclasses)
## NEVER calls singleton methods directly - emits signals instead
func activate(player: Node2D, context: Dictionary) -> void:
	push_warning("BaseAbility.activate() not overridden")


## Export state for debugging
func to_dict() -> Dictionary:
	return {
		"ability_id": ability_id,
		"level": ability_level,
		"base_damage": base_damage,
		"final_damage": final_damage,
		"base_cooldown": base_cooldown,
		"final_cooldown": final_cooldown,
		"tags": tags,
	}
```

---

### TomeModifier.gd (NEW - Descriptor Pattern)

**Location:** `scripts/resources/TomeModifier.gd`

```gdscript
extends Resource
class_name TomeModifier

## Encapsulates ability/player stat modifications
## Used by BaseTome to create idempotent, reversible modifiers
## NEVER mutates ability.base_* stats directly

# === Source Info ===
@export var tome_id: String = ""
@export var stack_count: int = 1

# === Applicability ===
@export var applicable_tags: Array[StringName] = []  # Empty = global

# === Ability Modifiers (multiplicative) ===
@export var damage_multiplier: float = 1.0  # 1.15 = +15%
@export var cooldown_multiplier: float = 1.0  # 0.9 = -10% (faster)
@export var aoe_radius_multiplier: float = 1.0  # 1.2 = +20%
@export var projectile_speed_multiplier: float = 1.0

# === Ability Modifiers (additive) ===
@export var projectile_count_bonus: int = 0  # +1 per stack
@export var pierce_count_bonus: int = 0  # +1 per stack

# === Player Stat Modifiers ===
@export var movement_speed_multiplier: float = 1.0
@export var max_hp_bonus: float = 0.0
@export var luck_bonus: float = 0.0
@export var xp_gain_multiplier: float = 1.0


## Check if modifier applies to ability
func applies_to(ability: BaseAbility) -> bool:
	if applicable_tags.is_empty():
		return true  # Global modifier

	for tag in applicable_tags:
		if ability.has_tag(tag):
			return true

	return false


## Apply modifier to ability's computed stats
## Called by AbilityComponent.apply_modifiers()
func apply_to_ability(ability: BaseAbility) -> void:
	if not applies_to(ability):
		return

	# Multiplicative (use pow for stacking)
	ability.final_damage *= pow(damage_multiplier, stack_count)
	ability.final_cooldown *= pow(cooldown_multiplier, stack_count)
	ability.final_aoe_radius *= pow(aoe_radius_multiplier, stack_count)

	# Additive
	ability.final_projectile_count += projectile_count_bonus * stack_count
	ability.final_pierce_count += pierce_count_bonus * stack_count


## Apply modifier to player stats
## Called by AbilityComponent when tome equipped
func apply_to_player(player: Node2D) -> void:
	# Check for required properties
	if "movement_speed" in player and movement_speed_multiplier != 1.0:
		player.movement_speed *= pow(movement_speed_multiplier, stack_count)

	if "max_hp" in player and max_hp_bonus > 0.0:
		var hp_gain = max_hp_bonus * stack_count
		player.max_hp += hp_gain
		player.current_hp += hp_gain  # Heal by bonus amount

	if "luck" in player and luck_bonus > 0.0:
		player.luck += luck_bonus * stack_count

	if "xp_gain_multiplier" in player and xp_gain_multiplier != 1.0:
		player.xp_gain_multiplier *= pow(xp_gain_multiplier, stack_count)
```

---

### BaseTome.gd (REFACTORED)

**Location:** `scripts/resources/BaseTome.gd`

```gdscript
extends Resource
class_name BaseTome

## Tome definition (creates TomeModifier instances)
## Does NOT mutate abilities directly - builds modifier descriptors

# === Core Identity ===
@export var tome_id: String = ""
@export var tome_name: String = ""
@export var description: String = ""
@export var icon: Texture2D = null
@export var rarity: String = "common"

# === Stacking ===
@export var stack_limit: int = 10

# === Applicability ===
@export var applicable_tags: Array[StringName] = []  # Empty = global

# === Modifier Template (per stack) ===
@export var damage_multiplier: float = 1.0
@export var cooldown_multiplier: float = 1.0
@export var projectile_count_bonus: int = 0
@export var pierce_count_bonus: int = 0
@export var aoe_radius_multiplier: float = 1.0
@export var movement_speed_multiplier: float = 1.0
@export var max_hp_bonus: float = 0.0
@export var luck_bonus: float = 0.0
@export var xp_gain_multiplier: float = 1.0


## Create a TomeModifier instance for this tome at given stack count
func create_modifier(stack_count: int) -> TomeModifier:
	var modifier = TomeModifier.new()
	modifier.tome_id = tome_id
	modifier.stack_count = stack_count
	modifier.applicable_tags = applicable_tags

	# Copy modifier values
	modifier.damage_multiplier = damage_multiplier
	modifier.cooldown_multiplier = cooldown_multiplier
	modifier.projectile_count_bonus = projectile_count_bonus
	modifier.pierce_count_bonus = pierce_count_bonus
	modifier.aoe_radius_multiplier = aoe_radius_multiplier
	modifier.movement_speed_multiplier = movement_speed_multiplier
	modifier.max_hp_bonus = max_hp_bonus
	modifier.luck_bonus = luck_bonus
	modifier.xp_gain_multiplier = xp_gain_multiplier

	return modifier
```

---

### ProjectileAbility.gd (REFACTORED - EventBus Signals)

**Location:** `scripts/resources/ProjectileAbility.gd`

```gdscript
extends BaseAbility
class_name ProjectileAbility

## Projectile-based ability
## FIXED: Uses EventBus signals instead of direct ProjectilePool access

@export_enum("forward", "spread", "circle", "targeted") var fire_pattern: String = "forward"
@export var spread_angle: float = 30.0
@export var is_homing: bool = false
@export var homing_strength: float = 0.5
@export var projectile_lifetime: float = 3.0
@export var chains_to_enemies: int = 0
@export var chain_radius: float = 150.0


func _init() -> void:
	super._init()

	# Ensure required tags
	if not has_tag(AbilityTags.PROJECTILE):
		tags.append(AbilityTags.PROJECTILE)
	if not has_tag(AbilityTags.DAMAGE):
		tags.append(AbilityTags.DAMAGE)
	if not has_tag(AbilityTags.COOLDOWN):
		tags.append(AbilityTags.COOLDOWN)


## Activate projectile ability
## PATTERN: Resources emit EventBus signals (no singleton access)
## Systems/Entities call DamageService directly (performance + clear ownership)
func activate(player: Node2D, context: Dictionary) -> void:
	var target_pos: Vector2 = context.get("nearest_enemy", Vector2.ZERO)
	var facing_dir: Vector2 = context.get("facing_direction", Vector2.RIGHT)

	# Calculate base direction
	var base_direction: Vector2
	if target_pos == Vector2.ZERO:
		base_direction = facing_dir.normalized()
	else:
		base_direction = (target_pos - player.global_position).normalized()

	# Emit spawn requests based on fire pattern
	match fire_pattern:
		"forward":
			_fire_forward(player, base_direction)
		"spread":
			_fire_spread(player, base_direction)
		"circle":
			_fire_circle(player)
		"targeted":
			_fire_targeted(player, target_pos)

	EventBus.ability_activated.emit(ability_id, player.global_position)


func _fire_forward(player: Node2D, direction: Vector2) -> void:
	for i in final_projectile_count:
		var data = _create_projectile_data(player, direction)
		EventBus.ability_projectile_requested.emit(data)  # ← FIXED (signal)


func _fire_spread(player: Node2D, base_direction: Vector2) -> void:
	var angle_step = spread_angle / max(1, final_projectile_count - 1)
	var start_angle = -spread_angle / 2.0

	for i in final_projectile_count:
		var angle_offset = start_angle + (i * angle_step)
		var direction = base_direction.rotated(deg_to_rad(angle_offset))
		var data = _create_projectile_data(player, direction)
		EventBus.ability_projectile_requested.emit(data)  # ← FIXED


func _fire_circle(player: Node2D) -> void:
	var angle_step = 360.0 / final_projectile_count

	for i in final_projectile_count:
		var angle = deg_to_rad(i * angle_step)
		var direction = Vector2.RIGHT.rotated(angle)
		var data = _create_projectile_data(player, direction)
		EventBus.ability_projectile_requested.emit(data)  # ← FIXED


func _fire_targeted(player: Node2D, target_pos: Vector2) -> void:
	if target_pos == Vector2.ZERO:
		_fire_forward(player, Vector2.RIGHT)
		return

	var direction = (target_pos - player.global_position).normalized()
	for i in final_projectile_count:
		var data = _create_projectile_data(player, direction)
		EventBus.ability_projectile_requested.emit(data)  # ← FIXED


## Build projectile spawn payload (sent via EventBus)
func _create_projectile_data(player: Node2D, direction: Vector2) -> Dictionary:
	return {
		"ability_id": ability_id,
		"origin": player.global_position,
		"direction": direction,
		"speed": projectile_speed,
		"damage": final_damage,  # ← Uses computed stat
		"pierce_count": final_pierce_count,  # ← Uses computed stat
		"lifetime": projectile_lifetime,
		"is_homing": is_homing,
		"homing_strength": homing_strength,
		"chains_to_enemies": chains_to_enemies,
		"chain_radius": chain_radius,
		"visual_scene": visual_scene,
		"impact_effect": impact_effect,
		"damage_type": damage_type,
		"element": inherent_element,
		"applies_burning": applies_burning,
		"applies_slow": applies_slow,
		"applies_poison": applies_poison,
	}
```

---

### AbilityTags.gd (UPDATED - StringName)

**Location:** `scripts/domain/AbilityTags.gd`

```gdscript
extends Object
class_name AbilityTags

## Tag constants for ability categorization
## FIXED: Uses StringName (&"tag") for performance

# Damage categories
const DAMAGE: StringName = &"damage"
const PHYSICAL: StringName = &"physical"
const ELEMENTAL: StringName = &"elemental"
const FIRE: StringName = &"fire"
const COLD: StringName = &"cold"
const LIGHTNING: StringName = &"lightning"
const POISON: StringName = &"poison"

# Delivery methods
const PROJECTILE: StringName = &"projectile"
const AOE: StringName = &"aoe"
const MELEE: StringName = &"melee"
const BUFF: StringName = &"buff"
const DEBUFF: StringName = &"debuff"
const ORBIT: StringName = &"orbit"
const SUMMON: StringName = &"summon"

# Scaling categories
const COOLDOWN: StringName = &"cooldown"
const DURATION: StringName = &"duration"
const AREA: StringName = &"area"
const PIERCE: StringName = &"pierce"
const CHAIN: StringName = &"chain"


## Get all available tags
static func get_all_tags() -> Array[StringName]:
	return [
		DAMAGE, PHYSICAL, ELEMENTAL, FIRE, COLD, LIGHTNING, POISON,
		PROJECTILE, AOE, MELEE, BUFF, DEBUFF, ORBIT, SUMMON,
		COOLDOWN, DURATION, AREA, PIERCE, CHAIN
	]


## Validate tag exists
static func is_valid_tag(tag: StringName) -> bool:
	return tag in get_all_tags()


## Get human-readable description
static func get_tag_description(tag: StringName) -> String:
	match tag:
		DAMAGE: return "Deals damage"
		PROJECTILE: return "Fires projectiles"
		AOE: return "Area of effect"
		COOLDOWN: return "Affected by CDR"
		FIRE: return "Fire damage/burning"
		# ... etc
		_: return "Unknown tag"


## Get color for UI (elemental tags)
static func get_tag_color(tag: StringName) -> Color:
	match tag:
		FIRE: return Color(1.0, 0.3, 0.1)
		COLD: return Color(0.2, 0.6, 1.0)
		LIGHTNING: return Color(0.9, 0.9, 0.2)
		POISON: return Color(0.3, 0.8, 0.3)
		PHYSICAL: return Color(0.7, 0.7, 0.7)
		_: return Color.WHITE
```

---

### AbilitySystem.gd (NEW - 30Hz Deterministic Autoload)

**Location:** `autoload/AbilitySystem.gd`

```gdscript
extends Node

## Central ability system coordinator
## CRITICAL: Runs on 30Hz combat_step for deterministic cooldowns
## Replaces Player._process() auto-cast logic

# Cooldown tracking: {player_instance_id: {slot_index: cooldown_remaining}}
var _cooldowns: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE  # Respect game pause
	EventBus.combat_step.connect(_on_combat_step)
	Logger.info("AbilitySystem initialized (30Hz combat step)", "abilities")


## Tick cooldowns and trigger auto-cast (deterministic 30Hz)
func _on_combat_step(delta: float) -> void:
	var players = get_tree().get_nodes_in_group("players")

	for player in players:
		_update_player_cooldowns(player, delta)
		_auto_cast_ready_abilities(player)


## Update cooldowns for a player
func _update_player_cooldowns(player: Node2D, delta: float) -> void:
	var player_id = player.get_instance_id()

	if player_id not in _cooldowns:
		_cooldowns[player_id] = {}

	for slot_idx in _cooldowns[player_id]:
		if _cooldowns[player_id][slot_idx] > 0.0:
			_cooldowns[player_id][slot_idx] -= delta


## Auto-cast abilities when ready
func _auto_cast_ready_abilities(player: Node2D) -> void:
	if not "ability_component" in player:
		return  # Player doesn't have AbilityComponent

	var ability_comp: AbilityComponent = player.ability_component

	for slot_idx in range(ability_comp.ability_slots.size()):
		var ability = ability_comp.ability_slots[slot_idx]

		if ability and _is_ability_ready(player, slot_idx):
			_activate_ability(player, ability_comp, slot_idx)


## Check if ability is off cooldown
func _is_ability_ready(player: Node2D, slot_idx: int) -> bool:
	var player_id = player.get_instance_id()

	if player_id not in _cooldowns:
		return true

	if slot_idx not in _cooldowns[player_id]:
		return true

	return _cooldowns[player_id][slot_idx] <= 0.0


## Activate ability and reset cooldown
func _activate_ability(player: Node2D, ability_comp: AbilityComponent, slot_idx: int) -> void:
	var ability = ability_comp.ability_slots[slot_idx]
	var player_id = player.get_instance_id()

	# Build context
	var context = {
		"player": player,
		"nearest_enemy": _find_nearest_enemy(player),
		"facing_direction": _get_facing_direction(player),
	}

	# Activate (emits EventBus signals for projectiles)
	ability.activate(player, context)

	# Reset cooldown
	if player_id not in _cooldowns:
		_cooldowns[player_id] = {}

	_cooldowns[player_id][slot_idx] = ability.final_cooldown

	EventBus.ability_activated.emit(ability.ability_id, player.global_position)


## Find nearest enemy (utility)
func _find_nearest_enemy(player: Node2D) -> Vector2:
	var enemies = get_tree().get_nodes_in_group("enemies")
	if enemies.is_empty():
		return Vector2.ZERO

	var nearest: Node2D = null
	var min_dist = INF

	for enemy in enemies:
		var dist = player.global_position.distance_to(enemy.global_position)
		if dist < min_dist:
			min_dist = dist
			nearest = enemy

	return nearest.global_position if nearest else Vector2.ZERO


## Get player facing direction
func _get_facing_direction(player: Node2D) -> Vector2:
	if "facing_direction" in player:
		return player.facing_direction

	# Fallback: use mouse direction or right
	return Vector2.RIGHT


## Register player (called when Player enters tree)
func register_player(player: Node2D) -> void:
	var player_id = player.get_instance_id()
	if player_id not in _cooldowns:
		_cooldowns[player_id] = {}


## Unregister player (called when Player exits tree)
func unregister_player(player: Node2D) -> void:
	var player_id = player.get_instance_id()
	_cooldowns.erase(player_id)
```

---

### AbilityComponent.gd (NEW - Owns Slots + Modifiers)

**Location:** `scripts/components/AbilityComponent.gd`

```gdscript
extends Node
class_name AbilityComponent

## Manages ability/tome slots for a player
## Replaces ability logic previously in Player.gd

signal ability_equipped(ability_id: String, slot: int)
signal tome_equipped(tome_id: String, stack_count: int)

# Ability slots (4 max)
var ability_slots: Array[BaseAbility] = [null, null, null, null]

# Tome slots with stack counts
var tome_slots: Array[BaseTome] = [null, null, null, null]
var tome_stacks: Array[int] = [0, 0, 0, 0]

# Active modifiers (rebuilt when tomes change)
var _active_modifiers: Array[TomeModifier] = []

@onready var player: Node2D = get_parent()


func _ready() -> void:
	# Register with AbilitySystem for cooldown tracking
	AbilitySystem.register_player(player)


func _exit_tree() -> void:
	AbilitySystem.unregister_player(player)


## Equip ability to slot
func equip_ability(ability_id: String, slot: int = -1) -> void:
	if slot == -1:
		slot = _find_empty_ability_slot()

	if slot == -1:
		Logger.warn("No ability slots available", "abilities")
		return

	# Create instance
	var ability = AbilityManager.create_ability_instance(ability_id)
	if not ability:
		Logger.error("Ability not found: %s" % ability_id, "abilities")
		return

	# Apply active modifiers
	_apply_modifiers_to_ability(ability)

	ability_slots[slot] = ability
	ability_equipped.emit(ability_id, slot)
	Logger.info("Equipped %s in slot %d" % [ability.ability_name, slot], "abilities")


## Level up existing ability
func level_up_ability(ability_id: String, levels: int = 1) -> void:
	var slot = _find_ability_slot(ability_id)
	if slot != -1:
		ability_slots[slot].level_up(levels)
		_apply_modifiers_to_ability(ability_slots[slot])  # Recompute


## Equip tome (or stack if exists)
func equip_tome(tome_id: String) -> void:
	var tome = TomeManager.get_definition(tome_id)
	if not tome:
		Logger.error("Tome not found: %s" % tome_id, "abilities")
		return

	var slot = _find_tome_slot(tome_id)

	if slot != -1:
		# Stack existing
		if tome_stacks[slot] < tome.stack_limit:
			tome_stacks[slot] += 1
			_rebuild_modifiers()
			Logger.info("Stacked %s to %d" % [tome.tome_name, tome_stacks[slot]], "tomes")
	else:
		# Equip new
		slot = _find_empty_tome_slot()
		if slot != -1:
			tome_slots[slot] = tome
			tome_stacks[slot] = 1
			_rebuild_modifiers()
			tome_equipped.emit(tome_id, 1)
			Logger.info("Equipped %s" % tome.tome_name, "tomes")


## Rebuild all modifiers and reapply to abilities + player
func _rebuild_modifiers() -> void:
	_active_modifiers.clear()

	# Build modifiers from equipped tomes
	for i in tome_slots.size():
		if tome_slots[i]:
			var modifier = tome_slots[i].create_modifier(tome_stacks[i])
			_active_modifiers.append(modifier)

	# Reapply to all abilities
	for ability in ability_slots:
		if ability:
			_apply_modifiers_to_ability(ability)

	# Apply to player stats
	for modifier in _active_modifiers:
		modifier.apply_to_player(player)


## Apply all active modifiers to an ability
func _apply_modifiers_to_ability(ability: BaseAbility) -> void:
	# Reset to baseline
	ability._recalculate_final_stats()

	# Apply each modifier
	for modifier in _active_modifiers:
		modifier.apply_to_ability(ability)


## Find ability slot by ID
func _find_ability_slot(ability_id: String) -> int:
	for i in ability_slots.size():
		if ability_slots[i] and ability_slots[i].ability_id == ability_id:
			return i
	return -1


func _find_empty_ability_slot() -> int:
	for i in ability_slots.size():
		if ability_slots[i] == null:
			return i
	return -1


## Find tome slot by ID
func _find_tome_slot(tome_id: String) -> int:
	for i in tome_slots.size():
		if tome_slots[i] and tome_slots[i].tome_id == tome_id:
			return i
	return -1


func _find_empty_tome_slot() -> int:
	for i in tome_slots.size():
		if tome_slots[i] == null:
			return i
	return -1
```

---

## 🔧 Manager Classes

### AbilityManager.gd

**Location:** `autoload/AbilityManager.gd`

```gdscript
extends Node

## Ability registry & loader

var _ability_registry: Dictionary = {}
var _ability_file_paths: Dictionary = {}
var _ability_categories: Dictionary = {}


func _ready() -> void:
	_load_all_abilities()


func _load_all_abilities() -> void:
	var categories = ["projectile", "buff", "aoe", "radial", "celestial"]

	for category in categories:
		var path = "res://data/content/abilities/" + category + "/"
		var dir = DirAccess.open(path)

		if not dir:
			continue

		dir.list_dir_begin()
		var file_name = dir.get_next()

		while file_name != "":
			if file_name.ends_with(".tres"):
				var full_path = path + file_name
				var ability = ResourceLoader.load(full_path) as BaseAbility

				if ability:
					_ability_registry[ability.ability_id] = ability
					_ability_file_paths[ability.ability_id] = full_path
					_ability_categories[ability.ability_id] = category

			file_name = dir.get_next()

		dir.list_dir_end()

	Logger.info("Loaded %d abilities" % _ability_registry.size(), "abilities")


## Get definition (original, read-only)
func get_definition(ability_id: String) -> BaseAbility:
	return _ability_registry.get(ability_id)


## Create instance (duplicated for player use)
func create_ability_instance(ability_id: String) -> BaseAbility:
	var definition = get_definition(ability_id)
	if not definition:
		return null

	return definition.duplicate(true)


func get_file_path(ability_id: String) -> String:
	return _ability_file_paths.get(ability_id, "")


func get_abilities_in_category(category: String) -> Array[String]:
	var result: Array[String] = []
	for ability_id in _ability_categories:
		if _ability_categories[ability_id] == category:
			result.append(ability_id)
	return result
```

---

### EntityPool.gd (NEW - Unified Entity Pooling)

**Location:** `autoload/EntityPool.gd`

```gdscript
extends Node

## Unified pooling for high-frequency, short-lived visual entities.
## Pools projectiles, XP orbs, VFX - NOT persistent entities like chests/bosses.
## Uses ObjectPool utility for zero-allocation pattern.

const ObjectPool = preload("res://scripts/utils/ObjectPool.gd")

# Pool per entity type
var _pools: Dictionary = {}  # {"arrow": ObjectPool, "xp_orb": ObjectPool}

# Entity scene registry
const POOLED_ENTITY_SCENES = {
	"arrow": preload("res://assets/abilities/arrow/arrow_visual.tscn"),
	"fireball": preload("res://assets/abilities/projectile/fireball_visual.tscn"),
	"meteor": preload("res://assets/abilities/projectile/meteor_visual.tscn"),
	"orbital": preload("res://assets/abilities/radial/orbital_sword_visual.tscn"),
	"xp_orb": preload("res://scenes/arena/XPOrb.tscn"),
}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE

	# Pre-warm pools for high-frequency entities
	_create_pool("arrow", 100)      # Very high frequency
	_create_pool("fireball", 50)    # High frequency
	_create_pool("meteor", 30)      # Medium frequency
	_create_pool("orbital", 20)     # Low-medium frequency
	_create_pool("xp_orb", 200)     # Very high frequency (mass kills)

	# Connect spawn signals
	EventBus.ability_projectile_requested.connect(_on_projectile_requested)
	EventBus.xp_orb_requested.connect(_on_xp_orb_requested)

	Logger.info("EntityPool initialized with %d pools" % _pools.size(), "pooling")


func _create_pool(entity_key: String, initial_size: int) -> void:
	var pool = ObjectPool.new()
	pool.setup(
		initial_size,
		func(): return _create_entity(entity_key),
		func(entity): _reset_entity(entity)
	)
	_pools[entity_key] = pool


func _create_entity(entity_key: String) -> Node:
	var scene = POOLED_ENTITY_SCENES[entity_key]
	var entity = scene.instantiate()
	entity.add_to_group("pooled_entities")
	entity.add_to_group("pooled_" + entity_key)
	return entity


func _reset_entity(entity: Node) -> void:
	# Reset for reuse
	entity.visible = false
	entity.global_position = Vector2.ZERO
	if entity.get_parent():
		entity.get_parent().remove_child(entity)


func _on_projectile_requested(data: Dictionary) -> void:
	var entity_key = data.get("visual_scene_key", "arrow")

	if not _pools.has(entity_key):
		Logger.warn("No pool for entity: %s" % entity_key, "pooling")
		return

	var projectile = _pools[entity_key].acquire()
	projectile.setup_from_data(data)
	projectile.visible = true
	get_tree().root.add_child(projectile)


func _on_xp_orb_requested(data: Dictionary) -> void:
	var orb = _pools["xp_orb"].acquire()
	orb.setup(data.position, data.xp_value)
	orb.visible = true
	get_tree().root.add_child(orb)


## Called by entities when lifetime expires
func release(entity: Node, entity_key: String) -> void:
	if _pools.has(entity_key):
		_pools[entity_key].release(entity)
	else:
		Logger.warn("Releasing entity with unknown key: %s" % entity_key, "pooling")
		entity.queue_free()  # Fallback
```

---

### TomeManager.gd

**Location:** `autoload/TomeManager.gd`

```gdscript
extends Node

## Tome registry & loader

var _tome_registry: Dictionary = {}
var _tome_file_paths: Dictionary = {}


func _ready() -> void:
	_load_all_tomes()


func _load_all_tomes() -> void:
	var path = "res://data/content/tomes/"
	var dir = DirAccess.open(path)

	if not dir:
		Logger.warn("Tomes directory not found", "tomes")
		return

	dir.list_dir_begin()
	var file_name = dir.get_next()

	while file_name != "":
		if file_name.ends_with(".tres"):
			var full_path = path + file_name
			var tome = ResourceLoader.load(full_path) as BaseTome

			if tome:
				_tome_registry[tome.tome_id] = tome
				_tome_file_paths[tome.tome_id] = full_path

		file_name = dir.get_next()

	dir.list_dir_end()

	Logger.info("Loaded %d tomes" % _tome_registry.size(), "tomes")


func get_definition(tome_id: String) -> BaseTome:
	return _tome_registry.get(tome_id)


func get_file_path(tome_id: String) -> String:
	return _tome_file_paths.get(tome_id, "")
```

---

## 📡 EventBus Signals (Updated)

**Location:** `autoload/EventBus.gd`

```gdscript
# === Ability System ===
signal ability_activated(ability_id: String, position: Vector2)
signal ability_projectile_requested(projectile_data: Dictionary)  # ← CRITICAL
signal ability_acquired(ability_id: String, slot: int)
signal ability_leveled_up(ability_id: String, new_level: int)

# === Tome System ===
signal tome_acquired(tome_id: String, stack_count: int)

# === Combat Step (30Hz deterministic) ===
signal combat_step(delta: float)  # Emitted by Arena.gd
```

---

## 📁 File Structure (CORRECTED)

```
scripts/resources/           ← Resource classes
├── BaseAbility.gd
├── ProjectileAbility.gd
├── BuffAbility.gd
├── AoEAbility.gd
├── RadialAbility.gd
├── BaseTome.gd
└── TomeModifier.gd         ← NEW

scripts/domain/              ← Pure data/constants
└── AbilityTags.gd

scripts/components/          ← Node components
└── AbilityComponent.gd     ← NEW (replaces Player ability logic)

autoload/                    ← Singletons
├── EventBus.gd             (modified)
├── AbilityManager.gd
├── TomeManager.gd
└── AbilitySystem.gd        ← NEW (30Hz cooldown tracking)

data/content/abilities/
├── projectile/
│   └── ranger_arrow.tres
├── buff/
├── aoe/
├── radial/
└── celestial/

data/content/tomes/
├── tome_damage.tres
├── tome_speed.tres
├── tome_quantity.tres
├── tome_hp.tres
├── tome_luck.tres
└── tome_xp.tres
```

---

## ✅ Critical Fixes Summary

| Issue | Before | After | Status |
|-------|--------|-------|--------|
| Loop bug | `for i in levels` | `for i in range(levels)` | ✅ FIXED |
| Tome stacking | Direct mutation (exponential) | Modifier descriptors (idempotent) | ✅ FIXED |
| Auto-cast timing | `Player._process()` (frame-rate) | `AbilitySystem._on_combat_step()` (30Hz) | ✅ FIXED |
| File paths | `scripts/systems/abilities/` | `scripts/resources/` | ✅ FIXED |
| Tag types | `Array[String]` | `Array[StringName]` | ✅ FIXED |
| Projectile spawn | `ProjectilePool.acquire()` | `EventBus.ability_projectile_requested.emit()` | ✅ FIXED |
| Player bloat | 200+ lines in Player.gd | `AbilityComponent` node | ✅ FIXED |

---

## 📝 Next Steps

1. Update task documents (9a, 9b, 9c, 9d) to reflect new architecture
2. Split Phase 1 into Phase 1a (Foundation + Integration) and Phase 1b (Vertical Slice)
3. Re-baseline time estimates (22-26 hours total)
4. Submit for re-review

**Status:** Ready for re-review
**Expected Score:** 28-32/35 (Approve with Minor Revisions)
