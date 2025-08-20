# Changelog Management System

This directory contains the project's change tracking system using **weekly archives** with current active changelog and **feature implementation files**.

## Current Structure

```
/changelogs/
├── README.md              # This file - workflow documentation
├── features/              # Feature implementation files (mandatory for major features)
│   ├── DD_MM_YYYY-FEATURE_NAME.md
│   └── DD_MM_YYYY-ANOTHER_FEATURE.md
└── weekly/                # Weekly archive files
    ├── 2025-w33.md       # Week 33: Aug 11-17, 2025
    ├── 2025-w32.md       # Week 32: Aug 4-10, 2025
    └── 2025-w31.md       # Week 31: July 28-Aug 3, 2025
```

**Root CHANGELOG.md**: Contains current sprint (2-3 weeks of active development)

## Weekly Workflow

**Every Monday:**
1. Archive current `CHANGELOG.md` → `weekly/2025-wXX.md`
2. Create feature files for major implementations → `features/DD_MM_YYYY-FEATURE_NAME.md`
3. Create fresh `CHANGELOG.md` with new week header
4. Reference previous week in new CHANGELOG.md

**Example weekly rotation:**
```bash
# Monday, Aug 18, 2025 (start of week 34)
mv CHANGELOG.md changelogs/weekly/2025-w33.md
echo "# Week 34: Aug 18-24, 2025" > CHANGELOG.md
```
## File Naming Conventions

### Feature Files (MANDATORY for major features)
- **Format**: `DD_MM_YYYY-FEATURE_NAME.md` (date_feature format)
- **Examples**: `20_08_2025-ENEMY_RADAR.md`, `15_08_2025-ARENA_SYSTEM.md`
- **Content**: Detailed implementation progress for specific features
- **When Required**: New systems, major refactors, significant feature implementations

### Weekly Files
- **Format**: `YYYY-wWW.md` (ISO week numbers)
- **Examples**: `2025-w33.md`, `2025-w01.md`
- **Content**: All changes for that specific week

## Content Guidelines

### Root CHANGELOG.md
- **Scope**: Current 2-3 weeks only
- **Detail**: Full implementation details
- **Length**: Keep under 200 lines
- **Format**: Standard changelog format with categories

### Feature Files (MANDATORY)
- **Scope**: Specific feature implementation session
- **Detail**: Complete progress narrative with required sections:
  1. **Date & Context** - When implemented and why
  2. **What Was Done** - Specific features/systems implemented
  3. **Technical Details** - Architecture decisions, key files modified
  4. **Testing Results** - Verification that features work correctly
  5. **Impact on Game** - How this changes gameplay or development
  6. **Next Steps** - Recommended follow-up tasks or improvements
- **Optional**: Issues encountered, performance notes, screenshots/media

### Weekly Archives
- **Scope**: Exact 7-day period (Monday-Sunday)
- **Detail**: Copy of root CHANGELOG.md from that week

## Documentation Integration

### Feature File Requirements
**MANDATORY**: All major feature implementations MUST have a feature file with the `DD_MM_YYYY-FEATURE_NAME.md` format.

### Obsidian Integration
For complex system implementations, use **Obsidian/systems/** for detailed architecture documentation.

### When to Create Feature Files
- ✅ New system implementations (UI, combat, data systems)
- ✅ Major refactors (architecture changes, performance improvements)
- ✅ Significant feature additions (new gameplay mechanics)
- ❌ Minor bug fixes, documentation updates, small tweaks

## Quick Reference Commands

```bash
# Get current week number
date +"%Y-w%V"

# Archive current changelog (Monday routine)
mv CHANGELOG.md "changelogs/weekly/$(date +"%Y-w%V").md"

# Start new week
echo "# Week $(date +"%V"): $(date '+%b %d')-$(date -d '+6 days' '+%b %d, %Y')" > CHANGELOG.md

# Find specific week
find changelogs/weekly -name "*w33*"

# Search across all changelogs
grep -r "enemy radar" changelogs/
```