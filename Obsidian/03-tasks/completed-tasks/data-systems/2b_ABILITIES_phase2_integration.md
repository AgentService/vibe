# [SUBTASK] Ability System - Phase 2: Ability Manager & Player Integration

**Parent Task:** `2_ABILITIES_system_implementation.md`
**Phase:** 2 of 4
**Status:** ✅ Complete (Code Verified 2025-10-14)
**Estimated Time:** 3-4 hours
**Depends On:** Phase 1.1 (Foundation) ✅ Complete

> **2025-10-14 CODE INSPECTION:** Phase 1.2 integration verified as complete:
> - AbilityController.gd: Component class (RefCounted) with 4 ability slots + 4 tome slots
> - EventBus signal consumers: ability_acquired, tome_acquired connected in _ready()
> - Auto-casting at 30Hz via combat_step signal
> - Memory leak prevention with proper signal cleanup in _notification(NOTIFICATION_PREDELETE)
> - Located at: scripts/systems/AbilityController.gd (434 lines)

---

## 🎯 Phase Goal

Wire ability slots into Player and create manager for cooldown tracking.
Integrate with Arena's 30Hz combat step for auto-cast system.

---

## 🏗️ Architecture Reminder (Phase 1.1 Refactor)

**This phase follows the Phase 1.1 baseline vs computed stats architecture:**

- **base_damage, base_cooldown, etc.** → Immutable baseline values (never modified after level-up)
- **final_damage, final_cooldown, etc.** → Computed values (base × modifiers, recalculated on modifier changes)
- **TomeModifier descriptors** → Stored in `_tome_modifiers` array, applied via `_recalculate_final_stats()`
- **Idempotent replacement** → Same tome_id replaces old modifier (not exponential stacking)

**Key Pattern:**
```gdscript
# ✓ Correct: Use final_damage for computed output
var damage_to_deal = ability.final_damage  # Includes tome modifiers

# ✗ Wrong: Don't mutate base_damage directly (except for level-up)
ability.base_damage *= 1.15  # BUG - breaks baseline immutability
```

---

## ✅ Tasks

### Task 1.2.1: Create AbilityManager Singleton (~1.5 hours)

**File:** `autoload/AbilityManager.gd`

**Requirements:**
- [ ] Create file at `autoload/AbilityManager.gd`
- [ ] Extend `Node`
- [ ] Implement ability registry:
  ```gdscript
  var _ability_registry: Dictionary = {}  # {ability_id: BaseAbility}
  var _ability_file_paths: Dictionary = {}  # {ability_id: "res://..."}
  var _ability_categories: Dictionary = {}  # {ability_id: "projectile"}
  ```
- [ ] Implement `_load_all_abilities()` in `_ready()`:
  - Scan `res://data/content/abilities/` subdirectories (projectile/, aoe/, melee/, etc.)
  - Load all `.tres` files as BaseAbility resources
  - Call `validate()` on each loaded ability and log warnings
  - Populate registries
- [ ] Implement `get_definition(ability_id: String) -> BaseAbility`
- [ ] Implement `create_ability_instance(ability_id: String) -> BaseAbility`:
  - Return `definition.duplicate(true)` for player modification
- [ ] Implement `get_file_path(ability_id: String) -> String`
- [ ] Implement `get_abilities_in_category(category: String) -> Array[String]`
- [ ] Add to project autoloads (`Project → Project Settings → Autoload`)

