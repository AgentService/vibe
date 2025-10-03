# Ability System - Technical Architecture

**Status:** 📐 Architecture Blueprint
**Created:** 2025-10-03
**Based On:** [ability-system-design-exploration.md](ability-system-design-exploration.md) (26 Q&A)

---

## 🎯 System Overview

The ability system implements auto-cast, data-driven abilities with:
- **4 ability slots** per character (1 base + 3 unlockable)
- **4 tome slots** for general ability buffs
- **Items** acquired via purchasable chests (gold economy)
- **Tag-based applicability** for Tomes and elemental conversions
- **Level-up progression** (abilities scale by re-picking)
- **Integration** with MetaProgression, Quest system, DamageService

---

## 📦 Core Class Hierarchy

```
BaseAbility (Resource)
├── ProjectileAbility
├── BuffAbility
├── AoEAbility
├── RadialAbility
└── CelestialAbility

BaseTome (Resource)
└── (No subclasses - unified structure)

BaseItem (Resource)
└── (No subclasses - unified structure)
```

### Why Unified BaseAbility?
- **Polymorphic application**: Tomes can modify any ability consistently
- **Optional properties**: Subclasses use what they need (`projectile_count` for ProjectileAbility)
- **Tag system**: Determines applicability, not class hierarchy
- **Simpler than**: Separate interfaces for each ability type

---

## 🏗️ Class Definitions

### BaseAbility.gd

**Location:** `scripts/systems/abilities/BaseAbility.gd`

```gdscript
extends Resource
class_name BaseAbility

## Base class for all abilities (unified hierarchy with optional properties)

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
@export var level_breakpoints: Dictionary = {}  # {5: {"projectile_count": 1}, ...}

# === Tags (determines Tome/modifier applicability) ===
@export var tags: Array[String] = []

# === Base Stats (all abilities have these) ===
@export var base_damage: float = 0.0
@export var cooldown: float = 1.0

# === Damage Type & Element ===
@export var damage_type: String = "physical"  # physical, fire, ice, poison, lightning
@export var inherent_element: String = ""  # If set, cannot be converted by power-ups

# === Optional Properties (subclasses use what they need) ===
# Projectile properties (used by ProjectileAbility)
@export var projectile_count: int = 1
@export var projectile_speed: float = 400.0
@export var pierce_count: int = 0
@export var max_visual_projectiles: int = 15  # Visual cap for performance

# Buff properties (used by BuffAbility)
@export var buff_duration: float = 5.0
@export var stat_modifier: Dictionary = {}  # {"damage": 1.25, "speed": 1.1}

# AoE properties (used by AoEAbility)
@export var aoe_radius: float = 100.0
@export var aoe_delay: float = 0.5

# Radial properties (used by RadialAbility)
@export var orbit_radius: float = 80.0
@export var orbit_speed: float = 180.0  # Degrees per second

# === Visual References ===
@export var visual_scene: PackedScene = null  # Projectile/effect visual
@export var impact_effect: PackedScene = null  # On-hit effect

# === Elemental Flags (set by Tomes/modifiers) ===
var applies_burning: bool = false
var applies_slow: bool = false
var applies_poison: bool = false


## Called when ability levels up (from re-picking)
func level_up(levels: int = 1) -> void:
	for i in levels:
		ability_level += 1

		# Apply scaling
		if has_tag("damage"):
			base_damage *= damage_scaling_per_level

		if has_tag("cooldown"):
			cooldown *= cooldown_scaling_per_level

		# Check for breakpoint bonuses
		if ability_level in level_breakpoints:
			_apply_breakpoint_bonus(level_breakpoints[ability_level])


## Apply breakpoint bonus (e.g., +1 projectile at level 5)
func _apply_breakpoint_bonus(bonus: Dictionary) -> void:
	for property in bonus:
		if property in self:
			self[property] += bonus[property]
			Logger.info("Breakpoint bonus: %s +%s" % [property, bonus[property]], "abilities")


## Tag system helpers
func has_tag(tag: String) -> bool:
	return tag in tags


func add_tag(tag: String) -> void:
	if not has_tag(tag):
		tags.append(tag)


func remove_tag(tag: String) -> void:
	tags.erase(tag)


## Check if ability has inherent element (cannot be converted)
func has_inherent_element() -> bool:
	return inherent_element != ""


## Activate ability (overridden by subclasses)
func activate(player: Node2D, context: Dictionary) -> void:
	push_warning("BaseAbility.activate() called - should be overridden by subclass")
```

