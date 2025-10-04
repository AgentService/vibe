# Ability System - Phase 1 Implementation Plan

**Status:** Planning
**Created:** 2025-10-03
**Target Completion:** TBD
**Dependencies:** [ability-system-architecture.md](ability-system-architecture.md)

---

## Overview

This document breaks down the ability system implementation into concrete, testable phases. Each phase builds on the previous, allowing for early validation and iterative refinement.

**Core Philosophy:**
- Build foundation first, features second
- Test each component in isolation before integration
- Create one complete vertical slice before expanding
- Validate performance assumptions early

**Out of Scope (Phase 1):**
- Gold economy / chest system (separate feature track)
- Meta-progression unlocks (integration happens in Phase 3+)
- Visual effects / polish (basic placeholders only)
- UI/HUD components (minimal debug display only)

---

## Phase Breakdown

### **Phase 1.1: Foundation & Infrastructure** (Est. 4-6 hours)

**Goal:** Create core classes and tag system without any gameplay integration.

#### Tasks:

**1.1.1 - Create Tag System** (~30 min)
- [ ] Create `/scripts/domain/AbilityTags.gd`
- [ ] Define ~15 StringName constants
- [ ] Add tag categories comment block
- [ ] Verify tag constants accessible globally

**Success Criteria:**
- Can reference `AbilityTags.PROJECTILE` in any script
- All tag categories documented inline

**Files Created:**
```
scripts/domain/AbilityTags.gd
```

---

**1.1.2 - Create BaseAbility Class** (~2 hours)
- [ ] Create `/scripts/resources/BaseAbility.gd`
- [ ] Implement all @export properties from architecture doc
- [ ] Implement `level_up()` method with scaling
- [ ] Implement `has_tag()` helper
- [ ] Implement `activate()` stub (push_warning)
- [ ] Add comprehensive class documentation

**Success Criteria:**
- Class loads without errors
- `level_up()` correctly scales damage/cooldown
- `has_tag()` returns correct bool
- Tags array can contain StringName values

**Files Created:**
```
scripts/resources/BaseAbility.gd
```

**Test Approach:**
- Create manual `.tres` file with test values
- Use Godot inspector to verify @export properties appear
- Write simple headless script to test `level_up()` math
  - Start ability at level 1, damage 10, cooldown 2.0
  - Level up 5 times
  - Verify damage = 10 * (1.15^5) ≈ 20.1
  - Verify cooldown = 2.0 * (0.95^5) ≈ 1.55

---

**1.1.3 - Create ProjectileAbility Subclass** (~1 hour)
- [ ] Create `/scripts/resources/ProjectileAbility.gd`
- [ ] Extend BaseAbility
- [ ] Override `activate()` to emit `EventBus.ability_projectile_requested`
- [ ] Add projectile-specific documentation

**Success Criteria:**
- Class extends BaseAbility correctly
- Inspector shows inherited + projectile-specific properties
- `activate()` emits signal with correct payload

**Files Created:**
```
scripts/resources/ProjectileAbility.gd
```

---

**1.1.4 - Create BaseTome Class** (~30 min)
- [ ] Create `/scripts/resources/BaseTome.gd`
- [ ] Implement all @export properties from architecture doc
- [ ] Implement `applies_to_ability()` tag-matching logic
- [ ] Implement `apply_to_ability()` stat modification
- [ ] Add comprehensive documentation

**Success Criteria:**
- Tag matching works correctly (ANY vs ALL logic)
- Stat modifications apply correctly (additive vs multiplicative)
- Can stack multiple tomes on same ability

**Files Created:**
```
scripts/resources/BaseTome.gd
```

**Test Approach:**
- Create test ability with tags `[projectile, fire]`
- Create test tome with `required_tags = [projectile]`
- Verify `applies_to_ability()` returns true
- Apply tome, verify damage multiplier = 1.25
- Apply second tome, verify stacking (additive or multiplicative)

---

**1.1.5 - Add EventBus Signals** (~15 min)
- [ ] Open `autoload/EventBus.gd`
- [ ] Add ability-related signals from architecture doc:
  - `ability_activated`
  - `ability_projectile_requested`
  - `ability_acquired`
  - `ability_leveled_up`
  - `tome_acquired`
  - `tome_applied`

**Success Criteria:**
- All signals defined with typed parameters
- No syntax errors in EventBus

**Files Modified:**
```
autoload/EventBus.gd
```

---

