# Melee System Migration Guide - Ability System Integration

**Created:** 2025-10-04
**Prerequisites:** Complete Task 2c (Ranger Arrow working)
**Estimated Time:** ~2 hours
**Status:** 📋 Reference Guide

---

## 🎯 Migration Overview

**Goal:** Create a clean MeleeAbilityHandler using DamageRegistry spatial queries, removing redundant entity management code.

**Architectural Decision:**
The existing `MeleeSystem.gd` (312 lines) contains ~200 lines of redundant code that duplicates `DamageRegistry.get_entities_in_cone()`. Rather than preserve legacy patterns, we'll create a **clean ~40-line handler** using the existing optimized spatial query infrastructure.

**What gets removed:**
- ❌ Custom cone detection (_is_enemy_in_cone) - **duplicates DamageRegistry**
- ❌ Manual enemy querying (_get_alive_enemies) - **duplicates DamageRegistry**
- ❌ Entity ID generation (_get_enemy_entity_id) - **handled by DamageRegistry**
- ❌ Manual entity registration (_register_enemy_entity, _register_boss_entity) - **DamageRegistry handles this**
- ❌ Separate boss/enemy logic paths - **unified via DamageRegistry type filtering**

**What gets preserved:**
- ✅ Visual effects spawning
- ✅ Attack animation timing
- ✅ DamageService.apply_damage() integration
- ✅ 30Hz combat step timing

**Architecture Pattern:**
```gdscript
// BEFORE (MeleeSystem.gd - 312 lines, redundant code):
func _is_enemy_in_cone(...)  // Duplicates DamageRegistry
func _get_alive_enemies()    // Manual SpawnDirector querying
func _register_enemy_entity() // Manual DamageService registration
// + separate boss detection logic

// AFTER (MeleeAbilityHandler.gd - ~40 lines, clean architecture):
var hit_ids = DamageRegistry.get_entities_in_cone(
    player_pos, attack_dir, cone_angle, attack_range, ["enemy", "boss"]
)
for id in hit_ids:
    DamageRegistry.apply_damage(id, damage, ...)
```

---

## 📋 Step 1: Create MeleeAbility Subclass (~1 hour)

### 1.1: Create MeleeAbility.gd

**File:** `scripts/resources/MeleeAbility.gd`

```gdscript
extends BaseAbility
class_name MeleeAbility

## Melee ability with cone-shaped AOE detection
## Supports knockback, multi-target damage, and visual effects

# === Melee-Specific Properties ===
@export_group("Cone Attack")
@export var cone_angle: float = 90.0  ## In degrees
@export var attack_range: float = 150.0  ## In pixels
@export var knockback_distance: float = 20.0
@export_enum("cone_forward", "cone_all_directions") var fire_pattern: String = "cone_forward"

@export_group("Visual Effects")
@export var swing_duration: float = 0.3  ## Animation duration
@export var impact_particle_scene: PackedScene  ## Hit particles

func activate(player: Node2D, context: Dictionary) -> void:
	## Called by AbilityComponent when cooldown expires
	## Context contains: { target_pos: Vector2 }

	var target_pos = context.get("target_pos", player.global_position + Vector2(100, 0))

	var payload = {
		"player_pos": player.global_position,
		"target_pos": target_pos,
		"cone_angle": cone_angle,
		"attack_range": attack_range,
		"damage": calculate_final_damage(),  # From BaseAbility
		"knockback": knockback_distance,
		"ability_id": ability_id,
		"swing_duration": swing_duration
	}

	EventBus.ability_melee_requested.emit(payload)

	Logger.debug("MeleeAbility activated: %s" % ability_id, "abilities")

func calculate_final_damage() -> float:
	## Override to apply tome modifiers
	var damage = base_damage

	# Apply tome modifiers (handled by TomeManager in Phase 4)
	if TomeManager:
		damage *= TomeManager.get_damage_multiplier(tags)

	return damage

func to_dict() -> Dictionary:
	var base_dict = super.to_dict()
	base_dict["cone_angle"] = cone_angle
	base_dict["attack_range"] = attack_range
	base_dict["knockback_distance"] = knockback_distance
	base_dict["fire_pattern"] = fire_pattern
	return base_dict
```

---

### 1.2: Add EventBus Signal

**File:** `autoload/EventBus.gd`

**Add to signals section:**
```gdscript
# === Ability System Signals ===
signal ability_projectile_requested(payload: Dictionary)
signal ability_melee_requested(payload: Dictionary)  # ← ADD THIS
signal ability_aoe_requested(payload: Dictionary)
```

