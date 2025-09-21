# Systems Directory

**Path:** `scripts/systems/`
**Purpose:** Core game systems that manage gameplay mechanics, spawning, events, and cross-system coordination.

## Directory Overview

This directory contains the foundational systems that drive the game's core mechanics. Each system is designed for modularity, performance, and maintainability following the project's architectural principles.

### Key Systems

#### Spawning & Enemy Management
- **`SpawnDirector.gd`** - Central enemy spawning coordinator
- **`WaveDirector.gd`** - Wave-based enemy spawning logic
- **`BossSpawnManager.gd`** - Specialized boss spawning system
- **`MultiMeshManager.gd`** - High-performance rendering for large enemy counts

#### Events & Special Mechanics
- **`events/`** - Event-driven gameplay systems
  - **`BreachEventHandler.gd`** - Breach event spawning and lifecycle
  - **`EventInstance.gd`** - Base event instance management

#### Core Gameplay Systems
- **`AbilitySystem.gd`** - Player ability processing and effects
- **`CombatSystem.gd`** - Combat calculations and damage resolution
- **`PlayerProgression.gd`** - Experience, leveling, and progression

## SpawnDirector Architecture

### Current Architecture (Post Direct Return Pattern)

The `SpawnDirector` serves as the central hub for all enemy spawning, using a **scene-based approach** for reliability and flexibility.

#### Core Spawn Flow
```gdscript
# Modern spawn flow (all enemies)
_spawn_from_config_v2(enemy_type, spawn_config) -> Node2D
└── _spawn_boss_scene(spawn_config) -> Node2D
    ├── enemy_scene.instantiate()
    ├── arena_root.add_child(enemy_instance)
    ├── enemy_instance.add_to_group("enemies")
    └── return enemy_instance  # Direct reference
```

#### Key Design Decisions

**1. Scene-Based Spawning (Decision 2024-12)**
- **All enemies** spawn as scene instances (no more MultiMesh pooled enemies)
- Unified spawning logic for regular, elite, boss, and event enemies
- Better debugging and individual enemy state management

**2. Direct Return Pattern (Decision 2025-01-20)**
- All spawn methods return `Node2D` references instead of `void`
- Eliminates race conditions in enemy tagging
- 100% reliable entity ownership tracking
- **Impact**: Fixed 40% tagging failure rate in breach events

**3. Configuration-Driven Spawning**
- `SpawnConfig` contains all spawn parameters
- Event-specific properties handled through `event_id` metadata
- Modulation, positioning, and special behaviors centralized

### Spawn Method Signatures

```gdscript
# Public Interface
func _spawn_from_config_v2(enemy_type: EnemyType, spawn_config: SpawnConfig) -> Node2D

# Internal Implementation
func _spawn_boss_scene(spawn_config: SpawnConfig) -> Node2D

# Legacy Support (still available)
func _spawn_from_type(enemy_type: EnemyType, position: Vector2) -> void
```

### Integration Points

#### Event Systems
```gdscript
# Breach events get direct node references for tagging
var enemy_node = spawn_director._spawn_from_config_v2(enemy_type, config)
if enemy_node:
    enemy_node.set_meta("breach_owner", breach_event.breach_id)
    enemy_node.add_to_group("breach_enemies")
```

#### Debug Systems
```gdscript
# Debug spawning (V key) - ignores return value
spawn_director._spawn_from_config_v2(legacy_type, debug_config)
```

#### Wave Systems
```gdscript
# Regular wave spawning - ignores return value
spawn_director._spawn_from_config_v2(enemy_type, wave_config)
```

### Performance Considerations

#### Scene Instantiation
- **All enemies**: Scene-based (no pooling currently)
- **Boss scenes**: Pre-loaded in `_preloaded_boss_scenes`
- **Fallback**: ancient_lich for missing boss scenes

#### MultiMesh Backup
- Previous MultiMesh system disabled but preserved
- **Location**: `data/content/enemy-variations-mesh-backup/`
- **Reactivation**: See README in backup directory for steps

### Error Handling

#### Common Warnings
```gdscript
# Missing enemy scene
[WARN:WAVES] No scene available for enemy type: ranged_base (render_tier: regular)

# Instantiation failure
[WARN:WAVES] Failed to instantiate enemy scene
```

#### Debugging Tips
- Use `Logger.debug()` with "waves" category for spawn tracing
- Check `_preloaded_boss_scenes` dictionary for available scenes
- Verify `SpawnConfig.template_id` matches available scene keys

### Future Architecture Considerations

#### Potential Improvements
1. **Hybrid Pooling**: Pool common enemies, scenes for special/boss
2. **Async Spawning**: Handle large spawn bursts without frame drops
3. **Resource Preloading**: Dynamic scene loading for memory optimization

#### Extension Points
- **Custom spawn strategies**: Extend `SpawnConfig` for new event types
- **Entity factories**: Specialized spawning for different game modes
- **Spawn validation**: Zone-based and rule-based spawn restrictions

### Dependencies

#### Required Autoloads
- **EventBus** - Cross-system event communication
- **Logger** - Centralized logging with categories
- **RNG** - Deterministic random number generation

#### Required Scenes
- Boss scenes in `scenes/bosses/`
- Component scenes (BossHealthBar, BossShadow)
- Arena structure for enemy parenting

#### Configuration Resources
- Enemy definitions in `data/content/enemies/`
- Balance configurations in `data/balance/`
- Zone definitions from arena scenes

---

## Best Practices

### When Adding New Systems

1. **Follow Autoload Pattern**: Use autoloads for global state coordination
2. **Emit via EventBus**: Use signals for cross-system communication
3. **Use Logger**: Never use `print()` - always use Logger with categories
4. **Resource-Driven**: Keep tunables in `.tres` files for hot-reload
5. **Fixed-Step Compatibility**: Heavy logic should work with 30Hz combat step

### Error Handling
- Use `Logger.warn()` for recoverable issues
- Use `Logger.error()` for critical failures
- Include context (IDs, positions, states) in log messages
- Test error paths during development

### Performance Guidelines
- Profile with >1000 enemies active
- Use object pooling for high-frequency spawning
- Consider MultiMesh for visual-only entities
- Monitor frame time during stress tests

### Testing Integration
- Create headless sims for new combat mechanics
- Use `print()` only in test files (never Logger in tests)
- Verify determinism with fixed RNG seeds
- Test edge cases (empty pools, missing resources)

---

**Related Documentation:**
- `Obsidian/systems/Spawn-System-Direct-Return-Pattern.md` - Direct return pattern details
- `ARCHITECTURE.md` - Overall system architecture and decisions
- `data/content/enemies/README.md` - Enemy configuration schemas
- Individual system files contain inline documentation for specific implementations