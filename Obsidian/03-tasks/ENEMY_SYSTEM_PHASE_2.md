# Enemy System Phase 2 - Full Implementation
> Advanced enemy system with animations, visual hierarchy, and complex behaviors

## Goal
Build on MVP foundation to create a flexible, scalable enemy system supporting animations, bosses, and advanced behaviors.

## Prerequisites
- ✅ [ENEMY_SYSTEM_MVP.md](ENEMY_SYSTEM_MVP.md) completed
- ✅ Basic enemy types working
- ✅ JSON-driven spawning functional

## Core Enhancements

### Week 1: Visual Hierarchy & Multi-Layer Rendering

#### 1. Multi-Layer MultiMesh System (Day 1 - 6 hours)
```
MODIFY: Arena.gd
├── MM_Enemies_Swarm      # Layer 1: 90% of enemies (small, fast)
├── MM_Enemies_Regular    # Layer 2: 8% of enemies (medium)
├── MM_Enemies_Elite      # Layer 3: 2% of enemies (large)
└── SpritePool_Bosses     # Layer 4: <1% of enemies (animated)
```

**Implementation:**
- Create render buckets by enemy tier
- Route enemies to appropriate rendering layer
- Maintain performance with smart culling

#### 2. Texture Atlas System (Day 1-2 - 4 hours)
```
CREATE: vibe/scripts/systems/EnemyAtlasManager.gd
- Pack multiple enemy sprites into 2048x2048 atlas
- Generate UV coordinates for each enemy type
- Support 64+ enemy types in single texture
```

#### 3. Enhanced Visual Configuration (Day 2 - 3 hours)
```json
// Enhanced enemy JSON schema
{
  "visual": {
    "render_tier": "regular",        // swarm|regular|elite|boss
    "sprite_sheet": "res://assets/sprites/slime_green.png",
    "frame_size": {"x": 32, "y": 32},
    "animations": {
      "idle": {"frames": [0,1,2,3], "fps": 8.0},
      "move": {"frames": [4,5,6,7], "fps": 12.0},
      "death": {"frames": [8,9,10], "fps": 15.0}
    },
    "scale_factor": 1.0,
    "color_tint": {"r": 1.0, "g": 1.0, "b": 1.0, "a": 1.0}
  }
}
```

### Week 2: Animation & State System

#### 4. Instance Data Animation (Day 3 - 8 hours)
```
MODIFY: EnemyVisualSystem
- Use MultiMesh.set_instance_custom_data() for animation
- Pack [frame_x, frame_y, anim_time, state] into Color
- Create shader for UV animation lookup
```

**Shader Implementation:**
```glsl
// Enemy MultiMesh shader
shader_type canvas_item;

uniform sampler2D enemy_atlas;
uniform vec2 atlas_size = vec2(2048.0, 2048.0);
uniform float frame_size = 32.0;

varying flat vec4 instance_data; // frame_x, frame_y, time, type

void vertex() {
    instance_data = INSTANCE_CUSTOM;
    // Transform based on enemy data
}

void fragment() {
    // Calculate animated UV from instance data
    vec2 frame_pos = vec2(instance_data.x, instance_data.y);
    vec2 uv_offset = frame_pos * frame_size / atlas_size;
    vec2 uv_size = vec2(frame_size) / atlas_size;
    
    vec2 animated_uv = uv_offset + (UV * uv_size);
    COLOR = texture(enemy_atlas, animated_uv);
}
```

#### 5. Enemy State Machine (Day 4 - 6 hours)
```
CREATE: vibe/scripts/systems/EnemyStateMachine.gd
enum EnemyState { SPAWNING, IDLE, MOVING, ATTACKING, HURT, DYING, DEAD }

- Track state per enemy
- State-based animation switching
- Behavior transitions
```

### Week 3: Advanced Behaviors & Boss System

#### 6. Advanced AI Behaviors (Day 5 - 8 hours)
```
ENHANCE: EnemyBehaviorSystem
- Chase patterns (direct, zigzag, circular)
- Formation behaviors (swarm, line, circle)
- Ranged attack AI (maintain distance, kite)
- Flee behaviors (low health, player proximity)
```

