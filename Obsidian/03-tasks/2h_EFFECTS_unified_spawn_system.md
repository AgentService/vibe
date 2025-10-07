# Task: Unified Enemy Spawn System

**Status:** 📋 Planning
**Priority:** Medium
**Complexity:** Medium
**Created:** 2025-10-07

## Problem Statement

Currently, enemy spawn behavior is inconsistent:
- **Bosses**: Have wake-up pause + dissolve shader effect
- **Regular enemies (AncientSlime, etc.)**: No pause, no dissolve shader
- **Result**: Visual inconsistency and missed opportunity for polish

## Objectives

Implement a unified spawn system that applies consistent visual effects to ALL enemies (bosses + regular enemies).

## Design Options

### Option A: Full Wake-Up System (Recommended for Bosses)
- ✅ Apply dissolve shader on spawn
- ✅ Pause enemy on first animation frame
- ✅ Wait for player to approach (`chase_range` trigger)
- ✅ Play wake-up animation or unpause
- ✅ Enemy begins movement/AI

**Pros:**
- Dramatic encounter moments
- Consistent with BananaLord/AncientLich behavior
- Already implemented for bosses

**Cons:**
- May feel slow for regular enemy spawns
- Could affect gameplay pacing with many enemies

### Option B: Dissolve-Only System (Recommended for Regular Enemies)
- ✅ Apply dissolve shader on spawn (0.6s animation)
- ✅ Enemy AI starts immediately (moves during dissolve)
- ✅ No pause/wake-up mechanic
- ❓ **Optional:** Apply dissolve shader on death (fade-out effect)

**Pros:**
- Fast-paced, suitable for wave spawning
- Maintains visual polish without gameplay delay
- Death dissolve creates satisfying feedback

**Cons:**
- Less dramatic than full wake-up system
- Enemies move while materializing (may look odd)

### Option C: Hybrid System (Recommended Overall)
- **Bosses**: Option A (wake-up pause + dissolve)
- **Regular enemies**: Option B (dissolve only, no pause)
- **Both**: Optional death dissolve effect

**Implementation:**
```gdscript
# In BaseEnemy or SpawnDirector
func spawn_enemy(template: EnemyType, position: Vector2, is_boss: bool):
    var enemy = create_enemy(template, position)

    # Apply spawn dissolve to ALL enemies
    EnemySpawnEffect.apply_spawn_effect(enemy.sprite, get_tree())

    if is_boss:
        # Bosses get wake-up pause
        enemy.pause_until_player_approaches()
    else:
        # Regular enemies start AI immediately
        enemy.activate_ai()

    return enemy
```

## Technical Requirements

### 1. Extend EnemySpawnEffect for Regular Enemies
**Current state:** Only used by scene-based bosses
**Need:** Support for pooled enemies spawned by WaveDirector

**Changes:**
- Modify `apply_spawn_effect()` to work with pooled sprite nodes
- Add initialization hook in WaveDirector for pooled enemies
- Ensure dissolve shader works with breach modulation

### 2. Death Dissolve Effect (Optional)
**New feature:** Fade-out shader on enemy death

**Implementation:**
```gdscript
# In scripts/domain/EnemyDeathEffect.gd
static func apply_death_effect(sprite: AnimatedSprite2D, scene_tree: SceneTree) -> Tween:
    # Similar to spawn, but reverse: progress 0.0 → 1.0 (visible to invisible)
    var tween = scene_tree.create_tween()
    tween.tween_property(material_instance, "shader_parameter/dissolve_progress", 1.0, 0.4).from(0.0)
    tween.finished.connect(_on_death_tween_finished.bind(sprite_id))
    return tween
```

**Integration points:**
- WaveDirector enemy death handling
- Boss death sequences
- XP orb spawn timing (wait for dissolve to complete?)

### 3. Spawn Pause Configuration
**Make wake-up behavior configurable per enemy type:**

```gdscript
# In EnemyType.gd
@export var spawn_behavior: String = "immediate"  # "immediate" | "wake_up" | "timed_pause"
@export var spawn_pause_duration: float = 0.0  # Seconds to pause before activating AI
```