**Phase 1.1 Completion Checklist:**
- [ ] All foundation classes load without errors
- [ ] Tag system accessible globally
- [ ] BaseAbility level-up math validated
- [ ] ProjectileAbility can emit activation signal
- [ ] BaseTome tag matching + stat modification works
- [ ] EventBus signals defined
- [ ] All code documented with class comments

---

### **Phase 1.2: Ability Manager & Player Integration** (Est. 3-4 hours)

**Goal:** Wire ability slots into Player and create manager for cooldown tracking.

#### Tasks:

**1.2.1 - Create AbilityManager Singleton** (~1.5 hours)
- [ ] Create `/autoload/AbilityManager.gd`
- [ ] Implement cooldown tracking dictionary
- [ ] Implement `tick(delta: float)` for cooldown updates
- [ ] Implement `can_activate()` cooldown check
- [ ] Implement `activate_ability()` orchestration
- [ ] Add to project autoloads (`Project Settings → Autoload`)
- [ ] Connect to Arena's 30Hz combat step

**Success Criteria:**
- AbilityManager accessible globally
- Cooldown tracking works correctly (10s → 9.5s → ... → 0s)
- `can_activate()` returns false during cooldown
- Activation triggers cooldown restart

**Files Created:**
```
autoload/AbilityManager.gd
```

**Files Modified:**
```
scripts/systems/Arena.gd (connect combat_step signal)
project.godot (add autoload)
```

**Test Approach:**
- Create test scene with single ability (cooldown = 5.0s)
- Activate ability, verify cooldown starts at 5.0
- Wait 2.5s (75 ticks at 30Hz), verify cooldown = 2.5
- Try activating during cooldown, verify denied
- Wait full cooldown, verify can activate again

---

**1.2.2 - Add Ability Slots to Player.gd** (~1 hour)
- [ ] Add `@export var ability_slots: Array[BaseAbility] = []` (size 4)
- [ ] Add `@export var tome_slots: Array[BaseTome] = []` (size 4)
- [ ] Implement `equip_ability(ability: BaseAbility, slot_index: int)`
- [ ] Implement `equip_tome(tome: BaseTome, slot_index: int)`
- [ ] Implement `_on_combat_step()` to auto-cast abilities
- [ ] Connect to `EventBus.combat_step` signal

**Success Criteria:**
- Player has 4 ability slots + 4 tome slots
- Can equip abilities to specific slots
- Auto-cast fires abilities on cooldown
- Empty slots safely ignored

**Files Modified:**
```
scripts/systems/Player.gd (or scenes/player/Player.gd - check current location)
```

**Test Approach:**
- Create test scene with Player node
- Equip ProjectileAbility to slot 0
- Run scene for 5 seconds
- Verify ability fires automatically based on cooldown
- Verify `EventBus.ability_activated` emits each cycle

---

**1.2.3 - Add Debug Display** (~30 min)
- [ ] Create `DebugAbilityDisplay.gd` Label node
- [ ] Show equipped abilities + current cooldowns
- [ ] Update every frame (or every 0.1s)
- [ ] Add to Player scene as child

**Success Criteria:**
- Can see ability names + cooldown timers in real-time
- Display updates correctly as abilities activate

**Files Created:**
```
scripts/ui/debug/DebugAbilityDisplay.gd
```

**Files Modified:**
```
scenes/player/Player.tscn (add Label child)
```

---

**Phase 1.2 Completion Checklist:**
- [ ] AbilityManager tracks cooldowns correctly
- [ ] Player has 4 ability slots
- [ ] Auto-cast system fires abilities on cooldown
- [ ] Debug display shows live cooldown state
- [ ] Arena combat step integration works
- [ ] No performance degradation (verify 30Hz stays stable)

---

### **Phase 1.3: First Vertical Slice - Ranger Arrow** (Est. 4-5 hours)

**Goal:** Implement ONE complete ability end-to-end, from .tres definition to damage dealing.

#### Tasks:

**1.3.1 - Create Projectile Pool Extension** (~1 hour)
- [ ] Verify existing projectile pool in codebase (likely exists)
- [ ] Extend to support ability-spawned projectiles
- [ ] Ensure pool can handle different projectile types (arrow vs fireball)
- [ ] Add `spawn_ability_projectile(ability_id, origin, direction)` method

**Success Criteria:**
- Projectile pool can spawn ability projectiles
- Pool reuses projectiles correctly (no memory leaks)
- Different projectile types coexist in pool

**Files Modified:**
```
scripts/systems/ProjectilePool.gd (or similar - verify current name)
```

---

