# Reversion Plan - Back to Working State

## Goal
Revert to commit `940a8d7` (spatial grid fix) which has all 3 real performance optimizations, before the EnemyPhysicsController experiments began.

## Step-by-Step Instructions

### 1. Save Template Speed Fixes (Important!)
```bash
# Stash ONLY the template files (these are real bug fixes)
git add data/content/enemy-templates/boss_base.tres
git add data/content/enemy-variations/*.tres
git stash push -m "Template speed fixes to preserve"
```

### 2. Revert to Last Good Commit
```bash
# This reverts 7 commits and restores working state
git reset --hard 940a8d7

# Commit message: "fix(collision): use EntityTracker spatial grid instead of linear scan"
```

### 3. Restore Template Speed Fixes
```bash
# Apply the stashed template fixes back
git stash pop
```

### 4. Commit Template Fixes Properly
```bash
git add data/content/enemy-templates/boss_base.tres
git add data/content/enemy-variations/*.tres
git commit -m "fix(templates): correct enemy speed ranges from 500-1000 to 45-80 px/s

Root cause: Enemy templates had inflated speed_range values (500-1000 px/s)
causing bosses to move 10× faster than intended.

Fix:
- boss_base.tres: speed_range Vector2(500, 1000) → Vector2(50, 80)
- banana_lord.tres: Vector2(500, 600) → Vector2(50, 70)
- ancient_lich.tres: Vector2(500, 800) → Vector2(60, 80)
- ancient_slime.tres: Vector2(500, 800) → Vector2(55, 75)
- demon_overlord.tres: Vector2(500, 800) → Vector2(65, 80)
- dragon_lord.tres: Vector2(500, 800) → Vector2(45, 65)

This was a data bug unrelated to the 400+ enemy performance issue.

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>"
```

### 5. Verify Clean State
```bash
git status  # Should show clean working tree
git log --oneline -5  # Should show template fix, then 940a8d7, 78e2b90, 179fa53
```

## What You'll Have After Reversion

### ✅ **Performance Optimizations (Kept)**
1. **Spatial grid collision detection** - 99% reduction in collision checks
2. **Staggered AI updates** - 87.5% reduction in AI overhead
3. **Spatial query player collisions** - 99% reduction in distance checks

**Combined:** Handles 400-1000 enemies smoothly at stable 30Hz.

### ✅ **Bug Fixes (Kept)**
- Template speed corrections (50-80 px/s instead of 500-1000 px/s)

### ❌ **Removed (Complexity Without Benefit)**
- EnemyPhysicsController centralized physics system
- CharacterBody2D → Node2D conversions
- Personal space radius runtime overrides
- Personal space strength tweaks

### 🏗️ **Architecture Restored**
- **BaseBoss:** Extends CharacterBody2D, uses move_and_slide()
- **Boss Scenes:** CharacterBody2D root type (standard Godot pattern)
- **BossUpdateManager:** Only handles AI batching (no physics)
- **Personal Space:** Area2D signals with moderate forces

## Expected Performance

At 400+ enemies:
- **FPS:** Stable 30Hz (no lag spikes)
- **AI Updates:** 87.5% reduction via batching
- **Collision:** 99% reduction via spatial grid
- **Boss Movement:** Standard move_and_slide() (simple and proven)

## Testing After Reversion

1. **Spawn 400+ enemies** via debug panel (V key repeatedly)
2. **Verify smooth movement** - no "quick step" lag behavior
3. **Check boss speeds** - should be 50-80 px/s, not 500+ px/s
4. **Confirm no parser errors** - EnemyPhysicsController references gone
5. **Test personal space** - bosses maintain spacing without overlapping

## Rollback Safety

If you need to restore the EnemyPhysicsController work later:
```bash
# Create a backup branch before reverting
git branch backup/physics-controller-experiment HEAD
git reset --hard 940a8d7

# Later, if needed:
git cherry-pick backup/physics-controller-experiment
```

---
**TL;DR:** Revert 7 commits to get back to `940a8d7`, preserve template speed fixes. You'll keep all 3 real performance optimizations and remove the experimental complexity.
