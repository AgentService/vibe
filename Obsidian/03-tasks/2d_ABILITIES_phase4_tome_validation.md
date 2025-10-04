# [SUBTASK] Ability System - Phase 4: Tome System Validation

**Parent Task:** `2_ABILITIES_system_implementation.md`
**Phase:** 4 of 4 (Final Phase 1 task)
**Status:** 📋 Not Started
**Estimated Time:** 2-3 hours
**Depends On:** Phase 1.3 (Vertical Slice) must be complete

---

## 🎯 Phase Goal

Create 2 realistic tomes and verify they correctly modify Ranger Arrow.
Validate modifier system with DPS/TTK measurements.

---

## ✅ Tasks

### Task 1.4.1: Create TomeManager Singleton (~1 hour)

**File:** `autoload/TomeManager.gd`

**Requirements:**
- [ ] Create file at `autoload/TomeManager.gd`
- [ ] Extend `Node`
- [ ] Implement tome registry:
  ```gdscript
  var _tome_registry: Dictionary = {}  # {tome_id: BaseTome}
  var _tome_file_paths: Dictionary = {}  # {tome_id: "res://..."}
  ```
- [ ] Implement `_load_all_tomes()` in `_ready()`:
  - Scan `res://data/content/tomes/` directory
  - Load all `.tres` files as BaseTome resources
  - Populate registries
- [ ] Implement `get_definition(tome_id: String) -> BaseTome`
- [ ] Implement `get_file_path(tome_id: String) -> String`
- [ ] Add to project autoloads (`Project → Project Settings → Autoload`)

**Success Criteria:**
- [ ] TomeManager accessible globally
- [ ] Tome registry loads without errors
- [ ] Can retrieve tome definitions by ID

**Testing:**
```gdscript
extends Node

func _ready():
	print("=== TomeManager Test ===")

	await get_tree().create_timer(0.1).timeout

	print("Loaded tomes: ", TomeManager._tome_registry.size())

	var tome = TomeManager.get_definition("tome_damage")
	if tome:
		print("✓ Found tome_damage")
		print("  Name: ", tome.tome_name)
		print("  Damage multiplier: ", tome.damage_multiplier)
	else:
		print("✗ tome_damage not found (will be created in Task 1.4.2)")

	get_tree().quit()
```

---

### Task 1.4.2: Create Tome of Power (Damage +15%) (~30 min)

**File:** `data/content/tomes/tome_damage.tres`