---

### ProjectileAbility.gd

**Location:** `scripts/systems/abilities/ProjectileAbility.gd`

```gdscript
extends BaseAbility
class_name ProjectileAbility

## Projectile-based ability (arrows, fireballs, lightning bolts, etc.)


func activate(player: Node2D, context: Dictionary) -> void:
	# Calculate visual projectile count (capped for performance)
	var actual_count = projectile_count
	var visual_count = min(actual_count, max_visual_projectiles)
	var damage_per_projectile = base_damage * (float(actual_count) / visual_count)

	# Spawn projectiles from object pool
	for i in visual_count:
		var projectile = ProjectilePool.acquire(ability_id)
		projectile.setup(damage_per_projectile, projectile_speed, pierce_count)
		projectile.damage_type = damage_type
		projectile.applies_burning = applies_burning
		projectile.applies_slow = applies_slow
		projectile.applies_poison = applies_poison

		# Position & direction
		projectile.global_position = player.global_position
		projectile.direction = _calculate_direction(i, visual_count, player)

		# Visual
		if visual_scene:
			projectile.set_visual(visual_scene)

	Logger.debug("Activated %s: %d projectiles, %.1f damage each" %
	            [ability_name, visual_count, damage_per_projectile], "abilities")


func _calculate_direction(index: int, total: int, player: Node2D) -> Vector2:
	# Spread projectiles in arc
	if total == 1:
		return player.get_facing_direction()  # Or mouse direction

	var arc_angle = 60.0  # Total arc in degrees
	var angle_step = arc_angle / (total - 1)
	var base_angle = player.get_facing_angle()
	var offset_angle = -arc_angle / 2.0 + (angle_step * index)

	return Vector2.RIGHT.rotated(deg_to_rad(base_angle + offset_angle))
```

---

### BaseTome.gd

**Location:** `scripts/systems/abilities/BaseTome.gd`

**Foundation Design Philosophy:**
The modifier system uses individual @export properties (not dictionaries) to:
- Enable Inspector editing without custom editors
- Support hot-reloading (F5 refresh sees changes immediately)
- Allow easy addition of new modifiers (just add new @export property)
- Keep type safety (float vs int vs bool) for each modifier
- Elemental/status effects can be added later by adding new @export properties

