# Obsidian Documentation System

This folder contains the project's **system architecture documentation** using Obsidian-style markdown with bidirectional linking.

## Documentation Philosophy

**Living Documentation**: This documentation stays synchronized with code changes through the development workflow, providing accurate system references for developers.

**Complementary to Changelogs**: While `changelogs/` tracks *what changed when*, `Obsidian/` documents *how systems currently work*.

## Folder Structure

```
Obsidian/
├── README.md              # This file - documentation guidelines
├── 00-meta/              # Vault metadata and configuration
├── 01-game-design/       # Game design documents and decisions  
├── 02-architecture/      # Technical architecture documentation
├── 03-tasks/             # Task planning and TODO management
├── 04-notes/             # Development notes and ideas
├── 05-resources/         # External resources and references
└── systems/              # System implementation documentation ⭐
```

## Primary Focus: /systems/ Directory

The **`systems/`** directory contains detailed documentation of implemented systems:

### Current System Documents
- **[[UI-Architecture-Overview]]** - Main UI architecture reference
- **[[Scene-Management-System]]** - Scene hierarchy and transitions  
- **[[Canvas-Layer-Structure]]** - UI layering and CanvasLayer setup
- **[[Modal-Overlay-System]]** - Modal dialogs and overlays
- **[[EventBus-System]]** - Signal-based communication patterns
- **[[Component-Structure-Reference]]** - Scene files and component breakdown

## Documentation Standards

### Linking Convention
Use **`[[Link-Name]]`** syntax for cross-references between documents:
```markdown
The [[EventBus-System]] connects to [[Modal-Overlay-System]] via signals.
```

### Implementation Status Indicators
- **✅** - Fully implemented and working
- **❌** - Missing or needs implementation
- **⚠️** - Partially implemented or has issues

### Code References
Include file paths and line numbers for concrete examples:
```markdown
CardPicker modal triggers in Arena.gd:228
```

### Current vs Proposed Sections
Structure documents with clear separation:
- **Current Implementation** - What exists now
- **Proposed Architecture** - What should be implemented
- **Migration Path** - How to get from current to proposed

## Integration with Development Workflow

### When to Update Documentation

**Trigger Events** (from CLAUDE.md workflow):
1. New system implementations
2. Major architectural changes  
3. Component refactoring
4. Signal flow modifications
5. UI structure changes

### Update Process

**Manual Updates** (Recommended):
1. Implement and test feature
2. Run `/obs-check` to identify outdated docs
3. Run `/obs-update` to update relevant documents  
4. Commit code and documentation together

**Custom Commands Available**:
- `/obs-check` - Identify which docs need updates
- `/obs-update [system]` - Update specific or all relevant docs

### Feature Implementation Integration

When documenting features in `changelogs/features/`, include:
```markdown
## Documentation Updates Required
- [ ] Obsidian/systems/UI-Architecture-Overview.md
- [ ] Obsidian/systems/Scene-Management-System.md
```

## Documentation Quality Guidelines

### Accuracy First
- Document **current implementation**, not aspirational goals
- Update **immediately** after code changes are verified working
- Include **concrete examples** with file references

### Structured Information
- Use **consistent headings** across similar documents
- Maintain **cross-reference links** between related systems
- Include **code snippets** with proper syntax highlighting

### Developer-Focused
- **Technical depth** appropriate for implementation
- **Architecture decisions** with reasoning
- **Dependency relationships** clearly mapped
- **Common patterns** documented for consistency

## Maintenance Commands

### Check Documentation Status
```bash
# Via Claude Code custom command
/obs-check

# Manual check for outdated references
grep -r "TODO\|FIXME\|outdated" Obsidian/systems/
```

### Update Documentation
```bash
# Via Claude Code custom command  
/obs-update

# Manual find and replace for system renames
find Obsidian/systems/ -name "*.md" -exec sed -i 's/OldSystemName/NewSystemName/g' {} \;
```

### Validate Links
```bash
# Check for broken internal links (requires custom script)
# TODO: Add link validation script
```

## Document Templates

### New System Document Template
```markdown
# [System Name]

## Current Implementation
**File**: `path/to/system.gd`
**Status**: ✅ Working / ❌ Missing / ⚠️ Partial

### [Component/Feature] Analysis
- **Responsibility**: What this does
- **Dependencies**: What it needs
- **Integration**: How it connects

## Proposed Improvements
[Future enhancements]

## Related Systems
- [[Related-System-Name]]
```

## Best Practices

### Do's ✅
- **Update after testing** - Only document working code
- **Use concrete examples** - Include file paths and line numbers  
- **Cross-reference liberally** - Link related concepts
- **Structure consistently** - Follow established document patterns
- **Focus on implementation** - Technical depth over theory

### Don'ts ❌
- **Don't document work-in-progress** - Wait until features work
- **Don't duplicate changelogs** - Focus on "how it works" not "what changed"
- **Don't skip cross-references** - Maintain the link network
- **Don't let docs drift** - Update when code changes
- **Don't over-abstract** - Stay concrete and actionable

## Related Documentation

- **`CLAUDE.md`** - Development workflow (includes Obsidian integration)
- **`custom-commands.md`** - Commands for documentation maintenance
- **`changelogs/README.md`** - Change tracking workflow
- **`ARCHITECTURE.md`** - High-level technical architecture
- **`DECISIONS.md`** - Technical decisions and rationale