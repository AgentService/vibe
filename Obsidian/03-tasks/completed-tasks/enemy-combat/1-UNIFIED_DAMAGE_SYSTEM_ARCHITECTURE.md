# Unified Damage System Architecture (System Quality Enhancement)

**Status:** ✅ IMPLEMENTATION COMPLETE  
**Owner:** Solo (Indie)  
**Priority:** High (Blocking future damage features)  
**Dependencies:** Enemy V2 MVP Complete ✅, EventBus ✅, existing DamageSystem ✅  
**Risk:** Medium (touches multiple systems, but A/B testable with feature flags)  
**Complexity:** 7/10 (Medium-High - architectural refactor across systems)

## 🎉 IMPLEMENTATION COMPLETED

**Completed Date:** 2025-01-01  
**Implementation Time:** ~6 hours (as planned)  
**Feature Flag:** `unified_damage_v3 = true` (enabled by default)

### ✅ All MVP Success Criteria Met:
- [x] Feature flag enables A/B testing between old and new systems
- [x] No scene tree traversal when feature flag ON
- [x] All damage flows through single pipeline (verified via Logger)
- [x] MeleeSystem works without WaveDirector reference
- [x] Combat feels identical with feature flag ON/OFF
- [x] Manual test checklist passes

### 🏗️ Architecture Quality Achieved:
- [x] Single damage pipeline (no more dual paths)  
- [x] No scene tree traversal (EntityTracker handles spatial queries)  
- [x] Pure EventBus communication (no direct system references)  
- [x] A/B testable architecture changes (feature flags)  
- [x] Extensible foundation for all future damage features

---

## Context & Current State (Dec 2024)

### Existing Implementation Analysis
The codebase already has a **DamageRegistry V2** (`scripts/systems/damage_v2/DamageRegistry.gd`) that attempts unified damage but has critical flaws:

**Current Architecture Issues (Confirmed in Code):**
- **Scene Tree Traversal**: `MeleeSystem._find_scene_bosses_in_cone()` (lines 198-233) recursively searches entire scene tree
- **Direct System Coupling**: 
  - MeleeSystem requires WaveDirector reference (line 8, 323-324)
  - DamageSystem requires AbilitySystem + WaveDirector references (lines 101-103)
- **Brittle Entity Syncing**: DamageRegistry uses `instance_from_id()` and direct property access (lines 183-230)
- **Dual Registration**: Entities must register in both DamageService AND their own systems

**Previous Attempt Failed Due To:**
- Circular dependencies: IDamageReceiver ↔ DamagePayload ↔ EntityId class loading issues
- Autoload name conflicts with class_name declarations
- Too much simultaneous change without stable checkpoints

**Technical Debt Impact:**
- Boss melee damage required scene tree search fix (brittle)
- Future skill systems will face same dual-path complexity
- Damage modifiers/effects must be implemented in multiple places
- Debug/logging inconsistent between damage paths

---

## Goals & Success Criteria

### MVP Goals (Focus on Extensibility)
1. **Single Damage Pipeline**: All damage flows through unified registry (no dual paths)
2. **Remove Scene Tree Searches**: Use registration-based entity discovery
3. **Feature Flag A/B Testing**: Old vs new system toggleable for validation
4. **Extensible Foundation**: Easy to add DoT, AoE, resistances later

### Success Criteria for MVP
- [ ] Feature flag enables A/B testing between old and new damage systems
- [ ] No scene tree traversal in combat systems
- [ ] MeleeSystem works without WaveDirector reference
- [ ] All damage flows through single pipeline (verified via Logger)
- [ ] Manual testing confirms combat feels identical
- [ ] Foundation ready for future damage effects (DoT, AoE, etc.)

---

## Technical Architecture

### Current State (Hybrid System)
```
Pooled Enemies:    MeleeSystem → EventBus.damage_requested → DamageSystem → WaveDirector.damage_enemy()
Scene Bosses:      MeleeSystem → boss.take_damage() [BYPASSES PIPELINE]

Problems:
• Two separate damage implementations
• Scene tree searching for boss detection  
• Direct system coupling (MeleeSystem needs WaveDirector reference)
• Damage modifiers only apply to pooled enemies
```

### Target State (Unified System)
```
All Damage:        SkillSystem → EventBus.damage_requested → DamageSystem → IDamageReceiver.apply_damage()

Benefits:
• Single damage pipeline with consistent modifiers
• Event-driven decoupling (no direct references)
• Uniform damage interface for all entity types
• Extensible for future damage types (DoT, AoE, etc.)
```

---