```gdscript
extends Resource
class_name BaseTome

## General buff that enhances abilities OR player stats (4 tome slots total)
## Tomes apply to ALL abilities if applicable_tags is empty (global modifiers)
## Player stat modifiers (speed, HP, luck) apply directly to Player node

# === Core Identity ===
@export var tome_id: String = ""
@export var tome_name: String = ""
@export var description: String = ""
@export var icon: Texture2D = null
@export var rarity: String = "common"  # common, uncommon, rare, epic, legendary

# === Stacking ===
@export var stack_limit: int = 10  # Max stacks per tome

# === Applicability (tag-based) ===
@export var applicable_tags: Array[String] = []  # Empty = applies to ALL abilities (global modifier)

# === ABILITY MODIFIERS (apply to abilities with matching tags) ===
@export_group("Ability Modifiers")
@export var damage_multiplier: float = 1.0  # 1.25 = +25% damage per stack
@export var cooldown_multiplier: float = 1.0  # 0.9 = -10% cooldown per stack (faster casting)
@export var projectile_count_bonus: int = 0  # +1 projectile per stack
@export var pierce_count_bonus: int = 0  # +1 pierce per stack
@export var aoe_radius_multiplier: float = 1.0  # 1.15 = +15% AoE radius per stack
@export var projectile_speed_multiplier: float = 1.0  # 1.1 = +10% projectile speed per stack

# === PLAYER STAT MODIFIERS (apply directly to Player, ignore tags) ===
@export_group("Player Stat Modifiers")
@export var movement_speed_multiplier: float = 1.0  # 1.1 = +10% movement speed per stack
@export var max_hp_bonus: float = 0.0  # +10.0 HP per stack
@export var luck_bonus: float = 0.0  # +5.0 luck per stack (chest rarity rolls)
@export var xp_gain_multiplier: float = 1.0  # 1.15 = +15% XP gain per stack


## Check if tome can apply to ability (tag-based)
## Returns true if applicable_tags is EMPTY (global) or ability has matching tag
func can_apply_to_ability(ability: BaseAbility) -> bool:
	# Empty tags = applies to ALL abilities (global modifier)
	if applicable_tags.is_empty():
		return true

	# Check if ability has any of the required tags
	for tag in applicable_tags:
		if ability.has_tag(tag):
			return true

	return false


## Apply tome modifiers to a specific ability
## Called when: (1) tome acquired/stacked, (2) new ability equipped
func apply_to_ability(ability: BaseAbility, stack_count: int) -> void:
	if not can_apply_to_ability(ability):
		return

	# Damage multiplier (multiplicative per stack)
	if damage_multiplier != 1.0 and ability.has_tag("damage"):
		var total_multiplier = pow(damage_multiplier, stack_count)
		ability.base_damage *= total_multiplier

	# Cooldown multiplier (multiplicative per stack, <1.0 = faster)
	if cooldown_multiplier != 1.0:
		var total_multiplier = pow(cooldown_multiplier, stack_count)
		ability.cooldown *= total_multiplier

	# Projectile count (additive per stack)
	if projectile_count_bonus > 0 and ability.has_tag("projectile"):
		ability.projectile_count += projectile_count_bonus * stack_count

	# Pierce count (additive per stack)
	if pierce_count_bonus > 0 and ability.has_tag("projectile"):
		ability.pierce_count += pierce_count_bonus * stack_count

	# AoE radius (multiplicative per stack)
	if aoe_radius_multiplier != 1.0 and ability.has_tag("aoe"):
		var total_multiplier = pow(aoe_radius_multiplier, stack_count)
		ability.aoe_radius *= total_multiplier

	# Projectile speed (multiplicative per stack)
	if projectile_speed_multiplier != 1.0 and ability.has_tag("projectile"):
		var total_multiplier = pow(projectile_speed_multiplier, stack_count)
		ability.projectile_speed *= total_multiplier

	Logger.debug("Applied %s (×%d) to %s" % [tome_name, stack_count, ability.ability_name], "tomes")


## Apply tome modifiers to Player stats (movement speed, HP, luck, etc.)
## Called when tome acquired/stacked
func apply_to_player(player: Node2D, stack_count: int) -> void:
	# Movement speed
	if movement_speed_multiplier != 1.0:
		var total_multiplier = pow(movement_speed_multiplier, stack_count)
		player.movement_speed *= total_multiplier
		Logger.debug("Applied %s: movement speed ×%.2f" % [tome_name, total_multiplier], "tomes")

	# Max HP (additive per stack)
	if max_hp_bonus > 0.0:
		var total_bonus = max_hp_bonus * stack_count
		player.max_hp += total_bonus
		player.current_hp += total_bonus  # Also heal by bonus amount
		Logger.debug("Applied %s: max HP +%.1f" % [tome_name, total_bonus], "tomes")

	# Luck (additive per stack, affects chest rarity rolls)
	if luck_bonus > 0.0:
		var total_bonus = luck_bonus * stack_count
		player.luck += total_bonus
		Logger.debug("Applied %s: luck +%.1f" % [tome_name, total_bonus], "tomes")

	# XP gain (multiplicative per stack)
	if xp_gain_multiplier != 1.0:
		var total_multiplier = pow(xp_gain_multiplier, stack_count)
		player.xp_gain_multiplier *= total_multiplier
		Logger.debug("Applied %s: XP gain ×%.2f" % [tome_name, total_multiplier], "tomes")
```

