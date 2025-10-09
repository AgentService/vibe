# REVERT: EnemyPhysicsController Implementation

**Status:** 🟡 Proposed
**Priority:** Low (Cleanup/Rollback)
**Effort:** 1-2 hours
**Category:** Code Cleanup / Reversion
**Created:** 2025-01-08

## Objective

Revert the addition of the EnemyPhysicsController centralized physics system, restoring the original per-boss move_and_slide() pattern.

## Context

**EnemyPhysicsController** was added as a performance optimization to batch physics updates for 500+ scene-based bosses:
- **Added:** Recent commits (a165afc, 9c342a3, 405ba03)
- **Purpose:** Replace individual move_and_slide() with centralized batch position updates
- **Claimed Benefit:** ~98% reduction in physics overhead

**Reason for Revert:**
- Complexity vs benefit analysis suggests minimal real-world gains
- Potential issues with spawn speed bursts still being debugged
- Preference to return to simpler, proven architecture
- MultiMesh POC may provide better performance path

## Reversion Steps

### Phase 1: Remove EnemyPhysicsController
1. **Delete autoload registration**:
   - Remove from `project.godot`:
     ```
     EnemyPhysicsController="*res://scripts/systems/boss/EnemyPhysicsController.gd"
     ```

2. **Delete controller file**:
   - `scripts/systems/boss/EnemyPhysicsController.gd`

### Phase 2: Restore BaseBoss Movement
3. **Revert BaseBoss.gd changes**:
   - Remove `EnemyPhysicsController.register_enemy(self)` from `_ready()`
   - Remove `EnemyPhysicsController.set_enemy_velocity()` calls
   - Restore original `move_and_slide()` pattern in `_update_ai()`

4. **Original movement pattern** (pre-PERFORMANCE V3):
```gdscript
func _update_ai(_dt: float) -> void:
    if _is_spawning or ai_paused or _is_dying:
        return

    var target_position = PlayerState.get_position()
    var distance_to_player = global_position.distance_to(target_position)

    if distance_to_player <= chase_range:
        if distance_to_player > attack_range:
            # Original: Use velocity + move_and_slide
            var direction = (target_position - global_position).normalized()
            velocity = direction * speed

            # Apply personal space forces
            var spacing_force = apply_personal_space_forces()
            velocity += spacing_force

            # Godot's built-in physics
            move_and_slide()

            _update_directional_animation(direction)
        else:
            # Stop when in attack range
            velocity = Vector2.ZERO
            attack_timer.start()
```

### Phase 3: Update BossUpdateManager
5. **Remove physics controller dependency**:
   - BossUpdateManager continues to work for AI batch processing
   - No changes needed (it only manages AI updates, not physics)

### Phase 4: Restore Boss Scene Files
6. **Re-enable CharacterBody2D** in boss scenes (if changed):
   - Check if BananaLord.tscn, AncientLich.tscn, etc. were changed from CharacterBody2D → Node2D
   - Restore CharacterBody2D root type if modified

7. **Verify collision layers** and physics properties still intact

## Files to Modify/Delete

**Delete:**
- `scripts/systems/boss/EnemyPhysicsController.gd`

**Modify:**
- `project.godot` - Remove EnemyPhysicsController autoload
- `scripts/systems/boss/BaseBoss.gd` - Restore move_and_slide() pattern
- `scenes/bosses/*.tscn` - Restore CharacterBody2D if changed

**Git History Reference:**
- Commit before EnemyPhysicsController: `9649a8b` (fix(boss): increase personal space strength)
- First EnemyPhysicsController commit: `405ba03` (implement centralized physics)

## Testing After Reversion

- [ ] Spawn 50+ bosses via debug panel - verify movement works
- [ ] Check no parser errors or autoload references remain
- [ ] Verify personal space system still functions
- [ ] Confirm no speed burst on spawn (if it was related to physics controller)
- [ ] Run performance test - document actual FPS difference

## Expected Outcome

**Performance Impact:**
- May see slight FPS drop with 500+ bosses
- If drop is <10 FPS, acceptable tradeoff for simplicity
- If drop is >20 FPS, consider keeping physics controller

**Code Clarity:**
- Simpler boss AI code (standard Godot patterns)
- Easier for future developers to understand
- Reduced autoload coupling

## Risks & Mitigations

| Risk | Mitigation |
|------|------------|
| Performance regression | Document actual FPS before/after |
| Collision issues | Test personal space system thoroughly |
| Lost optimization opportunity | MultiMesh POC may provide better path |

## Alternative: Keep Physics Controller

If reversion reveals significant performance cost:
1. Fix spawn speed burst issue properly
2. Document the system better
3. Add unit tests for velocity calculations
4. Consider this proven architecture

## Notes

This reversion is **optional** - should be done only if:
- EnemyPhysicsController complexity outweighs benefits
- spawn speed burst traced definitively to physics controller
- MultiMesh POC proves more promising optimization path

---
**Related:** EnemyPhysicsController, BaseBoss, Performance optimization, Code simplification
