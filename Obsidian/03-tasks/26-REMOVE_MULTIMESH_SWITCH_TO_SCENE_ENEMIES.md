# Remove MultiMesh - Switch to Scene-Based Enemies Only

Status: Ready to Start  
Owner: Solo (Indie)  
Priority: High  
Type: Architecture Refactor  
Dependencies: None (standalone cleanup)  
Risk: Low-Medium (simplification, not addition)  
Complexity: 6/10

---

## Background & Rationale

**Performance Data Proves Scene-Based is Superior:**
- **500 Scene Bosses**: 48.0 MB memory, 6.94ms P95, 99.9% FPS stability ✅
- **500 MultiMesh Enemies**: 133 MB memory, 141ms P95, 47.9% FPS stability ❌

**MultiMesh was 20x worse performance** despite all optimizations. The "optimization" became a pessimization.

**Scene-based rendering wins because:**
- **Godot-native optimizations**: Built-in culling, caching, rendering pipeline
- **Zero custom complexity**: No buffer management, batching logic, or allocation optimization
- **Proven scalability**: Banana boss test proves 500+ works perfectly
- **Simpler maintenance**: Standard Godot scene tree debugging and development

---

## Goals & Acceptance Criteria

Primary goals:
- **Complete MultiMesh removal**: Delete all MultiMesh-related code, classes, and systems
- **Scene-based enemy conversion**: Convert all enemies to use scene-based rendering like bosses
- **Performance validation**: Achieve 500+ enemy performance with scene-based approach
- **Code simplification**: Eliminate complex rendering tier system and buffer management

Acceptance criteria:
- All MultiMesh references removed from codebase
- Enemy spawning uses scene instantiation instead of MultiMesh batching
- 500-enemy stress test passes with scene-based enemies
- Code complexity significantly reduced (fewer files, simpler logic)
- Visual compatibility maintained (enemy colors, animations work correctly)

---

## Implementation Plan

### Phase 1: Analysis & Inventory
**Identify all MultiMesh components for removal:**

1. **Core MultiMesh Files (DELETE)**:
   - `scripts/systems/MultiMeshManager.gd` (349 lines of complex buffer management)
   - `scripts/systems/EnemyRenderTier.gd` (138 lines of tier grouping logic)

2. **MultiMesh Integration Points (REFACTOR)**:
   - `scenes/arena/Arena.tscn` - Remove MultiMesh nodes (MM_Enemies_*, MM_Projectiles)
   - `scripts/systems/WaveDirector.gd` - Remove MultiMesh update calls
   - `scripts/domain/DebugConfig.gd` - Remove MultiMesh performance flags

3. **Test Files (UPDATE)**:
   - `tests/test_performance_500_enemies.gd` - Update for scene-based validation

### Phase 2: Create Scene-Based Enemy Templates
**Model after successful boss implementation:**

1. **Enemy Scene Templates**:
   ```
   EnemySwarm.tscn     -> CharacterBody2D + AnimatedSprite2D (like bosses)
   EnemyRegular.tscn   -> CharacterBody2D + AnimatedSprite2D
   EnemyElite.tscn     -> CharacterBody2D + AnimatedSprite2D
   ```

2. **Scene Structure** (copy from working bosses):
   ```
   CharacterBody2D (root)
   ├── AnimatedSprite2D (visual)
   ├── CollisionShape2D (physics)
   ├── HealthComponent (script)
   └── EnemyScript.gd (behavior)
   ```

3. **Tier Colors** (maintain visual compatibility):
   - Set `modulate` property on AnimatedSprite2D nodes
   - Use same colors as current MultiMesh tiers

### Phase 3: Convert Spawning System
**Replace MultiMesh batching with scene instantiation:**

1. **WaveDirector Changes**:
   ```gdscript
   # OLD: MultiMesh updates
   multimesh_manager.update_enemies(alive_enemies)
   
   # NEW: Scene instantiation (like bosses)
   var enemy_scene = preload("res://enemies/EnemySwarm.tscn")
   var enemy_instance = enemy_scene.instantiate()
   arena.add_child(enemy_instance)
   ```

2. **Enemy Pool Conversion**:
   - Convert from Dictionary pool to scene node pool
   - Use `queue_free()` and `instantiate()` instead of enable/disable
   - Follow existing boss spawning patterns

3. **Remove MultiMesh Dependencies**:
   - Remove `MultiMeshManager` from Arena scene tree
   - Remove `EnemyRenderTier` usage from WaveDirector
   - Remove MultiMesh node references from Arena.tscn

### Phase 4: Cleanup & Validation
**Remove dead code and validate performance:**

1. **File Deletion**:
   ```bash
   rm scripts/systems/MultiMeshManager.gd
   rm scripts/systems/EnemyRenderTier.gd
   # Remove MultiMesh nodes from Arena.tscn via editor
   ```

2. **Reference Cleanup**:
   - Remove all `MultiMeshManager` references
   - Remove all `EnemyRenderTier` references  
   - Remove MultiMesh performance config flags
   - Update imports and dependencies

