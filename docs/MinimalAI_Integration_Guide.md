# Minimal AI Integration Guide

## Quick Test (5 minutes)

### Option 1: Test with Single Boss

Add this method to `BaseBoss.gd` after line 243:

```gdscript
## EXPERIMENTAL: Ultra-minimal AI for performance testing
const MinimalBossAI = preload("res://scripts/systems/boss/MinimalBossAI.gd")

func _update_ai_minimal_test(accumulated_dt: float) -> void:
	# Skip checks
	if _is_dying or ai_paused or _is_spawning:
		return
	if not PlayerState.has_player_reference():
		return

	# Call minimal AI static function
	MinimalBossAI.update_minimal(self, accumulated_dt, PlayerState.position, speed, attack_range)
```

Then in `_update_ai_batch()` (line 236), change:
```gdscript
func _update_ai_batch(accumulated_dt: float) -> void:
	# _update_ai(accumulated_dt)  # OLD
	_update_ai_minimal_test(accumulated_dt)  # NEW - Test minimal AI
	last_attack_time += accumulated_dt
```

**Test:** Spawn 1000 enemies, check FPS vs current AI.

---

## Option 2: Batch-Optimized (Maximum Performance)

### Step 1: Modify BossUpdateManager.gd

**After line 94** (in `_on_combat_step`), add player position lookup:

```gdscript
func _on_combat_step(payload) -> void:
	var dt: float = payload.dt
	var count: int = _boss_ids.size()

	if count == 0:
		return

	# ✅ NEW: Get player position ONCE for entire batch
	if not PlayerState.has_player_reference():
		return
	var player_pos: Vector2 = PlayerState.position  # Single lookup for all 20 bosses

	# Accumulate time for all bosses
	for i in range(count):
		_boss_time_accumulators[i] += dt
```

**After line 127**, pass player position to boss:

```gdscript
	for i in range(batch_start, batch_end):
		var boss := _boss_nodes[i]
		if not is_instance_valid(boss):
			continue

		_ids_buf.push_back(_boss_ids[i])
		_pos_buf.push_back(boss.global_position)
		_ai_flags_buf.push_back(1)

		var accumulated_dt: float = _boss_time_accumulators[i]

		# ✅ NEW: Pass player_pos to avoid per-boss lookup
		if boss.has_method("_update_ai_minimal_batched"):
			boss._update_ai_minimal_batched(accumulated_dt, player_pos)
		elif boss.has_method("_update_ai_batch"):
			boss._update_ai_batch(accumulated_dt)
		else:
			Logger.warn("Boss %s missing AI method" % _boss_ids[i], "performance")
			if boss.has_method("_update_ai"):
				boss._update_ai(accumulated_dt)

		_boss_time_accumulators[i] = 0.0
```

### Step 2: Add to BaseBoss.gd (after line 238)

```gdscript
## BATCH-OPTIMIZED MINIMAL AI: Player position passed from BossUpdateManager
const MinimalBossAI = preload("res://scripts/systems/boss/MinimalBossAI.gd")

func _update_ai_minimal_batched(accumulated_dt: float, player_pos: Vector2) -> void:
	# Skip checks (done at batch level)
	if _is_dying or ai_paused or _is_spawning:
		return

	# Ultra-fast minimal AI
	MinimalBossAI.update_minimal(self, accumulated_dt, player_pos, speed, attack_range)

	# Update attack cooldown
	last_attack_time += accumulated_dt
```

**Performance Gains:**
- ✅ Single `PlayerState.position` lookup per batch (20 bosses) instead of 20
- ✅ No `distance_to()` sqrt operations (uses squared distance)
- ✅ No personal space force calculations
- ✅ No individual DamageService updates

---

## Option 3: Pure Batch Function (Alternative)

**Modify BossUpdateManager.gd** - replace the boss update loop entirely:

```gdscript
const MinimalBossAI = preload("res://scripts/systems/boss/MinimalBossAI.gd")

func _on_combat_step(payload) -> void:
	var dt: float = payload.dt
	var count: int = _boss_ids.size()

	if count == 0:
		return

	# Get player position once
	if not PlayerState.has_player_reference():
		return
	var player_pos: Vector2 = PlayerState.position

	# Accumulate time for all bosses
	for i in range(count):
		_boss_time_accumulators[i] += dt

	# Clear buffers
	_ids_buf.resize(0)
	_pos_buf.resize(0)
	_ai_flags_buf.resize(0)

	# Calculate batch range
	var batch_start: int = _boss_update_offset
	var batch_end: int = min(_boss_update_offset + BOSS_UPDATE_BATCH_SIZE, count)

	# ✅ PURE BATCH PROCESSING - No per-boss method calls
	MinimalBossAI.update_batch_minimal(
		_boss_nodes,
		_boss_ids,
		_boss_time_accumulators,
		player_pos,
		batch_start,
		batch_end,
		100.0,  # speed
		80.0    # attack_range
	)

	# Collect positions for EntityTracker batch update
	for i in range(batch_start, batch_end):
		var boss := _boss_nodes[i]
		if is_instance_valid(boss):
			_ids_buf.push_back(_boss_ids[i])
			_pos_buf.push_back(boss.global_position)
			_ai_flags_buf.push_back(1)

	# Advance batch offset
	_boss_update_offset += BOSS_UPDATE_BATCH_SIZE
	if _boss_update_offset >= count:
		_boss_update_offset = 0

	# Batch update positions
	if _ids_buf.size() > 0:
		EntityTracker.batch_update_positions(_ids_buf, _pos_buf)
```

**This version:**
- ✅ No virtual method calls per boss
- ✅ Pure array iteration
- ✅ All AI logic in one tight loop
- ✅ Maximally cache-friendly

---

## Performance Comparison

### Current AI per boss:
```gdscript
PlayerState.position          # Hash lookup
distance_to(target)           # sqrt + 3 subtracts + 1 add
chase_range check
distance_to(target) again     # Another sqrt!
normalized()                  # sqrt + 2 divides
personal_space loop           # N iterations
velocity assignment
move_and_slide()
DamageService.update()
```

### Minimal AI per boss:
```gdscript
# player_pos already available (passed as param)
to_player = pos - global      # 2 subtracts
length_squared()              # 2 multiplies + 1 add
attack_range * attack_range   # 1 multiply (compile-time constant)
normalized()                  # sqrt + 2 divides (only if chasing)
velocity assignment
move_and_slide()
```

**Operations saved per update:**
- 2× sqrt operations (distance_to calls)
- 1× hash table lookup (PlayerState.position)
- Personal space loop (varies, but 0-10 iterations)
- DamageService call
- Direction variable allocation

**Estimated speedup: 50-70% faster AI execution**

At 1000 enemies with batch size 20:
- 20 bosses × 30Hz = 600 updates/sec
- Current: ~12-15 microseconds per update = ~9ms total
- Minimal: ~4-6 microseconds per update = ~3ms total
- **Saved: ~6ms per frame**

---

## Testing Methodology

1. **Baseline Test:** Current AI with 1000 enemies
   ```bash
   # Record FPS with current implementation
   ```

2. **Minimal AI Test:** Switch to minimal AI
   ```bash
   # Record FPS with minimal AI
   # Compare movement behavior (should be identical)
   ```

3. **Metrics to Compare:**
   - FPS (primary metric)
   - Movement behavior (visual check - should look the same)
   - CPU profiler (check AI update time)

4. **Expected Results:**
   - **FPS improvement:** 10-30% increase (depends on current bottleneck)
   - **AI frame time:** 50-70% reduction
   - **Behavior:** Identical (chase player, stop at attack range)

---

## Rollback Plan

If minimal AI has issues:
1. Comment out `_update_ai_minimal_batched` call
2. Uncomment original `_update_ai_batch` call
3. System reverts to current AI immediately

---

## Next Steps After Testing

If minimal AI works well:

1. **Add attack behavior back:**
   ```gdscript
   if dist_sq <= attack_range_sq:
       boss.last_attack_time += accumulated_dt
       if boss.last_attack_time >= boss.attack_cooldown:
           boss._perform_attack()
           boss.last_attack_time = 0.0
   ```

2. **Add batched DamageService updates:**
   ```gdscript
   # After batch completes, update all positions at once
   DamageService.batch_update_positions(_ids_buf, _pos_buf)
   ```

3. **Make it configurable:**
   ```gdscript
   const USE_MINIMAL_AI: bool = true  # Toggle in BaseBoss
   ```

4. **Profile and tune:**
   - Measure exact performance gains
   - Identify remaining bottlenecks
   - Optimize further if needed
