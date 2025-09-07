# .tres Folder Structure Optimization

**Status:** Pending  
**Priority:** MEDIUM  
**Category:** Developer Experience  
**Created:** 2025-09-07  

## Problem Statement

After implementing the hardcoded values migration, the current .tres file organization has become difficult to navigate. Developers struggle to locate the correct configuration files, leading to:

- **Time wasted searching** for specific .tres files across multiple directories
- **Inconsistent naming conventions** making files hard to predict
- **Scattered related configurations** that should be grouped together
- **Poor discoverability** of available configuration options

## Current Structure Analysis

```
data/
├── animations/           # Animation configs (5 files)
├── balance/             # Balance tunables (6 files) 
├── cards/               # Card definitions (nested: melee/, pools/)
├── content/             # Game content (nested: arena/, enemies_v2/, player/)
├── debug/               # Debug configurations (2 files)
├── progression/         # XP curves and unlocks (2 files)
└── ui/                  # UI configurations (2 files)
```

### Issues Identified

1. **Inconsistent categorization**: Some files could belong to multiple categories
2. **Deep nesting**: `content/enemies_v2/templates/` and `content/enemies_v2/variations/` are hard to reach
3. **Unclear naming**: `visual_feedback.tres` vs `visual_feedback_improved.tres` 
4. **Missing discovery**: No easy way to see "all character-related configs"
5. **Mixed abstraction levels**: High-level configs mixed with specific implementations

## Proposed Solutions

### Option 1: Flat Structure with Prefixed Names
```
data/
├── balance-combat.tres
├── balance-melee.tres
├── balance-player.tres
├── balance-visual-feedback.tres
├── balance-waves.tres
├── character-types.tres
├── character-progression.tres
├── enemy-templates-boss.tres
├── enemy-templates-melee.tres
├── enemy-variations-ancient-lich.tres
├── debug-boss-scaling.tres
├── debug-log-config.tres
└── ui-radar-config.tres
```

**Pros**: Easy to find, searchable, no deep nesting  
**Cons**: Long filenames, loses logical grouping

### Option 2: Functional Categories
```
data/
├── gameplay/            # Core game mechanics
│   ├── character-types.tres
│   ├── progression-curves.tres
│   ├── enemy-templates.tres
│   └── boss-scaling.tres
├── balance/            # Tuning and balance
│   ├── combat.tres
│   ├── melee.tres
│   ├── player.tres
│   ├── visual-feedback.tres
│   └── waves.tres
├── content/            # Asset definitions
│   ├── cards-melee.tres
│   ├── enemy-variations.tres
│   └── animations.tres
└── system/             # Technical configs
    ├── debug-logging.tres
    ├── ui-radar.tres
    └── performance-limits.tres
```

**Pros**: Clear functional separation, logical grouping  
**Cons**: Some files could fit multiple categories

### Option 3: Developer Workflow Categories
```
data/
├── designer/           # Game designer configs
│   ├── character-types.tres
│   ├── enemy-templates.tres
│   ├── progression-curves.tres
│   └── boss-scaling.tres
├── balancer/          # Balance tuning configs
│   ├── combat.tres
│   ├── melee.tres
│   ├── player.tres
│   ├── visual-feedback.tres
│   └── waves.tres
├── content/           # Content creator configs
│   ├── cards/
│   ├── animations/
│   └── enemy-variations/
└── technical/         # Developer/debug configs
    ├── debug-logging.tres
    ├── ui-radar.tres
    └── performance-limits.tres
```

**Pros**: Matches team roles and workflows  
**Cons**: Requires understanding team structure

## Recommended Approach: Hybrid Functional + Flat

```
data/
├── core/               # Essential game mechanics (most accessed)
│   ├── character-types.tres
│   ├── progression-xp-curve.tres
│   ├── enemy-templates.tres
│   └── boss-scaling.tres
├── balance/            # All tuning values (designer focus)
│   ├── combat.tres
│   ├── melee.tres
│   ├── player.tres
│   ├── visual-feedback.tres
│   └── waves.tres
├── content/            # Asset-heavy configurations
│   ├── cards-melee.tres
│   ├── animations-all.tres
│   └── enemy-variations.tres
├── debug.tres         # Single debug config file (consolidated)
└── ui.tres           # Single UI config file (consolidated)
```

## Implementation Plan

### Phase 1: Analysis and Consolidation
- [ ] Audit all current .tres files and their usage
- [ ] Identify files that can be consolidated (e.g., all debug configs → debug.tres)
- [ ] Create usage frequency analysis (which configs are accessed most often)
- [ ] Document current dependencies and references

### Phase 2: Structure Design
- [ ] Create detailed proposed structure with rationale
- [ ] Design naming conventions for consistency
- [ ] Plan migration strategy to minimize code changes
- [ ] Create discovery tools (README files, quick reference)

### Phase 3: Migration Execution
- [ ] Create new folder structure
- [ ] Move and rename files according to new scheme
- [ ] Update all code references to new paths
- [ ] Update ResourceLoader paths in all systems
- [ ] Test hot-reload functionality with new paths

### Phase 4: Developer Experience
- [ ] Create `/data/README.md` with complete file index
- [ ] Add VSCode workspace settings for better .tres file handling
- [ ] Create quick-access scripts or shortcuts for common configs
- [ ] Document the new structure in ARCHITECTURE.md

## Success Criteria

- [ ] **Reduced search time**: Developers can find any config file in <10 seconds
- [ ] **Logical organization**: Related configs are grouped together
- [ ] **Consistent naming**: Predictable file names following clear patterns
- [ ] **Easy discovery**: New developers can quickly understand available options
- [ ] **Maintained functionality**: All existing systems work with new paths
- [ ] **Hot-reload preserved**: F5 hot-reload continues to work for all configs

## Files to Create/Modify

### New Files
- `/data/README.md` - Complete configuration file index
- `.vscode/settings.json` - Better .tres file handling
- `tools/find-config.gd` - Quick config file finder script

### Modified References (estimate ~15-20 files)
- All ResourceLoader.load() calls with hardcoded paths
- CharacterSelect.gd, DebugManager.gd, BossHitFeedback.gd
- Balance system autoloads
- Test files with resource paths

## Risk Mitigation

- **Backup current structure** before migration
- **Gradual migration** - move files in small batches
- **Comprehensive testing** after each batch
- **Rollback plan** if issues are discovered
- **Team communication** about new structure before changes

## Future Considerations

- **Auto-discovery system**: Code that automatically finds configs by type
- **Config validation**: System to verify all .tres files load correctly
- **Usage analytics**: Track which configs are accessed most frequently
- **Dynamic reloading**: Hot-reload for entire config categories