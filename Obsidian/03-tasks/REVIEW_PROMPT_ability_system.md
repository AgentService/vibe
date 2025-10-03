# Ability System Implementation Review - Prompt for AI Reviewer

**Date:** 2025-10-03
**Project:** Godot 4.2+ Top-Down Wave Survival Roguelike
**Review Target:** Ability System Architecture & Phase 1 Implementation Tasks

---

## 🎯 Review Objectives

You are reviewing a **complete task breakdown system** for implementing an auto-cast ability system in a Godot game. The system includes:
- Architecture design documents
- Phase 1 implementation plan (4 sub-phases, 19 tasks, 13-18 hours)
- Detailed step-by-step task documents with testing strategies

**Your role:** Evaluate the approach for:
1. **Completeness** - Are there missing components or integration points?
2. **Technical Soundness** - Are the architectural decisions appropriate for Godot 4.2+?
3. **Task Clarity** - Can a developer execute these tasks without ambiguity?
4. **Testing Strategy** - Is the testing approach adequate for validation?
5. **Risk Management** - Are potential blockers identified and mitigated?
6. **Maintainability** - Will this system be extensible and maintainable long-term?

---

## 📁 Documents to Review (Read in This Order)

### 1. Project Context
**File:** `C:\App\GodotGame\CLAUDE.md`
**Purpose:** Understand project architecture, coding standards, and existing systems
**Focus Areas:**
- Fixed-step combat (30 Hz) system
- EventBus signal patterns
- DamageService integration
- Object pooling requirements
- Layer/dependency rules (scripts/systems vs scripts/domain vs autoload)

---

### 2. Design Exploration (Background Context - Optional)
**File:** `C:\App\GodotGame\Obsidian\02-brainstorm\ability-system\ability-system-design-exploration.md`
**Purpose:** 26 Q&A pairs exploring design decisions
**Focus Areas:**
- Why tag-based applicability vs class hierarchy?
- Why unified BaseAbility vs separate interfaces?
- Level-up acquisition flow (Abilities + Tomes from level-up, Items from chests)
- Performance considerations (visual caps, object pooling)
- MetaProgression integration (quest → discover → unlock flow)

**Note:** This is a 3000+ line exploration document. You can skim or skip if you prefer to focus on architecture directly.

---

### 3. Technical Architecture (PRIMARY REVIEW TARGET)
**File:** `C:\App\GodotGame\Obsidian\02-brainstorm\ability-system\ability-system-architecture.md`
**Purpose:** Complete technical blueprint for implementation
**Review Focus:**

#### Class Design
- [ ] **BaseAbility.gd**: Is the polymorphic design with optional properties sound?
  - Should all properties be in base class, or use composition instead?
  - Is level-up scaling approach (multiplicative per level) appropriate?
  - Are breakpoint bonuses (level 5, 10, etc.) well-designed?

- [ ] **ProjectileAbility.gd**: Is the fire pattern system adequate?
  - Are the 4 patterns (forward, spread, circle, targeted) sufficient?
  - Should homing/chaining be in base class or separate subclass?

- [ ] **BaseTome.gd**: Is the modifier system flexible enough?
  - Individual @export properties vs Dictionary - is this the right trade-off?
  - Ability modifiers vs Player stat modifiers - should these be separate classes?
  - Is the `applicable_tags` approach (empty = global) intuitive?

#### Manager Design
- [ ] **AbilityManager.gd**: Is the registry pattern appropriate?
  - Should abilities be loaded eagerly (_ready) or lazily (on-demand)?
  - Is `duplicate(true)` the right approach for instancing? (Creates deep copies)
  - Should there be a cooldown tracking system in AbilityManager, or just in Player?

- [ ] **TomeManager.gd**: Is this necessary, or should tomes be managed differently?
  - Could tomes be loaded by AbilityManager instead?
  - Is there benefit to separate manager?

