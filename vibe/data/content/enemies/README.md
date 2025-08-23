# Enemy Definitions

Enemy type definitions including stats, behaviors, and visual properties.

## Current Implementation

**Status**: ✅ **Implemented** (moved from `/data/enemies/`)

Enemy definitions are loaded by `EnemyRegistry.gd` and used by:
- `WaveDirector` for spawning
- `EnemyRenderTier` for visual rendering
- Combat systems for stats and behaviors

## File Structure

```
enemies/
├── knight_regular.json     # Basic enemy type
├── knight_elite.json       # Elite variant
├── knight_swarm.json       # Swarm variant  
├── knight_boss.json        # Boss variant
└── config/
    ├── enemy_tiers.json    # Tier definitions
    └── enemy_registry.json # Master registry
```

## Schema

Each enemy JSON contains:
- `id`: Unique identifier
- `health`: Base health value
- `speed`: Movement speed
- `size`: Collision size
- `damage`: Attack damage
- `tier`: Enemy tier (regular/elite/boss/swarm)
- `weight`: Spawn weight for random selection
- Visual properties (sprites, animations)

## Validation

Enemy JSONs are validated on load with:
- Required field checking
- Value range validation
- Fallback for invalid entries

## Hot-Reload

Press **F5** to reload enemy definitions during development.

---

**Migration**: Files moved from `/data/enemies/` to `/data/content/enemies/`