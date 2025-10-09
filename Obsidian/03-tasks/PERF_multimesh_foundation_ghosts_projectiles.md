# PERF: MultiMesh Foundation for Ghost Swarms + Projectiles

**Status:** 🟡 Proposed
**Priority:** Medium (Performance Infrastructure)
**Effort:** 1-2 days
**Category:** Performance / Rendering Foundation
**Created:** 2025-01-10

## Objective

Re-integrate MultiMesh rendering foundation to support two high-performance use cases:
1. **Ghost Swarms** - Simple static sprites for special waves (1000+ visual-only enemies)
2. **Projectile Rendering** - Foundation for future ability system projectiles (200+ simultaneous)

## Context

**Why MultiMesh for These Use Cases:**
- Current scene-based system handles 500-1000 complex enemies well (recent optimizations)
- MultiMesh excels at rendering 1000+ **simple, uniform entities** with minimal overhead
- Ghost swarms: Visual spectacle without combat complexity (no collision, no AI)
- Projectiles: Simple entities (position + velocity) with high counts

**Performance Crossover Point:**
- Scene-based: Excellent for complex enemies (<1000 with AI, collision, animations)
- MultiMesh: Excellent for simple entities (>1000 static/simple behavior)

**Existing Archive:**
- Complete MultiMesh system in `scripts/systems/multimesh-backup/`
- 500+ line implementation with pooling, hit feedback, performance testing
- Disabled September 2025 after scene-based optimizations proved sufficient for complex enemies

## Approach

### Phase 1: Restore Minimal MultiMesh Foundation (0.5 days)

**Create Simplified MultiMeshManager:**
- Extract core rendering logic from backup (discard complex enemy tiers)
- Support only 2 use cases: ghost swarms + projectiles
- Object pooling (MultiMesh + QuadMesh reuse) for memory efficiency
- No animation system (static sprites only)

**Files to Create:**
```
scripts/systems/rendering/MultiMeshManager.gd
  - setup(projectiles, ghost_swarm) - Simplified initialization
  - update_projectiles(projectile_data: Array[Dictionary])
  - update_ghost_swarm(ghost_positions: PackedVector2Array)
  - clear_ghost_swarm() / clear_projectiles()
  - set_ghost_texture() / set_ghost_modulate() - Visual customization
```

**Arena Integration:**
- Add `MM_Projectiles` and `MM_GhostSwarm` MultiMeshInstance2D nodes to Arena.tscn
- Wire MultiMeshManager in Arena._ready()
- No system injection needed (optional rendering path)

### Phase 2: Ghost Swarm System (0.5-1 day)

**Create GhostSwarmSpawner:**
```gdscript
# Simple ghost wave spawner for special events
class_name GhostSwarmSpawner
extends Node

# Configuration
@export var ghost_count: int = 1000
@export var spawn_radius: float = 800.0
@export var charge_speed: float = 200.0
@export var ghost_modulate: Color = Color(0.8, 0.9, 1.0, 0.7)

# Ghost state (simple PackedVector2Array for positions)
var ghost_positions: PackedVector2Array
var ghost_velocities: PackedVector2Array

func spawn_ghost_wave(player_pos: Vector2) -> void:
    # Spawn ghosts in circle around player
    # Update positions every frame (no collision, just movement)
    # Pass to MultiMeshManager.update_ghost_swarm()
```

**Integration Pattern:**
```gdscript
# Arena or EventSystem calls:
ghost_swarm_spawner.spawn_ghost_wave(player_position)

# Every frame:
ghost_swarm_spawner.update_ghost_positions(delta)
multimesh_manager.update_ghost_swarm(ghost_positions)

# Wave ends:
multimesh_manager.clear_ghost_swarm()
```

**Ghost Behavior:**
- No collision (pure visual)
- Simple charge AI (move toward player at fixed speed)
- No health/damage (optional: despawn on melee contact for visual feedback)
- Exponential scaling for pressure (1000 → 2000 → 4000 ghosts)

### Phase 3: Projectile Foundation (Optional - Future)

**When abilities are added later:**
```gdscript
# AbilitySystem integration
func fire_projectile(position: Vector2, velocity: Vector2) -> void:
    var projectile_data = {
        "pos": position,
        "velocity": velocity,
        "rotation": velocity.angle()
    }
    active_projectiles.append(projectile_data)

# Every frame:
_update_projectile_physics(delta)
multimesh_manager.update_projectiles(active_projectiles)
```

**Projectile System Pattern:**
- Simple physics (position += velocity * delta)
- Collision via spatial queries (EntityTracker.get_entities_in_radius)
- MultiMesh for rendering only (logic in AbilitySystem)

## Technical Implementation

### MultiMeshManager Simplified Pattern

```gdscript
# Minimal foundation - no animation, no tiers, just 2 use cases
class_name MultiMeshManager
extends Node

var mm_projectiles: MultiMeshInstance2D
var mm_ghost_swarm: MultiMeshInstance2D

# Object pools for reuse
var _multimesh_pool: Array[MultiMesh] = []
var _quadmesh_pool: Dictionary = {}  # size_key -> QuadMesh

func setup(projectiles: MultiMeshInstance2D, ghost_swarm: MultiMeshInstance2D) -> void:
    mm_projectiles = projectiles
    mm_ghost_swarm = ghost_swarm
    _initialize_pools()
    _setup_projectile_multimesh()
    _setup_ghost_swarm_multimesh()

func update_ghost_swarm(ghost_positions: PackedVector2Array) -> void:
    var count = ghost_positions.size()
    mm_ghost_swarm.multimesh.instance_count = count

    for i in range(count):
        var transform = Transform2D()
        transform.origin = ghost_positions[i]
        mm_ghost_swarm.multimesh.set_instance_transform_2d(i, transform)
```