**AI Types:**
```gdscript
enum AIType {
    BASIC_CHASE,     # MVP implementation
    ZIGZAG_CHASE,    # Erratic movement
    CIRCLE_STRAFE,   # Orbit player
    HIT_AND_RUN,     # Attack then retreat
    FORMATION_MOVE,  # Group coordination
    RANGED_KITE,     # Maintain attack distance
    AMBUSH_WAIT      # Hide then pounce
}
```

#### 7. Boss Enemy System (Day 6-7 - 12 hours)
```
CREATE: vibe/scripts/systems/BossEnemySystem.gd
- Individual sprite rendering for bosses
- Phase-based behaviors
- Special attack patterns
- Health bars and status effects
```

**Boss Features:**
- Dedicated AnimatedSprite2D rendering
- Multi-phase behavior patterns
- Special attack abilities
- Screen effects and particle systems
- Unique death sequences

### Week 4: Polish & Integration

#### 8. Performance Optimization (Day 8 - 6 hours)
- Level-of-detail (LOD) for distant enemies
- Frustum culling improvements
- Animation frame rate scaling based on distance
- Smart update frequency (30Hz for far, 60Hz for near)

#### 9. Audio Integration (Day 9 - 4 hours)
- Spawn sound effects
- Movement audio (footsteps, slithering)
- Death sounds per enemy type
- Positional audio with distance falloff

#### 10. Balance Integration (Day 10 - 4 hours)
- Damage resistance/weakness system
- Status effect support (poison, slow, burn)
- Scaling stats per wave/time
- Loot drop system beyond XP

## Advanced Features

### Procedural Enemy Variants
```json
{
  "id": "slime_template",
  "variants": {
    "green": {"color_tint": {"g": 1.2}, "health_mult": 1.0},
    "red": {"color_tint": {"r": 1.2}, "health_mult": 1.5, "damage_mult": 1.3},
    "blue": {"color_tint": {"b": 1.2}, "speed_mult": 0.8, "health_mult": 2.0}
  }
}
```

### Enemy Abilities System
```json
{
  "abilities": [
    {
      "id": "poison_spit",
      "cooldown": 3.0,
      "range": 200.0,
      "damage": 5.0,
      "effects": ["poison"]
    }
  ]
}
```

### Formation Behaviors
```gdscript
class EnemyFormation:
    var formation_type: enum { SWARM, LINE, WEDGE, CIRCLE }
    var leader_id: int
    var members: Array[int]
    var cohesion_strength: float
    var separation_distance: float
```

## Success Criteria

### Performance Targets
- ✅ 800 enemies at 60 FPS (maintained from MVP)
- ✅ 10-20 boss enemies with full animations
- ✅ <16ms frame time with all systems active

### Visual Quality
- ✅ Smooth animations for all enemy types
- ✅ Visual distinction between enemy tiers
- ✅ Boss enemies with unique presentations
- ✅ Screen effects and particles

### Gameplay Features
- ✅ 8+ distinct AI behavior patterns
- ✅ 3+ boss types with phase transitions
- ✅ Status effects and damage types
- ✅ Formation behaviors for group enemies

## Architecture Benefits

### Scalability
- Support for 100+ enemy types
- Easy addition of new AI patterns
- Flexible rendering pipeline
- Hot-reloadable all content

### Maintainability  
- Clear separation of concerns
- Data-driven configuration
- Debuggable state machines
- Performance profiling hooks

### Extensibility
- Plugin architecture for new AI types
- Scriptable boss encounters
- Modular ability system
- Event-driven interactions

## Risk Mitigation

### Performance Risks
- **Mitigation:** LOD system and smart culling
- **Monitoring:** Frame time profiler integration
- **Fallback:** Automatic quality scaling

### Complexity Risks
- **Mitigation:** Incremental implementation
- **Testing:** Automated performance regression tests
- **Documentation:** Clear architecture diagrams

### Integration Risks
- **Mitigation:** Backward compatibility maintained
- **Testing:** Existing gameplay validation suite
- **Rollback:** Feature flag system for new components

## Estimated Timeline: 4 weeks
- **Week 1:** Visual hierarchy (16 hours)
- **Week 2:** Animation system (20 hours)  
- **Week 3:** Advanced AI & bosses (20 hours)
- **Week 4:** Polish & optimization (16 hours)

**Total:** ~72 hours (9 development days)

## Next Steps After Phase 2
- Procedural enemy generation
- Player ability interaction system
- Advanced particle effects
- Multiplayer enemy synchronization