<!--
name: task-create
description: Create structured tasks in Obsidian/03-tasks/ directory
usage: /task-create "task description"
-->

# Create Obsidian Task

Create a new structured task in Obsidian: **$ARGUMENTS**

## ⚠️ Rules!

1. **NEVER assume** - Always verify or ask questions
2. **NEVER hallucinate** - Only existing, verified components
3. **ALWAYS cite** - Sources and references for all claims
4. **ALWAYS test** - No untested changes
5. **ALWAYS research** - As soon as there's even the slightest doubt about a technical implementation - immediately conduct deep research with multiple sources and official documentation (GitHub, Docs, etc.) to fully verify the code before responding
6. **ALWAYS be honest** - Give your honest opinion without adopting the user's tone/mood. If you disagree, simply say you disagree and explain why.

## 📋 Approach

- **MANDATORY:** Use Extended Thinking with MINIMUM 8000 tokens
- ALWAYS use the TodoWrite Tool
- ALWAYS use emojis to better present or highlight things in your outputs or summaries
- ALWAYS conduct deep research if any technical doubt exists

## 🧠 EXTENDED THINKING REQUIRED

**BEFORE creating the task, THINK with minimum 8000 tokens about:**

```
🎯 TASK UNDERSTANDING:
   What exactly needs to be achieved?

📊 COMPLEXITY ANALYSIS:
   How complex is this task? (1-10 scale)

🔍 VIBE PROJECT ANALYSIS:
   Which systems will be affected?
   What EventBus signals might be needed?
   What .tres resources are involved?
   How does this fit with 30Hz combat?

📚 GODOT DOCUMENTATION RESEARCH:
   Use Context7 MCP to research relevant Godot concepts
   What official patterns apply to this task?
   Are there performance considerations in the docs?
   What examples exist in Godot documentation?

⚠️ RISK ASSESSMENT:
   What could go wrong?
   What are the integration challenges?
   Performance implications?

🔗 DEPENDENCIES:
   What existing code can be reused?
   What patterns should be followed?
   Which autoloads are involved?
```

## ALWAYS Look at and Include Existing CODE

**MANDATORY CODE ARCHAEOLOGY:**
1. Similar implementations for the pending task
2. Reusable patterns and modules (EventBus, Logger, RNG)
3. Project-specific conventions (layer boundaries, 30Hz patterns)
4. Relevant dependencies and their versions (.tres schemas, autoloads)

## 🎯 Intelligent Task Creation Process

### 1. **Automated Analysis Phase**
**BEFORE generating task file, automatically:**
```bash
# Analyze current project state
git status --porcelain
git log --oneline -5
find scripts/systems/ -name "*.gd" -type f | head -10
find autoload/ -name "*.gd" -type f
```

**Smart task categorization based on description:**
- **Combat tasks** → ⚔️ Focus on DamageSystem, 30Hz patterns, EventBus signals
- **UI tasks** → 🎨 Focus on scenes/, EventBus integration, visual components
- **Data tasks** → 💾 Focus on .tres schemas, data/ directory, resource patterns
- **System tasks** → 🔧 Focus on autoload/, architecture, performance impact

### 2. **Generate Task File Name**
- **Automatically convert** task description to snake_case filename
- **Auto-add** current date prefix: `YYYY-MM-DD_task_name.md`
- **Auto-determine** location: `Obsidian/03-tasks/YYYY-MM-DD_task_name.md`

### 3. **Smart Task Template Generation**

**Automatically populate template based on analysis:**

