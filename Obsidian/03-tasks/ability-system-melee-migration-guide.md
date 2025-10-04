# Melee System Migration Guide - Ability System Integration

**Created:** 2025-10-04
**Prerequisites:** Complete Task 2c (Ranger Arrow working)
**Estimated Time:** ~2 hours
**Status:** 📋 Reference Guide

---

## 🎯 Migration Overview

**Goal:** Refactor the existing melee cone attack into the unified ability system without losing functionality.

**What stays the same:**
- ✅ Cone detection logic (production-ready)
- ✅ Visual effects system
- ✅ DamageService integration
- ✅ 30Hz combat step timing
- ✅ Balance hot-reload

**What changes:**
- 🔄 MeleeSystem.gd → MeleeAbilityHandler.gd (renamed)
- 🔄 `perform_attack()` direct calls → EventBus signals
- 🔄 Player input flow → Ability auto-cast system
- 🔄 Balance config → Ability resource (.tres)

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

## 📋 Step 2: Refactor MeleeSystem → MeleeAbilityHandler (~30 min)

### 2.1: Rename File

```bash
# In scripts/systems/combat/
mv MeleeSystem.gd MeleeAbilityHandler.gd
```

### 2.2: Update Class Declaration

**File:** `scripts/systems/combat/MeleeAbilityHandler.gd`

**Change header:**
```gdscript
extends Node

## Melee ability handler managing cone-shaped AOE attacks
## Listens to EventBus.ability_melee_requested and handles collision detection

class_name MeleeAbilityHandler  # Changed from MeleeSystem

# ❌ REMOVE old auto-attack fields (now handled by AbilityComponent)
# var attack_cooldown: float = 0.0
# var auto_attack_enabled: bool = true
# var auto_attack_target: Vector2 = Vector2.ZERO

# ❌ REMOVE balance values (now in ability .tres)
# var damage: float
# var attack_range: float
# var cone_angle: float
# var attack_speed: float
# var knockback_distance: float

# ✅ KEEP visual effects tracking
var attack_effects: Array[Dictionary] = []
var max_attack_effects: int = 10

# ✅ KEEP signals for visual effects
signal melee_attack_started(player_pos: Vector2, target_pos: Vector2)
signal enemies_hit(hit_enemies: Array[Dictionary])
```

### 2.3: Refactor _ready()

**Old code:**
```gdscript
func _ready() -> void:
	_load_balance_values()  # ❌ Remove
	EventBus.combat_step.connect(_on_combat_step)
	_initialize_attack_effects_pool()
	if BalanceDB:
		BalanceDB.balance_reloaded.connect(_on_balance_reloaded)  # ❌ Remove
```

**New code:**
```gdscript
func _ready() -> void:
	# Listen for melee ability requests from ability system
	EventBus.ability_melee_requested.connect(_on_melee_ability_requested)

	# Still use combat step for visual effect updates
	EventBus.combat_step.connect(_on_combat_step)

	# Initialize visual effects pool
	_initialize_attack_effects_pool()

	Logger.info("MeleeAbilityHandler initialized", "abilities")
```

### 2.4: Replace perform_attack() with Signal Handler

**❌ Remove old method:**
```gdscript
# DELETE THIS ENTIRE METHOD:
func perform_attack(player_pos: Vector2, target_pos: Vector2, enemies: Array[EnemyEntity]) -> Array[EnemyEntity]:
	# ... 110 lines of code ...
```

**✅ Add new signal handler:**
```gdscript
func _on_melee_ability_requested(payload: Dictionary) -> void:
	## Called when ability system requests melee attack
	## Payload contains all attack parameters from MeleeAbility

	var player_pos: Vector2 = payload.get("player_pos", Vector2.ZERO)
	var target_pos: Vector2 = payload.get("target_pos", Vector2.ZERO)
	var cone_angle: float = payload.get("cone_angle", 90.0)
	var attack_range: float = payload.get("attack_range", 150.0)
	var damage: float = payload.get("damage", 25.0)
	var knockback: float = payload.get("knockback", 20.0)

	# ✅ KEEP: Calculate attack direction (core logic stays)
	var attack_dir = (target_pos - player_pos).normalized()

	# ✅ KEEP: Find pooled enemies in cone (production-ready code)
	var hit_enemies: Array[EnemyEntity] = []
	var alive_enemies = _get_alive_enemies()  # Helper method (add below)

	for enemy in alive_enemies:
		if not enemy.alive:
			continue

		if _is_enemy_in_cone(enemy.pos, player_pos, attack_dir, cone_angle, attack_range):
			hit_enemies.append(enemy)

	# ✅ KEEP: Find scene bosses via DamageService
	var hit_scene_bosses = _find_bosses_in_cone_via_damage_service(player_pos, attack_dir, cone_angle, attack_range)

	# ✅ KEEP: Create visual effect
	_spawn_attack_effect(player_pos, target_pos)

	# ✅ KEEP: Emit signals for visual effects
	melee_attack_started.emit(player_pos, target_pos)
	if hit_enemies.size() > 0 or hit_scene_bosses.size() > 0:
		enemies_hit.emit(hit_enemies)

	# ✅ KEEP: Apply damage via DamageService (all existing logic)
	var _total_hit_count = 0

	for enemy in hit_enemies:
		var enemy_pool_index = enemy.index
		if enemy_pool_index == -1:
			Logger.warn("Enemy has invalid index for melee damage", "combat")
			continue

		var entity_id = _get_enemy_entity_id(enemy_pool_index)

		# Auto-register if needed
		if not DamageService.get_entity(entity_id).has("id"):
			_register_enemy_entity(entity_id, enemy)

		var killed = DamageService.apply_damage(entity_id, damage, "melee", ["melee"], knockback, player_pos)
		if killed:
			_total_hit_count += 1

	# Apply damage to scene bosses (keep existing logic)
	for boss in hit_scene_bosses:
		var boss_id = "boss_" + str(boss.get_instance_id())
		if not DamageService.get_entity(boss_id).has("id"):
			_register_boss_entity(boss_id, boss)

		var killed = DamageService.apply_damage(boss_id, damage, "melee", ["melee"], knockback, player_pos)
		if killed:
			_total_hit_count += 1

	Logger.debug("Melee attack hit %d pooled enemies + %d scene bosses" % [hit_enemies.size(), hit_scene_bosses.size()], "abilities")
```

