<!--
name: update-docs
description: Automatically update CLAUDE.md files and Obsidian/systems/ documentation based on recent changes
usage: /update-docs
-->

# Smart Documentation Update

Automatically analyze recent changes and update relevant CLAUDE.md files and Obsidian documentation.

## 🔍 Automated Documentation Analysis

### 1. **Auto-Detect Changes**

**Analyze recent git activity:**
```bash
# Get recent commits and changes
git log --oneline -5
git diff HEAD~1 HEAD --name-only
git diff HEAD~1 HEAD --stat
git show --name-only HEAD
```

**Automatically determine documentation updates based on file paths:**

### 2. **File Pattern → Documentation Mapping**

**autoload/ changes → Update `autoload/CLAUDE.md`:**
- `autoload/EventBus.gd` → New signals, payload types, integration patterns
- `autoload/RNG.gd` → New streams, seeding patterns, deterministic usage
- `autoload/RunManager.gd` → State management, scene transitions
- `autoload/Logger.gd` → New categories, logging patterns

**scripts/systems/ changes → Update `scripts/systems/CLAUDE.md`:**
- `scripts/systems/Arena.gd` → Combat coordination, 30Hz patterns
- `scripts/systems/DamageSystem.gd` → Damage calculation, performance notes
- `scripts/systems/BossSpawnManager.gd` → Spawning patterns, zone logic
- Any system file → EventBus integration, resource dependencies

**scripts/domain/ changes → Update `scripts/domain/CLAUDE.md`:**
- `scripts/domain/signal_payloads/*.gd` → New payload contracts, usage
- `scripts/domain/EnemyType.gd` → Data model relationships, schemas
- Any domain model → Pure data patterns, system integration

**scenes/ changes → Update `scenes/CLAUDE.md`:**
- `scenes/ui/` → UI component patterns, EventBus integration
- `scenes/arena/` → Scene structure, visual organization
- Any scene file → Component usage, signal wiring patterns

**data/ changes → Update relevant documentation:**
- `data/content/*.tres` → Schema documentation, usage examples
- `data/balance/*.tres` → Balance pattern documentation
- Resource changes → Content management patterns

**tests/ changes → Update `tests/CLAUDE.md`:**
- New `.tscn` tests → Autoload dependency patterns
- New `.gd` tests → Standalone testing patterns
- Monte-Carlo sims → Validation approaches, headless execution

### 2. **Required Documentation Updates**

#### For autoload/CLAUDE.md:
```markdown
## New Patterns Added

### [Date] - [Task Name]
- **New EventBus Signals:** [List with payload types]
- **RNG Stream Usage:** [New streams or patterns]
- **Logger Categories:** [New categories added]
- **Integration Notes:** [How other systems should use these]

## Updated Dependencies
- [List any new autoload dependencies]
- [Modified initialization order]
- [Changed signal contracts]
```

#### For scripts/systems/CLAUDE.md:
```markdown
## New System Patterns

### [Date] - [Task Name]
- **System:** [Which system was modified/added]
- **30Hz Compatibility:** [Performance impact notes]
- **EventBus Integration:** [Signals consumed/emitted]
- **Resource Dependencies:** [.tres files used]
- **Common Gotchas:** [Issues to watch for]

## Integration Examples
[Code snippets showing how to integrate with this system]
```

#### For scripts/domain/CLAUDE.md:
```markdown
## New Domain Models

### [Date] - [Task Name]
- **Models Added/Modified:** [List with brief descriptions]
- **Signal Payload Changes:** [New or modified payloads]
- **Relationships:** [How models connect to existing ones]
- **Usage Patterns:** [How systems should use these models]

## Schema Changes
[Document any breaking changes or new patterns]
```

#### For scenes/CLAUDE.md:
```markdown
## New UI Patterns

### [Date] - [Task Name]
- **Components Added:** [New scene components]
- **EventBus Integration:** [UI-specific signal patterns]
- **Scene Structure:** [New organizational patterns]
- **Performance Notes:** [Rendering implications]

## Component Usage
[Examples of how to use new components]
```

#### For tests/CLAUDE.md:
```markdown
## New Testing Patterns

### [Date] - [Task Name]
- **Test Type:** [.tscn vs .gd pattern]
- **Autoload Dependencies:** [Which autoloads needed]
- **Monte-Carlo Updates:** [New simulation patterns]
- **Headless Execution:** [Command line patterns]

## Test Examples
[Code snippets for similar tests]
```

### 3. **Obsidian Systems Documentation**

#### Update Obsidian/systems/[SystemName].md:
```markdown
## Recent Changes

### [Date] - [Task Name]
**Impact:** [Brief description of architectural impact]

**Changes Made:**
- [Detailed technical changes]
- [New patterns introduced]
- [Performance implications]

**Integration Points:**
- [How this affects other systems]
- [New dependencies created]
- [EventBus signal contracts]

**Migration Notes:**
- [Breaking changes]
- [How to adapt existing code]
- [Best practices for using new features]
```