---

### AbilityTags.gd

**Location:** `scripts/systems/abilities/AbilityTags.gd`

```gdscript
extends Node
class_name AbilityTags

## Centralized tag constants for ability/tome applicability

# Ability categories
const PROJECTILE: StringName = &"projectile"
const BUFF: StringName = &"buff"
const AOE: StringName = &"aoe"
const RADIAL: StringName = &"radial"
const CELESTIAL: StringName = &"celestial"

# Properties
const DAMAGE: StringName = &"damage"
const COOLDOWN: StringName = &"cooldown"
const DURATION: StringName = &"duration"

# Elements
const FIRE: StringName = &"fire"
const ICE: StringName = &"ice"
const POISON: StringName = &"poison"
const LIGHTNING: StringName = &"lightning"
const PHYSICAL: StringName = &"physical"

# Special
const PIERCE: StringName = &"pierce"
const CHAIN: StringName = &"chain"
const EXPLOSION: StringName = &"explosion"

# Total: ~15 tags (expandable as needed)
```

---

## 🔧 Manager Classes

### AbilityManager.gd (Autoload)

**Location:** `autoload/AbilityManager.gd`

```gdscript
extends Node

## Manages ability definitions (registry) and instance creation

# Registry of all loaded abilities
var _ability_registry: Dictionary = {}  # {ability_id: BaseAbility}
var _ability_file_paths: Dictionary = {}  # {ability_id: "res://..."}
var _ability_categories: Dictionary = {}  # {ability_id: "projectile"}


func _ready() -> void:
	_load_all_abilities()


## Load all ability .tres files from data/content/abilities/
func _load_all_abilities() -> void:
	var categories = ["projectile", "buff", "aoe", "radial", "celestial"]

	for category in categories:
		var category_path = "res://data/content/abilities/" + category + "/"
		var dir = DirAccess.open(category_path)

		if not dir:
			Logger.warn("Ability category not found: %s" % category, "abilities")
			continue

		dir.list_dir_begin()
		var file_name = dir.get_next()

		while file_name != "":
			if file_name.ends_with(".tres"):
				var full_path = category_path + file_name
				var ability = ResourceLoader.load(full_path) as BaseAbility

				if ability:
					_ability_registry[ability.ability_id] = ability
					_ability_file_paths[ability.ability_id] = full_path
					_ability_categories[ability.ability_id] = category

			file_name = dir.get_next()

		dir.list_dir_end()

	Logger.info("Loaded %d abilities across %d categories" %
	           [_ability_registry.size(), categories.size()], "abilities")


## Get ability definition (original resource, DO NOT modify directly)
func get_definition(ability_id: String) -> BaseAbility:
	return _ability_registry.get(ability_id)


## Create ability instance (duplicate for player use)
func create_ability_instance(ability_id: String) -> BaseAbility:
	var definition = get_definition(ability_id)
	if not definition:
		Logger.error("Ability not found: %s" % ability_id, "abilities")
		return null

	# Duplicate resource for player modification (Tomes will modify this)
	return definition.duplicate(true)


## Get file path for hot-reload/debug
func get_file_path(ability_id: String) -> String:
	return _ability_file_paths.get(ability_id, "")


## Get all abilities in category
func get_abilities_in_category(category: String) -> Array[String]:
	var result: Array[String] = []
	for ability_id in _ability_categories:
		if _ability_categories[ability_id] == category:
			result.append(ability_id)
	return result
```

---

### TomeManager.gd (Autoload)

**Location:** `autoload/TomeManager.gd`