**1.3.2 - Create Arrow Projectile Logic** (~1 hour)
- [ ] Create `/scripts/entities/AbilityProjectile.gd`
- [ ] Handle movement (speed, direction)
- [ ] Handle pierce logic (pierce_count)
- [ ] Handle lifetime (despawn after 3s or screen exit)
- [ ] Emit `EventBus.projectile_hit` on collision

**Success Criteria:**
- Projectile moves at specified speed
- Pierces correct number of enemies
- Despawns after lifetime or max pierce
- Collision detection works with enemy hitboxes

**Files Created:**
```
scripts/entities/AbilityProjectile.gd
```

---

**1.3.3 - Create Arrow Visual** (~30 min)
- [ ] Create simple arrow sprite (or use placeholder texture)
- [ ] Create `arrow_visual.tscn` scene
- [ ] Add Sprite2D + Area2D + CollisionShape2D
- [ ] Add script reference to `AbilityProjectile.gd`

**Success Criteria:**
- Arrow visible in game
- Collision shape matches visual
- Can be instantiated from pool

**Files Created:**
```
assets/abilities/arrow/arrow_visual.tscn
assets/abilities/arrow/arrow_placeholder.png (or reuse existing sprite)
```

---

**1.3.4 - Create Ranger Arrow .tres** (~15 min)
- [ ] Create `/data/content/abilities/projectile/ranger_arrow.tres`
- [ ] Set properties:
  - `ability_id = "ranger_arrow"`
  - `ability_name = "Ranger Arrow"`
  - `tags = [AbilityTags.PROJECTILE, AbilityTags.PHYSICAL, AbilityTags.DAMAGE]`
  - `base_damage = 15.0`
  - `cooldown = 1.0`
  - `projectile_count = 1`
  - `projectile_speed = 600.0`
  - `pierce_count = 0`
  - `visual_scene = arrow_visual.tscn`

**Success Criteria:**
- Resource loads in Godot inspector
- All properties visible and editable
- Can be assigned to Player ability slot

**Files Created:**
```
data/content/abilities/projectile/ranger_arrow.tres
```

---

**1.3.5 - Wire Damage Dealing** (~1 hour)
- [ ] Connect `EventBus.projectile_hit` → damage dealing
- [ ] Extract damage from ability properties
- [ ] Call `DamageService.deal_damage()` with correct payload
- [ ] Verify enemy health decreases
- [ ] Verify enemy dies at 0 HP

**Success Criteria:**
- Arrow hitting enemy deals damage
- Damage amount matches ability.base_damage
- Enemy dies after enough hits
- `EventBus.damage_dealt` emits correctly

**Files Modified:**
```
scripts/systems/DamageSystem.gd (or DamageService.gd - verify current name)
```

**Test Approach:**
- Spawn single enemy with 100 HP
- Equip Ranger Arrow to Player
- Run scene for 10 seconds
- Count arrow hits (should fire every 1s = ~10 shots)
- Verify enemy health = 100 - (15 * num_hits)
- Verify enemy despawns when HP ≤ 0

---

**1.3.6 - Create Isolated Test Scene** (~30 min)
- [ ] Create `/tests/ability_system/RangerArrow_Isolated.tscn`
- [ ] Add Player node with Ranger Arrow equipped
- [ ] Add 5-10 stationary enemies
- [ ] Add debug display (cooldowns, damage dealt, enemy HP)
- [ ] Run for 10 seconds, auto-quit

**Success Criteria:**
- Can run scene headless: `./Godot.exe --headless tests/ability_system/RangerArrow_Isolated.tscn --quit-after 10`
- All enemies die within expected time (100 HP ÷ 15 dmg = 7 hits = 7s)
- No errors in console
- No memory leaks (verify via Godot profiler)

**Files Created:**
```
tests/ability_system/RangerArrow_Isolated.tscn
```

---

**Phase 1.3 Completion Checklist:**
- [ ] Ranger Arrow projectile spawns correctly
- [ ] Projectile moves at correct speed
- [ ] Projectile deals damage on hit
- [ ] Enemies die after enough hits
- [ ] Auto-cast fires arrow every 1 second
- [ ] Isolated test scene passes (headless + visual)
- [ ] No errors/warnings in console
- [ ] Performance stable (30Hz combat step)

---

### **Phase 1.4: Tome System Validation** (Est. 2-3 hours)

**Goal:** Create 2 tomes and verify they correctly modify Ranger Arrow.

#### Tasks:

**1.4.1 - Create TomeManager Singleton** (~1 hour)
- [ ] Create `/autoload/TomeManager.gd`
- [ ] Implement `apply_tomes_to_ability(ability, tome_list)`
- [ ] Implement additive stat stacking logic
- [ ] Implement multiplicative modifier logic
- [ ] Add debug logging for stat changes