## 🤖 Automated Documentation Workflow

### Phase 1: Change Detection & Analysis
**Automatically execute:**
```bash
# Analyze recent changes
git log --oneline -3
git diff HEAD~1 HEAD --name-only
git diff HEAD~1 HEAD --stat
git show --name-only HEAD
```

**Pattern recognition:**
- **File paths** → Determine which CLAUDE.md files need updates
- **Code diff analysis** → Identify new patterns, signals, APIs
- **Commit messages** → Extract feature context and scope
- **Breaking changes** → Detect API modifications, schema changes

### Phase 2: Smart Documentation Generation
**For each affected CLAUDE.md file:**

1. **Read existing patterns** from current documentation
2. **Extract new patterns** from code changes
3. **Generate documentation sections** with examples
4. **Maintain consistency** with existing format
5. **Add integration notes** for other developers

### Phase 3: Obsidian Systems Update
**Automatically identify system impacts:**
- **New systems** → Create new `Obsidian/systems/[System].md`
- **Modified systems** → Update existing system documentation
- **Architecture changes** → Note in relevant system files
- **Integration patterns** → Document cross-system dependencies

### Phase 4: Cross-Reference & Validation
**Ensure documentation coherence:**
- **Link related changes** across multiple CLAUDE.md files
- **Update main CLAUDE.md** if project-wide patterns affected
- **Validate examples** against actual code changes
- **Check breaking change documentation** is complete

## 📋 Quality Checklist

### Documentation Quality:
- [ ] **Clear examples** provided for new patterns
- [ ] **Integration points** documented with other systems
- [ ] **Performance implications** noted (30Hz compatibility)
- [ ] **Breaking changes** clearly marked
- [ ] **File:line references** included where relevant

### Consistency:
- [ ] **Naming conventions** match existing docs
- [ ] **Code style** consistent with project patterns
- [ ] **EventBus usage** properly documented
- [ ] **Logger categories** mentioned where relevant

### Completeness:
- [ ] **All affected areas** identified and updated
- [ ] **Future developers** have enough context
- [ ] **Migration path** clear for breaking changes
- [ ] **Examples** demonstrate real usage

## 🔗 Template Snippets

### For New EventBus Signals:
```markdown
#### Signal: `signal_name(payload: PayloadType)`
**Purpose:** [What this signal does]
**Emitted by:** [Which system emits it]
**Consumed by:** [Which systems listen]
**Payload:** [Payload structure and fields]
**Example:**
```gdscript
# Emitting
EventBus.signal_name.emit(payload_data)

# Listening
EventBus.signal_name.connect(_on_signal_name)
```

### For New System Patterns:
```markdown
#### Pattern: [Pattern Name]
**Use Case:** [When to use this pattern]
**Performance:** [30Hz combat impact]
**Integration:** [How to integrate with EventBus]
**Example:** [Code snippet]
**Gotchas:** [Common mistakes to avoid]
```

## 🎯 Automated Execution Examples

### Example 1: EventBus Signal Addition
```bash
# Input: /update-docs
# Detects: autoload/EventBus.gd modified
# Updates: autoload/CLAUDE.md with new signal documentation
# Result: Documents signal contracts, payload types, usage examples
```

### Example 2: New Combat System
```bash
# Input: /update-docs
# Detects: scripts/systems/CriticalHitSystem.gd added
# Updates: scripts/systems/CLAUDE.md + Obsidian/systems/Combat.md
# Result: Documents 30Hz integration, EventBus usage, performance notes
```

### Example 3: UI Component Changes
```bash
# Input: /update-docs
# Detects: scenes/ui/BossHealthBar.gd + scenes/ui/BossHealthBar.tscn
# Updates: scenes/CLAUDE.md with component patterns
# Result: Documents EventBus integration, usage examples, scene structure
```

### Example 4: Resource Schema Update
```bash
# Input: /update-docs
# Detects: data/content/abilities/*.tres modified
# Updates: Relevant CLAUDE.md + data/README.md
# Result: Documents schema changes, migration notes, usage patterns
```

### Example 5: Multi-System Feature
```bash
# Input: /update-docs
# Detects: Changes across autoload/, scripts/systems/, scenes/
# Updates: Multiple CLAUDE.md files + Obsidian/systems/
# Result: Comprehensive documentation of feature integration
```

## 🤖 Smart Documentation Features

### Automatic Pattern Detection
- **EventBus signals** → Extract signal names, payloads, emitters/consumers
- **New classes** → Document purpose, integration points, usage patterns
- **API changes** → Identify breaking changes, migration paths
- **Performance code** → Note 30Hz compatibility, optimization patterns
- **Resource schemas** → Document .tres structure changes

### Context-Aware Updates
- **Read existing docs** → Maintain consistent style and format
- **Detect relationships** → Link related changes across systems
- **Generate examples** → Create relevant code snippets from actual changes
- **Note gotchas** → Extract common pitfalls from code patterns

Use this command by simply running `/update-docs` - it analyzes everything automatically! 📚🚀