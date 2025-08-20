# Custom Commands

## Current Commands

### `/doc-create` - Feature Implementation Documentation
Creates feature implementation file in changelogs/features folder with format: `DD_MM_YYYY-FEATURE_NAME.md`

**Usage**: `/doc-create [feature name]`

### `/obs-check` - Check Obsidian Documentation Status
Reviews recent changes and identifies which Obsidian/systems/*.md files need updates.

**Usage**: `/obs-check`

### `/obs-update` - Update Obsidian System Documentation  
Updates relevant Obsidian/systems/*.md files based on recent changes. Focuses on implementation status, new components, signal flows, and architecture changes.

**Usage**: `/obs-update [system name]` or `/obs-update` (for all relevant systems)

## Claude Code Settings

Add to `settings.json`:
```json
{
  "custom_commands": {
    "/doc-create": {
      "description": "Create feature implementation documentation", 
      "prompt": "Create a feature implementation file in the changelogs/features folder following the established naming convention (DD_MM_YYYY-FEATURE_NAME.md). Include all required sections: Date & Context, What Was Done, Technical Details, Testing Results, Impact on Game, and Next Steps. See /changelogs/README.md for detailed guidelines."
    },
    "/obs-check": {
      "description": "Check which Obsidian docs need updating",
      "prompt": "Review recent changes and identify which Obsidian/systems/*.md files need updates. List specific sections that are now outdated and explain why they need updating. Check for: new components, changed signal flows, modified architecture patterns, and implementation status changes."
    },
    "/obs-update": {
      "description": "Update Obsidian system documentation",
      "prompt": "Update the relevant Obsidian/systems/*.md files based on recent changes. Focus on: current implementation status, new components, signal flows, and architecture changes. Use [[tags]] for cross-references (just for Obsidian Linked View Graph). Maintain the established documentation structure and update any outdated information to reflect the current codebase state."
    }
  }
}
```

## Future Commands
- `/test` - Run test suite
- `/balance` - Hot reload balance data
- `/commit` - Smart commit with changelog