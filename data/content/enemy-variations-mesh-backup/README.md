# MultiMesh Enemy Variations - Backup

## Purpose
This folder contains enemy variation configurations that were designed for the MultiMesh rendering system, which has been temporarily disabled in favor of scene-based enemies.

## Contents
- `goblin.tres` - Swarm tier mesh enemy (render_tier: "swarm")
- `archer.tres` - Regular tier mesh enemy (render_tier: "regular") 
- `orc_warrior.tres` - Regular tier mesh enemy (render_tier: "regular")
- `elite_knight.tres` - Elite tier mesh enemy (render_tier: "elite")

## When to Restore
These files should be moved back to `data/content/enemy-variations/` when the MultiMesh enemy system is reactivated.

**Reactivation Conditions** (as documented in MultiMeshManager):
- Only reactivate if >2000 simultaneous enemies are needed
- Performance testing shows scene-based approach handles 500-700 enemies adequately
- MultiMesh provides benefits only at very high entity counts (>2000)

## Reactivation Steps
1. Move these files back to `data/content/enemy-variations/`
2. Follow reactivation instructions in `scripts/systems/MultiMeshManager.gd`
3. Modify `WaveDirector._spawn_from_config_v2()` to route non-boss enemies back to pooled spawning
4. Re-enable `enemies_updated.emit()` signals in `WaveDirector._on_combat_step()`
5. Test thoroughly with >2000 enemies to verify performance benefits

## Current Status
- **Disabled**: September 11, 2025
- **Reason**: Decision to standardize on scene-based enemies for consistency
- **Alternative**: All enemies now use scene spawning through existing boss scene logic