**Requirements:**
- [ ] Create directory: `data/content/tomes/` (if doesn't exist)
- [ ] Create file: `data/content/tomes/tome_damage.tres`
- [ ] Resource type: `BaseTome`
- [ ] Set properties:
  ```tres
  [gd_resource type="Resource" script_class="BaseTome" load_steps=2 format=3]

  [ext_resource type="Script" path="res://scripts/resources/BaseTome.gd" id="1"]

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

**Success Criteria:**
- [ ] Applies to Ranger Arrow (has DAMAGE tag)
- [ ] Increases damage by 15% per stack (15 → 17.25 at 1 stack)
- [ ] Loads in TomeManager registry

**Testing:**
```gdscript
extends Node

func _ready():
	var ability = BaseAbility.new()
	ability.tags = [AbilityTags.DAMAGE]
	ability.base_damage = 15.0

	var tome = TomeManager.get_definition("tome_damage")
	tome.apply_to_ability(ability, 1)

	print("Damage after 1 stack: ", ability.base_damage)  # 17.25
	assert(abs(ability.base_damage - 17.25) < 0.01, "Damage modifier failed")

	tome.apply_to_ability(ability, 2)
	print("Damage after 2 stacks: ", ability.base_damage)  # ~19.84
	# 15.0 * (1.15^2) = 19.8375

	get_tree().quit()
```

---

### Task 1.4.3: Create Tome of Swiftness (Speed +8%) (~30 min)

**File:** `data/content/tomes/tome_speed.tres`

**Requirements:**
- [ ] Create file: `data/content/tomes/tome_speed.tres`
- [ ] Resource type: `BaseTome`
- [ ] Set properties:
  ```tres
  [gd_resource type="Resource" script_class="BaseTome" load_steps=2 format=3]

  [ext_resource type="Script" path="res://scripts/resources/BaseTome.gd" id="1"]

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

**Success Criteria:**
- [ ] Applies to Player movement speed (not abilities)
- [ ] Increases movement speed by 8% per stack
- [ ] Loads in TomeManager registry

**Testing:**
```gdscript
extends Node

func _ready():
	var player = Node2D.new()
	player.set("movement_speed", 100.0)

	var tome = TomeManager.get_definition("tome_speed")
	tome.apply_to_player(player, 1)

	print("Movement speed after 1 stack: ", player.movement_speed)  # 108.0
	assert(abs(player.movement_speed - 108.0) < 0.01, "Speed modifier failed")

	tome.apply_to_player(player, 2)
	print("Movement speed after 2 stacks: ", player.movement_speed)  # ~116.64
	# 100.0 * (1.08^2) = 116.64

	get_tree().quit()
```

---

### Task 1.4.4: Test Tome Application & DPS Validation (~1 hour)

**File:** Extend `tests/ability_system/RangerArrow_Isolated.tscn`

**Requirements:**
- [ ] Open existing test scene from Phase 1.3
- [ ] Modify script to test 3 scenarios:

**Scenario 1: Ranger Arrow Only (Baseline)**
- Ranger Arrow (15 dmg, 1.0s cooldown)
- Expected DPS: 15 / 1.0 = **15 DPS**
- Expected TTK (100 HP enemy): 100 / 15 DPS ≈ **6.67 seconds**

**Scenario 2: Ranger Arrow + Tome of Power (×1)**
- Ranger Arrow (17.25 dmg, 1.0s cooldown)
- Expected DPS: 17.25 / 1.0 = **17.25 DPS**
- Expected TTK (100 HP enemy): 100 / 17.25 DPS ≈ **5.8 seconds**

**Scenario 3: Ranger Arrow + Tome of Power (×2)**
- Ranger Arrow (19.84 dmg, 1.0s cooldown)
- Expected DPS: 19.84 / 1.0 = **19.84 DPS**
- Expected TTK (100 HP enemy): 100 / 19.84 DPS ≈ **5.04 seconds**

**Implementation:**
```gdscript
extends Node2D

@onready var player = $Player
var test_scenario: int = 1  # 1, 2, or 3

var start_time: float = 0.0
var enemy_killed_time: float = 0.0

func _ready():
	print("=== Tome DPS Validation Test ===")
	print("Scenario: %d" % test_scenario)

	# Equip Ranger Arrow
	var arrow = AbilityManager.create_ability_instance("ranger_arrow")

	# Apply tomes based on scenario
	match test_scenario:
		1:  # Baseline
			print("Baseline (no tomes)")
		2:  # 1 stack Tome of Power
			var tome = TomeManager.get_definition("tome_damage")
			tome.apply_to_ability(arrow, 1)
			print("Applied Tome of Power ×1")
		3:  # 2 stacks Tome of Power
			var tome = TomeManager.get_definition("tome_damage")
			tome.apply_to_ability(arrow, 2)
			print("Applied Tome of Power ×2")

	print("Final damage: %.2f" % arrow.base_damage)
	print("Final cooldown: %.2f" % arrow.cooldown)

	player.ability_slots[0] = arrow
	player.ability_cooldowns[0] = 0.0

	# Spawn single enemy with 100 HP
	var enemy = preload("res://scenes/enemies/TestEnemy.tscn").instantiate()
	enemy.max_hp = 100.0
	enemy.current_hp = 100.0
	enemy.global_position = Vector2(300, 0)
	add_child(enemy)

	EventBus.enemy_killed.connect(_on_enemy_killed)
	start_time = Time.get_ticks_msec() / 1000.0

func _on_enemy_killed(enemy_id, position):
	enemy_killed_time = (Time.get_ticks_msec() / 1000.0) - start_time
	print("Enemy killed in %.2fs" % enemy_killed_time)

	# Expected TTK per scenario
	var expected_ttk_map = {
		1: 6.67,  # 100 HP / 15 DPS
		2: 5.8,   # 100 HP / 17.25 DPS
		3: 5.04,  # 100 HP / 19.84 DPS
	}

	var expected_ttk = expected_ttk_map[test_scenario]
	var ttk_diff = abs(enemy_killed_time - expected_ttk)

	print("Expected TTK: %.2fs" % expected_ttk)
	print("Difference: %.2fs" % ttk_diff)

	if ttk_diff < 0.5:  # ±0.5s margin
		print("✓ TTK within expected range")
	else:
		print("✗ TTK outside expected range")

	get_tree().quit()
```

**Success Criteria:**
- [ ] Scenario 1 (baseline): TTK ≈ 6.67s (±0.5s)
- [ ] Scenario 2 (×1 tome): TTK ≈ 5.8s (±0.5s)
- [ ] Scenario 3 (×2 tome): TTK ≈ 5.04s (±0.5s)
- [ ] All scenarios run without errors
- [ ] Tome modifiers visibly affect damage output

**Testing:**
Run each scenario:
```bash
# Scenario 1: Baseline
../Godot_v4.4.1-stable_win64_console.exe --headless tests/ability_system/RangerArrow_Isolated.tscn --quit-after 10

# Scenario 2: Change test_scenario = 2 in script, then:
../Godot_v4.4.1-stable_win64_console.exe --headless tests/ability_system/RangerArrow_Isolated.tscn --quit-after 10

# Scenario 3: Change test_scenario = 3 in script, then:
../Godot_v4.4.1-stable_win64_console.exe --headless tests/ability_system/RangerArrow_Isolated.tscn --quit-after 10
```

**Alternative:** Create 3 separate test scenes (Scenario1.tscn, Scenario2.tscn, Scenario3.tscn) for easier batch testing.

---

## 📊 Phase 1.4 Completion Checklist

- [ ] TomeManager applies stat modifications correctly
- [ ] Tome of Power increases damage by 15% per stack
- [ ] Tome of Swiftness increases movement speed by 8% per stack
- [ ] Multiple tomes stack correctly (multiplicative)
- [ ] TTK measurements match expected values (±5% margin)
- [ ] No performance degradation
- [ ] No errors/warnings in console

---

## 🧪 Final Validation (End of Phase 1.4 = END OF PHASE 1)

**Full integration test:**

Create `tests/ability_system/Phase1_Final_Integration_Test.tscn`:

```gdscript
extends Node2D

@onready var player = $Player

func _ready():
	print("=== PHASE 1 FINAL INTEGRATION TEST ===")

	# Test 1: Ability loading
	var arrow = AbilityManager.create_ability_instance("ranger_arrow")
	assert(arrow != null, "Ranger Arrow not loaded")
	print("✓ Ability loading")

	# Test 2: Tome loading
	var tome_dmg = TomeManager.get_definition("tome_damage")
	var tome_spd = TomeManager.get_definition("tome_speed")
	assert(tome_dmg != null, "Tome of Power not loaded")
	assert(tome_spd != null, "Tome of Swiftness not loaded")
	print("✓ Tome loading")

	# Test 3: Tome application
	tome_dmg.apply_to_ability(arrow, 1)
	assert(abs(arrow.base_damage - 17.25) < 0.01, "Damage modifier failed")
	print("✓ Tome ability modification")

	# Test 4: Player integration
	player.ability_slots[0] = arrow
	player.ability_cooldowns[0] = 0.0
	await get_tree().create_timer(1.5).timeout
	assert(player.ability_cooldowns[0] > 0.0, "Ability not auto-cast")
	print("✓ Player auto-cast")

	# Test 5: Projectile spawn
	var projectiles = get_tree().get_nodes_in_group("ability_projectiles")
	assert(projectiles.size() > 0, "No projectiles spawned")
	print("✓ Projectile spawning")

	# Test 6: Damage dealing
	var enemy = preload("res://scenes/enemies/TestEnemy.tscn").instantiate()
	enemy.max_hp = 100.0
	enemy.current_hp = 100.0
	enemy.global_position = Vector2(200, 0)
	add_child(enemy)

	await get_tree().create_timer(10.0).timeout

	var enemies_alive = get_tree().get_nodes_in_group("enemies").size()
	assert(enemies_alive == 0, "Enemy not killed")
	print("✓ Damage dealing & enemy death")

	print("\n✓✓✓ ALL PHASE 1 TESTS PASSED ✓✓✓")
	print("Ability System Phase 1 COMPLETE!")
	get_tree().quit(0)
```

Run:
```bash
../Godot_v4.4.1-stable_win64_console.exe --headless tests/ability_system/Phase1_Final_Integration_Test.tscn --quit-after 15
```

Expected output:
```
=== PHASE 1 FINAL INTEGRATION TEST ===
✓ Ability loading
✓ Tome loading
✓ Tome ability modification
✓ Player auto-cast
✓ Projectile spawning
✓ Damage dealing & enemy death

✓✓✓ ALL PHASE 1 TESTS PASSED ✓✓✓
Ability System Phase 1 COMPLETE!
```

---

## 📝 Phase 1 Completion Actions

**When all Phase 1.4 tasks complete:**

1. **Update CHANGELOG.md:**
   ```markdown
   ## [2025-10-XX] Ability System Phase 1 Complete

   ### Added
   - BaseAbility class with level-up progression system
   - ProjectileAbility subclass with fire patterns
   - BaseTome class with ability/player stat modifiers
   - AbilityManager singleton (ability registry & loading)
   - TomeManager singleton (tome registry & loading)
   - Player ability slots (4 slots) + auto-cast system
   - Player tome slots (4 slots) with modifier application
   - Ranger Arrow ability (first vertical slice)
   - Tome of Power (damage +15%)
   - Tome of Swiftness (movement speed +8%)
   - Ability projectile pooling system
   - Debug ability display (cooldown timers)

   ### Technical
   - Tag-based applicability system (~15 tags)
   - 30Hz combat step integration
   - DamageService integration for ability damage
   - Headless test suite (Foundation, Integration, Vertical Slice, Tome Validation)

   ### Performance
   - 60+ projectiles at 60 FPS (MultiMesh rendering)
   - 30Hz combat step remains stable
   - No memory leaks (projectile pooling confirmed)
   ```

2. **Update documentation (if needed):**
   - `/Obsidian/systems/ability-system.md` (if architecture changed)
   - `/Obsidian/current_state/PROJECT_STATE_ASSESSMENT.md` (note Phase 1 complete)

3. **Create git commit:**
   ```bash
   git add .
   git commit -m "feat(abilities): complete Phase 1 - foundation, Ranger Arrow, tome system

   - Implement BaseAbility + ProjectileAbility classes
   - Add AbilityManager + TomeManager singletons
   - Wire player ability slots + auto-cast
   - Create Ranger Arrow ability (15 dmg, 1.0s CD)
   - Create Tome of Power (dmg +15%) + Tome of Swiftness (speed +8%)
   - All isolated tests passing
   - DPS/TTK measurements validated (±5%)

   Phase 1 complete: 4 subtasks, 13-18 hours estimated, fully functional.
   Next: Phase 2 (Expand Ability Library)"
   ```

---

## ⏭️ Next Steps (Post-Phase 1)

**Phase 2 (Future):**
- Expand ability library (Fireball, Lightning, Sword Slash, Buff Aura)
- Create 5-10 more tomes (elemental, AoE, pierce, projectile count)
- Test different ability archetypes (AoE, Buff, Orbit)

**Phase 3 (Future):**
- Wire into existing level-up modal
- Generate upgrade options (abilities + tomes)
- Implement ability re-picking (level up existing)

**Phase 4 (Future):**
- MetaProgression integration (quest → discover → unlock)
- Shop system integration
- Persist unlocked abilities/tomes

---

**Status:** Ready to begin Task 1.4.1 (TomeManager)