## MVP Implementation Plan (With Testing Breaks)

### Phase 0: Setup & Feature Flag (30 min)
**Files to create/modify:**
- `data/balance/features.tres` - Add `unified_damage_v3` flag
- Create backup branch from current `unified-damage-system`

**Tasks:**
1. Add feature flag to BalanceDB: `unified_damage_v3 = false` (default off)
2. Document current damage flow in comments for reference
3. Verify game runs perfectly before any changes
4. Create simple test checklist for manual validation

**🛑 MANUAL TEST BREAK**: Confirm baseline combat works (melee, projectiles, boss damage)

---

### Phase 1: Fix DamageRegistry Syncing (1 hour)
**Problem:** Current DamageRegistry has brittle syncing with `instance_from_id()`

**Files to modify:**
- `scripts/systems/damage_v2/DamageRegistry.gd`

**Tasks:**
1. Behind feature flag, improve entity sync mechanism
2. Use EventBus signals instead of direct property access
3. Add proper Logger categories for damage events
4. Keep Dictionary-based approach (avoid class dependencies)

**🛑 MANUAL TEST BREAK**: Toggle feature flag on/off, verify damage still works both ways

---

### Phase 2: Simple Entity Tracker (1.5 hours)
**Goal:** Replace scene tree searches with registration

**Files to create/modify:**
- `scripts/systems/EntityTracker.gd` (NEW - not EntityRegistry to avoid name conflicts)
- `scenes/bosses/AncientLich.gd`
- `scripts/systems/WaveDirector.gd`

**Tasks:**
1. Create EntityTracker as autoload (tracks entity positions/states)
2. Auto-register bosses on `_ready()` 
3. Auto-register pooled enemies on spawn
4. Add spatial query methods: `get_entities_in_radius(pos, radius)`
5. Feature flag controls whether MeleeSystem uses EntityTracker or old scene search

**🛑 MANUAL TEST BREAK**: Verify melee cone detection works for both pooled enemies AND bosses

---

### Phase 3: Remove Direct System Coupling (1 hour)
**Goal:** Systems communicate only via EventBus

**Files to modify:**
- `scripts/systems/MeleeSystem.gd`
- `scripts/systems/DamageSystem.gd`

**Tasks:**
1. Behind feature flag, remove WaveDirector reference from MeleeSystem
2. Remove AbilitySystem reference from DamageSystem
3. Use EntityTracker for all entity lookups
4. Emit damage events with entity IDs instead of direct calls

**🛑 MANUAL TEST BREAK**: Full combat test - spawn waves, fight boss, check all damage types

---

### Phase 4: Unified Damage Pipeline (1 hour)  
**Goal:** Single damage path for all entity types

**Files to modify:**
- `scripts/systems/damage_v2/DamageRegistry.gd`
- `scripts/systems/MeleeSystem.gd`
- `scripts/systems/DamageSystem.gd`

**Tasks:**
1. Route all damage through improved DamageRegistry
2. Remove dual damage paths in MeleeSystem
3. Standardize damage event payloads
4. Add extensibility hooks for future damage modifiers

**🛑 MANUAL TEST BREAK**: A/B test with feature flag - combat should feel identical

---

### Phase 5: Cleanup & Validation (30 min)
**Goal:** Remove old code paths once new system is validated

**Tasks:**
1. Remove old scene tree search methods (keep commented for reference)
2. Update Logger output to clearly show damage flow
3. Document extension points for DoT, AoE, resistances
4. Final A/B testing with feature flag
5. Set feature flag to `true` by default once validated

---

## Cleanup Plan (Post-Implementation)

### Code Removal
**Remove these methods/patterns:**
- `MeleeSystem._find_scene_bosses_in_cone()` → EntityRegistry queries
- `MeleeSystem._get_all_characterbody2d_nodes()` → No longer needed
- `MeleeSystem.set_wave_director_reference()` → EventBus only
- `DamageSystem.set_references()` → EventBus + EntityRegistry  
- `AncientLich.take_damage()` direct calls → IDamageReceiver.apply_damage()
- Scene tree traversal code throughout combat systems

### Architecture Cleanup
**Remove these coupling patterns:**
- Direct system-to-system references
- Scene tree searches for entities
- Dual damage pipelines (direct calls + EventBus)
- Manual enemy pool index lookups

**Replace with:**
- EntityRegistry for entity lifecycle management
- EventBus for all system communication  
- IDamageReceiver interface for consistent damage handling
- Unified damage modifiers and effects system

---

## Risk Assessment & Mitigations

