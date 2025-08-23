# JSON to .tres Migration - Project Review

**Status**: 📋 **TODO - Review Phase**  
**Priority**: Medium  
**Type**: Architecture Migration Planning  
**Created**: 2025-08-23  
**Context**: Enemy .tres migration successful - expand to entire project

## Overview

Review all JSON files in the project to identify candidates for .tres migration. Create separate TODO documents for each category that would benefit from migration to maintain the step-by-step approach that worked well for enemies.

## Phase 1: Comprehensive JSON Review

### Inventory Tasks
- [ ] **Scan /data/ directory** - Identify all JSON files by category
- [ ] **Analyze complexity** - Determine which files are good .tres candidates
- [ ] **Assess current usage** - How each JSON file is currently loaded/used
- [ ] **Categorize files** - Group by system and migration priority

### Analysis Criteria

For each JSON file, evaluate:
- **Complexity**: Simple config vs complex structured data
- **Edit frequency**: How often does this content change during development?
- **Type safety benefit**: Would @export validation help catch errors?
- **Visual editing value**: Would Inspector editing improve workflow?

### Categories to Review

#### High Priority (Complex Content)
Files that contain structured game content similar to enemies:
- [ ] **Abilities/Skills** - If any JSON files exist
- [ ] **Items/Equipment** - If any JSON files exist  
- [ ] **Character/Hero data** - If any JSON files exist
- [ ] **Complex game mechanics** - Multi-property definitions

#### Medium Priority (Structured Config)
Files with moderate complexity that could benefit from type safety:
- [ ] **Animation configs** - Currently referenced by enemies
- [ ] **UI themes/layouts** - If complex enough
- [ ] **Game progression data** - Levels, unlocks, etc.
- [ ] **Audio/Visual effect configs** - If they exist

#### Low Priority (Simple Config)
Files that should likely stay JSON:
- [ ] **Balance tunables** - Already handled by BalanceDB
- [ ] **Debug settings** - Simple key-value pairs
- [ ] **Build configurations** - Tool-specific settings
- [ ] **Simple lookup tables** - Basic key-value mappings

### Review Deliverables

After completing the review, create separate TODO files for each category that needs migration:

#### Expected TODO Files to Create:
- [ ] `ANIMATION_CONFIG_TRES_MIGRATION.md` - If animation files are complex
- [ ] `UI_CONFIG_TRES_MIGRATION.md` - If UI configs would benefit
- [ ] `GAME_DATA_TRES_MIGRATION.md` - For any game progression/mechanics data
- [ ] `AUDIO_VISUAL_TRES_MIGRATION.md` - If A/V configs exist and are complex

#### Migration Decision Matrix
For each file, document:
```
File: [filename]
Current Usage: [how it's loaded/used]
Complexity: [Simple/Medium/Complex]
Edit Frequency: [Rare/Occasional/Frequent]
Type Safety Value: [Low/Medium/High]
Visual Editing Value: [Low/Medium/High]
Decision: [Keep JSON/Migrate to .tres]
Priority: [Low/Medium/High]
```

## Phase 2: Documentation Updates

### Documentation Review Tasks
- [ ] **Scan all .md files** - Find references to "JSON as main pattern"
- [ ] **Update CLAUDE.md** - Change examples from JSON to .tres where appropriate
- [ ] **Update ARCHITECTURE.md** - Reflect .tres as ContentDB standard
- [ ] **Update README files** - Ensure consistent messaging about file formats
- [ ] **Update development guides** - Show .tres workflow as primary

### Key Documents to Update
- [ ] **CLAUDE.md** - Update content creation examples
- [ ] **ARCHITECTURE.md** - Update ContentDB format references
- [ ] **Data README files** - Ensure format consistency
- [ ] **Development workflow docs** - Show .tres as standard

### Documentation Consistency Goals
- ContentDB = .tres resources (things you add)
- BalanceDB = JSON files (numbers you tweak)  
- Simple config = JSON (when appropriate)
- Complex content = .tres resources

## Success Criteria

### Review Complete When:
- ✅ All JSON files categorized and analyzed
- ✅ Migration candidates identified with clear reasoning
- ✅ Separate TODO files created for each migration category
- ✅ Documentation inconsistencies identified
- ✅ Clear migration priority established

### Expected Outcomes:
- **0-3 high-priority migration categories** identified
- **Clear migration plan** for each category
- **Updated documentation strategy** for format consistency
- **Step-by-step approach** maintained for manageable progress

## Implementation Notes

### Migration Pattern Established (from Enemy Success)
1. **Test with one item** in category first
2. **Create enhanced Resource class** with @export properties
3. **Implement dual-format loading** during transition
4. **Validate functionality** matches original
5. **Complete category migration** and cleanup
6. **Update documentation** for new workflow

### Risk Mitigation
- **Start small** - Test one file per category first
- **Maintain backwards compatibility** during transition
- **Keep JSON fallbacks** until migration proven
- **Document rollback plan** for each category

## Timeline Estimate

### Review Phase: 1-2 hours
- Systematic scan of all JSON files
- Analysis and categorization
- Creation of migration TODO files

### Documentation Phase: 30-60 minutes  
- Update key documentation files
- Ensure consistent messaging about formats
- Remove outdated JSON-centric references

---

**Next Steps After Review:**
1. Execute the JSON file review systematically
2. Create specific migration TODOs for each category identified
3. Update documentation to reflect .tres as ContentDB standard
4. Begin migrations in priority order using proven enemy migration pattern

**Success Pattern:** Apply the step-by-step, test-first approach that made enemy migration successful