**Signal Payload Documentation:**
```gdscript
## ability_melee_requested payload structure:
## {
##   "player_pos": Vector2,           # Where player is standing
##   "target_pos": Vector2,           # Mouse position or auto-target
##   "cone_angle": float,             # Degrees
##   "attack_range": float,           # Max distance
##   "damage": float,                 # Final damage (with modifiers)
##   "knockback": float,              # Knockback distance
##   "ability_id": String,            # For logging/debugging
##   "swing_duration": float          # Visual animation time
## }
```

---

### 1.3: Create melee_slash.tres

**File:** `data/content/abilities/melee/melee_slash.tres`

**Create directory first:**
```bash
mkdir -p data/content/abilities/melee
```

**Resource content:**
```tres
[gd_resource type="Resource" script_class="MeleeAbility" load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/resources/MeleeAbility.gd" id="1"]

[resource]
script = ExtResource("1")
ability_id = "melee_slash"
ability_name = "Melee Slash"
description = "Powerful cone attack dealing physical damage with knockback"

# Progression
ability_level = 1
max_level = 20
damage_scaling_per_level = 1.12  # +12% per level
cooldown_scaling_per_level = 0.98  # -2% cooldown per level

# Tags (for tome applicability)
tags = PackedStringArray("melee", "damage", "physical", "knockback", "cooldown")

# Base Stats
base_damage = 25.0
cooldown = 0.5  # Fast attack speed
damage_type = "physical"

# Melee-Specific
cone_angle = 90.0
attack_range = 150.0
knockback_distance = 20.0
fire_pattern = "cone_forward"
swing_duration = 0.3
```

**💡 Values Migrated From:**
- `data/balance/melee.tres` → damage, range, cone_angle, attack_speed, knockback

---

## 📋 Step 2: Create Clean MeleeAbilityHandler (~30 min)

### 2.1: Delete Old MeleeSystem

```bash
# Delete the old implementation (contains redundant code)
rm scripts/systems/combat/MeleeSystem.gd
```

**Rationale:** The existing MeleeSystem duplicates DamageRegistry functionality. Starting fresh ensures clean architecture.

### 2.2: Create New MeleeAbilityHandler

**File:** `scripts/systems/combat/MeleeAbilityHandler.gd`

**Complete implementation (~40 lines):**
```gdscript
extends Node
class_name MeleeAbilityHandler

## Clean melee ability handler using DamageRegistry spatial queries
## Listens to EventBus.ability_melee_requested and applies damage via DamageRegistry

# Visual effects
signal melee_attack_started(player_pos: Vector2, target_pos: Vector2)
signal enemies_hit(hit_count: int)

var attack_effects: Array[Dictionary] = []
var max_attack_effects: int = 10

func _ready() -> void:
	EventBus.ability_melee_requested.connect(_on_melee_ability_requested)
	EventBus.combat_step.connect(_on_combat_step)
	_initialize_attack_effects_pool()
	Logger.info("MeleeAbilityHandler initialized", "abilities")

func _on_melee_ability_requested(payload: Dictionary) -> void:
	## Handle melee ability activation using DamageRegistry spatial query
	var player_pos: Vector2 = payload.get("player_pos", Vector2.ZERO)
	var target_pos: Vector2 = payload.get("target_pos", Vector2.ZERO)
	var cone_angle: float = payload.get("cone_angle", 90.0)
	var attack_range: float = payload.get("attack_range", 150.0)
	var damage: float = payload.get("damage", 25.0)
	var knockback: float = payload.get("knockback", 20.0)

	var attack_dir = (target_pos - player_pos).normalized()

	# ✅ CLEAN: Single spatial query for all entity types
	var hit_entity_ids = DamageRegistry.get_entities_in_cone(
		player_pos, attack_dir, cone_angle, attack_range, ["enemy", "boss"]
	)

	# Spawn visual effects
	_spawn_attack_effect(player_pos, target_pos)
	melee_attack_started.emit(player_pos, target_pos)

	if hit_entity_ids.size() > 0:
		enemies_hit.emit(hit_entity_ids.size())

	# ✅ CLEAN: Single damage loop for all entities
	for entity_id in hit_entity_ids:
		DamageRegistry.apply_damage(entity_id, damage, "melee", ["melee", "physical"], knockback, player_pos)

	Logger.debug("Melee attack hit %d entities" % hit_entity_ids.size(), "abilities")
```

### 2.3: Add Visual Effects Methods

**Visual effects implementation (reuse from MeleeSystem if needed):**

