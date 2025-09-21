<!--
name: guide-create
description: Create system implementation guides in appropriate Obsidian folders
usage: /guide-create "system_type" "object_type" ["specific_description"]
-->

# Create System Implementation Guide

Create a new implementation guide for **$1** system: **$2** type

**Optional specific description**: $3

## ⚠️ Rules!

1. **NEVER assume** - Always verify existing patterns and conventions
2. **NEVER hallucinate** - Only reference existing, verified systems
3. **ALWAYS cite** - Sources and file references for all claims
4. **ALWAYS test** - Verify guide steps work in practice
5. **ALWAYS research** - Deep dive into existing implementation patterns before creating guide
6. **ALWAYS be consistent** - Follow established GUIDE_ naming and folder structure

## 📋 Approach

- **MANDATORY:** Use Extended Thinking with MINIMUM 6000 tokens
- ALWAYS use the TodoWrite Tool for progress tracking
- ALWAYS conduct deep research of existing systems and guides
- ALWAYS follow vibe project conventions (EventBus, Logger, .tres resources)

## 🧠 EXTENDED THINKING REQUIRED

**BEFORE creating the guide, THINK with minimum 6000 tokens about:**

```
🎯 SYSTEM ANALYSIS:
   What system type is being requested? (arena, boss, event, player, ui, etc.)
   What existing patterns exist for this system?
   What are the key implementation entry points?

🔍 OBJECT TYPE ANALYSIS:
   What specific object type within the system? (new arena type, new boss, new event, etc.)
   How do similar objects integrate with the system?
   What are the creation vs modification patterns?

📚 EXISTING PATTERNS RESEARCH:
   What guides already exist for this system?
   What implementation patterns are established in the codebase?
   What .tres schemas, EventBus signals, and autoloads are involved?

🗂️ FOLDER STRUCTURE ANALYSIS:
   Where should this guide be placed in Obsidian/systems/?
   What naming convention should be used?
   How does this relate to existing guide organization?

📋 TEMPLATE SELECTION:
   Which template approach best fits this system type?
   What are the key implementation phases for this object type?
   What are the integration points and testing requirements?
```

## 🎯 System-Specific Templates

### Arena System Guides
**Folder**: `Obsidian/systems/Arena/`
**Pattern**: Data-driven MapConfig → Scene creation → Script implementation → Integration
**Examples**: GUIDE_Arena_Creation.md, GUIDE_Arena_Usage.md

### Boss System Guides
**Folder**: `Obsidian/systems/Bosses/`
**Pattern**: Enemy template → Scene-based entity → Behavior implementation → Arena integration
**Focus**: Scene hierarchy, behavior trees, EventBus integration

### Event System Guides
**Folder**: `Obsidian/systems/Events/`
**Pattern**: Event type definition → Handler implementation → Trigger system → Integration
**Focus**: BreachEventHandler patterns, signal contracts, data structures

### Player System Guides
**Folder**: `Obsidian/systems/Player/`
**Pattern**: Character data → Scene setup → Ability integration → Progression systems
**Focus**: Character classes, ability system integration, progression mechanics

### UI System Guides
**Folder**: `Obsidian/systems/UI/`
**Pattern**: Component creation → Scene hierarchy → Signal integration → Modal patterns
**Focus**: HUD components, modal system, signal-driven updates

### Equipment System Guides
**Folder**: `Obsidian/systems/Equipment/`
**Pattern**: Item data → Resource schema → Equipment logic → Integration
**Focus**: Item templates, equipment slots, stat modifications

### General System Guides
**Folder**: `Obsidian/systems/[SystemName]/`
**Pattern**: System analysis → Implementation → Integration → Testing
**Focus**: Custom system creation, architecture integration

## 🛠️ Guide Creation Process

### 1. **System Research Phase**
```bash
# Automatically analyze relevant system files
find scripts/systems/ -name "*{system_type}*" -type f
find scripts/domain/ -name "*{object_type}*" -type f
find data/content/ -name "*{system_type}*" -type f
find Obsidian/systems/ -name "*{system_type}*" -type f
```

