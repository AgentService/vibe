<!--
name: commit
description: Analyze current git changes and create smart conventional commits automatically
usage: /commit
model: sonnet
allowed-tools: Bash(git add:*), Bash(git status:*), Bash(git commit:*), Bash(git diff:*), Bash(git log:*)
-->

# Smart Git Commit for Vibe Project

Analyze git state and create intelligent conventional commits automatically.

## 🚀 Automated Workflow

### 1. Git State Analysis
```bash
git status --porcelain
git diff --name-only
git diff --cached --name-only
git log --oneline -3
```

### 2. Smart File Staging & Commit Type Detection

**Auto-detect by file paths & patterns:**

🎮 **Game Types:** ⚔️ combat, 🌊 waves, 🎯 arena, 📊 balance, 🎲 rng, 💾 data
📋 **Standard:** ✨ feat, 🐛 fix, ♻️ refactor, ⚡️ perf, ✅ test, 🔧 chore

**Multi-commit rules:**
- Different layers (autoload/ + scripts/systems/) → Split
- Different concerns (combat + UI) → Split
- Breaking changes → Separate commit

### 3. Commit Message Format
```
<emoji> <type>: <description>

[Optional body with bullet points]
[Performance/Breaking notes if relevant]
```

## 📋 Quick Examples

```bash
⚔️ combat: implement critical hit system
- Add crit_chance to DamageSystem 30Hz loop
- Create CriticalHitPayload for EventBus
- Use deterministic RNG.crit stream

🔧 chore: add boss_spawned signal to EventBus
- Create BossSpawnedPayload
- Update BossSpawnManager to emit signal

💾 data: extend EnemyType with movement patterns
- Add movement_speed and movement_pattern fields
- Backward compatible with existing configs

⚡️ perf: optimize projectile rendering with MultiMesh
- 40% fps improvement with 100+ projectiles
- Maintain object pools for game logic
```

## 🎯 Validation Checklist
- [ ] Conventional format (emoji + type + description)
- [ ] Vibe patterns (EventBus, Logger, layer boundaries)
- [ ] Performance considered (30Hz combat impact)
- [ ] Related files only

Use `/commit` - handles everything automatically! 🚀