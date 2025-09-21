<!--
name: commit
description: Analyze current git changes and create smart conventional commits automatically
usage: /commit
model: sonnet
allowed-tools: Bash(git add:*), Bash(git status:*), Bash(git commit:*), Bash(git diff:*), Bash(git log:*)
-->

# Smart Git Commit for Vibe Project

Analyze current git state and create intelligent commits based on actual changes.

## 📊 Current Repository State

### Git Status Check
```bash
# Check current state
git status --porcelain
git branch --show-current
git diff --cached --stat
git diff --stat
git log --oneline -5
```

## 🎯 What This Command Does

1. **Analyzes current git state** - Automatically checks staged/unstaged files
2. **Stages files intelligently** - If nothing staged, analyzes and stages appropriate files
3. **Understands the changes** - Uses git diff to analyze what actually changed
4. **Detects change patterns** - Identifies system types, file patterns, and impact scope
5. **Generates smart commit messages** - Creates conventional format based on actual changes
6. **Handles multiple concerns** - Suggests/creates multiple commits if changes are unrelated
7. **Validates vibe patterns** - Ensures compliance with project architecture

## 🚀 Automated Commit Analysis Workflow

### Phase 1: Git State Analysis
**Automatically check:**
```bash
# Get current status
git status --porcelain
git diff --name-only  # Unstaged changes
git diff --cached --name-only  # Staged changes
git diff --stat  # Change summary
git diff --cached --stat  # Staged summary
```

### Phase 2: Smart File Staging
**If no files staged:**
1. **Analyze all changed files** for related changes
2. **Group by logical concerns** (same feature, same system, same fix)
3. **Stage first logical group** for initial commit
4. **Leave unrelated changes** for separate commits

### Phase 3: Change Pattern Detection
**Automatically analyze diff content for:**
- **File paths** → Determine affected systems (autoload/, scripts/systems/, etc.)
- **Code patterns** → Identify EventBus signals, Logger usage, .tres changes
- **Function signatures** → Detect API changes, new features, bug fixes
- **Performance code** → 30Hz combat loops, MultiMesh, object pools
- **Test patterns** → .tscn vs .gd, Monte-Carlo sims

### Phase 4: Intelligent Commit Type Detection
**Based on analysis, auto-determine type:**

🎮 **Game-Specific Types:**
- ⚔️ `combat`: Combat system, damage, abilities
- 🌊 `waves`: Wave spawning, enemy management
- 🎯 `arena`: Arena mechanics, boundaries, zones
- 📊 `balance`: Tuning, rates, damage values
- 🎲 `rng`: Random generation, seeding, determinism
- 🔊 `audio`: Sound effects, music, audio systems
- 🎨 `visuals`: Sprites, animations, UI styling
- 🎮 `input`: Controls, player interaction
- 💾 `data`: .tres files, content, schemas

📋 **Standard Types:**
- ✨ `feat`: New feature
- 🐛 `fix`: Bug fix
- 📝 `docs`: Documentation
- 💄 `style`: Code formatting
- ♻️ `refactor`: Code restructuring
- ⚡️ `perf`: Performance improvements
- ✅ `test`: Tests, Monte-Carlo sims
- 🔧 `chore`: Tools, configuration

### Step 4: Commit Message Format
```
<emoji> <type>: <description>

[Optional body explaining what and why]

[Optional footer with breaking changes or issue references]
```

## 🧱 Multi-Commit Detection Rules

**Split commits when changes involve:**

1. **Different system layers**
   - autoload/ + scripts/systems/ → Separate commits
   - scripts/domain/ + scenes/ → Usually separate

2. **Different concerns**
   - Combat mechanics + UI styling → Split
   - Bug fix + new feature → Split
   - Data files + code logic → Can be together if related

3. **Different file types**
   - .gd scripts + .tres resources → Together if same feature
   - .gd scripts + .md docs → Split unless docs explain code

4. **Breaking vs non-breaking**
   - Breaking API changes → Separate commit
   - New features → Separate from fixes

## 📋 Vibe-Specific Commit Examples

