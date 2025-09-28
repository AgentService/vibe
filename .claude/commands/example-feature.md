<!--
name: feature-add
description: Structured workflow for adding new features to the vibe project
usage: /feature-add "feature description"
-->

# Add New Feature to Vibe Project

Implement the following feature with proper architecture: **$ARGUMENTS**

## Required Steps:

### 1. FEATURE ANALYSIS

Analyze the feature requirements:
- What gameplay mechanics are involved?
- Which systems need modification (Arena, DamageSystem, EventBus)?
- What new signals/events are needed?
- Performance implications for 30Hz combat loop?

### 2. ARCHITECTURE PLANNING

Before coding, determine:
- **Layer placement**: scenes/ vs systems/ vs domain/ vs autoload/
- **EventBus signals**: New signals needed for this feature
- **Resource files**: New .tres files in /data/content/ or /data/balance/
- **Testing approach**: .tscn (with autoloads) or .gd (standalone)

### 3. CODE ARCHAEOLOGY

Search existing codebase for:
```bash
# Find similar features
grep -r "similar_pattern" scripts/systems/
# Check EventBus for related signals
grep -r "related_signal" autoload/EventBus.gd
# Look for reusable components
find . -name "*.gd" -type f | xargs grep -l "component_name"
```

### 4. IMPLEMENTATION CHECKLIST

- [ ] Create/modify domain models in `scripts/domain/`
- [ ] Add EventBus signals if needed
- [ ] Implement system logic in `scripts/systems/`
- [ ] Use Logger for all output (no print() statements)
- [ ] Keep functions under 40 lines
- [ ] Add .tres resources to `/data/` with documentation
- [ ] Create UI components in `scenes/ui/` if needed

### 5. VALIDATION

- [ ] Run headless tests: `./Godot_v4.4.1-stable_win64_console.exe --headless tests/test_feature.tscn`
- [ ] Verify 30Hz combat compatibility
- [ ] Check EventBus signal flow
- [ ] Update CHANGELOG.md
- [ ] Update relevant CLAUDE.md files

## Output Format

After completion, provide:
1. Files modified/created with line counts
2. New EventBus signals added
3. Performance impact assessment
4. Test results summary

**Feature request details:** $ARGUMENTS