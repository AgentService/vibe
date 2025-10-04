# [SUBTASK] Ability System - Phase 3: First Vertical Slice (Ranger Arrow)

**Parent Task:** `2_ABILITIES_system_implementation.md`
**Phase:** 3 of 4
**Status:** 📋 Not Started
**Estimated Time:** 4-5 hours
**Depends On:** Phase 1.2 (Integration) must be complete

---

## 🎯 Phase Goal

Implement ONE complete ability end-to-end, from .tres definition to damage dealing.
Validate entire ability pipeline: definition → manager → player → auto-cast → projectile → damage → enemy death.

---

## 🔄 Architecture Pattern: Hybrid Spawning & Damage

**This phase implements the hybrid pattern:**

### **Spawning:**
- **ProjectileAbility.activate()** (Resource) → `EventBus.ability_projectile_requested.emit()` ✅
- **ProjectilePool** (Autoload) → Listens to signal and spawns AbilityProjectile entities

### **Damage:**
- **AbilityProjectile._on_enemy_collision()** (Entity) → `DamageService.apply_damage()` direct call ✅
- **NEVER** `EventBus.damage_requested` (removed signal)

**Rationale:** Resources stay decoupled (no singleton access), entities get performance (direct calls), damage has single entry point (DamageService).

---

## ✅ Tasks

### Task 1.3.1: Create EntityPool for High-Frequency Entities (~1.5 hours)

**File:** `autoload/EntityPool.gd` (NEW - unified pooling for projectiles, XP orbs, VFX)

