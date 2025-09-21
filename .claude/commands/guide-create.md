<!--
name: guide-create
description: Create system implementation guides in appropriate Obsidian folders
usage: /guide-create "description of what you want to implement"
-->

# Create System Implementation Guide

Create a new implementation guide based on your description: **$1**

Claude will intelligently analyze your description to determine:
- **System type** (arena, boss, event, player, ui, equipment, etc.)
- **Object type** (specific implementation within the system)
- **Implementation approach** (creation, modification, integration)

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
🧠 DESCRIPTION ANALYSIS:
   What is the user trying to implement based on their description?
   What keywords indicate the system type (arena, boss, event, player, ui, etc.)?
   What specific object or feature are they describing?
   What implementation approach is implied (create new, modify existing, integrate)?

🎯 INTELLIGENT SYSTEM DETECTION:
   Based on the description, what system type is being requested?
   What existing patterns exist for this detected system?
   What are the key implementation entry points for this system?

🔍 OBJECT TYPE INFERENCE:
   What specific object type can be inferred from the description?
   How do similar objects integrate with the detected system?
   What are the creation vs modification patterns for this object type?

📚 EXISTING PATTERNS RESEARCH:
   What guides already exist for the detected system?
   What implementation patterns are established in the codebase?
   What .tres schemas, EventBus signals, and autoloads are involved?

🗂️ FOLDER STRUCTURE ANALYSIS:
   Where should this guide be placed in Obsidian/systems/?
   What naming convention should be used?
   How does this relate to existing guide organization?

📋 TEMPLATE SELECTION:
   Which template approach best fits the detected system type?
   What are the key implementation phases for the inferred object type?
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

### 3. **Intelligent Template Selection Logic**
Claude analyzes the description to determine the best template:

**Description Keywords → System Detection:**
- **Arena/Environment**: "arena", "level", "map", "zone", "environment", "volcanic", "underwater", "forest"
- **Boss/Enemy**: "boss", "enemy", "monster", "creature", "miniboss", "encounter", "fight"
- **Event/Mechanics**: "event", "breach", "ritual", "mechanic", "system", "trigger", "condition"
- **Player/Character**: "player", "character", "class", "hero", "necromancer", "warrior", "abilities"
- **UI/Interface**: "ui", "hud", "modal", "inventory", "menu", "interface", "component", "widget"
- **Equipment/Items**: "equipment", "item", "weapon", "armor", "gear", "loot", "drop"

**Auto-Selected Template and Folder:**
```
Description analysis → Detected system → Template + Folder
"volcanic arena" → Arena system → ARENA_TEMPLATE + "Obsidian/systems/Arena/"
"necromancer class" → Player system → PLAYER_TEMPLATE + "Obsidian/systems/Player/"
"inventory modal" → UI system → UI_TEMPLATE + "Obsidian/systems/UI/"
```

### 4. **Auto-Generate Guide File Name**
Claude intelligently generates file names based on description analysis:

**Pattern**: `GUIDE_{DetectedSystem}_{InferredObject}_{DeterminedAction}.md`

**Examples of Intelligent Naming**:
- Description: "volcanic arena with lava hazards" → `GUIDE_Arena_Volcanic_Creation.md`
- Description: "necromancer player class" → `GUIDE_Player_Necromancer_Implementation.md`
- Description: "inventory modal system" → `GUIDE_UI_Inventory_Creation.md`
- Description: "miniboss encounters" → `GUIDE_Boss_Miniboss_Implementation.md`
- Description: "ritual event mechanics" → `GUIDE_Event_Ritual_Creation.md`

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
"Analyze the vibe codebase for patterns related to: [user_description]
- Identify the most relevant system from the description
- Find existing implementations and file structure
- Analyze EventBus signal usage and contracts
- Document resource file patterns and schemas
- Map integration points with other systems
Return structured analysis with file:line references."
```

### Agent 2: Guide Pattern Analysis
```
"Research existing GUIDE_ files related to: [user_description]
- Determine the most appropriate guide category
- Analyze current guide structure and templates
- Document implementation step patterns
- Review testing and validation approaches
- Extract integration requirements and checklists
Return consistent pattern recommendations for this type of implementation."
```

### Agent 3: Implementation Research
```
"Research implementation requirements for: [user_description]
- Infer the specific object/feature type being described
- Document required file structure and naming
- Identify key classes and inheritance patterns
- Analyze configuration and data requirements
- Note performance and architectural considerations
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
# Claude intelligently determines: Arena system, Volcanic type, Creation action
/guide-create "volcanic arena with lava hazards and environmental damage"

# Claude intelligently determines: Boss system, Miniboss type, Implementation action
/guide-create "smaller boss entities for wave encounters and mini-bosses"

# Claude intelligently determines: Event system, Ritual type, Creation action
/guide-create "ritual event system for summoning mechanics and player interaction"

# Claude intelligently determines: Player system, Necromancer type, Implementation action
/guide-create "necromancer character class with death magic and minion control"

# Claude intelligently determines: UI system, Inventory type, Creation action
/guide-create "expandable inventory modal system with drag and drop"

# Claude intelligently determines: Equipment system, Weapon type, Creation action
/guide-create "legendary weapon system with special effects and upgrade paths"
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