3. **Performance Validation**:
   - Run `tests/test_performance_500_enemies.tscn` 
   - Should achieve boss-level performance: <50MB memory, <10ms P95
   - Verify 500+ enemies run smoothly

---

## Technical Implementation Details

### Enemy Scene Template Structure
```gdscript
# EnemySwarm.gd (attached to CharacterBody2D)
extends CharacterBody2D

@export var enemy_data: EnemyType  # Reference to data
@export var health: float = 100.0
@export var speed: float = 60.0

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var collision: CollisionShape2D = $CollisionShape2D

func _ready():
    # Set tier color (equivalent to MultiMesh self_modulate)
    sprite.modulate = get_tier_color()
    
func get_tier_color() -> Color:
    # Same colors as MultiMesh tiers
    return Color(1.5, 0.3, 0.3, 1.0)  # Swarm = Bright Red
```

### WaveDirector Spawning Refactor
```gdscript
# Replace MultiMesh batching with scene instantiation
func spawn_enemy(enemy_type: EnemyType, position: Vector2) -> Node:
    var enemy_scene = _get_enemy_scene(enemy_type.render_tier)
    var enemy_instance = enemy_scene.instantiate()
    
    enemy_instance.global_position = position
    enemy_instance.enemy_data = enemy_type
    
    arena.add_child(enemy_instance)
    return enemy_instance

func _get_enemy_scene(tier: String) -> PackedScene:
    match tier:
        "swarm": return preload("res://enemies/EnemySwarm.tscn")
        "regular": return preload("res://enemies/EnemyRegular.tscn")
        "elite": return preload("res://enemies/EnemyElite.tscn")
        _: return preload("res://enemies/EnemySwarm.tscn")
```

---

## Benefits & Impact

### **Performance Benefits**:
- **Massive performance gain**: From 141ms P95 to ~7ms P95 (20x improvement)
- **Memory efficiency**: From 133MB to ~48MB (65% reduction)
- **FPS stability**: From 47.9% to 99.9% (stable framerates)

### **Development Benefits**:
- **Code simplification**: Remove 487 lines of complex MultiMesh code
- **Easier debugging**: Standard Godot scene tree tools work
- **Better maintainability**: Any Godot dev understands scene-based enemies
- **Faster iteration**: No need to understand custom batching systems

### **Architectural Benefits**:
- **Remove premature optimization**: MultiMesh was optimization that made things worse
- **Godot-native approach**: Use engine strengths instead of fighting them
- **Proven scalability**: Boss system already handles hundreds of entities

---

## Risks & Mitigation

### **Risk: Visual Regression**
- **Mitigation**: Use same colors via `modulate` property on sprites
- **Mitigation**: Copy exact boss visual setup (AnimatedSprite2D)

### **Risk: Performance Regression** 
- **Mitigation**: Banana boss test proves 500 scenes work perfectly
- **Mitigation**: Remove performance bottleneck (MultiMesh) not add complexity

### **Risk: Integration Issues**
- **Mitigation**: Follow proven boss patterns exactly
- **Mitigation**: Incremental conversion - test each enemy type individually

---

## File Touch List

**Files to DELETE:**
- `scripts/systems/MultiMeshManager.gd` 
- `scripts/systems/EnemyRenderTier.gd`

**Files to CREATE:**
- `enemies/EnemySwarm.tscn`
- `enemies/EnemyRegular.tscn` 
- `enemies/EnemyElite.tscn`
- `enemies/scripts/EnemySwarm.gd`
- `enemies/scripts/EnemyRegular.gd`
- `enemies/scripts/EnemyElite.gd`

**Files to MODIFY:**
- `scenes/arena/Arena.tscn` (remove MultiMesh nodes)
- `scripts/systems/WaveDirector.gd` (convert spawning)
- `scripts/domain/DebugConfig.gd` (remove MultiMesh flags)
- `tests/test_performance_500_enemies.gd` (update validation)

---

## Validation Steps

1. **Pre-conversion**: Run current performance test for baseline
2. **Phase 1**: Create single enemy scene, test spawning 10 enemies
3. **Phase 2**: Test 100 scene enemies vs 100 MultiMesh enemies
4. **Phase 3**: Test 500 scene enemies - should match banana boss performance  
5. **Final**: Full stress test should achieve <50MB memory, <10ms P95, >99% stability

---

## Definition of Done

- [ ] All MultiMesh files deleted from codebase
- [ ] Enemy scene templates created and working
- [ ] WaveDirector converted to scene-based spawning
- [ ] 500-enemy stress test passes with scene-based approach
- [ ] Performance matches or exceeds banana boss test results
- [ ] Visual compatibility maintained (tier colors work)
- [ ] No MultiMesh references remain in codebase
- [ ] Code complexity significantly reduced

**Success Metrics**: 500 enemies with <50MB memory growth, <10ms P95 frame time, >99% FPS stability