**Requirements:**
- [ ] Create `autoload/EntityPool.gd`
- [ ] Use `ObjectPool` utility (res://scripts/utils/ObjectPool.gd)
- [ ] Implement per-type pooling:
  ```gdscript
  const POOLED_ENTITY_SCENES = {
      "arrow": preload("res://assets/abilities/arrow/arrow_visual.tscn"),
      "fireball": preload("res://assets/abilities/projectile/fireball_visual.tscn"),
      "xp_orb": preload("res://scenes/arena/XPOrb.tscn"),
  }
  ```
- [ ] Pre-warm pools in `_ready()`:
  - Arrows: 100 instances
  - Fireballs: 50 instances
  - XP Orbs: 200 instances (for mass enemy kills)
- [ ] Implement factory/reset callables for each entity type
- [ ] **Pattern:** High-frequency, short-lived entities only (NOT chests/bosses)
- [ ] Connect to `EventBus.ability_projectile_requested` signal
- [ ] Spawn projectile entities from pool when signal received

**Success Criteria:**
- [ ] EntityPool registered as autoload in Project Settings
- [ ] Can spawn arrows, fireballs, and XP orbs via pool
- [ ] Pool reuses entities correctly (acquire/release cycle)
- [ ] Different entity types have separate pools
- [ ] Can handle 100+ simultaneous projectiles without GC stutter
- [ ] XP orb pooling works (test with mass enemy kill)

**Testing:**
```gdscript
extends Node

func _ready():
	print("=== EntityPool Test ===")

	# Test 1: Spawn projectile via signal
	var projectile_data = {
		"visual_scene_key": "arrow",
		"origin": Vector2(100, 100),
		"direction": Vector2.RIGHT,
		"speed": 400.0,
		"damage": 15.0,
	}
	EventBus.ability_projectile_requested.emit(projectile_data)

	await get_tree().create_timer(0.1).timeout

	var projectiles = get_tree().get_nodes_in_group("pooled_projectiles")
	print("Projectiles spawned: ", projectiles.size())

	# Test 2: Check pool stats
	print("Arrow pool available: ", EntityPool._pools["arrow"].available_count())
	print("XP orb pool available: ", EntityPool._pools["xp_orb"].available_count())

	if projectiles.size() > 0:
		print("✓ EntityPool spawning works")
	else:
		print("✗ No projectile spawned")

	get_tree().quit()
```

**Note:** If existing projectile system is incompatible, create simple spawning without pooling as fallback.

---

### Task 1.3.2: Create Arrow Projectile Logic (~1 hour)

**File:** `scripts/entities/AbilityProjectile.gd`

**Requirements:**
- [ ] Create file at `scripts/entities/AbilityProjectile.gd`
- [ ] Extend `Node2D` or `CharacterBody2D` (depending on existing projectile pattern)
- [ ] Add to "ability_projectiles" group
- [ ] Implement properties from projectile_data:
  ```gdscript
  var ability_id: String
  var direction: Vector2
  var speed: float
  var damage: float
  var pierce_count: int
  var lifetime: float
  var is_homing: bool
  var homing_strength: float
  var damage_type: String
  var element: String
  ```
- [ ] Implement `_physics_process(delta)`:
  - Move in direction at speed
  - Decrement lifetime
  - Despawn after lifetime expires
  - Handle homing logic (if enabled)
- [ ] Implement collision detection:
  - Detect enemy hits (use Area2D or existing enemy hitbox system)
  - Emit `EventBus.projectile_hit` on collision
  - Decrement pierce_count
  - Despawn when pierce_count <= 0
- [ ] Implement `setup(projectile_data: Dictionary)` for pool initialization
- [ ] Implement `reset()` for pool recycling

**Success Criteria:**
- [ ] Projectile moves at specified speed
- [ ] Pierces correct number of enemies
- [ ] Despawns after lifetime or max pierce
- [ ] Collision detection works with enemy hitboxes
- [ ] Properly resets when returned to pool

**Testing:**
Create test scene with:
- Single projectile spawned
- Stationary enemy at (300, 0)
- Projectile spawned at (0, 0), direction = Vector2.RIGHT

Expected behavior:
- Projectile moves right at 400 px/s
- Hits enemy at ~0.75s
- `EventBus.projectile_hit` emits
- Projectile despawns (pierce_count = 0)

---

### Task 1.3.3: Create Arrow Visual (~30 min)

**File:** `assets/abilities/arrow/arrow_visual.tscn`

**Requirements:**
- [ ] Create scene file at `assets/abilities/arrow/arrow_visual.tscn`
- [ ] Root node: `Node2D` (or reuse AbilityProjectile as root)
- [ ] Add children:
  - `Sprite2D` (arrow graphic)
  - `Area2D` (collision detection)
  - `CollisionShape2D` (arrow hitbox, child of Area2D)
- [ ] Create placeholder arrow sprite:
  - Use Godot's built-in shapes: Create white triangle
  - Or reuse existing projectile sprite from current game
  - Size: 16×8 pixels
  - Facing right (default direction)
- [ ] Attach script: `scripts/entities/AbilityProjectile.gd`
- [ ] Configure collision:
  - Area2D layer: projectiles (verify existing layer mask)
  - Area2D mask: enemies
  - CollisionShape2D: RectangleShape2D or CircleShape2D

**Success Criteria:**
- [ ] Arrow visible in game
- [ ] Collision shape matches visual
- [ ] Can be instantiated from pool
- [ ] Rotates to match direction of travel

**File Structure:**
```
assets/abilities/arrow/
├── arrow_visual.tscn         # Scene file
└── arrow_placeholder.png     # Sprite (or reuse existing)
```

**Testing:**
Instantiate scene manually, verify:
- Sprite appears
- Collision shape visible in debug (F7 in Godot)
- Script attached and working

---

### Task 1.3.4: Create ranger_arrow.tres (~15 min)

**File:** `data/content/abilities/projectile/ranger_arrow.tres`

**Requirements:**
- [ ] Create directory: `data/content/abilities/projectile/` (if doesn't exist)
- [ ] Create file: `data/content/abilities/projectile/ranger_arrow.tres`
- [ ] Resource type: `ProjectileAbility`
- [ ] Set properties:
  ```tres
  [gd_resource type="Resource" script_class="ProjectileAbility" load_steps=3 format=3]

  [ext_resource type="Script" path="res://scripts/resources/ProjectileAbility.gd" id="1"]
  [ext_resource type="PackedScene" path="res://assets/abilities/arrow/arrow_visual.tscn" id="2"]

  [resource]
  script = ExtResource("1")
  ability_id = "ranger_arrow"
  ability_name = "Ranger Arrow"
  description = "Fire a piercing arrow that deals physical damage"
  ability_level = 1
  max_level = 20
  tags = PackedStringArray("projectile", "damage", "physical", "cooldown")

  base_damage = 15.0
  cooldown = 1.0
  damage_type = "physical"

  projectile_count = 1
  projectile_speed = 600.0
  pierce_count = 0
  max_visual_projectiles = 15

  fire_pattern = "forward"

  visual_scene = ExtResource("2")
  ```

**Success Criteria:**
- [ ] Resource loads in Godot inspector
- [ ] All properties visible and editable
- [ ] Can be assigned to Player ability slot
- [ ] AbilityManager can load this definition

**Testing:**
- Open in Godot Inspector
- Verify all fields populated
- Try loading via `AbilityManager.get_definition("ranger_arrow")`

---

### Task 1.3.5: Wire Damage Dealing (~1 hour)

**File:** `scripts/entities/AbilityProjectile.gd` (projectile handles collision detection)

**Requirements:**
- [ ] Locate existing DamageService autoload (check `autoload/` folder)
- [ ] In `AbilityProjectile._on_enemy_collision(enemy_id)`:
  - [ ] Call `DamageService.apply_damage()` directly (no EventBus signal)
  - [ ] Use method signature: `DamageService.apply_damage(source_id, target_id, damage, tags)`
  ```gdscript
  # AbilityProjectile.gd - ENTITY (has autoload access)
  func _on_enemy_collision(enemy_id: String) -> void:
      # PATTERN: Entities always call DamageService directly (not EventBus)
      DamageService.apply_damage(
          _source_player_id,   # Who shot this projectile
          enemy_id,            # Which enemy was hit
          _damage,             # How much damage
          _damage_tags         # Tags (physical, fire, etc.)
      )
      _on_hit()  # Trigger visual effects, lifetime reduction, etc.
  ```
- [ ] Verify enemy health decreases
- [ ] Verify enemy dies at 0 HP (emits `EventBus.enemy_killed`)
- [ ] **IF DamageService DOESN'T EXIST:** Create minimal damage autoload
  - Create `autoload/DamageService.gd`
  - Implement `apply_damage(source_id: String, target_id: String, damage: float, tags: Array[StringName])`
  - Look up entity in EntityTracker or WaveDirector
  - Reduce entity HP
  - Emit `EventBus.damage_applied` signal (for UI/stats)
  - Emit `EventBus.entity_killed` if HP reaches 0

**Success Criteria:**
- [ ] Arrow hitting enemy deals damage
- [ ] Damage amount matches ability.base_damage
- [ ] Enemy dies after enough hits
- [ ] `EventBus.damage_dealt` emits correctly
- [ ] No errors when projectile hits enemy

**Testing:**
Create test scene:
- Spawn single enemy with 100 HP
- Spawn arrow projectile heading toward enemy
- Verify:
  - Projectile hits enemy
  - Enemy HP = 85 (100 - 15)
  - After 7 hits, enemy dies (100 / 15 ≈ 7 hits)

---

### Task 1.3.6: Create Isolated Test Scene (~1 hour)

**File:** `tests/ability_system/RangerArrow_Isolated.tscn`

**Requirements:**
- [ ] Create test scene at `tests/ability_system/RangerArrow_Isolated.tscn`
- [ ] Add nodes:
  - Player node (with Ranger Arrow equipped in slot 0)
  - 5-10 stationary enemies (arranged in grid pattern)
  - Camera2D (for visual testing)
  - CanvasLayer with debug Label (show damage dealt, enemy HP)
- [ ] Attach script to root node:
  ```gdscript
  extends Node2D

  @onready var player = $Player
  @onready var debug_label = $CanvasLayer/DebugLabel

  var total_damage_dealt: float = 0.0
  var enemies_killed: int = 0

  func _ready():
    print("=== Ranger Arrow Isolated Test ===")

    # Equip Ranger Arrow
    var arrow_ability = AbilityManager.create_ability_instance("ranger_arrow")
    player.ability_slots[0] = arrow_ability
    player.ability_cooldowns[0] = 0.0

    # Connect signals
    EventBus.damage_dealt.connect(_on_damage_dealt)
    EventBus.enemy_killed.connect(_on_enemy_killed)

    # Auto-quit after 15 seconds
    await get_tree().create_timer(15.0).timeout
    _print_results()
    get_tree().quit()

  func _process(delta):
    debug_label.text = "Damage Dealt: %.1f\nEnemies Killed: %d" % [
      total_damage_dealt, enemies_killed
    ]

  func _on_damage_dealt(target_id, amount, source, damage_type):
    total_damage_dealt += amount

  func _on_enemy_killed(enemy_id, position):
    enemies_killed += 1

  func _print_results():
    print("Total Damage: %.1f" % total_damage_dealt)
    print("Enemies Killed: %d" % enemies_killed)

    var enemies_remaining = get_tree().get_nodes_in_group("enemies").size()
    print("Enemies Remaining: %d" % enemies_remaining)

    if enemies_killed > 0:
      print("✓✓✓ RANGER ARROW WORKING ✓✓✓")
    else:
      print("✗ No enemies killed - check damage/collision")
  ```

**Success Criteria:**
- [ ] Can run scene visually (see arrow firing, enemies dying)
- [ ] Can run scene headless: `./Godot.exe --headless tests/ability_system/RangerArrow_Isolated.tscn --quit-after 15`
- [ ] All enemies die within expected time (100 HP ÷ 15 dmg = 7 hits ≈ 7s per enemy)
- [ ] No errors in console
- [ ] No memory leaks (verify via Godot profiler)

---

## 📊 Phase 1.3 Completion Checklist

- [ ] Ranger Arrow projectile spawns correctly
- [ ] Projectile moves at correct speed (600 px/s)
- [ ] Projectile deals damage on hit (15 dmg)
- [ ] Enemies die after enough hits (100 HP / 15 dmg = 7 hits)
- [ ] Auto-cast fires arrow every 1 second
- [ ] Isolated test scene passes (headless + visual)
- [ ] No errors/warnings in console
- [ ] Performance stable (30Hz combat step, 60 FPS rendering)
- [ ] Memory stable (projectiles recycled by pool)

---

## 🧪 Final Validation (End of Phase 1.3)

**Run headless test:**
```bash
../Godot_v4.4.1-stable_win64_console.exe --headless tests/ability_system/RangerArrow_Isolated.tscn --quit-after 15
```

**Expected output:**
```
=== Ranger Arrow Isolated Test ===
Loaded abilities: 1
Equipped Ranger Arrow in slot 0
[... gameplay logs ...]
Total Damage: 750.0
Enemies Killed: 5
Enemies Remaining: 0
✓✓✓ RANGER ARROW WORKING ✓✓✓
```

**Run visual test:**
- Open scene in Godot editor
- Press F6 (run scene)
- Watch arrows fire automatically
- Verify enemies die after ~7 hits each
- Check debug label updates correctly

---

## 📝 Notes

- If projectile pool is incompatible, use simple `instantiate()` spawning as fallback
- If DamageService is missing, create minimal version (can refactor later)
- Stationary enemies are fine for this test (no AI needed)
- Debug label is critical for visual feedback
- Commit after each task: `feat: create ranger_arrow ability`

---

## ⏭️ Next Phase

**After Phase 1.3 complete → `2d_ABILITIES_phase4_tome_validation.md`**

---

**Status:** Ready to begin Task 1.3.1 (Projectile Pool)