### 2. **Smart Folder Detection**
- **Determine target folder** based on system type
- **Check existing guides** in that folder for patterns
- **Identify naming convention** and numbering if applicable

### 3. **Template Selection Logic**
```gdscript
match system_type.to_lower():
    "arena", "arenas":
        template = ARENA_TEMPLATE
        folder = "Obsidian/systems/Arena/"
    "boss", "bosses", "enemy":
        template = BOSS_TEMPLATE
        folder = "Obsidian/systems/Bosses/"
    "event", "events", "breach":
        template = EVENT_TEMPLATE
        folder = "Obsidian/systems/Events/"
    "player", "character", "hero":
        template = PLAYER_TEMPLATE
        folder = "Obsidian/systems/Player/"
    "ui", "hud", "modal":
        template = UI_TEMPLATE
        folder = "Obsidian/systems/UI/"
    "equipment", "item", "gear":
        template = EQUIPMENT_TEMPLATE
        folder = "Obsidian/systems/Equipment/"
    _:
        template = GENERAL_TEMPLATE
        folder = "Obsidian/systems/" + system_type.capitalize() + "/"
```

### 4. **Generate Guide File Name**
- **Pattern**: `GUIDE_{SystemType}_{ObjectType}_{Action}.md`
- **Examples**:
  - `GUIDE_Arena_Creation.md` (how to create new arenas)
  - `GUIDE_Boss_Implementation.md` (how to implement new boss types)
  - `GUIDE_Event_NewTypes.md` (how to create new event types)
  - `GUIDE_Player_NewClass.md` (how to add new player classes)
  - `GUIDE_UI_ComponentCreation.md` (how to create UI components)

### 5. **Template Structure Components**

**Universal Guide Structure:**
```markdown
# [Action] Guide: [SystemType] - [ObjectType]

## 🎯 Overview
[Brief description and context]

**★ Insight ─────────────────────────────────────**
- **[Key Pattern 1]**: [Description]
- **[Key Pattern 2]**: [Description]
- **[Key Pattern 3]**: [Description]
**─────────────────────────────────────────────────**

## 🚀 Quick Start Checklist
### Phase 1: [First Phase]
- [ ] [Step 1]
- [ ] [Step 2]

### Phase 2: [Second Phase]
- [ ] [Step 1]
- [ ] [Step 2]

[Additional phases as needed]

## 📋 Step-by-Step Implementation
[Detailed implementation steps with code examples]

## 🧪 Testing Your [ObjectType]
[Testing procedures and validation steps]

## 🎨 Advanced Patterns
[Optional enhancements and advanced usage]

## 🚀 Next Steps
[Follow-up tasks and related guides]

## 📚 References
[Related files, documentation, and examples]
```

**System-Specific Adaptations:**

**Arena Template Additions:**
- MapConfig .tres creation patterns
- Scene hierarchy requirements
- Zone-based spawning integration
- Visual environment setup

**Boss Template Additions:**
- Enemy template inheritance
- Behavior state machine setup
- Attack pattern implementation
- Arena integration points

**Event Template Additions:**
- Event type registration
- Handler implementation patterns
- Trigger system integration
- Data structure requirements

**Player Template Additions:**
- Character class definition
- Ability system integration
- Progression mechanics
- Equipment compatibility

**UI Template Additions:**
- Component scene hierarchy
- Signal integration patterns
- Modal system usage
- HUD component creation

## 📋 Implementation Steps

1. **Research existing patterns** for the requested system
2. **Select appropriate template** based on system type
3. **Create folder structure** if needed
4. **Generate guide file** with proper GUIDE_ naming
5. **Populate template** with system-specific content
6. **Add file references** and code examples
7. **Create integration checklist** for testing
8. **Link to related guides** and documentation

## 🔗 Integration Requirements

### Must Include in Every Guide:
- [ ] **EventBus patterns** - How signals are used
- [ ] **Logger integration** - Proper logging with categories
- [ ] **Resource files** - .tres schemas and data patterns
- [ ] **Performance considerations** - 30Hz compatibility notes
- [ ] **Testing approach** - .tscn vs .gd test patterns
- [ ] **File structure** - Where files belong in the project
- [ ] **Related documentation** - Links to other guides and CLAUDE.md files