**Success Criteria:**
- Can apply multiple tomes to same ability
- Stat modifications stack correctly
- Original ability.base_damage preserved (modifications applied to derived stats)

**Files Created:**
```
autoload/TomeManager.gd
```

**Files Modified:**
```
project.godot (add autoload)
```

---

**1.4.2 - Create Tome: Power (Damage +25%)** (~30 min)
- [ ] Create `/data/content/tomes/tome_power.tres`
- [ ] Set properties:
  - `tome_id = "tome_power"`
  - `tome_name = "Tome of Power"`
  - `required_tags = [AbilityTags.DAMAGE]`
  - `tag_match_mode = ANY`
  - `damage_multiplier = 1.25`

**Success Criteria:**
- Applies to Ranger Arrow (has DAMAGE tag)
- Increases damage by 25% (15 → 18.75)

**Files Created:**
```
data/content/tomes/tome_power.tres
```

---

**1.4.3 - Create Tome: Swiftness (Cooldown -20%)** (~30 min)
- [ ] Create `/data/content/tomes/tome_swiftness.tres`
- [ ] Set properties:
  - `tome_id = "tome_swiftness"`
  - `tome_name = "Tome of Swiftness"`
  - `required_tags = [AbilityTags.COOLDOWN]`
  - `tag_match_mode = ANY`
  - `cooldown_multiplier = 0.8`

**Success Criteria:**
- Applies to Ranger Arrow (has COOLDOWN tag)
- Reduces cooldown by 20% (1.0s → 0.8s)

**Files Created:**
```
data/content/tomes/tome_swiftness.tres
```

---

**1.4.4 - Test Tome Application** (~1 hour)
- [ ] Extend isolated test scene
- [ ] Equip Ranger Arrow + Tome of Power
- [ ] Verify damage increases to 18.75 (or 19 if rounded)
- [ ] Equip both tomes
- [ ] Verify damage = 18.75 AND cooldown = 0.8s
- [ ] Verify DPS increase: (15 / 1.0 = 15 DPS) → (18.75 / 0.8 = 23.4 DPS)

**Success Criteria:**
- Single tome application works
- Multiple tome application works (both modifiers active)
- DPS increase measurable (kill time reduces)
- No errors when applying/removing tomes

**Files Modified:**
```
tests/ability_system/RangerArrow_Isolated.tscn (add tome tests)
```

**Test Approach:**
- Spawn enemy with 1000 HP
- Scenario 1: Ranger Arrow only (base: 15 dmg, 1.0s CD)
  - Expected TTK = 1000 / (15 / 1.0) = 66.7s
- Scenario 2: Ranger Arrow + Tome of Power
  - Expected TTK = 1000 / (18.75 / 1.0) = 53.3s
- Scenario 3: Ranger Arrow + Both Tomes
  - Expected TTK = 1000 / (18.75 / 0.8) = 42.7s
- Log actual TTK, verify within ±5% margin

---

**Phase 1.4 Completion Checklist:**
- [ ] TomeManager applies stat modifications correctly
- [ ] Tome of Power increases damage by 25%
- [ ] Tome of Swiftness reduces cooldown by 20%
- [ ] Multiple tomes stack correctly
- [ ] TTK measurements match expected values (±5%)
- [ ] No performance degradation

---

## Success Criteria (Overall Phase 1)

**Functional:**
- [ ] BaseAbility + ProjectileAbility classes fully functional
- [ ] AbilityManager tracks cooldowns correctly
- [ ] Player has 4 ability slots with auto-cast
- [ ] Ranger Arrow fires every 1s (or modified by tomes)
- [ ] Projectiles deal damage and kill enemies
- [ ] Tomes modify abilities correctly
- [ ] All isolated tests pass (headless + visual)

**Performance:**
- [ ] 30Hz combat step remains stable
- [ ] No memory leaks (projectile pooling works)
- [ ] Can handle 4 abilities + 15 projectiles each (60 total) at 60 FPS

**Code Quality:**
- [ ] All classes documented with class comments
- [ ] All signals typed with payloads
- [ ] No `print()` statements (use Logger)
- [ ] No errors/warnings in console
- [ ] Follows CLAUDE.md patterns (signals, typed GDScript, layers)

**Testing:**
- [ ] At least 1 isolated test scene per phase
- [ ] DPS/TTK measurements documented
- [ ] Edge cases tested (empty slots, max pierce, cooldown edge cases)