### Risks
1. **Previous Failure Pattern**: Circular dependencies and too much simultaneous change
2. **Entity Lifecycle**: Registration/deregistration timing bugs  
3. **Combat Feel**: Damage timing or feedback might change
4. **A/B Testing Complexity**: Maintaining two code paths temporarily

### Mitigations
1. **Dictionary-Based Design**: No class dependencies, just data structures
2. **Feature Flags**: A/B test old vs new system at any time
3. **Manual Test Breaks**: Validate after each phase before proceeding
4. **Incremental Changes**: Small, testable steps with stable checkpoints
5. **Keep Old Code**: Comment out rather than delete until fully validated

---

## Testing Strategy

### Manual Testing Checklist (After Each Phase)
**Basic Combat:**
- [ ] Player melee damages pooled enemies
- [ ] Player melee damages scene bosses  
- [ ] Projectiles damage enemies
- [ ] Enemies damage player on contact
- [ ] Boss attacks work properly

**A/B Testing:**
- [ ] Toggle feature flag OFF - old system works
- [ ] Toggle feature flag ON - new system works
- [ ] Combat feels identical between systems
- [ ] Logger shows correct damage flow

### Automated Tests (Don't implement for MVP)
- Skip unit tests for MVP
- Skip integration tests for MVP  
- Focus on manual validation and A/B testing

---

## Timeline & Effort Estimate

**Total MVP Effort:** ~5-6 hours (with breaks for testing)

**Phase 0 (Setup):** 30 min + test break  
**Phase 1 (Fix Syncing):** 1 hour + test break  
**Phase 2 (Entity Tracker):** 1.5 hours + test break  
**Phase 3 (Decouple):** 1 hour + test break  
**Phase 4 (Unified Pipeline):** 1 hour + test break
**Phase 5 (Cleanup):** 30 min + final validation

**When to do this task:**
- ✅ **NOW**: Enemy V2 MVP is complete, DamageRegistry V2 exists but needs fixing
- ✅ **Good timing**: Before adding any new damage features (DoT, AoE, resistances)
- ⚠️ **Blocking**: New damage types will inherit current architectural problems
- 💡 **MVP Focus**: Get foundation right, extend later

---

## Benefits After Completion

### Developer Experience
- Single place to add damage modifiers and effects
- No more dual damage path maintenance  
- Clean system boundaries and dependencies
- Easier debugging with unified damage logging

### Performance  
- No scene tree traversal for entity detection
- Spatial queries instead of recursive searches
- More efficient entity lifecycle management

### Future Features Enabled
- Damage-over-time effects (unified pipeline)
- Area-of-effect damage (EntityRegistry spatial queries)  
- Damage resistance/vulnerability systems
- Combat replay and analytics systems
- Visual damage number systems

### Architecture Quality
- Pure event-driven system communication
- Consistent damage interfaces across all entity types
- Clear separation of concerns between systems
- Maintainable and testable damage pipeline

---

## MVP Acceptance Criteria

### Must Have (MVP)
- [ ] Feature flag enables A/B testing of old vs new system
- [ ] No scene tree traversal when feature flag ON
- [ ] All damage flows through single pipeline (verified via Logger)
- [ ] MeleeSystem works without WaveDirector reference
- [ ] Combat feels identical with feature flag ON/OFF
- [ ] Manual test checklist passes

### Nice to Have (Post-MVP)
- [ ] Performance metrics collected
- [ ] Automated test coverage
- [ ] Full documentation of extension points
- [ ] Remove old code paths after validation period

---

## Future Extensions (Post-MVP)

The MVP foundation will make these features trivial to add:

### Damage Effects System
- **Damage over Time (DoT)**: Add timer-based damage to EntityTracker
- **Resistances/Vulnerabilities**: Add modifier lookup to damage pipeline
- **Status Effects**: Extend entity data with effect arrays
- **Critical Hit System**: Already has hooks in DamageRegistry

### Advanced Combat Features  
- **Area Damage**: Use EntityTracker spatial queries for AoE
- **Damage Reflection**: Add pre/post damage event hooks
- **Combat Analytics**: DamageRegistry already logs all damage events
- **Visual Effects**: Unified damage events make VFX consistent

### Architecture Quality Achieved
- ✅ Single damage pipeline (no more dual paths)
- ✅ No scene tree traversal (EntityTracker handles spatial queries)
- ✅ Pure EventBus communication (no direct system references)  
- ✅ A/B testable architecture changes (feature flags)
- ✅ Extensible foundation for all future damage features

The MVP approach ensures we get a solid, testable foundation without over-engineering upfront.