### GhostSwarmSpawner Simple Pattern

```gdscript
# Minimal ghost wave logic - no complex AI
var _ghost_positions: PackedVector2Array
var _ghost_velocities: PackedVector2Array

func spawn_ghost_wave(player_pos: Vector2, count: int) -> void:
    _ghost_positions.resize(count)
    _ghost_velocities.resize(count)

    # Spawn in circle around player
    for i in range(count):
        var angle = (i / float(count)) * TAU
        var offset = Vector2(cos(angle), sin(angle)) * spawn_radius
        _ghost_positions[i] = player_pos + offset

        # Calculate velocity toward player
        var direction = (player_pos - _ghost_positions[i]).normalized()
        _ghost_velocities[i] = direction * charge_speed

func _process(delta: float) -> void:
    if _ghost_positions.size() == 0:
        return

    var player_pos = PlayerState.position

    # Update all ghost positions
    for i in range(_ghost_positions.size()):
        # Recalculate direction toward player (simple chase)
        var direction = (player_pos - _ghost_positions[i]).normalized()
        _ghost_velocities[i] = direction * charge_speed

        # Apply velocity
        _ghost_positions[i] += _ghost_velocities[i] * delta

    # Update rendering
    multimesh_manager.update_ghost_swarm(_ghost_positions)
```

## Success Criteria

- [ ] MultiMeshManager restored and simplified (2 use cases only)
- [ ] MM_Projectiles and MM_GhostSwarm nodes added to Arena.tscn
- [ ] GhostSwarmSpawner creates 1000+ ghosts at 60 FPS
- [ ] Ghost swarm charges player with simple AI (no collision)
- [ ] Memory pooling working (MultiMesh + QuadMesh reuse)
- [ ] Projectile foundation ready (update_projectiles method available)

## Performance Expectations

**Ghost Swarm (1000 entities):**
- **Rendering**: <2ms per frame (GPU batching)
- **Physics**: <1ms per frame (simple velocity updates, no collision)
- **Total overhead**: <3ms (30 FPS headroom at 33.3ms budget)

**Scalability:**
- 1000 ghosts: 60 FPS expected
- 2000 ghosts: 50-60 FPS (pressure wave)
- 4000 ghosts: 40-50 FPS (extreme pressure, visual spectacle)

**Comparison to Scene-Based:**
- Scene-based 1000 enemies: 30-40 FPS (AI + collision + animations)
- MultiMesh 1000 ghosts: 60 FPS (rendering only, no overhead)

## Risks & Mitigations

| Risk | Mitigation |
|------|------------|
| Complexity creep (adding features to MultiMesh) | Keep it minimal - 2 use cases only, no animation system |
| Ghost collision needed later | Start pure visual, add spatial queries if needed (not physics) |
| Projectile system never implemented | Foundation is cheap to maintain, minimal code |

## Files to Create/Modify

**New Files:**
- `scripts/systems/rendering/MultiMeshManager.gd` - Simplified 2-use-case manager
- `scripts/systems/spawn/GhostSwarmSpawner.gd` - Ghost wave event system
- `assets/sprites/ghost_sprite.png` - Simple semi-transparent ghost sprite (optional)

**Modified Files:**
- `scenes/arena/Arena.tscn` - Add MM_Projectiles + MM_GhostSwarm nodes
- `scenes/arena/Arena.gd` - Wire MultiMeshManager setup (optional path)
- `scripts/systems/CLAUDE.md` - Document MultiMesh usage patterns

**Reference Files (Archive):**
- `scripts/systems/multimesh-backup/MultiMeshManager.gd` - Original 568-line implementation
- `scripts/systems/multimesh-backup/test_performance_500_enemies.gd` - Performance test framework

## Dependencies

- Arena.tscn scene structure
- PlayerState.position for ghost targeting
- (Future) AbilitySystem for projectile integration

## Notes

**Philosophy: Pragmatic Foundation**
- Avoid animation baking complexity (not needed for ghosts/projectiles)
- Keep it simple: static sprites with modulation for visual variety
- Foundation-only: Easy to extend when abilities are added

**Ghost Swarm Use Cases:**
- Special breach event: "Ghost Wave" - 1000+ spirits charge player
- Pressure mechanic: Forces movement, creates spectacle
- Visual variety: Different modulations (blue ghosts, red ghosts, green ghosts)

**Projectile Use Cases (Future):**
- Arrow volleys (100+ arrows)
- Magic missiles (50+ homing projectiles)
- AoE explosions (particle-like projectiles)

**Performance Budget:**
- 3ms for 1000 ghosts = 10% of 30 FPS frame budget
- Acceptable overhead for special event waves

---
**Related:** Performance optimization, Visual spectacle, Event system, Future abilities foundation
