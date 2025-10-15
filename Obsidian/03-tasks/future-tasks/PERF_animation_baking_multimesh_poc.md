# PERF: Animation Baking + MultiMesh POC for BananaBoss

**Status:** 🟡 Proposed
**Priority:** Medium (Performance Optimization)
**Effort:** 2-3 days
**Category:** Performance / Visual Optimization
**Created:** 2025-01-08

## Objective

Implement texture atlas animation baking and re-enable MultiMeshInstance2D rendering for BananaBoss as a proof-of-concept performance test inspired by the navigation optimization video patterns.

## Context

**Video Reference:** Pathfinding optimization video discussing:
- Baking animations into texture atlases (flipbook/sprite sheet approach)
- Using GPU instancing via MultiMesh for massive enemy counts
- Reducing per-instance overhead by moving logic to shaders

**Current State:**
- BananaBoss uses AnimatedSprite2D with individual scene instances (500+ bosses)
- MultiMesh system exists in `scripts/systems/multimesh-backup/` but is disabled
- Each boss runs individual move_and_slide() calls (recently centralized via EnemyPhysicsController)

## Approach

### Phase 1: Animation Baking
1. **Export BananaBoss animations** to texture atlas:
   - Walk cycles (4 directions × 3-4 frames)
   - Attack animations
   - Damage flash states
2. **Create shader-based animation controller**:
   - UV offset animation (flipbook style)
   - Frame timing via shader uniforms
   - Direction switching via atlas regions

### Phase 2: MultiMesh Integration
3. **Re-enable MultiMesh rendering** from backup:
   - Port `EnemyMultiMesh.gd` to work with baked animations
   - Update transform buffer for 500+ instances
   - Implement shader-based animation state
4. **Physics decoupling**:
   - Keep EnemyPhysicsController for movement
   - MultiMesh only handles rendering
   - Sync position updates via batch transforms

### Phase 3: Testing
5. **Performance comparison** (500 BananaBosses):
   - Scene-based (current): FPS, frame time, CPU usage
   - MultiMesh (POC): FPS, frame time, CPU/GPU usage
   - Document bottlenecks and gains

## Technical Notes

**Shader Animation Pattern:**
```gdscript
# Vertex shader transforms UVs for animation frames
shader_type canvas_item;

uniform int frame_count = 12;
uniform float animation_speed = 1.0;
uniform vec2 atlas_size = vec2(4, 3);  // 4 columns, 3 rows

void vertex() {
    // Calculate current frame based on time
    float frame = mod(TIME * animation_speed, float(frame_count));
    int current_frame = int(floor(frame));

    // UV offset for flipbook animation
    vec2 frame_offset = vec2(
        float(current_frame % int(atlas_size.x)),
        float(current_frame / int(atlas_size.x))
    );

    UV = (UV + frame_offset) / atlas_size;
}
```

**MultiMesh Transform Update:**
```gdscript
# Batch update all boss transforms from EnemyPhysicsController
func _sync_multimesh_transforms(boss_positions: PackedVector2Array) -> void:
    for i in range(boss_positions.size()):
        var transform = Transform2D()
        transform.origin = boss_positions[i]
        multimesh.set_instance_transform_2d(i, transform)
```

## Success Criteria

- [ ] BananaBoss animations baked to single texture atlas
- [ ] Shader-based flipbook animation working (walk cycles)
- [ ] MultiMesh rendering 500+ bosses with correct animations
- [ ] Performance metrics collected (FPS comparison)
- [ ] Documentation of gains vs complexity tradeoff

## Risks & Mitigations

| Risk | Mitigation |
|------|------------|
| Shader complexity for directional animations | Start with single-direction POC, expand later |
| MultiMesh state synchronization overhead | Use EnemyPhysicsController's existing batch system |
| Loss of per-instance flexibility | Keep scene-based as primary, MultiMesh as optional tier |

## Files to Modify/Create

**New Files:**
- `assets/sprites/banana_boss_atlas.png` - Baked animation atlas
- `scripts/systems/rendering/BananaBossMultiMesh.gd` - MultiMesh controller
- `assets/shaders/boss_flipbook_animation.gdshader` - Animation shader

**Modified Files:**
- `scripts/systems/spawn/SpawnDirector.gd` - Add MultiMesh spawn path
- `scripts/systems/boss/EnemyPhysicsController.gd` - Sync to MultiMesh transforms
- `scripts/systems/rendering/EnemyRenderTier.gd` - Add multimesh tier

**Reference Files:**
- `scripts/systems/multimesh-backup/` - Existing MultiMesh implementation

## Dependencies

- EnemyPhysicsController (already implemented)
- Texture atlas export tool (Godot built-in or external)
- Shader knowledge for flipbook animation

## Notes

This is a **POC only** - not intended for immediate production use. Goal is to validate if the video's optimization patterns apply to our boss-heavy scenario (500+ large entities vs 1000+ small projectiles).

**Follow-up Tasks:**
- If successful: Extend to other boss types
- If marginal: Document why and keep scene-based approach
- Consider hybrid: MultiMesh for distant bosses, scenes for close-up

---
**Related:** Performance optimization, Visual effects POC, EnemyPhysicsController
