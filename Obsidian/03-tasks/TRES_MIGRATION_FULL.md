# .tres Migration - Full Implementation

**Status**: ✅ **Complete**  
**Priority**: Medium  
**Type**: Architecture Migration  
**Created**: 2025-08-23  
**Depends On**: [[TRES_MIGRATION_TEST_SWARM]] success

## Overview

Complete migration from JSON to .tres format for all enemy content, establishing .tres as the standard for ContentDB if the swarm enemy test proves successful.

## Prerequisites

### Required from Test Phase
- ✅ Swarm enemy test completed successfully
- ✅ Performance meets or exceeds JSON baseline
- ✅ Developer workflow compatible with vibe-coding style
- ✅ Type safety provides meaningful value

### Migration Completed 2025-08-23
- ✅ All enemy types successfully migrated to .tres format
- ✅ All animation files successfully migrated to .tres format
- ✅ JSON loading code removed and simplified
- ✅ Documentation updated to reflect new system
- ✅ System tested and validated

## Phase 2: Complete Enemy Migration

### Migration Order (Risk-Based)

#### Step 1: Simple Enemies
- [ ] **knight_regular.tres** - Most common, well-tested
- [ ] **knight_elite.tres** - Similar to regular, minor differences
- [ ] Test both enemies work correctly before proceeding

#### Step 2: Complex Enemies  
- [ ] **knight_boss.tres** - Most complex, highest risk
- [ ] Verify boss mechanics still function correctly

#### Step 3: Configuration Files
- [ ] **enemy_tiers.tres** (or keep as JSON if simple)
- [ ] **enemy_registry.tres** (or keep as JSON if simple)
- [ ] Evaluate complexity vs benefit for config files

### System Updates

#### Code Changes
- [ ] Remove JSON loading from EnemyRegistry (after all migrations)
- [ ] Simplify loading code (no dual format support needed)
- [ ] Update error messages to reference .tres files
- [ ] Clean up unused JSON parsing logic

#### Documentation Updates
- [ ] Update `/data/content/enemies/README.md`
- [ ] Update main ContentDB README
- [ ] Update CLAUDE.md with .tres workflow
- [ ] Create .tres editing guidelines

#### Tooling & Scripts
- [ ] Create JSON→.tres conversion script for future use
- [ ] Document .tres file creation process
- [ ] Add .tres templates/examples

## Migration Validation

### For Each Migrated Enemy
- [ ] Load test: File loads without errors
- [ ] Spawn test: Enemy spawns correctly in game
- [ ] Property test: All properties match JSON version
- [ ] Behavior test: AI, movement, combat work identically
- [ ] Visual test: Appearance matches expectations

### System Integration Tests
- [ ] Enemy selection pool works correctly
- [ ] Wave spawning functions normally  
- [ ] Performance benchmarks maintained
- [ ] Hot-reload across all enemy types

## Rollback Plan

### If Migration Issues Occur
1. **Keep JSON backups** - Don't delete during migration
2. **Git revert capability** - Each step is a separate commit
3. **Dual format fallback** - Temporary JSON loading if needed
4. **Issue documentation** - Record what went wrong for future

### Rollback Triggers
- Game crashes or functionality breaks
- Significant performance regression  
- Workflow becomes significantly worse
- Critical bugs introduced

## Future Content Strategy

### New Content Types (Post-Migration)
- [ ] **Abilities** - Start with .tres from day one
- [ ] **Items** - Use .tres format
- [ ] **Heroes** - Use .tres format
- [ ] **Maps** - Evaluate complexity, may use JSON for simple configs

### Hybrid Approach Guidelines
```
Use .tres for:
- Complex content with many properties
- Content that benefits from type safety
- Content frequently edited in inspector

Use JSON for:
- Simple configuration files
- Content better suited to text editing
- Content requiring AI assistance frequently
```

## Performance Targets

### Must Meet or Exceed JSON Performance
- **Startup time**: ≤ JSON baseline
- **Memory usage**: ≤ JSON baseline  
- **Hot-reload**: ≤ 200ms (faster than F5)

### Quality Targets
- **Error rate**: Reduced due to type safety
- **Development speed**: Equal or improved
- **Maintainability**: Improved code clarity

## Implementation Timeline

### Week 1: Core Migration
- [ ] Complete enemy .tres migration
- [ ] System integration testing
- [ ] Performance validation

### Week 2: Polish & Documentation
- [ ] Clean up code (remove JSON support)
- [ ] Update all documentation
- [ ] Create migration tools/scripts

### Week 3: Evaluation & Planning
- [ ] Assess overall migration success
- [ ] Plan future content type approach
- [ ] Update long-term ContentDB strategy

## Success Metrics

### Quantitative
- **Loading time**: 0-50% faster than JSON
- **Memory usage**: 0-20% lower than JSON
- **Development time**: Equal or faster content creation
- **Error rate**: 30%+ reduction in content-related bugs

### Qualitative
- **Developer satisfaction**: Improved or maintained workflow
- **Code maintainability**: Cleaner, more type-safe code
- **Future readiness**: Better foundation for complex content

## Decision Documentation

### Key Decisions Made
- [ ] JSON vs .tres format choice
- [ ] Hybrid approach for different content types
- [ ] Tooling and workflow standards
- [ ] Migration rollback criteria

### Lessons Learned
- [ ] What worked well in migration process
- [ ] What would be done differently
- [ ] Recommendations for future format changes
- [ ] Performance and workflow insights

## Post-Migration Tasks

### Immediate (Week 1)
- [ ] Update ContentDB-Architecture-Enhancement.md with results
- [ ] Create changelog entry for migration
- [ ] Update development workflows in CLAUDE.md

### Future (Month 1)  
- [ ] Apply learnings to ability system design
- [ ] Plan item system format approach
- [ ] Evaluate modding implications of .tres format

---

**Related Documents:**
- [[TRES_MIGRATION_TEST_SWARM]] - Prerequisite test phase
- [[ContentDB-Architecture-Enhancement]] - Overall architecture plan
- [[CONVERSATION_SUMMARY_CONTEXT_DECISIONS_NEXT_STEPS]] - Project context

**Status Dependencies:**
- Can only proceed if swarm test is successful
- Must document decision rationale regardless of outcome
- Rollback plan ready if issues arise