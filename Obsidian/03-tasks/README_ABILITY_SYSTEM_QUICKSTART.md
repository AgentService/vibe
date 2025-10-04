# Ability System Implementation - Quick Start Guide

**Created:** 2025-10-03
**Status:** Ready to begin Phase 1

---

## 📋 What Was Created

### Architecture Documents
1. **`/Obsidian/02-brainstorm/ability-system/ability-system-architecture.md`**
   - Complete technical blueprint (500+ lines)
   - Class definitions with full code examples
   - Manager classes (AbilityManager, TomeManager)
   - Player integration code
   - EventBus signal additions
   - Example .tres files (Ranger Arrow, 6 realistic tomes)

2. **`/Obsidian/02-brainstorm/ability-system/ability-system-phase1-plan.md`**
   - 4-phase implementation breakdown
   - Time estimates (13-18 hours for Phase 1)
   - Success criteria per phase
   - Risk mitigation strategies

### Task Documents (Step-by-Step Implementation)
1. **`/Obsidian/03-tasks/9_ABILITIES_system_implementation.md`** (PARENT)
   - Epic-level overview
   - Phase breakdown (4 phases)
   - Success criteria
   - File structure
   - Dependencies

2. **`/Obsidian/03-tasks/9a_ABILITIES_phase1_foundation.md`** (SUBTASK - START HERE!)
   - 5 detailed tasks with checkboxes
   - Task 1.1.1: Create Tag System (~30 min)
   - Task 1.1.2: Create BaseAbility Class (~2 hours)
   - Task 1.1.3: Create ProjectileAbility Subclass (~1 hour)
   - Task 1.1.4: Create BaseTome Class (~30 min)
   - Task 1.1.5: Add EventBus Signals (~15 min)
   - **Each task includes:**
     - File path to create
     - Complete requirements
     - Success criteria
     - Testing code snippets
     - Validation steps

3. **`/Obsidian/03-tasks/9b_ABILITIES_phase2_integration.md`** (SUBTASK - AFTER 9a)
   - 4 tasks: AbilityManager, Player slots, Debug UI, Arena integration
   - 3-4 hours estimated

4. **`/Obsidian/03-tasks/9c_ABILITIES_phase3_vertical_slice.md`** (SUBTASK - AFTER 9b)
   - 6 tasks: Projectile pool, Arrow logic, Arrow visual, ranger_arrow.tres, damage wiring, isolated test
   - 4-5 hours estimated

5. **`/Obsidian/03-tasks/9d_ABILITIES_phase4_tome_validation.md`** (SUBTASK - AFTER 9c)
   - 4 tasks: TomeManager, Tome of Power, Tome of Swiftness, DPS validation
   - 2-3 hours estimated

---

## 🔄 Key Architecture Patterns

### Hybrid Spawning & Damage Pattern
The ability system uses a **hybrid approach** for performance and decoupling:

