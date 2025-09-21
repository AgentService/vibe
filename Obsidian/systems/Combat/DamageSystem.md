# Damage System

## Current Implementation

**Files**: 
- `scripts/systems/damage_v2/DamageRegistry.gd` - Core damage processing
- `scripts/utils/RingBuffer.gd` - Zero-allocation circular buffer
- `scripts/utils/ObjectPool.gd` - Payload object pooling
- `scripts/utils/PayloadReset.gd` - Shape-preserving cleanup
- `autoload/DamageService.gd` - Single entry point

**Type**: System with Autoload Service Layer

## Architecture Overview

### Single Entry Point Pattern
All damage requests flow through a single entry point for consistency and performance optimization:

```gdscript
# Single damage entry point - used by all systems
DamageService.apply_damage(source_id, target_id, base_damage, damage_tags)
```

### Zero-Allocation Queue System
The damage system uses a revolutionary zero-allocation queue for batched processing:

- **Ring Buffer**: Power-of-two sized circular buffer with bit masking for efficient wraparound
- **Object Pooling**: Reused Dictionary payloads and Array instances to eliminate allocations
- **30Hz Batch Processing**: Aligned with combat tick rate for optimal performance
- **Drop-Oldest Policy**: Graceful overflow handling with metrics tracking

## Performance Metrics

**Current Performance** (as of cleanup):
- **568 damage events** processed at **0.0ms overhead**
- **4096 queue capacity** with **4096 object pool**
- **30Hz batched processing** aligned with combat step
- **Zero allocations** during steady-state operation

## Configuration

### Balance Configuration
Located in `data/balance/combat.tres`:

```gdscript
@export var use_zero_alloc_damage_queue: bool = true
@export var damage_queue_capacity: int = 4096
@export var damage_queue_pool_size: int = 4096
@export var damage_queue_process_hz: int = 30
```

### Feature Flags
- **Runtime toggling**: Supports A/B testing without restart
- **Fallback mode**: Direct processing when queue disabled
- **Metrics tracking**: Performance monitoring and overflow detection

## Console Commands

### Debug Commands Available
- `damage_queue_stats` - Show current queue metrics and performance
- `damage_queue_reset` - Clear queue and reset metrics (for testing)

**Note**: Zero-allocation queue is always enabled - it's the only damage processing mode.

### Usage Examples
```
> damage_queue_stats
Queue enabled: true
Current count: 12/4096 (0.3%)
Total processed: 568
Overflows: 0
Processing rate: 30Hz (0.0ms avg)
```

## Signal Integration

### Outgoing Signals
The damage system emits the following EventBus signals after processing:

- `damage_applied(payload)` - Single damage instance processed
- `damage_batch_applied(payload)` - Multiple damages (AoE attacks)
- `damage_entity_sync(payload)` - Unified entity HP updates
- `damage_dealt(payload)` - For camera shake and visual effects

### Signal Flow
```
DamageService.apply_damage() → Queue/Direct Processing → EventBus emissions → UI Updates
```

## Implementation Details

### Core Components

**DamageRegistry** (`scripts/systems/damage_v2/DamageRegistry.gd`):
- Handles actual damage calculations and application
- Manages zero-allocation queue when enabled
- Processes batched damage at 30Hz intervals
- Emits appropriate EventBus signals

**DamageService** (`autoload/DamageService.gd`):
- Provides single entry point API
- Routes to DamageRegistry for processing
- Maintains backward compatibility layer

**Zero-Allocation Utilities**:
- **RingBuffer**: Efficient circular buffer with power-of-two masking
- **ObjectPool**: Reusable object allocation for Dictionary/Array payloads
- **PayloadReset**: Shape-preserving cleanup to maintain zero allocations

### Queue Processing Flow

1. **Enqueue**: Damage requests added to ring buffer with pooled payloads
2. **Batch Processing**: Timer processes queue contents every 33.33ms (30Hz)
3. **Calculation**: Standard damage calculations applied to batched requests
4. **Signal Emission**: Results broadcasted via EventBus
5. **Cleanup**: Payloads returned to object pool for reuse

### Overflow Handling

- **Drop-Oldest Policy**: When queue full, oldest damage request is discarded
- **Metrics Tracking**: Overflow events logged and available via console
- **Graceful Degradation**: System continues operating with some damage loss
- **Alert System**: Warnings logged when approaching capacity limits

## Integration Patterns

### From Projectile Systems
```gdscript
# AbilitySystem.gd
func _on_projectile_hit(projectile_data, enemy):
    DamageService.apply_damage(
        projectile_data.source_id,
        enemy.entity_id,
        projectile_data.damage,
        projectile_data.tags
    )
```

### From Melee Systems
```gdscript
# MeleeSystem.gd  
func _process_melee_hits(enemies_hit: Array):
    for enemy in enemies_hit:
        DamageService.apply_damage(
            "player_melee",
            enemy.entity_id,
            calculate_melee_damage(),
            ["physical", "melee"]
        )
```

### Boss Attack Integration
```gdscript
# Boss attack scripts
func execute_attack():
    DamageService.apply_damage(
        entity_id,
        "player",
        attack_damage,
        ["boss", damage_type]
    )
```

## Testing & Validation

### Component Testing
- **Unit Tests**: Individual components (RingBuffer, ObjectPool) tested in isolation
- **Integration Tests**: Full queue system tested with real damage scenarios
- **Performance Tests**: Zero-allocation behavior validated under load

### A/B Testing Framework
- **Dual Mode Operation**: Can run with/without queue for comparison
- **Consistency Validation**: Ensures identical behavior between modes
- **Performance Monitoring**: Tracks allocation differences

## Troubleshooting

### Common Issues

**Queue Disabled Despite Configuration**:
- Check `data/balance/combat.tres` has `use_zero_alloc_damage_queue = true`
- Verify BalanceDB loaded configuration correctly
- Use `damage_queue_stats` to check actual state

**Performance Degradation**:
- Monitor queue capacity usage via `damage_queue_stats`
- Check for overflow events indicating queue too small
- Verify 30Hz processing timer is running correctly

**Missing Damage Events**:
- Check for queue overflows in stats
- Verify all damage sources use `DamageService.apply_damage()`
- Monitor EventBus signal emissions for dropped events

## Future Enhancements

### Potential Optimizations
- **SIMD Processing**: Batch mathematical operations for multiple damage instances
- **Hierarchical Queues**: Separate queues for different damage priorities
- **Predictive Sizing**: Dynamic queue capacity based on combat intensity

### Monitoring Improvements
- **Real-time Metrics**: Live performance dashboard during gameplay
- **Historical Analysis**: Track performance patterns across game sessions
- **Automated Alerts**: Warning system for performance degradation

## Related Systems

- [[EventBus-System]]: Signal integration and communication patterns
- [[Combat-Architecture]]: Overall combat system coordination
- [[Performance-Systems]]: Zero-allocation patterns and object pooling
- [[Balance-System]]: Configuration management and hot-reload patterns