```markdown
# [TASK_NAME]

**Created:** [CURRENT_DATE]
**Status:** 🟡 Planning
**Priority:** [Low/Medium/High]
**Estimated Effort:** [Hours/Days]

## 📋 Task Description

[DETAILED_DESCRIPTION]

## 🎯 Acceptance Criteria

- [ ] Criterion 1
- [ ] Criterion 2
- [ ] Criterion 3

## 🔍 Technical Analysis

### Affected Systems
- [ ] autoload/ (EventBus, RNG, RunManager, Logger)
- [ ] scripts/systems/ (Arena, DamageSystem, etc.)
- [ ] scripts/domain/ (Data models, signal payloads)
- [ ] scenes/ (UI components, visual elements)
- [ ] data/ (Content .tres files, balance configs)
- [ ] tests/ (Monte-Carlo sims, validation)
- [ ] new system?

### Dependencies & Patterns
- **EventBus Signals:** [List new/modified signals]
- **Resource Files:** [New .tres files needed]
- **Performance Impact:** [30Hz combat compatibility]
- **Testing Strategy:** [.tscn vs .gd patterns]

## 📊 Implementation Plan

### Phase 1: Analysis & Design
- [ ] Study existing similar implementations
- [ ] Design EventBus signal contracts
- [ ] Plan resource file schemas
- [ ] Identify reusable patterns

### Phase 2: Core Implementation
- [ ] Create/modify domain models
- [ ] Implement system logic
- [ ] Add EventBus integration
- [ ] Create resource files

### Phase 3: UI & Integration
- [ ] Build UI components (if needed)
- [ ] Wire EventBus connections
- [ ] Add logging with Logger and make sure the used category is available in debug.tres (add if not, also in LogConfigResource)
- [ ] Performance optimization

### Phase 4: Testing & Validation
- [ ] Write/update tests (headless Godot)
- [ ] Monte-Carlo simulation (if combat-related)
- [ ] Performance validation (30Hz compatibility)
- [ ] Edge case testing

### Phase 5: Documentation & Finalization
- [ ] Update relevant CLAUDE.md files
- [ ] Update CHANGELOG.md
- [ ] Document new patterns in Obsidian/systems/
- [ ] Prepare commit with conventional format

## 🔗 Related Files

### Will Likely Modify:
- [ ] `autoload/EventBus.gd` (new signals)
- [ ] `scripts/systems/[relevant_system].gd`
- [ ] `scripts/domain/[models].gd`
- [ ] `data/content/[new_resources].tres`

### Documentation Updates Needed:
- [ ] `autoload/CLAUDE.md`
- [ ] `scripts/systems/CLAUDE.md`
- [ ] `scripts/domain/CLAUDE.md`
- [ ] `scenes/CLAUDE.md`
- [ ] `tests/CLAUDE.md`
- [ ] `Obsidian/systems/[system_docs].md`

## 📝 Progress Notes

### [DATE] - Planning
- Initial task creation
- [Add notes as you progress]

### [DATE] - Implementation
- [Track progress and decisions]

### [DATE] - Testing
- [Test results and issues]

### [DATE] - Completion
- [Final notes and lessons learned]

## 🚨 Risks & Considerations

- **Performance:** [30Hz combat impact]
- **Architecture:** [Layer boundary respect]
- **Testing:** [Headless compatibility]
- **Dependencies:** [Existing system integration]

## ✅ Definition of Done

- [ ] All acceptance criteria met
- [ ] Code follows vibe project patterns
- [ ] EventBus properly used (no direct coupling)
- [ ] Logger used (no print() statements)
- [ ] Tests written and passing
- [ ] Documentation updated
- [ ] CHANGELOG.md updated
- [ ] Performance validated via `bash tests\run_performance_tests.sh`
- [ ] Commit ready with conventional format
```

## 🛠️ Implementation Steps

1. **Create the task file** in `Obsidian/03-tasks/`
2. **Fill in the template** with specific details
3. **Link to related Obsidian documents** if applicable
4. **Update task status** as you progress through phases
5. **Use as checklist** throughout implementation

## 📋 Status Indicators

- 🟡 **Planning** - Initial analysis and design
- 🔵 **In Progress** - Active implementation
- 🟠 **Testing** - Validation phase
- 🟢 **Complete** - Ready for commit
- 🔴 **Blocked** - Waiting for dependencies

## 🤖 Parallel Agent Coordination

**MANDATORY:** Use as many parallel agents as needed for optimal task analysis:

### Agent 1: Code Archaeology
```
"Analyze the vibe project for:
- Similar implementations to: $ARGUMENTS
- Reusable EventBus patterns and autoload systems
- Existing .tres schemas and data patterns
- 30Hz combat integration points
Return structured analysis with file:line references."
```

### Agent 2: Technical Research + Context7 MCP
```
"Research technical requirements for: $ARGUMENTS
- MANDATORY: Use Context7 MCP to get up-to-date Godot documentation
- Godot 4.2+ best practices and patterns from official docs
- Performance implications for 30Hz combat loops
- EventBus signal design patterns
- Resource file organization strategies
- MultiMeshInstance2D usage for high-count rendering
- Scene tree optimization techniques
Return implementation recommendations with official doc citations."
```

### Agent 3: Risk Assessment
```
"Assess risks and challenges for: $ARGUMENTS
- Integration complexity with existing systems
- Performance bottlenecks and optimization needs
- Breaking change potential and migration paths
- Testing strategy and validation approaches
Return comprehensive risk analysis."
```

## ⚠️ VALIDATION CHECKPOINTS

**BEFORE proceeding with task creation:**

- [ ] **Extended Thinking completed** with MINIMUM 8000 tokens
- [ ] **Context7 MCP research completed** for Godot documentation
- [ ] **All parallel agents launched** and results analyzed
- [ ] **Code archaeology conducted** for similar implementations
- [ ] **Technical research verified** with official documentation
- [ ] **Risk assessment completed** with mitigation strategies
- [ ] **TodoWrite tool used** throughout the process

**ONLY AFTER ALL CHECKPOINTS:** Create the detailed task file

## 📚 Context7 MCP Integration Workflow

### Mandatory Godot Documentation Research

**BEFORE any Godot-related task creation:**

1. **Resolve Godot Library ID**
   ```
   Use mcp__context7__resolve-library-id with "godot" to get the proper library ID
   ```

2. **Get Relevant Documentation**
   ```
   Use mcp__context7__get-library-docs with:
   - context7CompatibleLibraryID: [from step 1]
   - topic: [specific to your task, e.g., "signals", "scenes", "performance"]
   - tokens: 5000 (for comprehensive coverage)
   ```

### Integration with Task Template

**Automatically include in task:**

```markdown
## 📚 Official Godot Documentation Research

### Relevant Concepts from Godot Docs:
[Auto-populated from Context7 MCP research]

### Best Practices Identified:
[Performance patterns, architectural recommendations]

### Examples from Documentation:
[Code examples relevant to the task]

### Performance Considerations:
[Official performance guidance for this feature type]
```
