# Current Damage System Flow (Before V2 Refactor)

## Dual Damage Paths

### Path 1: Pooled Enemies (WaveDirector enemies array)
1. **MeleeSystem.gd** (lines 121-132):
   - Creates `EventBus.DamageRequestPayload_Type`
   - Emits `EventBus.damage_requested.emit(damage_payload)`

2. **DamageSystem.gd** `_on_damage_requested()`:
   - Listens to `EventBus.damage_requested` signal
   - Calculates final damage (includes 10% crit chance)
   - Calls `wave_director.damage_enemy(target_index, final_damage)`

3. **WaveDirector.gd** `damage_enemy()`:
   - Directly modifies `enemies[index].hp -= damage`
   - Handles death logic (`enemy.alive = false`)
   - Emits death signals and XP events

### Path 2: Scene-Based Bosses
1. **MeleeSystem.gd** (lines 136-143):
   - Finds scene bosses via `_find_scene_bosses_in_cone()`
   - Calls `boss.take_damage(final_damage, "melee")` directly

2. **Scene Boss Scripts** (e.g., DragonLord.gd):
   - Individual `take_damage(damage, source)` methods
   - Handle own death logic with `_die()` and `queue_free()`

## Problems with Current System
- **Dual paths**: Different logic for pooled vs scene entities
- **Direct method calls**: MeleeSystem directly calls boss methods (tight coupling)
- **Scene tree traversal**: `_find_scene_bosses_in_cone()` searches entire scene tree
- **Inconsistent damage modifiers**: Crits only applied to pooled enemies via DamageSystem
- **No unified damage events**: Different systems emit different signals

## Files That Need Modification
- `vibe/scripts/systems/MeleeSystem.gd` (lines 121-147)
- `vibe/scripts/systems/DamageSystem.gd` (_on_damage_requested method)
- `vibe/scripts/systems/WaveDirector.gd` (damage_enemy method)
- `vibe/scenes/bosses/DragonLord.gd` (take_damage method)
- Any other scene boss scripts with take_damage methods