### 2.5: Add Helper Methods

**Add these methods (extracted from perform_attack logic):**

```gdscript
func _get_alive_enemies() -> Array[EnemyEntity]:
	## Get alive enemies from SpawnDirector
	var game_orchestrator = get_node_or_null("/root/GameOrchestrator")
	if game_orchestrator:
		var sd = game_orchestrator.get_spawn_director()
		if sd and sd.has_method("get_alive_enemies"):
			return sd.get_alive_enemies()
	return []

func _get_enemy_entity_id(enemy_pool_index: int) -> String:
	## Get entity ID for enemy (use SpawnDirector if available)
	var game_orchestrator = get_node_or_null("/root/GameOrchestrator")
	if game_orchestrator:
		var sd = game_orchestrator.get_spawn_director()
		if sd and sd.has_method("get_enemy_entity_id"):
			return sd.get_enemy_entity_id(enemy_pool_index)
	return "enemy_" + str(enemy_pool_index)

func _register_enemy_entity(entity_id: String, enemy: EnemyEntity) -> void:
	## Auto-register enemy with DamageService
	var entity_data = {
		"id": entity_id,
		"type": "enemy",
		"hp": enemy.hp,
		"max_hp": enemy.hp,
		"alive": true,
		"pos": enemy.pos
	}
	DamageService.register_entity(entity_id, entity_data)

func _register_boss_entity(boss_id: String, boss: Node) -> void:
	## Auto-register boss with DamageService
	var entity_data = {
		"id": boss_id,
		"type": "boss",
		"hp": boss.get_current_health() if boss.has_method("get_current_health") else 200.0,
		"max_hp": boss.get_max_health() if boss.has_method("get_max_health") else 200.0,
		"alive": boss.is_alive() if boss.has_method("is_alive") else true,
		"pos": boss.global_position
	}
	DamageService.register_entity(boss_id, entity_data)
```

### 2.6: Update _on_combat_step()

**Old code:**
```gdscript
func _on_combat_step(payload) -> void:
	_update_cooldown(payload.dt)  # ❌ Remove (now handled by AbilityComponent)
	_update_attack_effects(payload.dt)
	_handle_auto_attack()  # ❌ Remove (now handled by AbilityComponent)
```

**New code:**
```gdscript
func _on_combat_step(payload) -> void:
	# Only update visual effects now (cooldowns handled by ability system)
	_update_attack_effects(payload.dt)
```

### 2.7: Remove Unused Methods

**❌ DELETE these methods (no longer needed):**
```gdscript
# func _update_cooldown(dt: float)  # Cooldowns handled by AbilityComponent
# func can_attack() -> bool  # Cooldowns handled by AbilityComponent
# func _calculate_damage() -> float  # Damage in ability .tres
# func _get_effective_attack_speed() -> float  # In ability .tres
# func _get_effective_range() -> float  # In ability .tres
# func _get_effective_cone_angle() -> float  # In ability .tres
# func _get_effective_knockback_distance() -> float  # In ability .tres
# func _handle_auto_attack() -> void  # Handled by AbilityComponent
# func set_auto_attack_enabled(enabled: bool)  # Not needed
# func set_auto_attack_target(target_pos: Vector2)  # Not needed
# func get_attack_stats() -> Dictionary  # Not needed
# func _load_balance_values()  # Values in ability .tres
# func _on_balance_reloaded()  # Not needed
```

**✅ KEEP these methods (core logic):**
```gdscript
# _is_enemy_in_cone()  # Cone detection math
# _find_bosses_in_cone_via_damage_service()  # Boss detection
# _spawn_attack_effect()  # Visual effects
# _find_free_attack_effect()  # Visual effects
# _update_attack_effects()  # Visual effects
# get_active_attack_effects()  # Visual effects
# _initialize_attack_effects_pool()  # Visual effects
```

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
                                    → Cone detection (reused logic)
                                    → DamageService.apply_damage()
```

**What You Preserved:**
- ✅ Production-quality cone detection math
- ✅ Visual effects system
- ✅ DamageService integration
- ✅ Boss + pooled enemy support
- ✅ 30Hz deterministic timing

**What You Gained:**
- ✅ Unified ability management
- ✅ Tome modifier support
- ✅ Level-up progression
- ✅ Hot-reload via .tres resources
- ✅ Consistent auto-cast behavior

---

**See Also:**
- `/Obsidian/03-tasks/2_ABILITIES_system_implementation.md` Phase 5
- `/Obsidian/02-brainstorm/ability-system/ability-system-architecture-REVISED.md`