### Vibe Project Integration:
- [ ] **Layer boundaries** - Respect domain/systems/scenes separation
- [ ] **Signal-driven communication** - No direct node references
- [ ] **Data-driven configuration** - Use .tres resources appropriately
- [ ] **Hot-reload support** - F5 compatibility where applicable
- [ ] **Deterministic patterns** - RNG streams, fixed timestep considerations

## 🤖 Parallel Agent Coordination

**MANDATORY:** Use parallel agents for comprehensive guide creation:

### Agent 1: System Archaeology
```
"Analyze the vibe codebase for [system_type] patterns:
- Existing implementations and file structure
- EventBus signal usage and contracts
- Resource file patterns and schemas
- Integration points with other systems
Return structured analysis with file:line references."
```

### Agent 2: Guide Pattern Analysis
```
"Research existing GUIDE_ files for [system_type]:
- Current guide structure and templates
- Implementation step patterns
- Testing and validation approaches
- Integration requirements and checklists
Return consistent pattern recommendations."
```

### Agent 3: Implementation Research
```
"Research [object_type] implementation requirements:
- Required file structure and naming
- Key classes and inheritance patterns
- Configuration and data requirements
- Performance and architectural considerations
Return practical implementation roadmap."
```

## ⚠️ VALIDATION CHECKPOINTS

**BEFORE creating the guide:**

- [ ] **Extended Thinking completed** with MINIMUM 6000 tokens
- [ ] **System patterns researched** with file references
- [ ] **Existing guides analyzed** for consistency
- [ ] **Template selected** based on system type
- [ ] **Folder structure determined** following project conventions
- [ ] **Integration requirements identified** (EventBus, Logger, etc.)
- [ ] **All parallel agents completed** and results integrated

**ONLY AFTER ALL CHECKPOINTS:** Create the detailed guide file

## 📚 Context7 MCP Integration

### Mandatory Godot Documentation Research

**For Godot-specific implementation patterns:**

1. **Resolve Godot Library ID**
   ```
   Use mcp__context7__resolve-library-id with "godot" to get proper ID
   ```

2. **Get Relevant Documentation**
   ```
   Use mcp__context7__get-library-docs with:
   - context7CompatibleLibraryID: [from step 1]
   - topic: [specific to guide type, e.g., "scenes", "signals", "resources"]
   - tokens: 5000 (for comprehensive coverage)
   ```

### Include in Guide Documentation:
```markdown
## 📚 Official Godot Integration

### Relevant Godot Patterns:
[Auto-populated from Context7 research]

### Best Practices from Docs:
[Performance and architectural guidance]

### Code Examples:
[Official examples adapted for vibe patterns]
```

## 🎯 Example Usage

```bash
# Create new arena type guide
/guide-create "arena" "volcanic" "lava-themed arena with environmental hazards"

# Create new boss implementation guide
/guide-create "boss" "miniboss" "smaller boss entities for wave encounters"

# Create new event type guide
/guide-create "event" "ritual" "ritual event system for summoning mechanics"

# Create new player class guide
/guide-create "player" "necromancer" "death magic focused character class"

# Create new UI component guide
/guide-create "ui" "inventory" "expandable inventory modal system"
```

## 🚨 Success Criteria

- [ ] **Guide is actionable** - Someone can follow it step-by-step
- [ ] **Integration verified** - Works with existing vibe systems
- [ ] **Patterns consistent** - Follows established project conventions
- [ ] **Testing included** - Clear validation and debugging steps
- [ ] **Documentation linked** - References to CLAUDE.md and related guides
- [ ] **Performance considered** - 30Hz compatibility and optimization notes
- [ ] **Future-proofed** - Extensible patterns for system evolution

## 📋 Status Indicators

- 🟡 **Research** - Analyzing existing patterns and requirements
- 🔵 **Template** - Selecting and customizing guide template
- 🟠 **Writing** - Creating step-by-step implementation content
- 🟢 **Complete** - Guide ready and validated
- 🔴 **Blocked** - Missing dependencies or unclear requirements