# Documentation Updates for .tres Migration

**Status**: 📋 **TODO**  
**Priority**: Low  
**Type**: Documentation  
**Created**: 2025-08-23  
**Context**: Update documentation to reflect .tres as standard format

## Overview

Update all project documentation to reflect the shift from JSON to .tres resources as the standard format for game content and configuration.

## Documentation Files to Update

### Core Project Files
- [ ] `CLAUDE.md` - Update content creation examples
- [ ] `ARCHITECTURE.md` - Update ContentDB format references  
- [ ] `vibe/data/README.md` - Complete rewrite for .tres schemas

### Additional Documentation
- [ ] Any README files in subdirectories
- [ ] Development workflow documentation
- [ ] Content creation guides

## CLAUDE.md Updates

### Update Content Format Section
- [ ] Change examples from JSON to .tres
- [ ] Update "Content formats" section to show .tres as primary
- [ ] Remove JSON references for game content
- [ ] Keep BalanceDB references but for .tres files

### Update Workflow Section
- [ ] Show .tres resource creation in workflow examples
- [ ] Update schema documentation approach
- [ ] Show Inspector editing examples instead of JSON editing

### Example Updates Needed
```gdscript
# OLD: JSON reference
// Example: /godot/data/abilities/fireball.json
{"id": "fireball", "damage": 25, "cooldown": 1.5}

# NEW: .tres reference  
# Example: Create FireballAbility resource in Inspector
# Set damage=25, cooldown=1.5 via @export properties
```

## data/README.md Rewrite

### New Structure
- [ ] Remove all JSON schemas
- [ ] Document .tres resource classes instead
- [ ] Show Inspector editing workflows
- [ ] Update directory structure to show .tres files

### Resource Class Documentation
- [ ] Document each resource class (AnimationConfig, ArenaConfig, etc.)
- [ ] Show @export property descriptions
- [ ] Provide Inspector usage examples
- [ ] Include migration notes from JSON

### Content Creation Guide
- [ ] Step-by-step .tres resource creation
- [ ] Inspector editing best practices
- [ ] Resource inheritance patterns
- [ ] Testing workflow for .tres resources

## ARCHITECTURE.md Updates

### ContentDB Section Updates
- [ ] Update ContentDB description to focus on .tres loading
- [ ] Remove JSON parsing references
- [ ] Add ResourceLoader usage patterns
- [ ] Document resource validation approaches

### System Architecture
- [ ] Update system diagrams if they show JSON
- [ ] Correct any file format assumptions
- [ ] Update data flow descriptions

## Key Messaging Updates

### Before (JSON-focused)
- "JSON as main content format"  
- "Balance tunables in JSON"
- "JSON schema validation"

### After (.tres-focused)
- ".tres resources for all content and config"
- "Type-safe @export properties" 
- "Inspector-driven content creation"
- "Resource class inheritance patterns"

## Content Creation Workflow Updates

### New Recommended Workflow
1. Create resource class with @export properties
2. Use Inspector to create .tres files
3. Test loading in systems
4. Version control .tres files normally

### Remove Old JSON Workflow
- Remove JSON schema creation steps
- Remove JSON validation references
- Remove manual JSON editing instructions

## Testing Documentation

### Update Test Examples
- [ ] Change test examples to use .tres loading
- [ ] Update resource loading test patterns
- [ ] Show Inspector-based test data creation

## Success Criteria

- ✅ CLAUDE.md shows .tres as primary format
- ✅ data/README.md documents resource classes instead of JSON schemas
- ✅ ARCHITECTURE.md reflects .tres in ContentDB
- ✅ All documentation consistently shows .tres workflow
- ✅ No misleading JSON references remain
- ✅ Inspector editing documented as standard approach
- ✅ Migration context documented for future reference