**Success Criteria:**
- [ ] AbilityManager accessible globally
- [ ] Ability registry loads without errors
- [ ] Can create instances from definitions
- [ ] Instances are independent (modifying one doesn't affect registry)

**Testing:**
Create test scene:
```gdscript
extends Node

func _ready():
	print("=== AbilityManager Test ===")

	# Wait for autoload to load abilities
	await get_tree().create_timer(0.1).timeout

	print("Loaded abilities: ", AbilityManager._ability_registry.size())

	var definition = AbilityManager.get_definition("ranger_arrow")
	if definition:
		print("✓ Found ranger_arrow definition")

		var instance1 = AbilityManager.create_ability_instance("ranger_arrow")
		var instance2 = AbilityManager.create_ability_instance("ranger_arrow")

		# Test baseline vs computed stats separation (Phase 1.1 architecture)
		# Baseline (base_damage) is immutable, computed (final_damage) includes modifiers
		instance1.base_damage = 15.0  # Set immutable baseline
		instance1._recalculate_final_stats()
		print("Instance 1 base_damage: ", instance1.base_damage)    # 15.0
		print("Instance 1 final_damage: ", instance1.final_damage)  # 15.0 (no modifiers)
		print("Instance 2 base_damage: ", instance2.base_damage)    # Original value
		print("Definition base_damage: ", definition.base_damage)   # Original value

		# Test that instances are independent (modifying instance1 doesn't affect instance2)
		if instance2.base_damage != instance1.base_damage and definition.base_damage == instance2.base_damage:
			print("✓ Instances are independent")
		else:
			print("✗ Instances are NOT independent - duplicate() failed")
	else:
		print("✗ ranger_arrow not found (will be created in Phase 1.3)")

	get_tree().quit()
```

**Note:** This test will partially fail until ranger_arrow.tres exists (Phase 1.3).
You can create a dummy ability .tres file for testing if needed.

---

### Task 1.2.2: Add Ability Slots to Player.gd (~1 hour)

**File:** `scenes/player/Player.gd` (or `scripts/systems/Player.gd` - verify current location)

**Requirements:**
- [ ] Locate Player.gd file (use Glob or Grep to find it)
- [ ] Add ability system properties:
  ```gdscript
  # === Ability System ===
  var ability_slots: Array[BaseAbility] = [null, null, null, null]
  var ability_cooldowns: Array[float] = [0.0, 0.0, 0.0, 0.0]

  # === Tome System ===
  var tome_slots: Array[BaseTome] = [null, null, null, null]
  var tome_stacks: Array[int] = [0, 0, 0, 0]
  ```
- [ ] Add to `_process(delta)`:
  ```gdscript
  _update_ability_cooldowns(delta)
  _auto_cast_ready_abilities()
  ```
- [ ] Implement `_update_ability_cooldowns(delta: float)`
- [ ] Implement `_auto_cast_ready_abilities()`
- [ ] Implement `_activate_ability(slot_index: int)`
- [ ] Implement `equip_ability(ability_id: String, slot: int = -1)`
- [ ] Implement `level_up_ability(ability_id: String, levels: int = 1)`
- [ ] Implement `equip_tome(tome: BaseTome)`
- [ ] Implement `_apply_tome_to_all_abilities(tome, stack_count)`
- [ ] Implement `_apply_tome_to_player(tome, stack_count)`
- [ ] Implement helper functions:
  - `find_ability_slot(ability_id) -> int`
  - `_find_empty_ability_slot() -> int`
  - `find_tome_slot(tome_id) -> int`
  - `_find_empty_tome_slot() -> int`

**Success Criteria:**
- [ ] Player has 4 ability slots + 4 tome slots
- [ ] Can equip abilities to specific slots
- [ ] Auto-cast fires abilities on cooldown
- [ ] Empty slots safely ignored (no null errors)
- [ ] Tomes apply to all equipped abilities when added

**Testing:**
Create test scene with Player node:
```gdscript
extends Node

@onready var player = $Player

func _ready():
	print("=== Player Ability Slots Test ===")

	# Create dummy ability
	var ability = BaseAbility.new()
	ability.ability_id = "test_ability"
	ability.ability_name = "Test Ability"
	ability.base_damage = 10.0
	ability.cooldown = 1.0
	ability.tags = [AbilityTags.DAMAGE]

	# Equip to slot 0
	player.ability_slots[0] = ability
	player.ability_cooldowns[0] = 0.0

	print("Equipped ability: ", player.ability_slots[0].ability_name)

	# Wait 1 second (should auto-cast)
	await get_tree().create_timer(1.1).timeout

	print("Cooldown after 1s: ", player.ability_cooldowns[0])
	# Should be ≈1.0 (ability just fired, cooldown reset)

	get_tree().quit()
```

---

### Task 1.2.3: Add Debug Display (~30 min)

**File:** `scripts/ui/debug/DebugAbilityDisplay.gd`

**Requirements:**
- [ ] Create file at `scripts/ui/debug/DebugAbilityDisplay.gd`
- [ ] Extend `Label`
- [ ] In `_process(delta)`:
  - Get player reference (via `get_tree().get_first_node_in_group("player")`)
  - Build display string showing:
    - Equipped abilities (name + level)
    - Current cooldowns (countdown timers)
    - Equipped tomes (name + stack count)
  - Update label text
- [ ] Add to Player scene as child:
  - Create Label node in `scenes/player/Player.tscn`
  - Attach script `scripts/ui/debug/DebugAbilityDisplay.gd`
  - Position above player (Y offset -100)
  - Set label settings (monospace font, white text, black outline)

**Success Criteria:**
- [ ] Can see ability names + cooldown timers in real-time
- [ ] Display updates correctly as abilities activate
- [ ] Shows tome information
- [ ] Readable against game background

**Example Display:**
```
[Abilities]
[0] Ranger Arrow Lv3 (CD: 0.5s)
[1] Fireball Lv1 (CD: READY)
[2] Empty
[3] Empty

[Tomes]
[0] Tome of Power ×3
[1] Tome of Swiftness ×1
[2] Empty
[3] Empty
```

**Testing:**
Equip abilities manually, run scene, verify display updates every frame.

---

### Task 1.2.4: Wire Arena 30Hz Combat Step (~30 min)

**File:** `scripts/systems/Arena.gd` (existing file)

**Requirements:**
- [ ] Locate Arena.gd file
- [ ] Find existing 30Hz combat step implementation (should exist from previous tasks)
- [ ] Verify `EventBus.combat_step` signal is emitted every 30Hz tick
- [ ] If combat_step signal DOESN'T exist:
  - Add signal to EventBus: `signal combat_step(delta: float)`
  - Emit in Arena's fixed timestep loop: `EventBus.combat_step.emit(FIXED_DELTA)`

**Success Criteria:**
- [ ] `EventBus.combat_step` emits at 30Hz (every ~0.033s)
- [ ] AbilityManager can connect to signal for future cooldown tracking
- [ ] No performance degradation (30Hz stays stable)

**Testing:**
```gdscript
extends Node

var tick_count: int = 0
var start_time: float = 0.0

func _ready():
	EventBus.combat_step.connect(_on_combat_step)
	start_time = Time.get_ticks_msec() / 1000.0

	await get_tree().create_timer(1.0).timeout

	var elapsed = (Time.get_ticks_msec() / 1000.0) - start_time
	var expected_ticks = int(elapsed * 30)
	var tick_diff = abs(tick_count - expected_ticks)

	print("=== Combat Step Test ===")
	print("Elapsed: %.2fs" % elapsed)
	print("Ticks received: %d" % tick_count)
	print("Expected ticks: %d" % expected_ticks)
	print("Difference: %d" % tick_diff)

	if tick_diff <= 2:  # Allow ±2 tick margin
		print("✓ 30Hz combat step OK")
	else:
		print("✗ Combat step timing OFF")

	get_tree().quit()

func _on_combat_step(delta: float):
	tick_count += 1
```

---

## 📊 Phase 1.2 Completion Checklist

- [ ] AbilityManager loads ability registry correctly
- [ ] Can create independent ability instances
- [ ] Player has 4 ability slots
- [ ] Auto-cast fires abilities on cooldown
- [ ] Debug display shows live cooldown state
- [ ] Arena combat step integration works (30Hz signal)
- [ ] No performance degradation (verify 30Hz stays stable)
- [ ] No errors/warnings in console

---

## 🧪 Final Validation (End of Phase 1.2)

**Create integration test scene:**
`tests/ability_system/Phase2_Integration_Test.tscn`

Setup:
- Add Player node to scene
- Add Arena node (or mock combat step emitter)
- Add debug Label child to Player

Script:
```gdscript
extends Node

@onready var player = $Player

func _ready():
	print("=== Phase 1.2 Integration Validation ===")

	# Create test ability
	var ability = BaseAbility.new()
	ability.ability_id = "test_auto_cast"
	ability.ability_name = "Test Auto Cast"
	ability.cooldown = 0.5  # Fire every 0.5s
	ability.tags = [AbilityTags.DAMAGE]

	player.ability_slots[0] = ability
	player.ability_cooldowns[0] = 0.0

	# Count activations over 2 seconds
	var activation_count = 0
	EventBus.ability_activated.connect(func(id): activation_count += 1)

	await get_tree().create_timer(2.0).timeout

	print("Activations in 2s: ", activation_count)
	# Expected: ~4 (2.0s / 0.5s cooldown = 4 casts)

	if activation_count >= 3 and activation_count <= 5:
		print("✓✓✓ AUTO-CAST WORKING ✓✓✓")
	else:
		print("✗ Auto-cast timing incorrect")

	get_tree().quit()
```

---

## 📝 Notes

- If Player.gd doesn't exist at expected location, use Glob to find it
- Arena.gd combat step should already exist from previous combat tasks
- Debug display is optional (can be disabled for release builds)
- Commit after each task: `feat: add AbilityManager singleton`

---

## ⏭️ Next Phase

**After Phase 1.2 complete → `2c_ABILITIES_phase3_vertical_slice.md`**

---

**Status:** Ready to begin Task 1.2.1 (AbilityManager)