### Combat System Changes:
```
⚔️ combat: implement critical hit multiplier system

- Add crit_chance and crit_multiplier to DamageSystem
- Create CriticalHitPayload for EventBus.critical_hit signal
- Update damage calculation in 30Hz combat step
- Add crit rate to enemy balance configs

Maintains 30Hz performance, uses deterministic RNG.crit stream
```

### EventBus Signal Addition:
```
🔧 chore: add boss_spawned signal to EventBus

- Create BossSpawnedPayload with boss_id and position
- Document signal in autoload/CLAUDE.md
- Update BossSpawnManager to emit signal
- Prepare for UI boss health bar integration
```

### Resource Schema Update:
```
💾 data: extend EnemyType with movement patterns

- Add movement_speed and movement_pattern fields
- Create example configs for basic enemy types
- Document schema in data/content/enemy-templates/README.md
- Backward compatible with existing enemy files
```

### Performance Optimization:
```
⚡️ perf: optimize projectile rendering with MultiMesh

- Implement ProjectileMultiMesh for high-count scenarios
- Maintain object pools for game logic
- Separate rendering from 30Hz combat calculations
- 40% fps improvement with 100+ projectiles
```

### Testing Addition:
```
✅ test: add Monte-Carlo DPS validation for new abilities

- Create headless test for ability damage output
- Use deterministic RNG seeds for consistency
- Validate DPS within ±10% of expected values
- Test pattern: .tscn with autoload dependencies
```

## 🔍 Validation Checklist

### Before Each Commit:
- [ ] **Git status clean** - No unintended files included
- [ ] **Diff reviewed** - All changes intentional and related
- [ ] **Conventional format** - Proper emoji + type + description
- [ ] **Vibe patterns followed** - EventBus, Logger, layer boundaries
- [ ] **Performance considered** - 30Hz combat, rendering impact
- [ ] **Documentation updated** - CLAUDE.md, CHANGELOG.md if needed

### For Breaking Changes:
- [ ] **BREAKING:** prefix in commit body
- [ ] **Migration notes** in commit description
- [ ] **Affected systems** clearly documented
- [ ] **Version bump** planned

## 🤖 Automated Implementation Process

### Step 1: Analyze Current State
```bash
# Execute these commands automatically
git status --porcelain
git diff --name-only
git diff --cached --name-only
git log --oneline -3
```

### Step 2: Intelligent Change Analysis
**Automatically determine:**
- **Affected systems** based on file paths
- **Change scope** (single feature vs multiple concerns)
- **Commit type** from code diff patterns
- **Breaking changes** from API modifications
- **Performance impact** from 30Hz combat code

### Step 3: Smart Commit Generation
**Generate commit message like:**
```
⚔️ combat: implement critical hit system for player abilities

- Add crit_chance field to AbilityType resource schema
- Update DamageSystem to calculate critical hits in 30Hz loop
- Create CriticalHitPayload for EventBus.critical_hit signal
- Maintain deterministic behavior with RNG.crit stream

Performance: No impact on combat step timing
Breaking: None - additive changes only
```

### Step 4: Multi-Commit Detection
**If multiple unrelated changes detected:**
1. **Group related changes** into logical commits
2. **Stage first group** and commit
3. **Prompt for next group** or handle automatically
4. **Continue until all changes committed**

### Step 5: Validation & Execution
**Before each commit:**
- ✅ **Validate vibe patterns** (EventBus, Logger, layers)
- ✅ **Check conventional format** (emoji + type + description)
- ✅ **Verify file staging** (only related files)
- ✅ **Execute git commit** with generated message

## 🎯 Example Automated Workflows

### Single Feature Commit:
```bash
# Input: /commit
# Detects: Modified DamageSystem.gd + new CriticalHitPayload.gd
# Output: ⚔️ combat: implement critical hit system
```

### Multi-Concern Detection:
```bash
# Input: /commit
# Detects: Modified Arena.gd + updated CHANGELOG.md + new UI component
# Action: Suggests 3 separate commits:
#   1. ⚔️ combat: arena boundary improvements
#   2. 📝 docs: update changelog for v0.3.0
#   3. ✨ feat: add boss health bar UI component
```

### Resource Schema Update:
```bash
# Input: /commit
# Detects: Modified .tres files + schema docs
# Output: 💾 data: extend enemy configs with movement patterns
```

Use this command by simply running `/commit` - it handles everything automatically! 🚀✨