#### Integration Points
- [ ] **Player.gd enhancements**: Are the integration points clean?
  - Auto-cast in `_process()` vs `_physics_process()` vs combat_step signal?
  - Tome application: Should tomes re-apply on every stack, or track deltas?
  - Gold streak system: Should this be in Player or separate GoldManager?

- [ ] **DamageService integration**: Is the damage flow correct?
  - Projectile → hit → EventBus.projectile_hit → DamageService.deal_damage
  - Are there missing steps (damage resistance, armor, critical hits)?

- [ ] **EventBus signals**: Are the signal contracts sufficient?
  - Are typed parameters used correctly?
  - Are there missing signals for critical events?

#### File Structure
- [ ] Is the file organization logical?
  - `scripts/resources/` for ability/tome Resources - correct?
  - `scripts/domain/` for AbilityTags - correct?
  - `autoload/` for managers - correct?

---

### 4. Phase 1 Implementation Plan (REVIEW FOR EXECUTION VIABILITY)
**File:** `C:\App\GodotGame\Obsidian\02-brainstorm\ability-system\ability-system-phase1-plan.md`
**Purpose:** High-level 4-phase breakdown with time estimates
**Review Focus:**

- [ ] **Phase ordering**: Is Foundation → Integration → Vertical Slice → Tome Validation logical?
- [ ] **Time estimates**: Are 13-18 hours realistic for Phase 1? (19 tasks total)
- [ ] **Success criteria**: Are phase completion criteria measurable?
- [ ] **Dependencies**: Are phase dependencies clear? (Can't do 1.2 without 1.1)
- [ ] **Scope creep**: Is Phase 1 scope appropriate, or trying to do too much?

---

### 5. Detailed Task Documents (REVIEW FOR CLARITY & COMPLETENESS)

#### Phase 1.1: Foundation (4-6 hours, 5 tasks)
**File:** `C:\App\GodotGame\Obsidian\03-tasks\9a_ABILITIES_phase1_foundation.md`
**Review Each Task For:**

**Task 1.1.1: Create Tag System (~30 min)**
- [ ] Are 15 tags sufficient, or too many/too few?
- [ ] Is StringName (&"tag") the right choice for performance?
- [ ] Are helper functions (get_all_tags, is_valid_tag, get_tag_color) useful or over-engineering?

**Task 1.1.2: Create BaseAbility Class (~2 hours)**
- [ ] Is 2 hours realistic for ~300 lines of code + documentation?
- [ ] Is the headless test approach (test_base_ability_levelup.gd) adequate?
- [ ] Are level-up scaling tests comprehensive enough? (Test breakpoints? Test max_level capping?)

**Task 1.1.3: Create ProjectileAbility Subclass (~1 hour)**
- [ ] Should fire patterns be tested in this task, or wait until Phase 1.3?
- [ ] Is `_create_projectile_data()` the right abstraction?

**Task 1.1.4: Create BaseTome Class (~30 min)**
- [ ] Is the tome application test comprehensive? (Tests stacking? Tests non-applicable tags?)
- [ ] Should tome application be idempotent, or cumulative?

**Task 1.1.5: Add EventBus Signals (~15 min)**
- [ ] Are gold/chest signals premature (not used until future phases)?
- [ ] Should signals be added incrementally as needed, or all upfront?

---

#### Phase 1.2: Integration (3-4 hours, 4 tasks)
**File:** `C:\App\GodotGame\Obsidian\03-tasks\9b_ABILITIES_phase2_integration.md`

**Task 1.2.1: Create AbilityManager Singleton (~1.5 hours)**
- [ ] Is category-based directory scanning robust? (What if directory doesn't exist?)
- [ ] Should AbilityManager emit signals when abilities load? (For loading screens?)

**Task 1.2.2: Add Ability Slots to Player.gd (~1 hour)**
- [ ] Is auto-cast in `_process()` correct, or should it be in `_physics_process()`?
- [ ] Should cooldowns be tracked in Player, or in AbilityManager centrally?
- [ ] Is tome re-application on every stack correct? (Performance concern?)

**Task 1.2.3: Add Debug Display (~30 min)**
- [ ] Is debug display necessary for Phase 1, or can it wait?
- [ ] Should it use a UI layer (CanvasLayer) or just a Label child?

**Task 1.2.4: Wire Arena 30Hz Combat Step (~30 min)**
- [ ] Is 30Hz the right frequency for ability cooldowns? (Or should it be frame-rate independent?)
- [ ] Should abilities tick on combat_step, or in Player._process()?

---

#### Phase 1.3: Vertical Slice (4-5 hours, 6 tasks)
**File:** `C:\App\GodotGame\Obsidian\03-tasks\9c_ABILITIES_phase3_vertical_slice.md`

**Task 1.3.1: Extend Projectile Pool (~1 hour)**
- [ ] Is the fallback plan (simple spawning without pooling) acceptable?
- [ ] Should projectile pooling be a hard requirement for Phase 1?

**Task 1.3.2: Create Arrow Projectile Logic (~1 hour)**
- [ ] Is `Area2D` collision detection correct, or should it use `CharacterBody2D`?
- [ ] Is homing logic in scope for Phase 1, or should it be deferred?

**Task 1.3.3: Create Arrow Visual (~30 min)**
- [ ] Is placeholder sprite adequate, or should there be a proper arrow asset?
- [ ] Should visual rotation match projectile direction automatically?

**Task 1.3.4: Create ranger_arrow.tres (~15 min)**
- [ ] Are the property values balanced? (15 damage, 1.0s cooldown)
- [ ] Should this be tested in isolation, or only in integration test?

**Task 1.3.5: Wire Damage Dealing (~1 hour)**
- [ ] Is the fallback DamageService creation acceptable?
- [ ] Should damage types (physical, elemental) be implemented in Phase 1, or deferred?

**Task 1.3.6: Create Isolated Test Scene (~1 hour)**
- [ ] Is 15 second test duration sufficient?
- [ ] Should test be deterministic (fixed enemy positions), or randomized?
- [ ] Is headless test approach adequate, or should there be visual validation too?

---

#### Phase 1.4: Tome Validation (2-3 hours, 4 tasks)
**File:** `C:\App\GodotGame\Obsidian\03-tasks\9d_ABILITIES_phase4_tome_validation.md`

**Task 1.4.1: Create TomeManager Singleton (~1 hour)**
- [ ] Is this necessary, or could TomeManager be merged with AbilityManager?

**Task 1.4.2: Create Tome of Power (~30 min)**
- [ ] Is +15% damage per stack balanced? (10 stacks = 4x damage?)

**Task 1.4.3: Create Tome of Swiftness (~30 min)**
- [ ] Should movement speed modifier be in Phase 1, or wait until player movement is finalized?

**Task 1.4.4: Test Tome Application & DPS Validation (~1 hour)**
- [ ] Is TTK (time-to-kill) measurement approach sound?
- [ ] Is ±0.5s margin adequate, or too loose?
- [ ] Should there be 3 separate test scenes, or 1 parameterized scene?

---

### 6. Parent Task Document
**File:** `C:\App\GodotGame\Obsidian\03-tasks\9_ABILITIES_system_implementation.md`
**Review Focus:**
- [ ] Does parent task clearly summarize all phases?
- [ ] Are dependencies on external systems clearly documented?
- [ ] Are potential blockers identified?
- [ ] Is the file structure diagram accurate?

---

### 7. Quick Start Guide
**File:** `C:\App\GodotGame\Obsidian\03-tasks\README_ABILITY_SYSTEM_QUICKSTART.md`
**Review Focus:**
- [ ] Is the guide clear for a developer new to the codebase?
- [ ] Are testing instructions comprehensive?
- [ ] Is the FAQ helpful?
- [ ] Is the learning path appropriate?

---

## 🔍 Specific Review Questions

### Architecture Questions
1. **Tag System**: Is StringName the right choice, or should tags be an enum?
2. **Polymorphism**: Should BaseAbility use optional properties, or composition pattern?
3. **Tome Application**: Should tomes modify abilities directly, or return modifier objects?
4. **Cooldown Tracking**: Player-local vs centralized in AbilityManager?
5. **Auto-cast**: `_process()` vs `_physics_process()` vs combat_step signal?

### Task Breakdown Questions
6. **Phase 1 Scope**: Is Phase 1 trying to do too much? Should it be split into Phase 1a/1b?
7. **Testing Strategy**: Are headless tests adequate, or should there be visual tests too?
8. **Time Estimates**: Are estimates realistic? (13-18 hours for 19 tasks)
9. **Task Dependencies**: Are dependencies between tasks clear?
10. **Fallback Plans**: Are fallback plans (no projectile pool, no DamageService) acceptable?

### Risk Questions
11. **Performance**: Will 4 abilities × 15 projectiles = 60 entities cause lag?
12. **Memory Leaks**: Is projectile pooling mandatory, or can we rely on GC?
13. **Integration**: What if Player.gd has conflicting properties?
14. **DamageService**: What if DamageService doesn't support ability damage types?
15. **30Hz Combat Step**: What if Arena.gd doesn't have a combat_step signal?

### Maintainability Questions
16. **Extensibility**: How easy is it to add new ability types (AoE, Buff, Orbit)?
17. **Tome Scaling**: How easy is it to add new tome modifiers (pierce, AoE radius)?
18. **Hot-Reload**: Will .tres file changes hot-reload correctly (F5 in Godot)?
19. **Code Duplication**: Is there duplication between AbilityManager and TomeManager?
20. **Documentation**: Is inline documentation sufficient, or should there be external docs?

---

## 📋 Review Deliverables

Please provide:

### 1. Architecture Review
- **Strengths**: What architectural decisions are sound?
- **Weaknesses**: What could be improved?
- **Risks**: What technical risks are present?
- **Alternatives**: Are there better approaches?

### 2. Task Clarity Review
- **Clear Tasks**: Which tasks are well-defined?
- **Ambiguous Tasks**: Which tasks need more detail?
- **Missing Tasks**: Are there missing steps?
- **Ordering Issues**: Are tasks in the right order?

### 3. Testing Strategy Review
- **Adequate Tests**: Which testing approaches are sound?
- **Insufficient Tests**: What needs more testing?
- **Test Gaps**: Are there untested scenarios?
- **Test Timing**: Should tests be earlier/later in the process?

### 4. Time Estimate Review
- **Realistic Estimates**: Which time estimates seem accurate?
- **Underestimated Tasks**: Which tasks will likely take longer?
- **Overestimated Tasks**: Which tasks will likely take less time?
- **Buffer Adequacy**: Is 20-30% buffer sufficient?

### 5. Risk Mitigation Review
- **Identified Risks**: Are all major risks identified?
- **Unidentified Risks**: What risks are missing?
- **Mitigation Adequacy**: Are mitigation strategies sufficient?
- **Fallback Plans**: Are fallback plans viable?

### 6. Overall Recommendation
- **Ready to Implement**: Is this ready for development?
- **Needs Revision**: What must be fixed before starting?
- **Alternative Approach**: Should we reconsider the entire approach?

---

## 🎯 Evaluation Criteria

Rate each area on a scale of 1-5:

**1 = Major Issues** (Cannot proceed, needs significant rework)
**2 = Moderate Issues** (Can proceed with caution, needs revisions)
**3 = Acceptable** (Can proceed, minor improvements recommended)
**4 = Good** (Well-designed, ready to implement)
**5 = Excellent** (Best practices, exemplary design)

### Scoring Areas
- [ ] **Architecture Soundness**: ___ / 5
- [ ] **Task Clarity**: ___ / 5
- [ ] **Testing Strategy**: ___ / 5
- [ ] **Time Estimates**: ___ / 5
- [ ] **Risk Management**: ___ / 5
- [ ] **Maintainability**: ___ / 5
- [ ] **Documentation Quality**: ___ / 5

**Overall Score**: ___ / 35

**Recommendation**:
- [ ] **Approve** (30-35 points): Ready to implement
- [ ] **Approve with Minor Revisions** (24-29 points): Address specific issues, then proceed
- [ ] **Revise and Re-Review** (18-23 points): Significant changes needed
- [ ] **Reject** (<18 points): Fundamental issues, reconsider approach

---

## 📄 Additional Context Files (Optional Reference)

**Project Root:**
- `C:\App\GodotGame\ARCHITECTURE.md` - Overall project architecture
- `C:\App\GodotGame\README.md` - Project overview

**Existing Systems (Integration Points):**
- `C:\App\GodotGame\autoload/EventBus.gd` - Signal hub
- `C:\App\GodotGame\scripts/systems/Arena.gd` - 30Hz combat step
- `C:\App\GodotGame\scripts/systems/DamageSystem.gd` - Damage dealing (if exists)
- `C:\App\GodotGame\scripts/resources/MetaProgressionData.gd` - Persistent progression

**Coding Standards:**
- Typed GDScript required
- Signals for cross-system communication
- Logger for all output (no print() statements)
- Deterministic RNG (seeded streams)
- Object pooling for high-count entities

---

## 🚀 How to Conduct This Review

### Step 1: Read Project Context
**Time:** 20-30 minutes
- Read `CLAUDE.md` to understand project architecture
- Skim `ability-system-design-exploration.md` (or skip if time-constrained)

### Step 2: Review Architecture
**Time:** 30-45 minutes
- Read `ability-system-architecture.md` in full
- Evaluate class designs, manager patterns, integration points
- Note strengths, weaknesses, and risks

### Step 3: Review Implementation Plan
**Time:** 15-20 minutes
- Read `ability-system-phase1-plan.md`
- Evaluate phase ordering, time estimates, success criteria

### Step 4: Review Task Documents
**Time:** 45-60 minutes
- Read all 4 phase subtask documents (9a, 9b, 9c, 9d)
- Evaluate task clarity, completeness, testing approaches
- Note ambiguous tasks, missing steps, ordering issues

### Step 5: Answer Review Questions
**Time:** 30-45 minutes
- Answer the 20 specific review questions above
- Provide detailed rationale for each answer

### Step 6: Write Review Deliverables
**Time:** 30-45 minutes
- Architecture Review
- Task Clarity Review
- Testing Strategy Review
- Time Estimate Review
- Risk Mitigation Review
- Overall Recommendation

**Total Review Time:** 3-4 hours

---

## 📧 Submission Format

Please structure your review as:

```markdown
# Ability System Implementation Review
**Reviewer:** [Your Name/ID]
**Date:** [Review Date]
**Overall Score:** X / 35

## Executive Summary
[2-3 paragraph overview of your assessment]

## Architecture Review
### Strengths
- [Bullet points]

### Weaknesses
- [Bullet points]

### Risks
- [Bullet points]

### Recommended Changes
- [Numbered list with rationale]

## Task Clarity Review
[Same structure as Architecture Review]

## Testing Strategy Review
[Same structure]

## Time Estimate Review
[Same structure]

## Risk Mitigation Review
[Same structure]

## Specific Review Question Answers
1. **Tag System (StringName vs Enum)**: [Your answer]
2. **Polymorphism (Optional properties vs Composition)**: [Your answer]
[... continue for all 20 questions]

## Overall Recommendation
- [X] Approve / [ ] Approve with Minor Revisions / [ ] Revise and Re-Review / [ ] Reject

### Critical Issues (Must Fix)
- [Numbered list]

### Recommended Improvements (Should Fix)
- [Numbered list]

### Optional Enhancements (Nice to Have)
- [Numbered list]

## Conclusion
[Final thoughts and recommendations]
```

---

**Thank you for your review!** Your feedback will help ensure this implementation is robust, maintainable, and ready for production.