```gdscript
extends Node

## Manages tome definitions (similar structure to AbilityManager)

var _tome_registry: Dictionary = {}  # {tome_id: BaseTome}
var _tome_file_paths: Dictionary = {}


func _ready() -> void:
	_load_all_tomes()


func _load_all_tomes() -> void:
	var tomes_path = "res://data/content/tomes/"
	var dir = DirAccess.open(tomes_path)

	if not dir:
		Logger.warn("Tomes directory not found", "tomes")
		return

	dir.list_dir_begin()
	var file_name = dir.get_next()

	while file_name != "":
		if file_name.ends_with(".tres"):
			var full_path = tomes_path + file_name
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

## 🎮 Player Integration

### Player.gd Enhancements

**Location:** `scenes/player/Player.gd` (existing file, add these sections)

```gdscript
# === Ability System ===
var ability_slots: Array[BaseAbility] = [null, null, null, null]
var ability_cooldowns: Array[float] = [0.0, 0.0, 0.0, 0.0]

# === Tome System ===
var tome_slots: Array[BaseTome] = [null, null, null, null]
var tome_stacks: Array[int] = [0, 0, 0, 0]

# === Gold Economy ===
var gold: int = 0
var gold_streak_active: bool = false
var gold_streak_timer: float = 0.0
var gold_streak_amount: int = 0
const GOLD_STREAK_TIMEOUT: float = 2.0

@onready var gold_streak_label: Label = $GoldStreakLabel


func _ready() -> void:
	# ... existing code ...
	EventBus.enemy_killed.connect(_on_enemy_killed)
	gold_streak_label.visible = false


func _process(delta: float) -> void:
	# Update ability cooldowns (every frame)
	_update_ability_cooldowns(delta)

	# Auto-cast ready abilities (every frame, but abilities on 30Hz step)
	_auto_cast_ready_abilities()

	# Update gold streak
	if gold_streak_active:
		gold_streak_timer -= delta
		if gold_streak_timer <= 0.0:
			_end_gold_streak()


## Update ability cooldowns
func _update_ability_cooldowns(delta: float) -> void:
	for i in ability_cooldowns.size():
		if ability_cooldowns[i] > 0.0:
			ability_cooldowns[i] -= delta


## Auto-cast abilities when ready
func _auto_cast_ready_abilities() -> void:
	for i in ability_slots.size():
		if ability_slots[i] and ability_cooldowns[i] <= 0.0:
			_activate_ability(i)


## Activate ability
func _activate_ability(slot_index: int) -> void:
	var ability = ability_slots[slot_index]
	if not ability:
		return

	# Activate (subclass handles spawning projectiles, etc.)
	ability.activate(self, {"player": self})

	# Reset cooldown
	ability_cooldowns[slot_index] = ability.cooldown

	# Track for stats
	EventBus.ability_activated.emit(ability.ability_id)


## Add ability to slot
func add_ability(ability_id: String, slot: int = -1) -> void:
	# Find empty slot if not specified
	if slot == -1:
		slot = _find_empty_ability_slot()

	if slot == -1:
		Logger.warn("No ability slots available", "abilities")
		return

	# Create instance from definition
	var ability = AbilityManager.create_ability_instance(ability_id)

	# Apply ALL existing tomes to new ability
	for i in tome_slots.size():
		if tome_slots[i]:
			tome_slots[i].apply_to_ability(ability, tome_stacks[i])

	ability_slots[slot] = ability
	ability_cooldowns[slot] = 0.0  # Ready immediately

	Logger.info("Equipped %s in slot %d" % [ability.ability_name, slot], "abilities")


## Level up existing ability
func level_up_ability(ability_id: String, levels: int = 1) -> void:
	var slot = find_ability_slot(ability_id)
	if slot != -1:
		ability_slots[slot].level_up(levels)
		Logger.info("Leveled up %s to level %d" %
		           [ability_slots[slot].ability_name, ability_slots[slot].ability_level], "abilities")