**Spawning:**
- **Resources (BaseAbility subclasses)** → Emit `EventBus.ability_*_requested` signals (can't access singletons)
- **Systems (ProjectilePool, EntityPool)** → Listen to signals and spawn entities

**Damage:**
- **ALL sources** → Call `DamageService.apply_damage()` directly (single entry point)
- **NEVER** use `EventBus.damage_requested` (removed signal)

**Example:**
```gdscript
// ProjectileAbility.activate() - Resource
EventBus.ability_projectile_requested.emit(projectile_data)

// AbilityProjectile._on_enemy_hit() - Entity
DamageService.apply_damage(source_id, target_id, damage, tags)
```

**Rationale:** Resources stay decoupled (EventBus), entities get performance (direct calls), damage has single entry point.

### Unified Entity Pooling
**EntityPool** (autoload) manages all high-frequency, short-lived entities:
- **Projectiles** (arrows, fireballs, meteors) - 50-100 instances each
- **XP Orbs** - 200 instances (mass enemy kills)
- **VFX particles** - future expansion

**Pattern:** Pre-warmed pools using `ObjectPool` utility, zero-allocation spawning. Persistent entities (chests, bosses) are NOT pooled.

### Component Pattern
**AbilityComponent** is the **first of many** player components:
- Future: `HealthComponent`, `MovementComponent`, `BuffComponent`
- Each component manages isolated responsibility
- Communicates via EventBus signals

---

## 🚀 How to Start

### Step 1: Read the Architecture
**Read:** `/Obsidian/02-brainstorm/ability-system/ability-system-architecture.md`

**Focus on:**
- Class Hierarchy section (BaseAbility → ProjectileAbility)
- Hybrid Spawning & Damage Pattern (EventBus vs Singleton)
- EntityPool section (unified pooling for projectiles + XP orbs)
- BaseTome.gd section (realistic tome examples)
- Tag system (AbilityTags.gd)

**Time:** 15-20 minutes

---

### Step 2: Open First Subtask
**Open:** `/Obsidian/03-tasks/9a_ABILITIES_phase1_foundation.md`

This document has **5 tasks**, each with:
- ✅ Checkbox to mark complete
- File path to create
- Full code requirements
- Testing instructions

**Work through tasks in order:**
1. Task 1.1.1 → Create `scripts/domain/AbilityTags.gd` (~30 min)
2. Task 1.1.2 → Create `scripts/resources/BaseAbility.gd` (~2 hours)
3. Task 1.1.3 → Create `scripts/resources/ProjectileAbility.gd` (~1 hour)
4. Task 1.1.4 → Create `scripts/resources/BaseTome.gd` (~30 min)
5. Task 1.1.5 → Add EventBus signals (~15 min)

---

### Step 3: Mark Tasks Complete as You Go
**In the subtask file:** Check off each ✅ checkbox when task is done.

**Example:**
```markdown
- [x] Create file at `scripts/domain/AbilityTags.gd`
- [x] Define ~15 StringName constants
- [x] Add tag categories comment block
- [ ] Add helper functions  ← Currently working on this
```

---

### Step 4: Test After Each Task
**Each task has a "Testing" section.**

**Example:** Task 1.1.2 (BaseAbility) includes headless test script:
```bash
../Godot_v4.4.1-stable_win64_console.exe --headless --script tests/ability_system/test_base_ability_levelup.gd
```

**Expected output:**
```
=== BaseAbility Level-Up Test ===
Initial: damage=10.00, cooldown=2.00
After 5 levels: damage=20.11 (expected: 20.11)
After 5 levels: cooldown=1.55 (expected: 1.55)
✓ TEST PASSED
```

**If test fails:** Fix before moving to next task.

---

### Step 5: Complete Phase 1.1, Then Move to Phase 1.2
**After completing all 5 tasks in `9a_ABILITIES_phase1_foundation.md`:**

**Open:** `/Obsidian/03-tasks/9b_ABILITIES_phase2_integration.md`

**Repeat:** Work through tasks → Test → Mark complete → Move to next phase.

---

### Step 6: Commit After Each Phase
**After completing Phase 1.1 (Foundation):**

```bash
git add scripts/domain/AbilityTags.gd scripts/resources/BaseAbility.gd scripts/resources/ProjectileAbility.gd scripts/resources/BaseTome.gd autoload/EventBus.gd

git commit -m "feat(abilities): complete Phase 1.1 - foundation classes + tag system

- Add AbilityTags.gd with 15 StringName constants
- Implement BaseAbility class with level-up progression
- Implement ProjectileAbility subclass with fire patterns
- Implement BaseTome class with ability/player stat modifiers
- Add ability-related signals to EventBus

All foundation tests passing."
```

---

## 🧪 Testing Strategy

### After Each Task
**Run individual test** (provided in task document)

### After Each Phase
**Run phase integration test** (provided at end of phase document)

**Example:** Phase 1.1 Final Validation
```bash
../Godot_v4.4.1-stable_win64_console.exe --headless tests/ability_system/Phase1_Foundation_Test.tscn --quit-after 1
```

### After Phase 1 Complete
**Run full integration test:**
```bash
../Godot_v4.4.1-stable_win64_console.exe --headless tests/ability_system/Phase1_Final_Integration_Test.tscn --quit-after 15
```

**Expected:**
```
✓✓✓ ALL PHASE 1 TESTS PASSED ✓✓✓
Ability System Phase 1 COMPLETE!
```

---

## 📊 Time Estimates

| Phase | Tasks | Estimated Time |
|-------|-------|----------------|
| 1.1 Foundation | 5 tasks | 4-6 hours |
| 1.2 Integration | 4 tasks | 3-4 hours |
| 1.3 Vertical Slice | 6 tasks | 4-5 hours |
| 1.4 Tome Validation | 4 tasks | 2-3 hours |
| **Total Phase 1** | **19 tasks** | **13-18 hours** |

**Add 20-30% buffer for debugging:** ~16-23 hours total

---

## 🎯 Success Criteria (Overall Phase 1)

**Phase 1 complete when:**
- [ ] BaseAbility + ProjectileAbility classes functional
- [ ] AbilityManager tracks cooldowns (30Hz combat step)
- [ ] Player has 4 ability slots with auto-cast
- [ ] Ranger Arrow fires every 1s, deals damage, kills enemies
- [ ] Tomes modify abilities correctly (damage, cooldown, projectile count)
- [ ] All isolated tests pass (headless + visual)
- [ ] No performance degradation (30Hz stays stable)
- [ ] No memory leaks (projectile pooling works)

---

## 📁 File Structure (What You'll Create)

```
scripts/domain/
└── AbilityTags.gd                    ← Phase 1.1

scripts/resources/
├── BaseAbility.gd                    ← Phase 1.1
├── ProjectileAbility.gd              ← Phase 1.1
├── BaseTome.gd                       ← Phase 1.1
└── TomeModifier.gd                   ← Phase 1.1

scripts/components/
└── AbilityComponent.gd               ← Phase 1.2

scripts/entities/
└── AbilityProjectile.gd              ← Phase 1.3

scripts/ui/debug/
└── DebugAbilityDisplay.gd            ← Phase 1.2

autoload/
├── EventBus.gd (modified)            ← Phase 1.1
├── AbilityManager.gd                 ← Phase 1.2
├── AbilitySystem.gd                  ← Phase 1.2
├── TomeManager.gd                    ← Phase 1.4
└── EntityPool.gd                     ← Phase 1.3

data/content/abilities/projectile/
└── ranger_arrow.tres                 ← Phase 1.3

data/content/tomes/
├── tome_power.tres                   ← Phase 1.4
└── tome_swiftness.tres               ← Phase 1.4

assets/abilities/arrow/
├── arrow_visual.tscn                 ← Phase 1.3
└── arrow_placeholder.png             ← Phase 1.3

tests/ability_system/
├── test_base_ability_levelup.gd      ← Phase 1.1
├── Phase1_Foundation_Test.tscn       ← Phase 1.1
├── Phase2_Integration_Test.tscn      ← Phase 1.2
├── RangerArrow_Isolated.tscn         ← Phase 1.3
└── Phase1_Final_Integration_Test.tscn ← Phase 1.4
```

---

## ❓ FAQ

**Q: Can I skip tasks?**
**A:** No - tasks have dependencies. Phase 1.2 requires Phase 1.1 to be complete.

**Q: What if a test fails?**
**A:** Fix before moving on. Each test validates critical functionality for next tasks.

**Q: Can I implement my own tomes?**
**A:** After Phase 1.4 complete, yes! Use `tome_damage.tres` as template.

**Q: Where do I ask questions?**
**A:** Document blockers in the subtask file (add notes section).

**Q: What if ObjectPool utility doesn't exist?**
**A:** Task 1.3.1 has fallback: create EntityPool with simple array-based pooling.

**Q: What if DamageService doesn't exist?**
**A:** Task 1.3.5 has fallback: create minimal damage system.

---

## 🎓 Learning Path

**New to the codebase?**

1. **Start here:** Read `/CLAUDE.md` (project overview)
2. **Then:** Read architecture document (understand system design)
3. **Then:** Start Phase 1.1 Task 1.1.1 (simplest task first)

**Experienced with codebase?**

1. **Skim:** Architecture document (class structure + integration points)
2. **Jump to:** Phase 1.1 Task 1.1.1
3. **Reference:** Architecture doc when needed

---

## 📞 Help & Support

**Blocked?**
- Check "Testing" section in task document
- Check "Success Criteria" to see what's expected
- Check architecture doc for code examples

**Found a bug in task docs?**
- Note it in the subtask file
- Continue with workaround
- Update task doc after completion

---

## 🎉 Next Steps After Phase 1

**When Phase 1 complete:**
1. Update CHANGELOG.md (template provided in Phase 1.4)
2. Commit with conventional prefix: `feat(abilities): complete Phase 1`
3. Create new task document for Phase 2 (Expand Ability Library)
4. Or: Move to different feature (quest system, gold economy, etc.)

---

**Status:** Ready to begin!
**First task:** `/Obsidian/03-tasks/9a_ABILITIES_phase1_foundation.md` → Task 1.1.1