**Benefits:**
- Per-enemy control (some regular enemies could have dramatic spawn)
- Easy to tune during playtesting
- No code changes needed for adjustments

## Implementation Plan

### Phase 1: Extend Spawn Dissolve to Regular Enemies
1. ✅ Create `EnemySpawnEffect` (DONE - already implemented)
2. ⏳ Add dissolve shader to pooled enemy spawning in WaveDirector
3. ⏳ Test with breach modulation for regular enemies
4. ⏳ Verify performance with 50+ simultaneous spawns

### Phase 2: Death Dissolve Effect (Optional)
1. ⏳ Create `EnemyDeathEffect.gd` helper class
2. ⏳ Add `enemy_death_dissolve.gdshader` (reverse progress)
3. ⏳ Integrate with WaveDirector death handling
4. ⏳ Integrate with boss death sequences
5. ⏳ Add config option to enable/disable death effects

### Phase 3: Configurable Spawn Behavior
1. ⏳ Add `spawn_behavior` field to EnemyType resource
2. ⏳ Update spawn logic to respect behavior setting
3. ⏳ Update all enemy templates with appropriate settings
4. ⏳ Document behavior options in data/README.md

## Files to Modify

### Core System Files
- `scripts/systems/waves/WaveDirector.gd` - Add spawn dissolve for pooled enemies
- `scripts/domain/EnemySpawnEffect.gd` - Verify pooled enemy support

### New Files (Optional Death Effect)
- `scripts/domain/EnemyDeathEffect.gd` - Death dissolve helper
- `shaders/enemy_death_dissolve.gdshader` - Reverse dissolve shader

### Data Files
- `scripts/domain/EnemyType.gd` - Add spawn_behavior config
- `data/content/enemy-templates/*.tres` - Update all templates

### Documentation
- `CHANGELOG.md` - Document unified spawn system
- `data/README.md` - Document spawn_behavior options

## Testing Checklist

### Visual Testing
- [ ] Regular enemy spawn with dissolve shader
- [ ] Boss spawn with wake-up pause + dissolve
- [ ] Breach enemies spawn with purple tint + dissolve
- [ ] Death dissolve effect (if implemented)
- [ ] Verify no visual glitches during rapid spawns

### Performance Testing
- [ ] Spawn 50+ enemies simultaneously (performance check)
- [ ] Verify shader pool efficiency
- [ ] Check for memory leaks during long sessions
- [ ] Profile tween cleanup (no orphaned tweens)

### Gameplay Testing
- [ ] Spawn pacing feels right (not too slow)
- [ ] Wake-up mechanic works for all bosses
- [ ] Regular enemies feel responsive (no spawn delay)
- [ ] Death feedback is satisfying (if death dissolve enabled)

## Success Criteria

✅ All enemies (bosses + regular) use spawn dissolve shader
✅ Bosses maintain wake-up pause behavior
✅ Regular enemies spawn without gameplay delay
✅ Breach modulation works correctly with dissolve
✅ No performance degradation with 50+ enemies
✅ Death dissolve effect (if implemented) enhances feedback
✅ Configurable spawn behavior per enemy type

## Related Tasks

- ✅ `2e_EFFECTS_boss_spawn_dissolve.md` (completed - boss spawn dissolve)
- ✅ Boss wake-up mechanic (completed - all bosses)
- 📋 This task - Extend to regular enemies + optional death effect

## Notes

**Current Implementation Status:**
- ✅ Boss spawn dissolve shader - WORKING
- ✅ Boss wake-up mechanic - WORKING
- ⏳ Regular enemy spawn dissolve - NOT IMPLEMENTED
- ⏳ Death dissolve effect - NOT IMPLEMENTED

**User Preference:**
- User wants unified spawn system
- Two options presented: wake-up pause OR dissolve-only
- **Recommendation:** Hybrid approach (bosses pause, regulars don't)
- Death dissolve is OPTIONAL enhancement for better feedback