## Add tome (or stack if already have)
func add_tome(tome: BaseTome) -> void:
	# Check if already have this tome
	var slot = find_tome_slot(tome.tome_id)

	if slot != -1:
		# Stack existing tome
		if tome_stacks[slot] < tome.stack_limit:
			tome_stacks[slot] += 1
			_apply_tome_to_all_abilities(tome, tome_stacks[slot])
			_apply_tome_to_player(tome, tome_stacks[slot])
			Logger.info("Stacked %s to %d" % [tome.tome_name, tome_stacks[slot]], "tomes")
	else:
		# Equip new tome
		slot = _find_empty_tome_slot()
		if slot != -1:
			tome_slots[slot] = tome
			tome_stacks[slot] = 1
			_apply_tome_to_all_abilities(tome, 1)
			_apply_tome_to_player(tome, 1)
			Logger.info("Equipped %s" % tome.tome_name, "tomes")


## Apply tome to all abilities (for ability modifiers)
func _apply_tome_to_all_abilities(tome: BaseTome, stack_count: int) -> void:
	for ability in ability_slots:
		if ability:
			tome.apply_to_ability(ability, stack_count)


## Apply tome to player stats (for player modifiers like speed, HP, luck)
func _apply_tome_to_player(tome: BaseTome, stack_count: int) -> void:
	tome.apply_to_player(self, stack_count)


## Find ability slot
func find_ability_slot(ability_id: String) -> int:
	for i in ability_slots.size():
		if ability_slots[i] and ability_slots[i].ability_id == ability_id:
			return i
	return -1


func _find_empty_ability_slot() -> int:
	for i in ability_slots.size():
		if ability_slots[i] == null:
			return i
	return -1


## Find tome slot
func find_tome_slot(tome_id: String) -> int:
	for i in tome_slots.size():
		if tome_slots[i] and tome_slots[i].tome_id == tome_id:
			return i
	return -1


func _find_empty_tome_slot() -> int:
	for i in tome_slots.size():
		if tome_slots[i] == null:
			return i
	return -1


## Gold economy
func _on_enemy_killed(enemy_id: String, position: Vector2) -> void:
	var enemy_type = EnemyManager.get_type(enemy_id)
	var gold_amount = enemy_type.gold_value

	gold += gold_amount
	EventBus.gold_gained.emit(gold_amount, "enemy_kill")

	# Update streak
	if gold_streak_active:
		gold_streak_amount += gold_amount
		gold_streak_timer = GOLD_STREAK_TIMEOUT
		_update_streak_label()
	else:
		_start_gold_streak(gold_amount)


func _start_gold_streak(initial_amount: int) -> void:
	gold_streak_active = true
	gold_streak_amount = initial_amount
	gold_streak_timer = GOLD_STREAK_TIMEOUT
	gold_streak_label.visible = true
	_update_streak_label()


func _update_streak_label() -> void:
	gold_streak_label.text = "+%dg" % gold_streak_amount

	if gold_streak_amount > 100:
		gold_streak_label.modulate = Color.GOLD
	elif gold_streak_amount > 50:
		gold_streak_label.modulate = Color.YELLOW
	else:
		gold_streak_label.modulate = Color.WHITE

	gold_streak_label.position = Vector2(0, -60)


func _end_gold_streak() -> void:
	gold_streak_active = false
	gold_streak_label.visible = false
```

---

## 📡 EventBus Signal Additions

**Location:** `autoload/EventBus.gd` (add these signals)

```gdscript
# === Ability System ===
signal ability_activated(ability_id: String)
signal ability_acquired(ability_id: String, slot: int)
signal ability_leveled_up(ability_id: String, new_level: int)

# === Tome System ===
signal tome_acquired(tome_id: String, stack_count: int)

# === Gold Economy ===
signal gold_gained(amount: int, source: String)  # source: "enemy_kill", "chest", etc.
signal gold_spent(amount: int, purpose: String)  # purpose: "chest", "shrine", etc.