```gdscript
func _spawn_attack_effect(player_pos: Vector2, target_pos: Vector2) -> void:
	## Create visual cone effect for melee attack
	var attack_dir = (target_pos - player_pos).normalized()
	var effect_index = _find_free_attack_effect()

	if effect_index >= 0:
		attack_effects[effect_index] = {
			"active": true,
			"elapsed": 0.0,
			"player_pos": player_pos,
			"direction": attack_dir,
			"duration": 0.3  # From payload.swing_duration
		}

func _find_free_attack_effect() -> int:
	## Find first inactive effect slot
	for i in attack_effects.size():
		if not attack_effects[i].get("active", false):
			return i
	return -1 if attack_effects.size() >= max_attack_effects else attack_effects.size()

func _on_combat_step(payload: Dictionary) -> void:
	## Update visual effect lifetimes
	_update_attack_effects(payload.dt)

func _update_attack_effects(dt: float) -> void:
	## Age out visual effects
	for effect in attack_effects:
		if effect.get("active", false):
			effect.elapsed += dt
			if effect.elapsed >= effect.duration:
				effect.active = false

func _initialize_attack_effects_pool() -> void:
	## Pre-allocate visual effect slots
	attack_effects.resize(max_attack_effects)
	for i in max_attack_effects:
		attack_effects[i] = {"active": false}

func get_active_attack_effects() -> Array[Dictionary]:
	## Query for visual rendering (used by HUD/debug)
	return attack_effects.filter(func(e): return e.get("active", false))
```

**Note:** If MeleeSystem has custom sprite/particle effects, copy those methods here. The core is just tracking effect lifetimes.

---

## 📋 Step 3: Integration (~30 min)

### 3.1: Update GameOrchestrator

**File:** `autoload/GameOrchestrator.gd`

**Change import:**
```gdscript
# OLD:
# const MeleeSystem = preload("res://scripts/systems/combat/MeleeSystem.gd")

# NEW:
const MeleeAbilityHandler = preload("res://scripts/systems/combat/MeleeAbilityHandler.gd")
```

**Update initialization:**
```gdscript
# OLD:
# _melee_system = MeleeSystem.new()

# NEW:
_melee_ability_handler = MeleeAbilityHandler.new()
add_child(_melee_ability_handler)
```

### 3.2: Update Player.gd

**File:** `scenes/arena/Player.gd`

**❌ REMOVE old melee trigger:**
```gdscript
# DELETE THIS METHOD:
func _handle_melee_attack() -> void:
	last_melee_attack_time = Time.get_ticks_msec() / 1000.0
	is_attacking = true
	attack_timer = 0.0
	EventBus.melee_swing_started.emit(0.3)
	var attack_direction := _get_attack_direction()
	_play_animation("attack_" + attack_direction)

	if EventBus.has_signal("melee_attack_started"):
		EventBus.melee_attack_started.emit({
			"player_pos": global_position,
			"target_pos": get_global_mouse_position()
		})
```

**✅ ADD to _ready() - Equip melee ability:**
```gdscript
func _ready() -> void:
	# ... existing code ...

	# Equip melee ability in slot 0
	if AbilityManager:
		var melee_ability = AbilityManager.create_ability_instance("melee_slash")
		if melee_ability:
			ability_slots[0] = melee_ability
			Logger.info("Equipped melee_slash in slot 0", "player")
```

### 3.3: Update ArenaInputHandler

**File:** `scripts/systems/arena/ArenaInputHandler.gd`

**❌ REMOVE old attack trigger:**
```gdscript
# DELETE THIS CODE:
func _handle_attack_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var world_pos = _get_world_mouse_position(event.position)
		player_attack_handler.handle_melee_attack(world_pos)  # ❌ Remove this
```

**✅ NEW: Melee attacks now auto-cast via AbilityComponent**
```gdscript
# No manual attack triggering needed!
# AbilityComponent auto-casts melee ability on cooldown
# Target position: nearest enemy or mouse direction
```

### 3.4: Remove PlayerAttackHandler (Optional)

**If PlayerAttackHandler only handled melee:**
```bash
# Delete the file (visual effects now in MeleeAbilityHandler)
rm scripts/systems/combat/PlayerAttackHandler.gd
```

**Update Arena.gd:**
```gdscript
# Remove PlayerAttackHandler import and initialization
# const PlayerAttackHandlerScript := preload("...")  # ❌ Delete
# var player_attack_handler: PlayerAttackHandler  # ❌ Delete
```

---

## 🧪 Step 4: Testing (~15 min)

### 4.1: Visual Test

**Run the game:**
1. Open Arena scene
2. Press F6 (run scene)
3. **Expected behavior:**
   - Melee attacks auto-fire every 0.5 seconds (from ability cooldown)
   - Cone visual effect appears
   - Enemies take damage and get knocked back
   - Works alongside Ranger Arrow (both auto-casting)

**Check console for:**
```
[INFO:abilities] Equipped melee_slash in slot 0
[DEBUG:abilities] MeleeAbility activated: melee_slash
[DEBUG:abilities] Melee attack hit 3 pooled enemies + 0 scene bosses
```

