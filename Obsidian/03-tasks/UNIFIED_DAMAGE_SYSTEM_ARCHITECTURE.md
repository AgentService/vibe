# Unified Damage System Architecture (System Quality Enhancement)

**Status:** Ready to Start (Post Enemy V2 MVP)  
**Owner:** Solo (Indie)  
**Priority:** Medium (Quality-of-Life Architecture Improvement)  
**Dependencies:** Enemy V2 MVP Complete, EventBus, existing DamageSystem  
**Risk:** Medium (touches multiple systems, but well-contained changes)  
**Complexity:** 7/10 (Medium-High - architectural refactor across systems)

---

## Context & Motivation

The current damage system works but has architectural inconsistencies that create maintenance complexity and potential for bugs. Following completion of the Enemy V2 MVP, this is an ideal time to unify the damage architecture before adding more skill types.

**Current Issues (Identified during Enemy V2 integration):**
- **Dual Damage Paths**: Pooled enemies use EventBus pipeline, scene bosses use direct method calls
- **Scene Tree Dependencies**: MeleeSystem recursively searches scene tree for boss detection
- **Tight System Coupling**: Direct references between MeleeSystem ↔ WaveDirector, DamageSystem ↔ AbilitySystem
- **Inconsistent Interfaces**: Different damage application methods for different enemy types

**Technical Debt Impact:**
- Boss melee damage required scene tree search fix (brittle)
- Future skill systems will face same dual-path complexity
- Damage modifiers/effects must be implemented twice
- Debug/logging inconsistent between damage paths

---

## Goals & Success Criteria

### Primary Goals
1. **Single Damage Pipeline**: All damage flows through EventBus (no direct `take_damage()` calls)
2. **Unified Interface**: Both pooled enemies and scene bosses implement same damage protocol
3. **Decoupled Systems**: Remove direct system references, use pure EventBus communication
4. **Maintainable Architecture**: One place to add damage modifiers, logging, effects

### Success Criteria
- [ ] All damage routes through EventBus.damage_requested → damage_applied flow
- [ ] Scene bosses and pooled enemies use identical damage interface
- [ ] MeleeSystem has no WaveDirector reference dependency  
- [ ] DamageSystem has no AbilitySystem reference dependency
- [ ] Damage modifiers (crits, resistances) apply uniformly to all enemy types
- [ ] Performance maintained or improved (no scene tree searching)
- [ ] All existing combat functionality preserved

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

## Implementation Plan

### Phase 1: Interface Unification
**Files to modify:**
- `vibe/scripts/domain/IDamageReceiver.gd` (NEW)
- `vibe/scenes/bosses/AncientLich.gd` 
- `vibe/scripts/systems/WaveDirector.gd`

**Tasks:**
1. Create `IDamageReceiver` interface with `apply_damage(payload: DamagePayload)` method
2. Make AncientLich implement IDamageReceiver (replace direct take_damage)
3. Make WaveDirector enemies implement IDamageReceiver via wrapper
4. Update DamageSystem to call IDamageReceiver.apply_damage() for all targets

### Phase 2: Entity Registration System  
**Files to modify:**
- `vibe/scripts/systems/EntityRegistry.gd` (NEW)
- `vibe/scripts/systems/DamageSystem.gd`
- `vibe/scripts/systems/WaveDirector.gd`

**Tasks:**
1. Create EntityRegistry to track all damage-receivable entities  
2. Scene bosses register themselves on spawn: `EntityRegistry.register_entity(entity_id, damage_receiver)`
3. Pooled enemies register via WaveDirector wrapper on spawn
4. DamageSystem looks up targets via EntityRegistry instead of direct references
5. Remove MeleeSystem.wave_director dependency

### Phase 3: Scene Detection Removal
**Files to modify:**
- `vibe/scripts/systems/MeleeSystem.gd`
- `vibe/scripts/systems/DamageSystem.gd`

**Tasks:**
1. Remove `_find_scene_bosses_in_cone()` method from MeleeSystem
2. Replace with EntityRegistry queries: `get_entities_in_area(center, radius, entity_types)`
3. Remove all scene tree traversal code
4. Update collision detection to use registered entity positions

### Phase 4: System Decoupling  
**Files to modify:**
- `vibe/scripts/systems/MeleeSystem.gd`
- `vibe/scripts/systems/DamageSystem.gd`
- `vibe/scripts/systems/AbilitySystem.gd`

**Tasks:**
1. Remove `set_wave_director_reference()` from MeleeSystem
2. Remove `set_references()` from DamageSystem  
3. All entity lookups via EntityRegistry
4. Pure EventBus communication between systems

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
1. **Performance Impact**: EntityRegistry lookups vs direct references
2. **Entity Lifecycle**: Registration/deregistration timing bugs  
3. **Combat Disruption**: Breaking existing damage flow during refactor
4. **Boss Integration**: Scene boss behavior changes

### Mitigations
1. **Performance**: Spatial partitioning in EntityRegistry for area queries
2. **Lifecycle**: Comprehensive registration/cleanup testing
3. **Incremental**: Implement behind feature flag, test each phase
4. **Compatibility**: Preserve all existing combat behavior contracts

---

## Testing Strategy

### Unit Tests
- EntityRegistry registration/deregistration
- IDamageReceiver interface compliance  
- Damage pipeline flow validation

### Integration Tests  
- Melee attacks damage both pooled enemies and scene bosses
- Projectile damage works for all entity types
- Damage modifiers apply uniformly
- Performance parity with current system

### Regression Tests
- All existing combat scenarios still work
- Boss AI and damage behavior unchanged
- Enemy pool damage timing preserved

---

## Timeline & Effort Estimate

**Total Effort:** ~2-3 development sessions (6-8 hours)

**Phase 1 (Interface):** 2-3 hours  
**Phase 2 (Registry):** 2-3 hours  
**Phase 3 (Scene Detection):** 1-2 hours  
**Phase 4 (Decoupling):** 1-2 hours  

**When to do this task:**
- ✅ **NOW**: Enemy V2 MVP is 100% complete  
- ✅ **Good timing**: Between major features for architectural improvement
- ⚠️ **Before**: Adding new skill types (DoT, AoE, etc.) that would duplicate current complexity
- ⚠️ **Before**: Adding damage effects system (resistances, vulnerabilities, etc.)

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

## Acceptance Criteria Checklist

### Functionality
- [ ] All existing combat scenarios work identically
- [ ] Melee attacks damage pooled enemies and scene bosses uniformly
- [ ] Projectile attacks work for all entity types
- [ ] Boss AI and combat behavior unchanged
- [ ] No performance regression in 500+ enemy stress test

### Architecture  
- [ ] Single damage pipeline (EventBus only, no direct calls)
- [ ] No scene tree traversal in combat systems
- [ ] No direct system-to-system references
- [ ] IDamageReceiver implemented by all damageable entities
- [ ] EntityRegistry manages all entity lifecycles

### Code Quality
- [ ] Removed all cleanup items listed above
- [ ] Comprehensive logging through unified damage pipeline
- [ ] Clear error handling for entity registration/lookup failures
- [ ] Documentation updated for new architecture patterns

---

## Future Extensions (Post-Task)

### Damage Effects System
- Status effects (poison, burn, freeze) via unified pipeline
- Damage resistance/vulnerability modifiers
- Conditional damage (crits, weakspot bonuses)

### Advanced Combat Features  
- Damage reflection and absorption
- Area damage with EntityRegistry spatial queries
- Combat replay system using damage event log
- Real-time damage analytics and balancing tools

This task positions the damage system for significant future expansion while eliminating current technical debt.