# === Chest System ===
signal chest_spawned(chest_position: Vector2, is_free: bool)
signal chest_opened(chest_cost: int, is_free: bool)
signal item_acquired(item_id: String, rarity: String)
```

---

## 📁 File Structure

```
scripts/systems/abilities/
├── BaseAbility.gd          ← Core ability class
├── ProjectileAbility.gd    ← Projectile subclass
├── BuffAbility.gd          ← Buff subclass
├── AoEAbility.gd           ← AoE subclass
├── RadialAbility.gd        ← Radial subclass
├── CelestialAbility.gd     ← Celestial subclass
├── BaseTome.gd             ← Tome class
├── BaseItem.gd             ← Item class (future)
└── AbilityTags.gd          ← Tag constants

autoload/
├── AbilityManager.gd       ← Ability registry/loader
├── TomeManager.gd          ← Tome registry/loader
└── ChestManager.gd         ← Chest spawning/economy (future)

data/content/abilities/
├── projectile/
│   ├── fireball.tres
│   ├── ranger_arrow.tres
│   └── ice_shard.tres
├── buff/
│   └── speed_boost.tres
├── aoe/
│   └── meteor_strike.tres
├── radial/
│   └── spinning_blades.tres
└── celestial/
    └── comet_rain.tres

data/content/tomes/
├── tome_damage.tres      # Global damage buff
├── tome_speed.tres       # Movement speed buff
├── tome_quantity.tres    # Projectile count buff
├── tome_hp.tres          # Max HP buff
├── tome_luck.tres        # Luck buff (chest rarity)
└── tome_xp.tres          # XP gain buff
```

---

## 🔗 Integration Points

### 1. DamageService Integration

**Projectile hit detection calls DamageService:**

```gdscript
// Projectile.gd (or similar)
func _on_enemy_hit(enemy_id: String) -> void:
	# Use central damage system
	DamageService.apply_damage(enemy_id, damage, ability_id, [damage_type])

	# Auto-emits: EventBus.damage_applied, damage_dealt
	# SessionManager automatically tracks damage per ability
```

### 2. MetaProgression Integration

**Level-up upgrade screen generation:**

```gdscript
// UpgradeManager.gd
func generate_levelup_upgrade_options(player: Player, count: int = 3) -> Array:
	var available_options: Array = []

	# Get unlocked abilities + tomes from MetaProgression
	var all_abilities = MetaProgression.get_unlocked_items("skills")
	var all_tomes = MetaProgression.get_unlocked_items("tomes")

	# Filter by availability (can level up, slots available, etc.)
	for ability_id in all_abilities:
		# Check if can level up or equip
		# ...

	for tome_id in all_tomes:
		# Check if can stack or equip
		# ...

	# Randomly select 3 from combined pool
	return available_options.slice(0, min(count, available_options.size()))
```

### 3. Quest System Integration

**Quest rewards unlock abilities/tomes:**

```gdscript
// QuestManager.gd
func _award_quest_rewards(quest: QuestConfig) -> void:
	# Discover abilities in shop
	for ability_id in quest.reward_discover:
		MetaProgression.discover_item("skills", ability_id)

	# Instant unlock abilities
	for ability_id in quest.reward_unlocks:
		MetaProgression.unlock_item("skills", ability_id)
```

---

## 🎨 Example .tres Files

### fireball.tres

```tres
[gd_resource type="Resource" script_class="ProjectileAbility" load_steps=3 format=3]

[ext_resource type="Script" path="res://scripts/systems/abilities/ProjectileAbility.gd" id="1"]
[ext_resource type="PackedScene" path="res://scenes/abilities/projectiles/fireball_visual.tscn" id="2"]

[resource]
script = ExtResource("1")
ability_id = "fireball"
ability_name = "Fireball"
description = "Launches a fiery projectile that explodes on impact"
ability_level = 1
max_level = 20
tags = PackedStringArray("projectile", "damage", "fire", "cooldown")