---

## Phase 2+ Preview (Not Implemented Yet)

**Phase 2: Expand Ability Library**
- Add 3-5 more abilities (Fireball, Lightning, Sword Slash, Buff Aura)
- Validate different ability archetypes (AoE, Buff, Orbit)
- Create 5-10 more tomes (elemental, AoE, pierce, projectile count)

**Phase 3: Level-Up Integration**
- Wire into existing level-up modal
- Generate upgrade options (abilities + tomes)
- Implement ability re-picking (level up existing)
- Test upgrade pool generation

**Phase 4: Meta-Progression Integration**
- Add quest → discover → unlock flow
- Wire into shop system
- Persist unlocked abilities/tomes
- Test progression across runs

**Phase 5: Visual Polish**
- Replace placeholder sprites
- Add impact effects
- Add sound effects
- Polish slot machine chest opening

---

## Risk Mitigation

**Known Risks:**

1. **Projectile Pool Complexity**
   - Risk: Existing pool may not support ability projectiles
   - Mitigation: Phase 1.3.1 validates early; fallback to simple spawning if needed

2. **DamageService Integration**
   - Risk: Current damage system may not support ability damage types
   - Mitigation: Verify DamageService.gd before Phase 1.3.5; extend if needed

3. **Performance at Scale**
   - Risk: 4 abilities * 15 projectiles = 60 entities may lag
   - Mitigation: Phase 1.3 tests with MultiMesh; visual cap at 15 already planned

4. **Tome Stacking Logic**
   - Risk: Additive vs multiplicative stacking may create imbalance
   - Mitigation: Phase 1.4.4 explicitly tests both; tune in Phase 2 if needed

---

## File Structure (New Files Created in Phase 1)

```
vibe/
├── autoload/
│   ├── AbilityManager.gd          (Phase 1.2.1)
│   └── TomeManager.gd             (Phase 1.4.1)
├── scripts/
│   ├── domain/
│   │   └── AbilityTags.gd         (Phase 1.1.1)
│   ├── resources/
│   │   ├── BaseAbility.gd         (Phase 1.1.2)
│   │   ├── ProjectileAbility.gd   (Phase 1.1.3)
│   │   └── BaseTome.gd            (Phase 1.1.4)
│   ├── entities/
│   │   └── AbilityProjectile.gd   (Phase 1.3.2)
│   └── ui/debug/
│       └── DebugAbilityDisplay.gd (Phase 1.2.3)
├── data/content/
│   ├── abilities/
│   │   └── ranger_arrow.tres      (Phase 1.3.4)
│   └── tomes/
│       ├── tome_power.tres        (Phase 1.4.2)
│       └── tome_swiftness.tres    (Phase 1.4.3)
├── assets/abilities/arrow/
│   ├── arrow_visual.tscn          (Phase 1.3.3)
│   └── arrow_placeholder.png      (Phase 1.3.3)
└── tests/ability_system/
    └── RangerArrow_Isolated.tscn  (Phase 1.3.6)
```

---

## Estimated Timeline

**Total Estimated Time: 13-18 hours**

| Phase | Tasks | Est. Time |
|-------|-------|-----------|
| 1.1 Foundation | Tag system, BaseAbility, ProjectileAbility, BaseTome, EventBus | 4-6 hours |
| 1.2 Integration | AbilityManager, Player slots, Debug display | 3-4 hours |
| 1.3 Vertical Slice | Ranger Arrow end-to-end + isolated test | 4-5 hours |
| 1.4 Tome Validation | TomeManager + 2 tomes + TTK tests | 2-3 hours |

**Notes:**
- Estimates assume familiarity with Godot and existing codebase patterns
- Does NOT include debugging time (add 20-30% buffer)
- Does NOT include documentation updates (add 1-2 hours)

---

## Next Steps

1. **Review this plan** with team/stakeholders
2. **Create Phase 1.1 branch** (`git checkout -b ability-system/phase-1.1-foundation`)
3. **Start with Phase 1.1.1** (Tag system - easiest first task)
4. **Mark tasks complete** as you go (use checkboxes above)
5. **Update CHANGELOG.md** after each phase completion
6. **Commit frequently** with conventional prefixes (`feat: add BaseAbility class`)

---

**Questions Before Starting?**
- Is projectile pooling already implemented? (affects Phase 1.3.1 scope)
- Should we use existing DamageService or create new AbilityDamageService? (affects Phase 1.3.5)
- Do we want headless tests for all phases, or just critical ones? (affects test coverage)

---

**Document Status:** ✅ Ready for implementation
