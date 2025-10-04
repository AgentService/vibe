# [PARENT] Ability System Implementation

**Task ID:** 9
**Type:** ABILITIES
**Status:** 📋 Not Started
**Priority:** High
**Created:** 2025-10-03

---

## 📊 Overview

Implement complete auto-cast ability system with:
- 4 ability slots per player (polymorphic BaseAbility hierarchy)
- 4 tome slots for ability/player stat modifiers
- Tag-based applicability system (~15 tags)
- Level-up progression (damage scales via re-picking)
- Integration with MetaProgression, DamageService, Quest system

**Complexity:** Epic (13-18 hours estimated for Phase 1)

---

## 📚 Documentation References

- **Architecture:** `/Obsidian/02-brainstorm/ability-system/ability-system-architecture.md`
- **Phase 1 Plan:** `/Obsidian/02-brainstorm/ability-system/ability-system-phase1-plan.md`
- **Design Q&A:** `/Obsidian/02-brainstorm/ability-system/ability-system-design-exploration.md` (26 questions)

---

## 🎯 Success Criteria (Phase 1)

- [ ] BaseAbility + ProjectileAbility classes functional
- [ ] AbilityManager tracks cooldowns (30Hz combat step)
- [ ] Player has 4 ability slots with auto-cast
- [ ] Ranger Arrow fires every 1s, deals damage, kills enemies
- [ ] Tomes modify abilities correctly (damage, cooldown, projectile count)
- [ ] All isolated tests pass (headless + visual)
- [ ] No performance degradation (30Hz stays stable)
- [ ] No memory leaks (projectile pooling works)

---

## 📋 Phase Breakdown

### ✅ Phase 0: Architecture & Planning (COMPLETED)
- [x] Create Technical Architecture Document
- [x] Create Phase 1 Implementation Plan
- [x] Update realistic tome examples (Speed, Damage, Quantity, HP, Luck, XP)

**Status:** Complete (2025-10-03)

---

### 🔨 Phase 1: Foundation & Infrastructure (4-6 hours)

**Subtasks → See:** `2a_ABILITIES_phase1_foundation.md`

- Create Tag System (AbilityTags.gd)
- Create BaseAbility Class
- Create ProjectileAbility Subclass
- Create BaseTome Class
- Add EventBus Signals

**Success Criteria:**
- All foundation classes load without errors
- Tag system accessible globally
- BaseAbility level-up math validated
- ProjectileAbility can emit activation signal
- BaseTome tag matching + stat modification works

---

### 🔧 Phase 2: Ability Manager & Player Integration (3-4 hours)

**Subtasks → See:** `2b_ABILITIES_phase2_integration.md`

- Create AbilityManager Singleton
- Add Ability Slots to Player.gd
- Add Debug Display
- Wire Arena 30Hz combat step

**Success Criteria:**
- AbilityManager tracks cooldowns correctly
- Player has 4 ability slots
- Auto-cast fires abilities on cooldown
- Debug display shows live cooldown state
- 30Hz combat step stays stable

---

### 🎮 Phase 3: First Vertical Slice (Ranger Arrow) (4-5 hours)

**Subtasks → See:** `2c_ABILITIES_phase3_vertical_slice.md`

- Extend Projectile Pool for abilities
- Create Arrow Projectile Logic
- Create Arrow Visual
- Create ranger_arrow.tres
- Wire Damage Dealing
- Create Isolated Test Scene

**Success Criteria:**
- Ranger Arrow projectile spawns correctly
- Projectile moves at correct speed
- Projectile deals damage on hit
- Enemies die after enough hits
- Isolated test scene passes (headless + visual)
- No errors/warnings in console

---

### 📖 Phase 4: Tome System Validation (2-3 hours)

**Subtasks → See:** `2d_ABILITIES_phase4_tome_validation.md`

- Create TomeManager Singleton
- Create Tome of Power (damage +25%)
- Create Tome of Swiftness (cooldown -20%)
- Test Tome Application (DPS/TTK measurements)

**Success Criteria:**
- TomeManager applies stat modifications correctly
- Tome of Power increases damage by 25%
- Tome of Swiftness reduces cooldown by 20%
- Multiple tomes stack correctly
- TTK measurements match expected values (±5%)

---

## ⏭️ Future Phases (Not in Phase 1 Scope)

### Phase 5: Create Clean Melee Ability (~2 hours)

> **🏗️ Architecture:** Create clean MeleeAbilityHandler using DamageRegistry spatial queries, removing ~200 lines of redundant code from existing MeleeSystem.gd.

**Prerequisites:** Complete Phase 3 (Ranger Arrow working)

**Architectural Rationale:**
The existing `MeleeSystem.gd` (312 lines) duplicates `DamageRegistry.get_entities_in_cone()` functionality. Rather than preserve legacy patterns, create a **clean ~80-line handler** using existing optimized infrastructure.

**Migration Steps:**
1. **Create MeleeAbility subclass** (~1 hour)
   - Extend BaseAbility with cone attack properties (cone_angle, attack_range, knockback)
   - Emit `EventBus.ability_melee_requested` signal
   - Create `data/content/abilities/melee/melee_slash.tres`