base_damage = 25.0
cooldown = 1.5
damage_type = "fire"
inherent_element = "fire"

projectile_count = 1
projectile_speed = 400.0
pierce_count = 0
max_visual_projectiles = 15

visual_scene = ExtResource("2")
```

### Tome Examples (Realistic Gameplay Modifiers)

**tome_damage.tres** (Damage Tome - global ability buff)
```tres
[gd_resource type="Resource" script_class="BaseTome" load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/systems/abilities/BaseTome.gd" id="1"]

[resource]
script = ExtResource("1")
tome_id = "tome_damage"
tome_name = "Tome of Power"
description = "Increase all damage by 15% per stack"
rarity = "common"

stack_limit = 10
applicable_tags = PackedStringArray()  # Empty = applies to ALL abilities

damage_multiplier = 1.15  # +15% damage per stack (global modifier)
```

**tome_speed.tres** (Speed Tome - player movement buff)
```tres
[gd_resource type="Resource" script_class="BaseTome" load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/systems/abilities/BaseTome.gd" id="1"]

[resource]
script = ExtResource("1")
tome_id = "tome_speed"
tome_name = "Tome of Swiftness"
description = "Increase movement speed by 8% per stack"
rarity = "uncommon"

stack_limit = 10
applicable_tags = PackedStringArray()  # Not used for player stat modifiers

movement_speed_multiplier = 1.08  # +8% movement speed per stack
```

**tome_quantity.tres** (Quantity Tome - projectile/attack count)
```tres
[gd_resource type="Resource" script_class="BaseTome" load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/systems/abilities/BaseTome.gd" id="1"]

[resource]
script = ExtResource("1")
tome_id = "tome_quantity"
tome_name = "Tome of Quantity"
description = "Increase projectile count by 1 per stack (projectile abilities only)"
rarity = "rare"

stack_limit = 5  # Lower limit due to power
applicable_tags = PackedStringArray("projectile")  # Only applies to projectile abilities

projectile_count_bonus = 1  # +1 projectile per stack
```

**tome_hp.tres** (HP Tome - max health buff)
```tres
[gd_resource type="Resource" script_class="BaseTome" load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/systems/abilities/BaseTome.gd" id="1"]

[resource]
script = ExtResource("1")
tome_id = "tome_hp"
tome_name = "Tome of Vitality"
description = "Increase max HP by 15 per stack"
rarity = "common"

stack_limit = 10
applicable_tags = PackedStringArray()  # Not used for player stat modifiers

max_hp_bonus = 15.0  # +15 HP per stack
```

**tome_luck.tres** (Lucky Tome - chest rarity buff)
```tres
[gd_resource type="Resource" script_class="BaseTome" load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/systems/abilities/BaseTome.gd" id="1"]

[resource]
script = ExtResource("1")
tome_id = "tome_luck"
tome_name = "Tome of Fortune"
description = "Increase luck by 5 per stack (better chest loot)"
rarity = "uncommon"

stack_limit = 10
applicable_tags = PackedStringArray()  # Not used for player stat modifiers

luck_bonus = 5.0  # +5 luck per stack (affects chest rarity rolls)
```

**tome_xp.tres** (XP Tome - experience gain buff)
```tres
[gd_resource type="Resource" script_class="BaseTome" load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/systems/abilities/BaseTome.gd" id="1"]

[resource]
script = ExtResource("1")
tome_id = "tome_xp"
tome_name = "Tome of Knowledge"
description = "Increase XP gain by 10% per stack"
rarity = "uncommon"

stack_limit = 10
applicable_tags = PackedStringArray()  # Not used for player stat modifiers

xp_gain_multiplier = 1.10  # +10% XP gain per stack
```

---

## ✅ Architecture Complete

**Next Step:** [Phase 1 Implementation Plan](ability-system-implementation-plan.md)

**Status:** 📐 Ready for implementation