### 4.2: Isolated Test

**Create:** `tests/ability_system/MeleeSlash_Isolated.tscn`

**Script:**
```gdscript
extends Node2D

@onready var player = $Player

func _ready():
	print("=== Melee Slash Isolated Test ===")

	# Equip melee ability
	var melee_ability = AbilityManager.create_ability_instance("melee_slash")
	player.ability_slots[0] = melee_ability

	# Spawn test enemies in cone
	_spawn_test_enemies()

	# Auto-quit after 10 seconds
	await get_tree().create_timer(10.0).timeout
	_print_results()
	get_tree().quit()

func _spawn_test_enemies() -> void:
	# Create 5 enemies in front of player in cone formation
	for i in range(5):
		var enemy_pos = player.global_position + Vector2(100 + i * 30, -50 + i * 25)
		# Spawn logic here...

func _print_results() -> void:
	var enemies_remaining = get_tree().get_nodes_in_group("enemies").size()
	print("Enemies Remaining: %d / 5" % enemies_remaining)

	if enemies_remaining == 0:
		print("✓✓✓ MELEE SLASH WORKING ✓✓✓")
	else:
		print("✗ Some enemies survived - check damage/cooldown")
```

**Run headless:**
```bash
../Godot_v4.4.1-stable_win64_console.exe --headless tests/ability_system/MeleeSlash_Isolated.tscn --quit-after 10
```

### 4.3: Verify Dual Auto-Cast

**Both abilities should fire independently:**
- ✅ Melee Slash: Every 0.5s (from melee_slash.tres cooldown)
- ✅ Ranger Arrow: Every 1.0s (from ranger_arrow.tres cooldown)
- ✅ No conflicts or timing issues
- ✅ Each respects its own cooldown

---

## 📊 Migration Checklist

### Code Changes
- [ ] Created `scripts/resources/MeleeAbility.gd`
- [ ] Added `EventBus.ability_melee_requested` signal
- [ ] Created `data/content/abilities/melee/melee_slash.tres`
- [ ] Renamed `MeleeSystem.gd` → `MeleeAbilityHandler.gd`
- [ ] Updated class declaration to `MeleeAbilityHandler`
- [ ] Replaced `perform_attack()` with `_on_melee_ability_requested()`
- [ ] Removed old balance loading and auto-attack code
- [ ] Kept cone detection logic (production-ready)
- [ ] Updated GameOrchestrator imports
- [ ] Removed `Player._handle_melee_attack()` method
- [ ] Removed PlayerAttackHandler (if only used for melee)
- [ ] Updated ArenaInputHandler (removed manual attack trigger)

### Testing
- [ ] Visual test: Melee attacks auto-fire in game
- [ ] Cone detection works correctly
- [ ] Damage and knockback functional
- [ ] No console errors
- [ ] Isolated test passes
- [ ] Both melee + projectile abilities work together

### Cleanup
- [ ] Remove old `data/balance/melee.tres` (values migrated to ability)
- [ ] Update CHANGELOG.md with migration notes
- [ ] Commit changes: `feat(abilities): migrate melee system to ability framework`

---

## 🎉 Result

**Unified Ability System:**
```
Player Ability Slots:
├─ [0] melee_slash.tres (auto-cast every 0.5s)
├─ [1] ranger_arrow.tres (auto-cast every 1.0s)
├─ [2] (empty)
└─ [3] (empty)

Auto-Cast Flow:
AbilityComponent → AbilityManager → MeleeAbility.activate()
                                    → EventBus.ability_melee_requested
                                    → MeleeAbilityHandler._on_melee_ability_requested()
                                    → DamageRegistry.get_entities_in_cone()
                                    → DamageRegistry.apply_damage()
```

**Code Size Comparison:**
- ❌ **Old MeleeSystem.gd**: 312 lines (redundant entity management)
- ✅ **New MeleeAbilityHandler.gd**: ~80 lines (clean delegation to services)
- 📉 **Reduction**: 232 lines removed (74% smaller)

**What You Preserved:**
- ✅ Visual effects system
- ✅ Attack animation timing
- ✅ 30Hz deterministic timing
- ✅ Knockback functionality

**What You Gained:**
- ✅ Unified ability management
- ✅ Architectural consistency (uses DamageRegistry like all other abilities)
- ✅ Simplified codebase (no duplicate spatial query logic)
- ✅ Type filtering (unified boss + enemy handling)
- ✅ Tome modifier support
- ✅ Level-up progression
- ✅ Hot-reload via .tres resources

---

**See Also:**
- `/Obsidian/03-tasks/2_ABILITIES_system_implementation.md` Phase 5
- `/Obsidian/02-brainstorm/ability-system/ability-system-architecture-REVISED.md`