2. **Create clean MeleeAbilityHandler** (~30 min)
   - Delete old MeleeSystem.gd (contains ~200 lines of redundant entity management)
   - Create new MeleeAbilityHandler.gd (~80 lines)
   - Use `DamageRegistry.get_entities_in_cone()` for spatial queries
   - Use `DamageRegistry.apply_damage()` for unified damage handling
   - Preserve visual effects spawning

3. **Integration** (~30 min)
   - Add melee ability to Player ability slots
   - Remove old PlayerAttackHandler direct calls
   - Test auto-cast melee alongside projectiles
   - Verify cone detection, damage, knockback still work

**Code Reduction:**
- ❌ **Old**: 312 lines (custom cone math, manual entity registration, separate boss/enemy paths)
- ✅ **New**: ~80 lines (delegates to DamageRegistry services)
- 📉 **Result**: 74% code reduction, architectural consistency

**Result:** Unified ability system with clean architecture - both melee + projectile abilities use DamageRegistry for spatial queries.

---

### Phase 6: Expand Ability Library
- Add 3-5 more abilities (Fireball, Lightning, Sword Slash, Buff Aura)
- Validate different ability archetypes (AoE, Buff, Orbit)
- Create 5-10 more tomes (elemental, AoE, pierce, projectile count)

### Phase 7: Level-Up Integration
- Wire into existing level-up modal
- Generate upgrade options (abilities + tomes)
- Implement ability re-picking (level up existing)
- Test upgrade pool generation

### Phase 8: Meta-Progression Integration
- Add quest → discover → unlock flow
- Wire into shop system
- Persist unlocked abilities/tomes
- Test progression across runs

### Phase 8: Visual Polish
- Replace placeholder sprites
- Add impact effects
- Add sound effects
- Polish animations

---

## 🎲 Testing Strategy

### Unit Tests (Headless)
- BaseAbility.level_up() math validation
- BaseTome.apply_to_ability() modifier application
- Tag matching logic (has_tag, has_all_tags, has_any_tag)

### Integration Tests (Isolated Scenes)
- Ranger Arrow end-to-end (spawn → move → hit → damage → death)
- Tome stacking (apply 2+ tomes, verify modifiers)
- Auto-cast timing (verify abilities fire on cooldown)

### Performance Tests
- 4 abilities × 15 projectiles = 60 entities at 60 FPS
- Memory leak check (projectile pool recycling)
- 30Hz combat step stability (no frame drops)

---

## 🔗 Dependencies

### External Systems (Existing)
- **DamageService:** Used for projectile damage dealing
- **EventBus:** Ability activation, damage dealt, enemy killed signals
- **ProjectilePool:** Reused/extended for ability projectiles (verify exists!)
- **Arena.gd:** 30Hz combat step integration point
- **Player.gd:** Existing player node to enhance

### Potential Blockers
- Projectile pool may not support ability projectiles → fallback to simple spawning
- DamageService may not support ability damage types → extend if needed
- Player.gd may have conflicting properties → coordinate with existing systems

---

## 📁 New Files Created (Phase 1)

```
scripts/domain/AbilityTags.gd
scripts/resources/BaseAbility.gd
scripts/resources/ProjectileAbility.gd
scripts/resources/BaseTome.gd
scripts/resources/TomeModifier.gd
scripts/entities/AbilityProjectile.gd
scripts/ui/debug/DebugAbilityDisplay.gd
scripts/components/AbilityComponent.gd

autoload/AbilityManager.gd
autoload/AbilitySystem.gd
autoload/TomeManager.gd
autoload/EntityPool.gd

data/content/abilities/projectile/ranger_arrow.tres
data/content/tomes/tome_power.tres
data/content/tomes/tome_swiftness.tres

assets/abilities/arrow/arrow_visual.tscn
assets/abilities/arrow/arrow_placeholder.png

tests/ability_system/RangerArrow_Isolated.tscn
```

---

## ⏱️ Time Estimates

| Phase | Tasks | Time |
|-------|-------|------|
| 1. Foundation | Tag system, core classes, EventBus | 4-6 hours |
| 2. Integration | Managers, player slots, debug UI | 3-4 hours |
| 3. Vertical Slice | Ranger Arrow end-to-end + tests | 4-5 hours |
| 4. Tome Validation | TomeManager + 2 tomes + TTK tests | 2-3 hours |
| **Phase 1 Total** | | **13-18 hours** |

**Buffer:** Add 20-30% for debugging (total: ~16-23 hours)

---

## 📝 Notes

- Start with Phase 1.1 (Foundation) - simplest tasks first
- Mark subtasks complete as you go (use checkboxes in subtask files)
- Commit frequently with conventional prefixes (`feat: add BaseAbility class`)
- Update CHANGELOG.md after each phase completion
- If blocked, document blocker in subtask file and move to next unblocked task

---

## ✅ Completion Checklist

**Phase 1 Complete When:**
- [ ] All foundation classes created + tested
- [ ] Ranger Arrow fires + deals damage + kills enemies
- [ ] Tomes modify abilities correctly
- [ ] All isolated tests pass
- [ ] No errors/warnings in console
- [ ] Performance metrics verified (30Hz stable, no leaks)
- [ ] CHANGELOG.md updated
- [ ] Architecture docs updated (if needed)

**Next Step:** Start `9a_ABILITIES_phase1_foundation.md` → Task 1.1.1 (Tag System)

---

**Status:** Ready to begin Phase 1
